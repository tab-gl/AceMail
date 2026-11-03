import 'package:ace_mail/models/message_security.dart';
import 'package:flutter_test/flutter_test.dart';

/// The reader's security chip is only worth anything if it reads the headers
/// the way the servers that wrote them meant them. These are real shapes: a
/// Gmail-delivered Amazon message, a forged one, a forwarder's soft fail, and
/// mail that arrived with no verdicts at all.
void main() {
  group('MessageSecurity.parse', () {
    test('reads a passing Gmail authentication header', () {
      const String headers = 'From: Amazon <ship-confirm@amazon.in>\n'
          'Subject: Your package has shipped\n'
          'Authentication-Results: mx.google.com;\n'
          '       dkim=pass header.i=@amazon.in header.s=abc123 header.b=xyz;\n'
          '       spf=pass (google.com: domain of ship-confirm@amazon.in '
          'designates 203.0.113.9 as permitted sender) '
          'smtp.mailfrom=ship-confirm@amazon.in;\n'
          '       dmarc=pass (p=REJECT sp=REJECT dis=NONE) '
          'header.from=amazon.in\n';

      final MessageSecurity security = MessageSecurity.parse(headers);

      expect(security.spf, AuthVerdict.pass);
      expect(security.dkim, AuthVerdict.pass);
      expect(security.dmarc, AuthVerdict.pass);
      expect(security.signedBy, 'amazon.in');
      expect(security.mailedBy, 'amazon.in');
      expect(security.reported, isTrue);
      expect(security.trust, SenderTrust.verified);
      expect(security.headline, 'Signed by amazon.in');
    });

    test('rejoins a header folded mid-method', () {
      // Some servers wrap between `dkim=` and its value. Splitting on the raw
      // lines instead of rejoining them turns `dkim=pass` into `dkim=` and the
      // message reads as unverified for no reason.
      const String headers = 'Authentication-Results: mx.example.com;\n'
          ' dkim=\n'
          ' pass header.d=example.com;\n'
          ' spf=pass smtp.mailfrom=example.com\n';

      final MessageSecurity security = MessageSecurity.parse(headers);

      expect(security.dkim, AuthVerdict.pass);
      expect(security.spf, AuthVerdict.pass);
      expect(security.signedBy, 'example.com');
    });

    test('flags a message whose SPF and DMARC failed', () {
      const String headers = 'From: PayPal <service@paypal.com>\n'
          'Authentication-Results: mx.example.net;\n'
          ' spf=fail smtp.mailfrom=evil.example;\n'
          ' dmarc=fail header.from=paypal.com\n';

      final MessageSecurity security = MessageSecurity.parse(headers);

      expect(security.spf, AuthVerdict.fail);
      expect(security.dmarc, AuthVerdict.fail);
      expect(security.trust, SenderTrust.suspicious);
      expect(security.headline, "Couldn't verify this sender");
      expect(security.detail, 'DMARC failed for this sender.');
    });

    test('a soft fail is not a warning', () {
      // What every forwarded message produces. Warning on it would put a red
      // chip on mail from every mailing list somebody is subscribed to.
      const String headers = 'Authentication-Results: mx.example.net;\n'
          ' spf=softfail smtp.mailfrom=forwarder.example;\n'
          ' dkim=pass header.d=example.org;\n'
          ' dmarc=none header.from=example.org\n';

      final MessageSecurity security = MessageSecurity.parse(headers);

      expect(security.spf, AuthVerdict.softFail);
      expect(security.trust, isNot(SenderTrust.suspicious));
      expect(security.trust, SenderTrust.unverified);
    });

    test('falls back to Received-SPF when there are no auth results', () {
      const String headers = 'From: a@example.com\n'
          'Received-SPF: pass (example.com: domain of a@example.com '
          'designates 203.0.113.9 as permitted sender)\n';

      final MessageSecurity security = MessageSecurity.parse(headers);

      expect(security.spf, AuthVerdict.pass);
      expect(security.dkim, AuthVerdict.unknown);
      // One method passing is not enough to call a sender verified.
      expect(security.trust, SenderTrust.unverified);
      expect(security.headline, 'Partially verified');
    });

    test('takes the signing domain from a DKIM-Signature', () {
      const String headers = 'From: a@example.com\n'
          'DKIM-Signature: v=1; a=rsa-sha256; c=relaxed/relaxed; d=example.com;\n'
          ' s=selector1; h=from:to:subject\n';

      final MessageSecurity security = MessageSecurity.parse(headers);

      expect(security.signedBy, 'example.com');
      // A signature is a claim, not a verdict: nothing here verified it.
      expect(security.dkim, AuthVerdict.unknown);
      expect(security.trust, SenderTrust.unverified);
    });

    test('reports nothing when the message carries nothing', () {
      const MessageSecurity security = MessageSecurity();
      expect(security.reported, isFalse);
      expect(security.trust, SenderTrust.unverified);
      expect(security.headline, 'No verification details');
      expect(MessageSecurity.parse('').reported, isFalse);
    });

    test('uses the topmost results block, not an earlier hop\'s', () {
      // Each server that handles a message prepends its own verdicts, so the
      // topmost block is the one from the server that accepted the message for
      // this mailbox. A block further down describes a different server's view
      // of a different hop.
      const String headers = 'Authentication-Results: mx.google.com; '
          'spf=pass smtp.mailfrom=example.com; dkim=pass header.d=example.com\n'
          'Authentication-Results: relay.internal; spf=fail smtp.mailfrom=x\n';

      final MessageSecurity security = MessageSecurity.parse(headers);

      expect(security.spf, AuthVerdict.pass);
      expect(security.trust, SenderTrust.verified);
    });

    test('a verdict it does not know is unknown, not a pass', () {
      const String headers =
          'Authentication-Results: mx.example.com; dkim=weird; dmarc=fail\n';

      final MessageSecurity security = MessageSecurity.parse(headers);

      expect(security.dkim, AuthVerdict.unknown);
      expect(security.dmarc, AuthVerdict.fail);
      expect(security.trust, SenderTrust.suspicious);
    });
  });

  group('MessageSecurity.splitHeaders', () {
    test('lowercases names and keeps repeated headers apart', () {
      final Map<String, List<String>> headers = MessageSecurity.splitHeaders(
        'Received: from a\n'
        'RECEIVED: from b\n'
        'Subject: hi\n',
      );

      expect(headers['received'], <String>['from a', 'from b']);
      expect(headers['subject'], <String>['hi']);
    });

    test('ignores a line that is not a header', () {
      final Map<String, List<String>> headers =
          MessageSecurity.splitHeaders('this is not a header\nSubject: ok\n');

      expect(headers['subject'], <String>['ok']);
      expect(headers.length, 1);
    });
  });
}

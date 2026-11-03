import 'package:flutter/foundation.dart';

/// One authentication method's verdict, as the receiving server reported it.
///
/// The names are the ones in the `Authentication-Results` header, because they
/// are the ones a person can look up: `pass`, `fail`, `softfail`, `neutral`,
/// `none`, `temperror`, `permerror`. Nothing here is inferred — a verdict this
/// app did not read is [unknown], which is a different thing from [none] (the
/// server looked and the domain publishes no record).
enum AuthVerdict {
  pass,
  fail,
  softFail,
  neutral,
  none,
  temporaryError,
  permanentError,

  /// The server said nothing about this method, or there was no
  /// `Authentication-Results` header at all.
  unknown;

  /// Whether this is a failure worth warning about.
  ///
  /// A `softfail` is deliberately *not* one. It is what a forwarder produces
  /// for mail that was perfectly genuine, so treating it as a failure would put
  /// a warning on mail from every mailing list somebody is subscribed to —
  /// which is how people learn to ignore the warning.
  bool get isFailure => this == fail || this == permanentError;

  bool get isPass => this == pass;

  /// Whether the server reached a verdict at all.
  bool get isKnown => this != unknown;

  /// The word the header uses, for showing the header's own answer back.
  String get label => switch (this) {
        AuthVerdict.pass => 'pass',
        AuthVerdict.fail => 'fail',
        AuthVerdict.softFail => 'softfail',
        AuthVerdict.neutral => 'neutral',
        AuthVerdict.none => 'none',
        AuthVerdict.temporaryError => 'temperror',
        AuthVerdict.permanentError => 'permerror',
        AuthVerdict.unknown => '—',
      };

  /// How much of a sentence this verdict is worth.
  String get description => switch (this) {
        AuthVerdict.pass => 'Passed',
        AuthVerdict.fail => 'Failed',
        AuthVerdict.softFail => 'Soft fail',
        AuthVerdict.neutral => 'Neutral',
        AuthVerdict.none => 'Not published',
        AuthVerdict.temporaryError => 'Temporary error',
        AuthVerdict.permanentError => 'Error',
        AuthVerdict.unknown => 'Not reported',
      };
}

/// What the headers say about who sent a message, in one word.
enum SenderTrust {
  /// The domain's own policy vouched for the message.
  verified,

  /// Nothing failed, but nothing proved it either — no `Authentication-Results`
  /// at all, or verdicts that are neither a pass nor a failure.
  unverified,

  /// A method failed. Not proof of forgery, but the one case worth saying out
  /// loud before somebody acts on the message.
  suspicious,
}

/// Who sent a message, according to the headers it arrived with.
///
/// This is the client's half of what Gmail puts behind the little arrow beside
/// the sender: *signed by*, *mailed by*, and whether the domain's own policy
/// passed. It reads headers that are already in hand — no DNS lookup, no
/// network, no verification performed here. The receiving server did the
/// checking; this reports what it said.
///
/// Being honest about that distinction is the whole design. Nothing in this
/// class claims to have verified a signature, because nothing here can: the
/// message is whatever the IMAP server handed over, and the only party that can
/// say a DKIM signature is good is the server that computed it.
@immutable
class MessageSecurity {
  const MessageSecurity({
    this.spf = AuthVerdict.unknown,
    this.dkim = AuthVerdict.unknown,
    this.dmarc = AuthVerdict.unknown,
    this.signedBy,
    this.mailedBy,
    this.encrypted = true,
  });

  final AuthVerdict spf;
  final AuthVerdict dkim;
  final AuthVerdict dmarc;

  /// The DKIM signing domain — `header.d=` — when the message carries one.
  ///
  /// A signature being present is not a signature that checked out: this is the
  /// domain that signed, and [dkim] is the separate question of whether the
  /// server liked the result.
  final String? signedBy;

  /// The domain the message was mailed from, as the server recorded it.
  final String? mailedBy;

  /// Whether the message reached this device over an encrypted connection.
  ///
  /// Always true in practice, and not a claim about the sender: it describes the
  /// connection *this app* made to *your* provider. The app refuses to talk to a
  /// server that will not encrypt — see `MailSecurity` in `ace_account.dart` and
  /// `test/transport_security_test.dart` — so there is no code path that sets
  /// this false today. It is a field rather than a constant so the reader can
  /// say it out loud without asserting something it did not check.
  final bool encrypted;

  /// Whether the receiving server reported anything at all.
  bool get reported => spf.isKnown || dkim.isKnown || dmarc.isKnown;

  /// The one-word answer the chip wears.
  SenderTrust get trust {
    if (dmarc.isFailure || spf.isFailure || dkim.isFailure) {
      return SenderTrust.suspicious;
    }
    // DMARC passing means SPF or DKIM passed *aligned with the From domain*,
    // which is the strongest thing a header can say. Without it, both methods
    // passing is the next best — they were checked, even if not aligned.
    if (dmarc.isPass || (spf.isPass && dkim.isPass)) {
      return SenderTrust.verified;
    }
    return SenderTrust.unverified;
  }

  /// The line under the sender, in the reader.
  String get headline => switch (trust) {
        SenderTrust.verified =>
          signedBy == null ? 'Verified sender' : 'Signed by $signedBy',
        SenderTrust.suspicious => "Couldn't verify this sender",
        SenderTrust.unverified =>
          reported ? 'Partially verified' : 'No verification details',
      };

  /// The second line, when there is something worth adding to [headline].
  String? get detail {
    if (trust == SenderTrust.suspicious) {
      final String failed = dmarc.isFailure
          ? 'DMARC'
          : spf.isFailure
              ? 'SPF'
              : 'DKIM';
      return '$failed failed for this sender.';
    }
    final String? mailed = mailedBy;
    if (mailed == null || mailed.isEmpty) return null;
    if (signedBy != null && signedBy == mailed) return null;
    return 'Mailed by $mailed';
  }

  /// Everything the header said, for the details sheet.
  Map<String, AuthVerdict> get verdicts => <String, AuthVerdict>{
        'SPF': spf,
        'DKIM': dkim,
        'DMARC': dmarc,
      };

  /// Reads the headers of a message that has already arrived.
  ///
  /// Tolerant by design: mail is full of headers that are nearly, but not
  /// quite, the shape the specification describes, and a parse that throws on
  /// one of them would take the reader down over a message that displays
  /// perfectly well. Anything unreadable is simply [AuthVerdict.unknown].
  static MessageSecurity parse(String rawHeaders) {
    if (rawHeaders.trim().isEmpty) return const MessageSecurity();
    final Map<String, List<String>> headers = splitHeaders(rawHeaders);

    // The receiving provider's own results come first in the header block, and
    // they are the ones that matter: an earlier hop's verdict describes a
    // different server's view. So the first readable one wins, and the next is
    // only tried when the first said nothing about SPF, DKIM or DMARC.
    String? authResults;
    for (final String value in <String>[
      ...?headers['authentication-results'],
      ...?headers['arc-authentication-results'],
    ]) {
      if (_reads(value)) {
        authResults = value;
        break;
      }
    }

    AuthVerdict spf = AuthVerdict.unknown;
    AuthVerdict dkim = AuthVerdict.unknown;
    AuthVerdict dmarc = AuthVerdict.unknown;
    String? signedBy;
    String? mailedBy;

    if (authResults != null) {
      // Everything before the first ';' is the authserv-id — the name of the
      // server that did the checking — and it is not a method.
      final int semicolon = authResults.indexOf(';');
      final String body =
          semicolon >= 0 ? authResults.substring(semicolon + 1) : authResults;

      for (final RegExpMatch match in _method.allMatches(body)) {
        final AuthVerdict verdict = _verdict(match.group(2)!);
        switch (match.group(1)!.toLowerCase()) {
          case 'spf':
            if (spf == AuthVerdict.unknown) spf = verdict;
          case 'dkim':
            if (dkim == AuthVerdict.unknown) dkim = verdict;
          case 'dmarc':
            if (dmarc == AuthVerdict.unknown) dmarc = verdict;
        }
      }

      // `header.d=` is the signing domain, but plenty of receivers report only
      // the identity — `header.i=@amazon.in` — which is the same domain said
      // differently. Falling back to it is what makes "Signed by amazon.in"
      // appear for mail from a provider that writes its results that way.
      signedBy = _domainOf(_firstGroup(body, _dkimDomain)) ??
          _domainOf(_firstGroup(body, _dkimIdentity));
      mailedBy = _domainOf(_firstGroup(body, _mailFrom)) ??
          _domainOf(_firstGroup(body, _headerFrom));
    }

    // Fallbacks, for providers that write the answer somewhere else. Plenty do:
    // `Received-SPF` predates `Authentication-Results` and is still common.
    if (spf == AuthVerdict.unknown) {
      for (final String value in headers['received-spf'] ?? const <String>[]) {
        final String word = value.trim().split(RegExp(r'[\s(]')).first;
        if (word.isNotEmpty) {
          spf = _verdict(word);
          if (spf.isKnown) break;
        }
      }
    }
    if (signedBy == null) {
      // A `DKIM-Signature` header is the sender's own claim, not a verdict —
      // which is exactly why only the *domain* is taken from it here, and why
      // `dkim` stays whatever the server said.
      for (final String value
          in headers['dkim-signature'] ?? const <String>[]) {
        signedBy = _domainOf(_firstGroup(value, _signatureDomain));
        if (signedBy != null) break;
      }
    }

    return MessageSecurity(
      spf: spf,
      dkim: dkim,
      dmarc: dmarc,
      signedBy: signedBy,
      mailedBy: mailedBy,
    );
  }

  /// Headers as name → values, lowercased, with folded lines rejoined.
  ///
  /// Public because the raw-header view and the security parse want the same
  /// reading of the same block, and two parsers would eventually disagree about
  /// a message with a folded `Authentication-Results`.
  static Map<String, List<String>> splitHeaders(String rawHeaders) {
    final Map<String, List<String>> out = <String, List<String>>{};
    String? current;
    final StringBuffer value = StringBuffer();

    void flush() {
      if (current == null) return;
      out.putIfAbsent(current, () => <String>[]).add(value.toString().trim());
      value.clear();
    }

    for (final String line in rawHeaders.split('\n')) {
      if (line.isEmpty) continue;
      // A continuation line starts with a space or a tab. Rejoining it with a
      // space rather than nothing keeps `dkim=pass` from becoming
      // `dkim=passheader.d=…` when a server wraps mid-method.
      if ((line.startsWith(' ') || line.startsWith('\t')) && current != null) {
        value
          ..write(' ')
          ..write(line.trim());
        continue;
      }
      final int colon = line.indexOf(':');
      if (colon <= 0) continue;
      flush();
      current = line.substring(0, colon).trim().toLowerCase();
      value.write(line.substring(colon + 1).trim());
    }
    flush();
    return out;
  }

  static bool _reads(String value) {
    final int semicolon = value.indexOf(';');
    final String body =
        semicolon >= 0 ? value.substring(semicolon + 1) : value;
    return _method.hasMatch(body);
  }

  static final RegExp _method = RegExp(
    r'\b(spf|dkim|dmarc)\s*=\s*([a-zA-Z]+)',
    caseSensitive: false,
  );

  /// `header.d=example.com` — the DKIM signing domain.
  static final RegExp _dkimDomain = RegExp(
    r'header\.d\s*=\s*([^\s;)]+)',
    caseSensitive: false,
  );

  /// `header.i=@example.com` — the DKIM identity, which carries the same
  /// domain when the receiver reports no `d=`.
  static final RegExp _dkimIdentity = RegExp(
    r'header\.i\s*=\s*([^\s;)]+)',
    caseSensitive: false,
  );

  /// `d=example.com` in a `DKIM-Signature` header.
  static final RegExp _signatureDomain = RegExp(
    r'(?:^|[;\s])d\s*=\s*([^;\s]+)',
    caseSensitive: false,
  );

  static final RegExp _mailFrom = RegExp(
    r'smtp\.mailfrom\s*=\s*([^\s;)]+)',
    caseSensitive: false,
  );

  static final RegExp _headerFrom = RegExp(
    r'header\.from\s*=\s*([^\s;)]+)',
    caseSensitive: false,
  );

  static String? _firstGroup(String text, RegExp pattern) =>
      pattern.firstMatch(text)?.group(1);

  /// The bare domain out of whatever the header wrote: `@example.com`,
  /// `<a@example.com>`, `"example.com"`.
  static String? _domainOf(String? value) {
    if (value == null) return null;
    String out = value.trim().replaceAll(RegExp(r'["<>]'), '');
    final int at = out.lastIndexOf('@');
    if (at >= 0 && at < out.length - 1) out = out.substring(at + 1);
    out = out.replaceAll(RegExp(r'[.,;:]+$'), '');
    if (out.isEmpty || out.contains(' ')) return null;
    return out.toLowerCase();
  }

  static AuthVerdict _verdict(String word) => switch (word.toLowerCase()) {
        'pass' => AuthVerdict.pass,
        'fail' => AuthVerdict.fail,
        'softfail' => AuthVerdict.softFail,
        'neutral' => AuthVerdict.neutral,
        'none' => AuthVerdict.none,
        'temperror' => AuthVerdict.temporaryError,
        'permerror' => AuthVerdict.permanentError,
        _ => AuthVerdict.unknown,
      };
}

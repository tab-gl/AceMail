import 'package:ace_mail/models/full_message.dart';
import 'package:ace_mail/models/message_summary.dart';
import 'package:ace_mail/services/chyme.dart';
import 'package:ace_mail/services/chyme_context.dart';
import 'package:ace_mail/services/chyme_tools.dart';
import 'package:flutter_test/flutter_test.dart';

MessageSummary summary(int uid, {String subject = 'Hello', bool seen = true}) {
  return MessageSummary(
    uid: uid,
    sequenceId: uid,
    subject: subject,
    fromName: 'Some One',
    fromEmail: 'someone@example.com',
    date: DateTime(2026, 10, 28, 9, 30),
    isSeen: seen,
    isFlagged: false,
    folderPath: 'INBOX',
  );
}

FullMessage openMessage(String body) {
  return FullMessage(
    uid: 1,
    subject: 'Hello',
    fromName: 'Some One',
    fromEmail: 'someone@example.com',
    toLine: 'me@example.com',
    ccLine: '',
    date: DateTime(2026, 10, 28, 9, 30),
    textBody: body,
    htmlBody: null,
    attachments: const <MailAttachment>[],
  );
}

void main() {
  group('the tool table is the one source', () {
    test('every tool the app can run is named in the prompt', () {
      // The registry and the prose used to be two descriptions of one contract,
      // and the drift was silent: the model was told about a tool that did not
      // exist, or had one it was never told about.
      for (final ChymeToolSpec spec in ChymeTools.all) {
        expect(
          Chyme.systemPrompt.contains(spec.name),
          isTrue,
          reason: 'the model cannot use a tool it was not told about: '
              '${spec.name}',
        );
      }
    });

    test('the prompt lists every tool exactly once', () {
      for (final String name in ChymeTools.names) {
        final int count = RegExp(
          '(^|\\n)\\s*${RegExp.escape(name)}\\s',
        ).allMatches(ChymeTools.promptList).length;
        expect(count, 1, reason: '$name is listed $count times');
      }
    });

    test('the tools that change mail are the ones that wait for a button', () {
      // Reading is what it was asked to do; changing mail is not.
      for (final String read in <String>['mail_search', 'message_read', 'contact_search']) {
        expect(ChymeTools.mutates(read), isFalse, reason: read);
      }
      for (final String writes in <String>[
        'message_star',
        'message_unstar',
        'message_mark_read',
        'message_archive',
        'message_delete',
        'message_reply',
        'contact_add',
        'contact_block',
        'contact_delete',
      ]) {
        expect(ChymeTools.mutates(writes), isTrue, reason: writes);
      }
    });

    test('a tool nobody wrote down is treated as changing mail', () {
      // The safe answer for an unknown name: propose it, do not run it.
      expect(ChymeTools.mutates('launch_missiles'), isTrue);
      expect(ChymeTools.byName('launch_missiles'), isNull);
    });

    test('the runtime handler contract can be checked without a widget', () {
      expect(ChymeTools.missingHandlers(ChymeTools.names), isEmpty);
      expect(ChymeTools.missingHandlers(<String>['message_read']), contains('mail_search'));
    });

    test('every spec has a name, an argument and a description', () {
      for (final ChymeToolSpec spec in ChymeTools.all) {
        expect(spec.name, isNotEmpty);
        expect(spec.argument, isNotEmpty);
        expect(spec.description, isNotEmpty);
        expect(spec.line, contains(spec.name));
      }
    });
  });

  group('the context Chyme is given', () {
    test('lists the mail, newest first, with the uid the tools use', () {
      final String text = ChymeContext.forMail(
        visible: <MessageSummary>[summary(7, subject: 'Invoice')],
        readsMail: true,
      );
      expect(text, contains('[7]'));
      expect(text, contains('Invoice'));
      expect(text, contains('someone@example.com'));
    });

    test('a folder is capped, so a big mailbox is not a big request', () {
      final String text = ChymeContext.forMail(
        visible: <MessageSummary>[
          for (int i = 1; i <= ChymeContext.maxSummaries + 10; i++) summary(i),
        ],
        readsMail: true,
      );
      expect(RegExp(r'^- \[', multiLine: true).allMatches(text).length,
          ChymeContext.maxSummaries);
    });

    test('the open message is included in full, up to the cap', () {
      final String long = 'x' * (ChymeContext.maxBodyCharacters + 500);
      final String text = ChymeContext.forMail(
        visible: <MessageSummary>[summary(1)],
        open: openMessage(long),
        readsMail: true,
      );
      expect(text, contains('The message they have open'));
      expect(text.length, lessThan(ChymeContext.maxBodyCharacters + 1000));
    });

    test('reading turned off says so instead of sending the mail', () {
      final String text = ChymeContext.forMail(
        visible: <MessageSummary>[summary(1, subject: 'Private')],
        readsMail: false,
      );
      expect(text, isNot(contains('Private')));
      expect(text.toLowerCase(), contains('turned off'));
    });

    test('an empty mailbox is a sentence, not an empty prompt', () {
      expect(
        ChymeContext.forMail(
          visible: const <MessageSummary>[],
          readsMail: true,
        ),
        'No mail is loaded at the moment.',
      );
    });
  });
}

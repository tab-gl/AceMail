import '../models/contact.dart';
import '../models/full_message.dart';
import '../models/message_summary.dart';
import 'chyme.dart';
import 'chyme_tools.dart';
import 'contacts.dart';
import '../state/mail_controller.dart';

typedef ChymeConfirm = Future<bool> Function({
  required String title,
  required String body,
  required String confirm,
  required String cancel,
});

typedef ChymeOpenReply = Future<void> Function({
  required MessageSummary message,
  required String body,
});

/// Runtime handlers for the model-facing tool specifications. UI operations
/// are injected; this service never owns a BuildContext or displays a dialog.
/// Once a user accepts a proposal, non-destructive work completes even if the
/// sheet closes. Destructive work that needs a second confirmation rechecks
/// the sheet before committing, so a dismissed dialog cannot authorize it.
class ChymeToolRegistry {
  static const int maxResults = 8;

  const ChymeToolRegistry({
    required this.controller,
    required this.confirm,
    required this.openReply,
    required this.isMounted,
  });

  final MailController controller;
  final ChymeConfirm confirm;
  final ChymeOpenReply openReply;
  final bool Function() isMounted;

  MessageSummary? find(String argument) {
    final String cleaned = argument.trim().toLowerCase();
    final MessageSummary? open = controller.openSummary;
    if (cleaned == 'open' || cleaned == 'current') return open;
    final String digits = cleaned.replaceAll(RegExp(r'[^0-9]'), '');
    final int? uid = int.tryParse(digits);
    if (uid == null) return null;
    if (open?.uid == uid) return open;
    for (final MessageSummary message in controller.visibleMessages) {
      if (message.uid == uid) return message;
    }
    return null;
  }

  String describe(FullMessage message) {
    final String body = message.textBody.trim();
    if (body.isEmpty) return 'The message has no readable text body.';
    return 'From ${message.fromName} — ${message.subject}\n\n${Chyme.truncateBody(body)}';
  }

  Map<String, ChymeTool> build() {
    final MailController controller = this.controller;
    final Map<String, ChymeTool> handlers = <String, ChymeTool>{
      // The message on screen, in full. The prompt already carries a shortened
      // copy so a question about it needs no tool at all; this is for the long
      // one, where the answer is further down than the excerpt.
      ChymeToolNames.read: (String argument) async {
        final MessageSummary? summary = find(argument);
        final FullMessage? open = controller.openMessage;
        if (summary == null && open == null) return 'No message is open.';
        if (summary != null && open != null && summary.uid == open.uid) {
          return describe(open);
        }
        if (summary == null) return describe(open!);
        // A row that is not open has no body in memory; opening it is what the
        // person would do, and it is what this does — through the controller,
        // so the reader follows.
        await controller.open(summary);
        final FullMessage? loaded = controller.openMessage;
        if (loaded == null) return 'That message could not be opened.';
        return describe(loaded);
      },
      ChymeToolNames.search: (String argument) async {
        final String needle = argument.toLowerCase().trim();
        if (needle.isEmpty) return 'No words to search for.';
        final List<MessageSummary> hits = controller.visibleMessages
            .where(
              (MessageSummary message) =>
                  message.subject.toLowerCase().contains(needle) ||
                  message.fromName.toLowerCase().contains(needle) ||
                  message.fromEmail.toLowerCase().contains(needle),
            )
            .take(maxResults)
            .toList();
        if (hits.isEmpty) {
          final String where = controller.selectedFolder?.name ?? 'this folder';
          return 'Nothing in $where matches "$argument".';
        }
        return hits
            .map((MessageSummary m) =>
                '[${m.uid}] ${m.fromName} — ${m.subject}')
            .join('\n');
      },
      ChymeToolNames.star: (String argument) async {
        final MessageSummary? message = find(argument);
        if (message == null) return 'No message with that number.';
        if (message.isFlagged) return 'Already starred: ${message.subject}.';
        await controller.toggleFlag(message);
        return 'Starred "${message.subject}".';
      },
      ChymeToolNames.unstar: (String argument) async {
        final MessageSummary? message = find(argument);
        if (message == null) return 'No message with that number.';
        if (!message.isFlagged) return 'Not starred: ${message.subject}.';
        await controller.toggleFlag(message);
        return 'Removed the star from "${message.subject}".';
      },
      ChymeToolNames.seen: (String argument) async {
        final MessageSummary? message = find(argument);
        if (message == null) return 'No message with that number.';
        if (message.isSeen) return 'Already read: ${message.subject}.';
        await controller.markRead(message);
        return 'Marked "${message.subject}" read.';
      },
      ChymeToolNames.archive: (String argument) async {
        final MessageSummary? message = find(argument);
        if (message == null) return 'No message with that number.';
        await controller.archive(message);
        return 'Archived "${message.subject}".';
      },
      ChymeToolNames.delete: (String argument) async {
        final MessageSummary? message = find(argument);
        if (message == null) return 'No message with that number.';
        if (!isMounted()) return 'The sheet closed; nothing was deleted.';
        final bool yes = await confirm(
          title: 'Delete this message?',
          body: '\u201C${message.subject}\u201D goes to the trash. You can put '
              'it back.',
          confirm: 'Delete',
          cancel: 'Keep',
        );
        if (!yes || !isMounted()) return 'The person kept "${message.subject}".';
        await controller.delete(message);
        return 'Moved "${message.subject}" to the trash.';
      },
      ChymeToolNames.reply: (String argument) async {
        final ChymeToolArgument parsed = ChymeToolArgument.parse(argument);
        final String body = parsed.tail ?? '';
        final MessageSummary? message = find(parsed.head);
        if (message == null) return 'No message with that number.';
        if (body.isEmpty) {
          return 'A reply needs a message number and a body, like: '
              'reply 12 | Thanks, I will look at it today.';
        }
        if (!isMounted()) return 'The sheet closed; no draft was opened.';
        await openReply(message: message, body: body);
        return 'Opened a reply to ${message.fromName}, in their composer, with '
            'that draft. They read it and send it.';
      },
      ChymeToolNames.contacts: (String argument) async {
        await Contacts.load();
        final String needle = argument.trim().toLowerCase();
        if (needle.isEmpty) return 'No name to look for.';
        final List<Contact> hits = Contacts.search(needle).take(maxResults).toList();
        if (hits.isEmpty) return 'Nobody in their contacts matches "$argument".';
        return hits
            .map((Contact c) =>
                '${c.label} <${c.email}>'
                '${c.saved ? ' · saved' : ''}'
                '${Contacts.isBlocked(c.email) ? ' · blocked' : ''}')
            .join('\n');
      },
      ChymeToolNames.contactAdd: (String argument) async {
        final ChymeToolArgument parsed = ChymeToolArgument.parse(argument);
        final String name = parsed.head;
        final String email = (parsed.tail ?? parsed.head).trim().toLowerCase();
        if (!email.contains('@')) {
          return 'That is not an address. Use: contact_add Name | a@b.com';
        }
        final Contact contact = await Contacts.add(
          email: email,
          name: email == name ? '' : name,
        );
        return 'Saved ${contact.label} <${contact.email}>.';
      },
      ChymeToolNames.contactBlock: (String argument) async {
        await Contacts.load();
        final String email = argument.trim().toLowerCase();
        if (!email.contains('@')) return 'That is not an address.';
        if (Contacts.isBlocked(email)) return '$email is already blocked.';
        if (!isMounted()) return 'The sheet closed; nothing was blocked.';
        final bool yes = await confirm(
          title: 'Block this address?',
          body: 'Mail from $email stops appearing in the list. Nothing is '
              'deleted, and unblocking brings it all back.',
          confirm: 'Block',
          cancel: 'Cancel',
        );
        if (!yes || !isMounted()) return 'The person did not block $email.';
        await Contacts.block(email);
        return 'Blocked $email. Their mail is hidden from the list.';
      },
      ChymeToolNames.contactDelete: (String argument) async {
        final String email = argument.trim().toLowerCase();
        if (!email.contains('@')) return 'That is not an address.';
        if (!isMounted()) return 'The sheet closed; nothing was removed.';
        final bool yes = await confirm(
          title: 'Forget this contact?',
          body: '$email is removed from your contacts here. Mail from them is '
              'untouched.',
          confirm: 'Forget',
          cancel: 'Cancel',
        );
        if (!yes || !isMounted()) return 'The person kept $email.';
        await Contacts.remove(email);
        return 'Removed $email from their contacts.';
      },
    };
    final List<String> missing = ChymeTools.missingHandlers(handlers.keys);
    final List<String> undocumented = handlers.keys
        .where((String name) => !ChymeTools.names.contains(name)).toList();
    if (missing.isNotEmpty || undocumented.isNotEmpty) {
      throw StateError('Chyme tool contract mismatch. Missing: $missing; undocumented: $undocumented');
    }
    return handlers;
  }
}

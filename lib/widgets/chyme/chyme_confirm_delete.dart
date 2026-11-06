import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/message_summary.dart';
import '../../state/mail_controller.dart';
import '../../util/ace_snack.dart';
import '../ace_confirm.dart';

/// Asks before it deletes, then moves the open message to the trash.
///
/// Chyme cannot delete anything by itself. It can say it would, and this is what
/// happens next: a question with the subject in it, and a way to say no.
/// Everything here is reversible — it goes to the trash, not away.
Future<void> confirmChymeDelete(BuildContext context) async {
  final MailController controller = context.read<MailController>();
  final MessageSummary? open = controller.openSummary;
  if (open == null) {
    AceSnack.show(context, 'Open the message first — there is nothing to delete.');
    return;
  }
  final bool yes = await aceConfirm(
    context,
    title: 'Delete this message?',
    body: '\u201C${open.subject}\u201D goes to the trash. You can put it back.',
    confirm: 'Delete',
    cancel: 'Keep',
    destructive: true,
  );
  if (!yes || !context.mounted) return;
  await controller.delete(open);
  if (context.mounted) AceSnack.show(context, 'Moved to the trash.');
}

/// One thing worth asking, as a card.

import '../models/full_message.dart';
import '../models/message_summary.dart';
import '../state/mail_controller.dart';

/// Naming a message, and describing one to the model.
///
/// Both are functions of data and nothing else — a controller's open summary
/// and visible list, or one loaded message — so they lived inside
/// `_ChymeSheetState` only because that is where the tool registry that uses
/// them happened to be. Here they can be tested with a fake controller instead
/// of by pumping a sheet, and the 6,000-character cap that keeps a long message
/// from becoming a long request sits in one place rather than inside a `State`.
abstract final class ChymeMessageRef {
  /// How much of a body a tool answer carries.
  ///
  /// Enough for a question about a long message to be answered from it, and
  /// small enough that a newsletter with a whole article in it does not fill
  /// the reply.
  static const int maxBody = 6000;

  /// The message a tool argument names, or null.
  ///
  /// Tolerant on purpose: a model will write `12`, `#12`, `[12]` and `uid 12`,
  /// and all four mean the same message. "open" means the one on screen, which
  /// is the only name that survives a list that has moved.
  static MessageSummary? find(MailController controller, String argument) {
    final String cleaned = argument.trim().toLowerCase();
    final MessageSummary? open = controller.openSummary;
    if (cleaned == 'open' || cleaned == 'current') return open;
    final String digits = cleaned.replaceAll(RegExp(r'[^0-9]'), '');
    final int? uid = int.tryParse(digits);
    if (uid == null) return open;
    if (open?.uid == uid) return open;
    for (final MessageSummary message in controller.visibleMessages) {
      if (message.uid == uid) return message;
    }
    return null;
  }

  /// One message, as a tool answer: who it is from, its subject, its text.
  static String describe(FullMessage message) {
    final String body = message.textBody.trim();
    final String html = message.htmlSource ?? '';
    final String text = body.isNotEmpty ? body : html;
    if (text.isEmpty) return 'The message has no readable body.';
    return 'From ${message.fromName} \u2014 ${message.subject}\n\n'
        '${text.length > maxBody ? '${text.substring(0, maxBody)}\u2026' : text}';
  }
}

import '../models/full_message.dart';
import '../models/message_summary.dart';
import '../util/dates.dart';
import 'chyme.dart';

/// What Chyme is told about the mail on screen.
///
/// Out of the widget, because it is a function of data and nothing else: a list
/// of summaries, one message maybe open, and whether the person has allowed the
/// assistant to read their mail. Being here means it can be tested with three
/// lists instead of by pumping a sheet, and the caps that keep a large folder
/// from becoming a large request are in one place rather than inside a `State`.
abstract final class ChymeContext {
  /// How many messages the prompt describes.
  ///
  /// Twenty-five is enough to answer "what needs answering today" and small
  /// enough that a mailbox with ten thousand messages costs the same request as
  /// a mailbox with thirty. The full bodies are not here — only what the list
  /// already shows.
  static const int maxSummaries = 25;
  static const int maxBodyCharacters = Chyme.maxBodyCharacters;

  /// The context block for [visible] and [open], or a sentence saying there is
  /// nothing to read.
  static String forMail({
    required List<MessageSummary> visible,
    FullMessage? open,
    required bool readsMail,
  }) {
    if (!readsMail) {
      return 'The person has turned off letting you read their mail. You can '
          'still help them write, and still answer questions about the app.';
    }

    final StringBuffer out = StringBuffer();
    if (visible.isNotEmpty) {
      out.writeln('Their recent mail, newest first:');
      for (final MessageSummary message
          in visible.take(maxSummaries)) {
        out.writeln(
          '- [${message.uid}] ${message.fromName} <${message.fromEmail}> · '
          '${message.subject}'
          ' · ${formatListDate(message.date)}'
          '${message.isSeen ? '' : ' · unread'}'
          '${message.isFlagged ? ' · starred' : ''}',
        );
      }
    }

    if (open != null) {
      final String body = open.textBody;
      out
        ..writeln()
        ..writeln('The message they have open, in full:')
        ..writeln('From: ${open.fromName} <${open.fromEmail}>')
        ..writeln('Subject: ${open.subject}')
        ..writeln('Date: ${open.date}')
        ..writeln('--- body ---')
        ..writeln(
          Chyme.truncateBody(body),
        );
    }

    if (out.isEmpty) return 'No mail is loaded at the moment.';
    return out.toString();
  }
}

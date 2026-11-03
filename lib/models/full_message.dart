import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';

import '../data/limits.dart';
import '../util/text.dart';
import '../util/file_names.dart';
import 'message_security.dart';

class MailAttachment {
  const MailAttachment({
    required this.fileName,
    required this.mediaType,
    required this.bytes,
  });

  final String fileName;
  final String mediaType;
  final Uint8List bytes;

  int get size => bytes.length;
}

/// A fully loaded message: headers, both body representations, and any
/// attachments already decoded.
class FullMessage {
  const FullMessage({
    required this.uid,
    required this.subject,
    required this.fromName,
    required this.fromEmail,
    required this.toLine,
    required this.ccLine,
    this.toEmails = '',
    this.ccEmails = '',
    required this.date,
    required this.textBody,
    required this.htmlBody,
    required this.attachments,
    this.skippedAttachments = 0,
    this.messageId,
    this.references,
    this.rawHeaders = '',
    this.security = const MessageSecurity(),
  });

  final int uid;
  final String subject;
  final String fromName;
  final String fromEmail;
  final String toLine;
  final String ccLine;

  /// Raw addresses, for building a reply-all.
  final String toEmails;
  final String ccEmails;
  final DateTime? date;
  final String textBody;
  final String? htmlBody;
  final List<MailAttachment> attachments;

  /// How many attachments were left out because of the size and count limits.
  final int skippedAttachments;

  /// The message's headers, as the server sent them.
  ///
  /// For the reader who wants to see what actually arrived — the route it took,
  /// the authentication results, the list-unsubscribe address — rather than
  /// what the client chose to show.
  final String rawHeaders;

  /// Who sent this, according to the headers it arrived with.
  ///
  /// Read once when the message is built rather than in the reader, because it
  /// is derived from [rawHeaders] and the reader rebuilds on every scroll tick
  /// — and because the cached copy carries the same headers, so the parse is
  /// identical whether the message came from the server or from the disk.
  final MessageSecurity security;

  bool get hasHtml => htmlBody != null && htmlBody!.trim().isNotEmpty;

  static final RegExp _htmlTag = RegExp(
    r'<\s*(html|body|div|p|table|br|span|a|td|tr)\b',
    caseSensitive: false,
  );

  /// The HTML to render: the real HTML part when there is one, otherwise a
  /// plain-text body that is plainly HTML. Senders do mislabel these, and
  /// rendering tags as text is worse than trusting the shape of the content.
  String? get htmlSource {
    if (hasHtml) return htmlBody;
    if (textBody.contains('<') && _htmlTag.hasMatch(textBody)) return textBody;
    return null;
  }

  /// Used to thread a reply: the message being answered, and its chain.
  final String? messageId;
  final String? references;

  /// This message as the local cache stores it.
  ///
  /// Attachments are deliberately absent. A cached message is one the cache can
  /// hand back **whole** — a cache that quietly loses the PDF you were sent is
  /// worse than no cache — so a message carrying attachments is simply not
  /// cached, and [isCacheable] is the test for that.
  Map<String, Object?> toCache() => <String, Object?>{
        'uid': uid,
        'subject': subject,
        'fromName': fromName,
        'fromEmail': fromEmail,
        'toLine': toLine,
        'ccLine': ccLine,
        'toEmails': toEmails,
        'ccEmails': ccEmails,
        'date': date?.toIso8601String(),
        'text': textBody,
        'html': htmlBody,
        'headers': rawHeaders,
        'messageId': messageId,
        'references': references,
      };

  /// Whether the cache can hold this message and give it back intact.
  bool get isCacheable => attachments.isEmpty;

  /// Rebuilds a message [toCache] wrote, or null when the record is not one.
  ///
  /// Null rather than a throw: a cache that cannot read its own record should
  /// fetch the message again, not bring the reader down.
  static FullMessage? fromCache(Map<String, Object?> record) {
    final Object? uid = record['uid'];
    final Object? subject = record['subject'];
    final Object? text = record['text'];
    if (uid is! int || subject is! String || text is! String) return null;

    final Object? html = record['html'];
    final Object? date = record['date'];
    return FullMessage(
      uid: uid,
      subject: subject,
      fromName: record['fromName'] as String? ?? '',
      fromEmail: record['fromEmail'] as String? ?? '',
      toLine: record['toLine'] as String? ?? '',
      ccLine: record['ccLine'] as String? ?? '',
      toEmails: record['toEmails'] as String? ?? '',
      ccEmails: record['ccEmails'] as String? ?? '',
      date: date is String ? DateTime.tryParse(date) : null,
      textBody: text,
      htmlBody: html is String ? html : null,
      attachments: const <MailAttachment>[],
      messageId: record['messageId'] as String?,
      references: record['references'] as String?,
      rawHeaders: record['headers'] as String? ?? '',
      // Derived, not stored: the headers are already in the record, and a
      // cached copy that keeps a second, separately-stored verdict could drift
      // from the headers it claims to describe.
      security: MessageSecurity.parse(record['headers'] as String? ?? ''),
    );
  }

  factory FullMessage.fromMime(MimeMessage message) {
    final MailAddress? from =
        (message.from != null && message.from!.isNotEmpty)
            ? message.from!.first
            : null;

    final List<MailAttachment> attachments = <MailAttachment>[];
    int total = 0;
    int skipped = 0;

    for (final ContentInfo info in message.findContentInfo()) {
      if (attachments.length >= MailLimits.maxAttachmentCount) {
        skipped++;
        continue;
      }

      // Check the declared size before decoding: decoding first would already
      // have spent the memory the limit exists to protect.
      final int? declared = info.size;
      if (declared != null && declared > MailLimits.maxAttachmentBytes) {
        skipped++;
        continue;
      }

      final Uint8List? bytes =
          message.getPart(info.fetchId)?.decodeContentBinary();
      if (bytes == null || bytes.isEmpty) continue;
      if (bytes.length > MailLimits.maxAttachmentBytes ||
          total + bytes.length > MailLimits.maxTotalAttachmentBytes) {
        skipped++;
        continue;
      }
      total += bytes.length;

      attachments.add(
        MailAttachment(
          fileName: sanitizeFileName(info.fileName ?? 'attachment'),
          mediaType: info.mediaType?.text ?? 'application/octet-stream',
          bytes: bytes,
        ),
      );
    }

    // Rendered once and parsed once: the security verdict and the headers view
    // are two readings of the same block, and re-rendering it for the second
    // would be a second chance for them to disagree.
    final String headers = _renderHeaders(message);

    return FullMessage(
      uid: message.uid ?? 0,
      subject: message.decodeSubject() ?? '(no subject)',
      fromName: from?.personalName ?? from?.email ?? '(unknown sender)',
      fromEmail: from?.email ?? '',
      toLine: _addresses(message.to),
      ccLine: _addresses(message.cc),
      toEmails: _emails(message.to),
      ccEmails: _emails(message.cc),
      date: message.decodeDate(),
      textBody: message.decodeTextPlainPart() ?? '',
      htmlBody: _capped(message.decodeTextHtmlPart()),
      attachments: attachments,
      skippedAttachments: skipped,
      messageId: message.getHeaderValue('message-id'),
      references: message.getHeaderValue('references'),
      rawHeaders: headers,
      security: MessageSecurity.parse(headers),
    );
  }

  /// The headers as text, in the order the server sent them.
  ///
  /// Capped: a message can carry a header block longer than its body, and this
  /// is for reading, not for archiving.
  static String _renderHeaders(MimeMessage message) {
    final List<Header>? headers = message.headers;
    if (headers == null || headers.isEmpty) return '';

    final StringBuffer out = StringBuffer();
    for (final Header header in headers) {
      if (out.length > MailLimits.maxHeaderBytes) {
        out.write('… (truncated)');
        break;
      }
      out.write(header.name);
      out.write(': ');
      out.write(header.value);
      out.write('\n');
    }
    return out.toString();
  }

  /// Truncate a body that is absurdly large rather than parse all of it.
  static String? _capped(String? html) {
    if (html == null) return null;
    if (html.length <= MailLimits.maxHtmlBytes) return html;
    return truncateSafely(html, MailLimits.maxHtmlBytes);
  }

  static String _emails(List<MailAddress>? list) => list == null
      ? ''
      : list
          .map((MailAddress a) => a.email)
          .where((String s) => s.isNotEmpty)
          .join(', ');

  static String _addresses(List<MailAddress>? list) => list == null
      ? ''
      : list
          .map((MailAddress a) => a.personalName ?? a.email)
          .where((String s) => s.isNotEmpty)
          .join(', ');
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import '../data/preferences.dart';
import '../models/full_message.dart';
import '../models/mail_folder.dart';
import '../models/message_summary.dart';
import '../screens/compose_screen.dart';
import '../state/mail_controller.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/addresses.dart';
import '../util/dates.dart';
import '../util/file_names.dart';
import '../util/files.dart';
import '../util/links.dart';
import '../util/text.dart';
import 'astryx_widgets.dart';
import 'folder_picker.dart';
import 'message_html.dart';
import 'security_chip.dart';
import 'avatar.dart';
import 'skeleton.dart';
import 'settings_group.dart';
import 'ace_icon_view.dart';

class MessageReader extends StatefulWidget {
  const MessageReader({super.key, this.onBack, this.onDismiss});

  /// The way back: the chevron in the toolbar, and the swipe to the right.
  ///
  /// Null where there is no page to go back to — a wide layout, where the
  /// reader is a pane that the list is always beside.
  final VoidCallback? onBack;

  /// How the message closes when that is not [onBack].
  ///
  /// In the sheet the way out is the drag handle or a swipe down, so a chevron
  /// on top of that would be a second door in the same wall. The actions that
  /// end the reading — delete, mark unread — still have to close it, and this
  /// is what they call.
  final VoidCallback? onDismiss;

  /// Whichever of the two closes the reader here.
  VoidCallback? get _close => onDismiss ?? onBack;

  @override
  State<MessageReader> createState() => _MessageReaderState();
}

class _MessageReaderState extends State<MessageReader> {
  bool _viewInitialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_viewInitialised) return;
    _viewInitialised = true;
  }

  /// Accumulated horizontal drag, for the swipe-right-to-go-back gesture.
  double _drag = 0;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final MailController controller = context.watch<MailController>();

    if (controller.loadingMessage) {
      return const MessageSkeleton();
    }

    final FullMessage? message = controller.openMessage;
    if (message == null) return _placeholder(c);

    return GestureDetector(
      // Swipe right to go back, the way Android gesture navigation works.
      onHorizontalDragStart:
          widget._close == null ? null : (DragStartDetails _) => _drag = 0,
      onHorizontalDragUpdate: widget._close == null
          ? null
          : (DragUpdateDetails details) =>
              _drag = details.delta.dx > 0 ? _drag + details.delta.dx : 0,
      onHorizontalDragEnd: widget._close == null
          ? null
          : (DragEndDetails details) {
              final double velocity = details.primaryVelocity ?? 0;
              if (_drag > 80 || velocity > 300) widget._close!.call();
              _drag = 0;
            },
      child: Container(
        color: c.backgroundSurface,
        child: Stack(
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // The toolbar sits in its own row above the message, so it
                // never covers the subject or the sender. It stays put while the
                // body scrolls underneath it.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AstryxSpace.s4,
                    AstryxSpace.s2,
                    AstryxSpace.s4,
                    AstryxSpace.s2,
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _actions(context, message),
                  ),
                ),
                Expanded(
                  // A flick sideways moves through the folder. Horizontal only:
                  // the body scrolls vertically, and a reader that also paged on
                  // a vertical fling would fight itself. Right is the message
                  // before, left the one after — the way a page turns.
                  child: GestureDetector(
                    onHorizontalDragEnd: (DragEndDetails details) {
                      final double velocity = details.primaryVelocity ?? 0;
                      if (velocity.abs() < 300) return;
                      unawaited(
                        context
                            .read<MailController>()
                            .openAdjacent(velocity < 0 ? 1 : -1),
                      );
                    },
                    // The message is a card, not a page. A reader that puts
                    // the mail on the same surface as the app is a reader you
                    // cannot tell from a settings screen; a card with a corner
                    // and air around it is one message, and the next one is a
                    // different card.
                    child: SingleChildScrollView(
                    // Clearance for the toolbar, which is at the top now.
                    padding: const EdgeInsets.fromLTRB(
                      AstryxSpace.s3,
                      0,
                      AstryxSpace.s3,
                      104,
                    ),
              child: Container(
                // The card: the raised surface, a large corner, and the same
                // padding on all four sides so the subject starts where the
                // body does.
                decoration: BoxDecoration(
                  color: c.backgroundCard,
                  borderRadius: BorderRadius.circular(AstryxRadius.lg),
                ),
                padding: const EdgeInsets.fromLTRB(
                  AstryxSpace.s4,
                  AstryxSpace.s4,
                  AstryxSpace.s4,
                  AstryxSpace.s5,
                ),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                    Text(
                      message.subject,
                      style: AstryxText.heading2(c.textPrimary),
                    ),
                    const SizedBox(height: AstryxSpace.s2),
                    _meta(c, message),
                    if (context.watch<Preferences>().showRawHeaders &&
                        message.rawHeaders.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AstryxSpace.s5),
                      _rawHeaders(context, c, message),
                    ],
                    if (message.attachments.isNotEmpty ||
                        message.skippedAttachments > 0) ...<Widget>[
                      const SizedBox(height: AstryxSpace.s4),
                      _attachments(context, c, message),
                      if (message.skippedAttachments > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: AstryxSpace.s2),
                          child: Text(
                            '${message.skippedAttachments} attachment(s) were too '
                            'large to open here.',
                            style: AstryxText.supporting(c.textSecondary),
                          ),
                        ),
                    ],
                    const SizedBox(height: AstryxSpace.s4),
                    Divider(height: 1, color: c.border),
                    const SizedBox(height: AstryxSpace.s4),
                      _body(c, message),
                    ],
                  ),
                  ),
                ),
              ),
                  ),
            ],
          ),
          ],
        ),
      ),
    );
  }

  /// The expressive floating toolbar.
  Widget _actions(BuildContext context, FullMessage message) {
    final bool flagged =
        context.watch<MailController>().openSummary?.isFlagged ?? false;

    return AceToolbar(
      actions: <AceToolbarAction>[
        // Only where a chevron is the way out. In the sheet the handle is.
        if (widget.onBack != null)
          AceToolbarAction(
            icon: AceIcons.chevronLeft,
            tooltip: 'Back',
            onPressed: widget.onBack!,
          ),
        AceToolbarAction(
          icon: AceIcons.reply,
          tooltip: 'Reply',
          onPressed: () => _reply(context, message),
        ),
        // No Chyme button here any more: the assistant has one way in — the
        // bar — and a reader toolbar with two of its controls in it was a
        // toolbar about the app rather than about the message.
        AceToolbarAction(
          icon: AceIcons.replyAll,
          tooltip: 'Reply all',
          onPressed: () => _reply(context, message, all: true),
        ),
        AceToolbarAction(
          icon: AceIcons.forward,
          tooltip: 'Forward',
          onPressed: () => _forward(context, message),
        ),
        AceToolbarAction(
          // Two glyphs, not one. The fill said which state it was in, but a
          // star and a star look the same at a glance, and the icon set has the
          // other one.
          icon: flagged ? AceIcons.star : AceIcons.starOff,
          tooltip: flagged ? 'Remove flag' : 'Flag',
          selected: flagged,
          onPressed: () => context.read<MailController>().toggleOpenFlagged(),
        ),
        AceToolbarAction(
          icon: AceIcons.mailUnread,
          tooltip: 'Mark as unread',
          onPressed: () {
            context.read<MailController>().markOpenUnread();
            widget._close?.call();
          },
        ),
        AceToolbarAction(
          icon: AceIcons.trash,
          tooltip: 'Delete',
          destructive: true,
          onPressed: () => _confirmDelete(context),
        ),
        // The rest, where the toolbar has run out of room: filing, and spam.
        AceToolbarAction(
          icon: AceIcons.more,
          tooltip: 'More',
          onPressed: () => _more(context, message),
        ),
      ],
    );
  }

  /// Everything that is a place to put the message rather than a thing to do
  /// with it.
  Future<void> _more(BuildContext context, FullMessage message) async {
    final AstryxColors c = context.astryx;
    final MailController controller = context.read<MailController>();
    final bool junk = controller.inJunk;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AstryxSpace.s5,
                0,
                AstryxSpace.s5,
                AstryxSpace.s2,
              ),
              child: Text(
                'This message',
                style: AstryxText.heading3(c.textPrimary),
              ),
            ),
            SettingsRow(
              icon: AceIcons.folder,
              title: 'Move to…',
              subtitle: 'File it in another folder.',
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final MessageSummary? summary = controller.openSummary;
                if (summary == null) return;
                final MailFolder? target = await showFolderPicker(
                  context,
                  folders: controller.filingFolders,
                  currentPath: summary.folderPath ??
                      controller.currentFolderPath,
                );
                if (target == null || !context.mounted) return;
                // The messenger is taken before the move: filing the open
                // message closes the reader, and a snack raised from a context
                // that has just gone is a snack raised at nothing.
                final ScaffoldMessengerState? messenger =
                    ScaffoldMessenger.maybeOf(context);
                await controller.moveMessageTo(summary, target);
                messenger?.showSnackBar(
                  SnackBar(content: Text('Moved to ${target.label}.')),
                );
              },
            ),
            SettingsRow(
              icon: junk ? AceIcons.inbox : AceIcons.warning,
              title: junk ? 'Not spam' : 'Mark as spam',
              subtitle: junk
                  ? 'Put it back in the inbox.'
                  : 'Move it to Junk. Nothing is reported to anybody.',
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final MessageSummary? summary = controller.openSummary;
                if (summary == null) return;
                final ScaffoldMessengerState? messenger =
                    ScaffoldMessenger.maybeOf(context);
                if (junk) {
                  await controller.markNotSpam(summary);
                } else {
                  await controller.markSpam(summary);
                }
                messenger?.showSnackBar(
                  SnackBar(
                    content: Text(
                      junk ? 'Moved back to the inbox.' : 'Moved to Junk.',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AstryxSpace.s3),
          ],
        ),
      ),
    );
  }

  /// Sends the message on: the body quoted under its own headers, and whatever
  /// was attached carried across.
  ///
  /// The attachments are the part most clients quietly drop and most people
  /// expect. They are written to a temporary directory so the composer can take
  /// them the same way it takes a file from the picker — one path for an
  /// attachment, whoever chose it.
  Future<void> _forward(BuildContext context, FullMessage message) async {
    final String subject = message.subject.toLowerCase().startsWith('fwd:')
        ? message.subject
        : 'Fwd: ${message.subject}';

    final StringBuffer quoted = StringBuffer()
      ..writeln()
      ..writeln('---------- Forwarded message ----------')
      ..writeln('From: ${message.fromName} <${message.fromEmail}>')
      ..writeln('Date: ${formatFullDate(message.date)}')
      ..writeln('Subject: ${message.subject}');
    if (message.toLine.isNotEmpty) quoted.writeln('To: ${message.toLine}');
    if (message.ccLine.isNotEmpty) quoted.writeln('Cc: ${message.ccLine}');
    quoted
      ..writeln()
      ..write(message.textBody);

    final List<File> carried = await _forwardAttachments(message);
    if (!context.mounted) return;
    await openComposeSheet(
      context,
      initialSubject: subject,
      initialBody: quoted.toString(),
      initialAttachments: carried,
    );
  }

  /// The message's attachments, as files the composer can take.
  ///
  /// Best effort, and silently so: a message whose attachments cannot be
  /// written is still worth forwarding, and a forward that refused because one
  /// attachment would not land would be worse than one that arrived with the
  /// text.
  Future<List<File>> _forwardAttachments(FullMessage message) async {
    if (message.attachments.isEmpty) return const <File>[];
    try {
      final Directory directory =
          await Directory.systemTemp.createTemp('ace-forward');
      final List<File> files = <File>[];
      for (final MailAttachment attachment in message.attachments) {
        final File file = File(
          '${directory.path}/${sanitizeFileName(attachment.fileName)}',
        );
        await file.writeAsBytes(attachment.bytes, flush: true);
        files.add(file);
      }
      return files;
    } catch (_) {
      return const <File>[];
    }
  }

  Widget _meta(AstryxColors c, FullMessage message) {
    // Who it is from, said once. Plenty of mail arrives with no display name at
    // all, and a blank line where the sender should be is a row that reads as
    // broken. So the address takes that line when there is no name, and the
    // second line appears only when it says something the first one did not.
    final String name = message.fromName.trim();
    final String email = message.fromEmail.trim();
    final bool named = name.isNotEmpty && name != email;
    final String from =
        named ? name : (email.isEmpty ? 'Unknown sender' : email);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        MailAvatar(email: email, name: name, size: 40),
        const SizedBox(width: AstryxSpace.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                from,
                overflow: TextOverflow.ellipsis,
                style: AstryxText.bodyStrong(c.textPrimary),
              ),
              if (named && email.isNotEmpty)
                Text(
                  email,
                  overflow: TextOverflow.ellipsis,
                  style: AstryxText.supporting(c.textSecondary),
                ),
              if (message.toLine.isNotEmpty)
                Text(
                  'To: ${message.toLine}',
                  style: AstryxText.supporting(c.textSecondary),
                ),
              if (message.ccLine.isNotEmpty)
                Text(
                  'Cc: ${message.ccLine}',
                  style: AstryxText.supporting(c.textSecondary),
                ),
              Text(
                formatFullDate(message.date),
                style: AstryxText.supporting(c.textSecondary),
              ),
              // The sender's authentication, where Gmail puts it: beside the
              // person, before the message. A line of its own rather than a
              // badge on the avatar, because the one case that matters — a
              // method failed — has to be readable as a sentence, and a glyph
              // on a picture is not.
              //
              // Only when the server said something. Plenty of small IMAP
              // hosts write no `Authentication-Results` at all, and a grey
              // "no details" pill on every message from them would be a line of
              // furniture that never has anything to say.
              if (message.security.reported) ...<Widget>[
                const SizedBox(height: AstryxSpace.s1_5),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SecurityChip(
                    security: message.security,
                    sender: email,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// The headers, in a box that scrolls on its own so a long Received chain
  /// does not turn the message into a wall of text.
  Widget _rawHeaders(BuildContext context, AstryxColors c, FullMessage message) {
    return Container(
      padding: const EdgeInsets.all(AstryxSpace.s3),
      decoration: BoxDecoration(
        color: c.backgroundMuted,
        borderRadius: BorderRadius.circular(AstryxRadius.element),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              AceIconView(icon: AceIcons.headers, size: 15, color: c.iconSecondary),
              const SizedBox(width: AstryxSpace.s2),
              Text('Headers', style: AstryxText.label(c.textSecondary)),
            ],
          ),
          const SizedBox(height: AstryxSpace.s2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: SingleChildScrollView(
              child: SelectableText(
                message.rawHeaders,
                style: AstryxText.supporting(c.textSecondary).copyWith(
                  fontFamily: 'monospace',
                  fontSize: AstryxType.sXs,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _attachments(
    BuildContext context,
    AstryxColors c,
    FullMessage message,
  ) {
    return Wrap(
      spacing: AstryxSpace.s2,
      runSpacing: AstryxSpace.s2,
      children: message.attachments.map((MailAttachment attachment) {
        return Material(
          color: c.accentMuted,
          borderRadius: BorderRadius.circular(AstryxRadius.full),
          child: InkWell(
            borderRadius: BorderRadius.circular(AstryxRadius.full),
            onTap: () => _saveAttachment(context, attachment),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AstryxSpace.s3,
                vertical: AstryxSpace.s2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AceIconView(icon: 
                    AceIcons.attachment,
                    size: 15,
                    color: c.textAccent,
                  ),
                  const SizedBox(width: AstryxSpace.s1_5),
                  Text(
                    attachment.fileName,
                    style: AstryxText.label(c.textAccent),
                  ),
                  const SizedBox(width: AstryxSpace.s2),
                  Text(
                    formatBytes(attachment.size),
                    style: AstryxText.supporting(c.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _body(AstryxColors c, FullMessage message) {
    // HTML first: it is what most mail is, and a plain-text body that is
    // plainly HTML is rendered as HTML rather than as tags.
    final String? html = message.htmlSource;
    // HTML when there is HTML. There is no plain-text mode: a message with both
    // is shown as it was written, and one with only text is shown as text
    // because that is all there is.
    final bool showHtml = html != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showHtml)
          _HtmlBody(
            html: html,
            confirmLink: (Uri uri) => _confirmLink(context, uri),
          )
        else
          _PlainBody(
            text: message.textBody,
            confirmLink: (Uri uri) => _confirmLink(context, uri),
          ),
      ],
    );
  }

  Widget _placeholder(AstryxColors c) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const BrandMark(size: 56),
          const SizedBox(height: AstryxSpace.s4),
          Text(
            'Select a message to read it.',
            style: AstryxText.body(c.textSecondary),
          ),
        ],
      ),
    );
  }

  /// `References` is the existing chain plus this message's id, which is what
  /// keeps a reply in the same conversation in every client.
  static String? _referencesFor(FullMessage message) {
    final List<String> parts = <String>[
      if (message.references != null && message.references!.trim().isNotEmpty)
        message.references!.trim(),
      if (message.messageId != null && message.messageId!.trim().isNotEmpty)
        message.messageId!.trim(),
    ];
    return parts.isEmpty ? null : parts.join(' ');
  }

  Future<void> _reply(
    BuildContext context,
    FullMessage message, {
    bool all = false,
  }) async {
    final String subject = message.subject.toLowerCase().startsWith('re:')
        ? message.subject
        : 'Re: ${message.subject}';

    String cc = '';
    if (all) {
      final String self = context.read<MailController>().account?.email ?? '';
      // Everyone the original went to, minus this account and minus the
      // person it is already addressed to.
      final Set<String> others = <String>{
        ...MailAddresses.excluding(
          message.toEmails,
          <String>[self, message.fromEmail],
        ).map((a) => a.email),
        ...MailAddresses.excluding(
          message.ccEmails,
          <String>[self, message.fromEmail],
        ).map((a) => a.email),
      };
      cc = others.join(', ');
    }

    // Quoting the original is the default, because a reply that carries the
    // message it answers is one the recipient can read without hunting. Off,
    // the reply starts empty — and the signature, if there is one, takes its
    // usual place at the top.
    final bool quote = context.read<Preferences>().quoteReplies;

    await openComposeSheet(
      context,
      initialTo: message.fromEmail,
      initialCc: cc,
      initialSubject: subject,
      initialBody:
          quote ? '\n\n--- Original message ---\n${message.textBody}' : '',
      inReplyTo: message.messageId,
      references: _referencesFor(message),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final MailController controller = context.read<MailController>();
    // No Trash folder means a permanent delete, which has to be asked for
    // explicitly and said plainly. So does being *in* the Trash: a message
    // there has nowhere left to go, and `canDeleteSafely` — which only asks
    // whether the account has a Trash folder — was the wrong question. It used
    // to copy the message into the folder it already sat in and leave it there,
    // while its row disappeared from the list and read as a success.
    final bool safe = controller.canDeleteSafely && !controller.inTrash;

    // The user can turn the question off — but never for a permanent delete,
    // which is the one case where asking is the whole point.
    if (!context.read<Preferences>().confirmDelete && safe) {
      await controller.deleteOpenMessage();
      if (context.mounted) widget._close?.call();
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(safe ? 'Move to Trash?' : 'Delete permanently?'),
        content: Text(
          safe
              ? 'The message will be moved to Trash.'
              : 'This account has no Trash folder, so the message will be '
                  'deleted permanently and cannot be recovered.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(safe ? 'Move to Trash' : 'Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await controller.deleteOpenMessage(permanently: !safe);
      if (context.mounted) widget._close?.call();
    }
  }

  Future<void> _saveAttachment(
    BuildContext context,
    MailAttachment attachment,
  ) async {
    // Captured before the await: the sheet may be gone by the time it returns.
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    try {
      final String? path = await saveAttachmentFile(
        attachment.fileName,
        attachment.bytes,
      );
      if (path != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('Saved to $path')));
      }
    } catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Could not save: $error')));
    }
  }
}

Future<bool> _confirmLink(BuildContext context, Uri uri) async {
  if (!context.mounted) return false;
  if (!context.read<Preferences>().warnExternalLinks) return true;

  final bool? go = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      final AstryxColors c = sheetContext.astryx;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AstryxSpace.s5,
            0,
            AstryxSpace.s5,
            AstryxSpace.s5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  AceIconView(icon: AceIcons.warning, size: 18, color: c.warning),
                  const SizedBox(width: AstryxSpace.s2),
                  Text('Open this link?', style: AstryxText.heading3(c.textPrimary)),
                ],
              ),
              const SizedBox(height: AstryxSpace.s3),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AstryxSpace.s3),
                decoration: BoxDecoration(
                  color: c.backgroundMuted,
                  borderRadius: BorderRadius.circular(AstryxRadius.element),
                ),
                // The host, first and larger. It is the only part of a link
                // that says where you are going, and a long URL buries it —
                // which is exactly what a deceptive link is built to rely on.
                // The whole address is still here, underneath, because the
                // path is sometimes the thing you are checking.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      uri.host.isEmpty ? uri.toString() : uri.host,
                      style: AstryxText.heading4(c.textPrimary),
                    ),
                    if (uri.host.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AstryxSpace.s1),
                      Text(
                        uri.toString(),
                        style: AstryxText.supporting(c.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AstryxSpace.s3),
              Text(
                'This leaves Ace Mail and opens in another app.',
                style: AstryxText.supporting(c.textSecondary),
              ),
              const SizedBox(height: AstryxSpace.s5),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AceButton(
                      label: 'Cancel',
                      variant: AceButtonVariant.tonal,
                      expand: true,
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                    ),
                  ),
                  const SizedBox(width: AstryxSpace.s3),
                  Expanded(
                    child: AceButton(
                      label: 'Open',
                      variant: AceButtonVariant.primary,
                      expand: true,
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return go ?? false;
}

/// The body of a message, rendered.
///
/// Stateless: the renderer owns its own lifecycle, so there are no recognisers
/// to release here, and nothing to rebuild by hand when the image setting
/// changes — [AceHtml] watches it.
class _HtmlBody extends StatelessWidget {
  const _HtmlBody({required this.html, required this.confirmLink});

  final String html;
  final Future<bool> Function(Uri uri) confirmLink;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final Preferences prefs = context.watch<Preferences>();

    return SelectionArea(
      child: AceHtml(
        html: html,
        baseStyle: AstryxText.body(c.textPrimary),
        linkColor: c.textAccent,
        codeStyle: AstryxText.body(c.textPrimary).copyWith(
          fontFamily: 'monospace',
          fontSize: AstryxType.sSm,
        ),
        // This is the line that makes the switch in Settings do anything.
        loadRemoteImages: prefs.loadRemoteImages,
        confirmLink: confirmLink,
      ),
    );
  }
}

/// A plain-text body with its links tappable.
///
/// `SelectableText` on its own draws a URL as a URL and does nothing when it is
/// tapped, which is worse than not looking like one: the text says "click
/// here" and the screen disagrees. Stateful because a `TapGestureRecognizer`
/// owns resources and has to be disposed — one per link, rebuilt on every
/// build, so they are cleared before they are replaced.
class _PlainBody extends StatefulWidget {
  const _PlainBody({required this.text, required this.confirmLink});

  final String text;
  final Future<bool> Function(Uri uri) confirmLink;

  @override
  State<_PlainBody> createState() => _PlainBodyState();
}

class _PlainBodyState extends State<_PlainBody> {
  final List<TapGestureRecognizer> _recognisers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    _clearRecognisers();
    super.dispose();
  }

  void _clearRecognisers() {
    for (final TapGestureRecognizer recogniser in _recognisers) {
      recogniser.dispose();
    }
    _recognisers.clear();
  }

  Future<void> _open(Uri uri) async {
    // The same two checks the formatted path makes, in the same order: the
    // scheme policy first, then the person.
    if (!mayOpenLink(uri)) return;
    if (!await widget.confirmLink(uri)) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Nothing installed that can handle it.
    }
  }

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    _clearRecognisers();

    final String text = widget.text.isEmpty
        ? '(This message has no text.)'
        : collapseBlankLines(widget.text);

    final List<InlineSpan> spans = <InlineSpan>[];
    int at = 0;
    for (final LinkSpan link in findLinks(text)) {
      if (link.start > at) {
        spans.add(TextSpan(text: text.substring(at, link.start)));
      }
      final TapGestureRecognizer recogniser = TapGestureRecognizer()
        ..onTap = () => _open(link.uri);
      _recognisers.add(recogniser);
      spans.add(
        TextSpan(
          text: text.substring(link.start, link.end),
          style: TextStyle(
            color: c.textAccent,
            decoration: TextDecoration.underline,
            decorationColor: c.textAccent,
          ),
          recognizer: recogniser,
        ),
      );
      at = link.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));

    return SelectableText.rich(
      TextSpan(style: AstryxText.body(c.textPrimary), children: spans),
    );
  }
}

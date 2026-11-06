import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../../screens/compose_screen.dart';
import '../../services/chyme.dart';
import '../../theme/ace_icons.dart';
import '../../theme/astryx_theme.dart';
import '../../theme/astryx_tokens.dart';
import '../../util/ace_snack.dart';
import '../astryx_widgets.dart';
import '../markdown_view.dart';
import 'chyme_confirm_delete.dart';

/// One turn, as a bubble.
class ChymeBubble extends StatelessWidget {
  const ChymeBubble({
    required this.turn,
    required this.onReply,
    this.canReply = false,
  });

  final ChymeTurn turn;

  /// Opens the composer with this text in it, as a reply to the open message.
  final Future<void> Function(String body) onReply;

  /// Whether there is a message to reply to.
  final bool canReply;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final bool mine = turn.role == 'user';
    final String text = mine
        ? turn.content
        : Chyme.withoutSearchLine(turn.content);

    return Padding(
      padding: const EdgeInsets.only(bottom: AstryxSpace.s3),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: <Widget>[
          // What Chyme wrote is the useful part, and there are only ever three
          // things anybody wants to do with it: keep it, reply with it, or
          // start a new message with it. All are one tap rather than a
          // selection and a long press.
          if (!mine)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                AceIconButton(
                  icon: AceIcons.copy,
                  tooltip: 'Copy',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) AceSnack.show(context, 'Copied.');
                  },
                ),
                if (canReply)
                  AceIconButton(
                    icon: AceIcons.reply,
                    tooltip: 'Reply with this',
                    onPressed: () => onReply(text),
                  ),
                AceIconButton(
                  icon: AceIcons.edit,
                  tooltip: 'Start a message with this',
                  onPressed: () => openComposeSheet(context, initialBody: text),
                ),
                // Only when the reply asked to delete, and only as a question.
                // A model may propose; the app asks; the person decides.
                if (Chyme.deleteFrom(text))
                  AceIconButton(
                    icon: AceIcons.trash,
                    tooltip: 'Delete this message',
                    onPressed: () => confirmChymeDelete(context),
                  ),
              ],
            ),
          Row(
            mainAxisAlignment: mine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: <Widget>[
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AstryxSpace.s4,
                    vertical: AstryxSpace.s3,
                  ),
                  decoration: BoxDecoration(
                    color: mine ? c.accent : c.backgroundMuted,
                    borderRadius: BorderRadius.circular(AstryxRadius.container),
                  ),
                  // What Chyme writes is Markdown, and it reads as Markdown when it
                  // is rendered as Markdown. What the person types is not, and is
                  // shown exactly as typed.
                  child: mine
                      ? SelectableText(text, style: AstryxText.body(c.onAccent))
                      : MarkdownView(
                          source: text,
                          onLink: (String url) =>
                              openMarkdownLink(context, url),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The search a reply asked for, offered rather than run.

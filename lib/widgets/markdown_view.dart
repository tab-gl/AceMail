import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';

import '../theme/astryx_tokens.dart';
import '../theme/astryx_theme.dart';
import '../util/links.dart';
import '../util/markdown.dart';

/// Renders Markdown in the app's own type.
///
/// Links are tappable and carry the accent; code is monospaced on the raised
/// surface. Nothing here is a Markdown *viewer* — there are no tables, no
/// footnotes, no raw HTML — because what it renders is a chat reply.
///
/// The parsing itself lives in `util/markdown.dart`. Stateful for two reasons:
/// the blocks are parsed once per source rather than once per build (this sits
/// inside chat and changelog surfaces that rebuild on scroll, on token arrival
/// and on theme change), and a `TapGestureRecognizer` owns resources and has to
/// be disposed — the same pattern `_PlainBodyState` in `message_reader.dart`
/// uses for the plain-text body.
class MarkdownView extends StatefulWidget {
  const MarkdownView({super.key, required this.source, this.onLink});

  final String source;

  /// Called when a link is tapped. Left null, links are drawn but inert.
  final void Function(String url)? onLink;

  @override
  State<MarkdownView> createState() => _MarkdownViewState();
}

class _MarkdownViewState extends State<MarkdownView> {
  /// Compiled once rather than per inline block per build.
  static final RegExp _inlinePattern = RegExp(
    r'(`[^`]+`)' // code
    r'|(\*\*[^*]+\*\*)' // bold
    r'|(__[^_]+__)' // bold, the other way
    r'|(\*[^*\n]+\*)' // italic
    r'|(\[[^\]]+\]\([^)]+\))', // link
  );

  /// The link pattern the alternation above guarantees, matched against a token
  /// that has already been found — so a failure here degrades to plain text
  /// instead of throwing inside a frame.
  static final RegExp _linkPattern = RegExp(r'^\[([^\]]+)\]\(([^)]+)\)$');

  late List<MdBlock> _blocks;
  final List<TapGestureRecognizer> _recognisers = <TapGestureRecognizer>[];

  @override
  void initState() {
    super.initState();
    _blocks = parseMarkdown(widget.source);
  }

  @override
  void didUpdateWidget(MarkdownView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _clearRecognisers();
      _blocks = parseMarkdown(widget.source);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    // The spans are rebuilt below, so last build's recognisers are done.
    _clearRecognisers();

    final List<Widget> children = <Widget>[];

    for (final MdBlock block in _blocks) {
      if (children.isNotEmpty) children.add(const SizedBox(height: AstryxSpace.s2));

      switch (block) {
        case MdHeading(:final int level, :final String text):
          children.add(
            Text.rich(
              TextSpan(children: _inline(context, text)),
              style: switch (level) {
                1 => AstryxText.heading2(c.textPrimary),
                2 => AstryxText.heading3(c.textPrimary),
                _ => AstryxText.label(c.textPrimary),
              },
            ),
          );
        case MdParagraph(:final String text):
          children.add(
            Text.rich(
              TextSpan(children: _inline(context, text)),
              style: AstryxText.body(c.textPrimary).copyWith(height: 1.45),
            ),
          );
        case MdList(:final List<String> items, :final bool ordered):
          for (int n = 0; n < items.length; n++) {
            children.add(
              Padding(
                padding: const EdgeInsets.only(bottom: AstryxSpace.s1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: 22,
                      child: Text(
                        ordered ? '${n + 1}.' : '·',
                        style: AstryxText.body(c.textSecondary),
                      ),
                    ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: _inline(context, items[n])),
                        style:
                            AstryxText.body(c.textPrimary).copyWith(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        case MdQuote(:final String text):
          children.add(
            Container(
              padding: const EdgeInsets.fromLTRB(
                AstryxSpace.s3,
                AstryxSpace.s1,
                AstryxSpace.s1,
                AstryxSpace.s1,
              ),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: c.accent, width: 3),
                ),
              ),
              child: Text.rich(
                TextSpan(children: _inline(context, text)),
                style: AstryxText.body(c.textSecondary),
              ),
            ),
          );
        case MdCode(:final String code):
          children.add(
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AstryxSpace.s3),
              decoration: BoxDecoration(
                color: c.backgroundMuted,
                borderRadius: BorderRadius.circular(AstryxRadius.inner),
              ),
              child: SelectableText(
                code,
                style: AstryxText.supporting(c.textPrimary).copyWith(
                  fontFamily: 'monospace',
                  height: 1.4,
                ),
              ),
            ),
          );
        case MdRule():
          children.add(Divider(color: c.border, height: AstryxSpace.s4));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  /// The inline rules: code, bold, italic, links.
  ///
  /// The alternation order is load-bearing: `**` is tried before `*` so bold
  /// wins over italic, and the link form comes last so its brackets are not
  /// mistaken for anything else.
  List<InlineSpan> _inline(BuildContext context, String text) {
    final AstryxColors c = context.astryx;
    final List<InlineSpan> spans = <InlineSpan>[];

    int index = 0;
    for (final RegExpMatch match in _inlinePattern.allMatches(text)) {
      if (match.start > index) {
        spans.add(TextSpan(text: text.substring(index, match.start)));
      }
      final String token = match.group(0)!;

      if (token.startsWith('`')) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: AstryxText.body(c.textPrimary).copyWith(
              fontFamily: 'monospace',
              backgroundColor: c.backgroundMuted,
            ),
          ),
        );
      } else if (token.startsWith('**') || token.startsWith('__')) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        );
      } else if (token.startsWith('*')) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      } else {
        final RegExpMatch? link = _linkPattern.firstMatch(token);
        if (link == null) {
          // Cannot happen for a token the alternation matched; falling back to
          // plain text is still better than a null assertion inside build.
          spans.add(TextSpan(text: token));
          index = match.end;
          continue;
        }
        final String label = link.group(1)!;
        final String url = link.group(2)!;
        final void Function(String url)? onLink = widget.onLink;
        TapGestureRecognizer? recogniser;
        if (onLink != null) {
          recogniser = TapGestureRecognizer()..onTap = () => onLink(url);
          _recognisers.add(recogniser);
        }
        spans.add(
          TextSpan(
            text: label,
            style: AstryxText.body(c.textAccent).copyWith(
              decoration: TextDecoration.underline,
              decorationColor: c.textAccent.withValues(alpha: 0.4),
            ),
            recognizer: recogniser,
          ),
        );
      }
      index = match.end;
    }

    if (index < text.length) spans.add(TextSpan(text: text.substring(index)));
    return spans;
  }
}

/// Opens a link the way the rest of the app does, or refuses politely.
///
/// The same two checks the message renderer makes — a scheme this app is
/// willing to hand over, and the user's own confirmation when they have asked
/// for one — because a link in an assistant's reply is no more trustworthy than
/// a link in a message.
Future<void> openMarkdownLink(
  BuildContext context,
  String url, {
  Future<bool> Function(Uri uri)? confirmLink,
}) async {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null || !mayOpenLink(uri)) return;
  if (confirmLink != null && !await confirmLink(uri)) return;

  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // Nothing installed that can handle it. The reply is still on screen, so
    // the URL is not lost.
  }
}

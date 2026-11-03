import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:html/dom.dart' as dom;
import 'package:url_launcher/url_launcher.dart';

import '../data/limits.dart';
import '../util/text.dart';
import '../util/links.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import 'ace_icon_view.dart';

/// A message body, as HTML.
///
/// Mail is HTML, and mail HTML is a museum of it: layout tables inside layout
/// tables, inline styles, unclosed tags, quoted-printable soft breaks, and a
/// `<style>` block that contradicts all of it. Hand-writing a renderer for that
/// is a losing game — it is what this file replaces.
///
/// So this is `flutter_widget_from_html_core`, the renderer the Flutter
/// ecosystem settled on. It is the same *kind* of thing a desktop mail client
/// uses: a real HTML parser plus a CSS cascade, turned into native widgets
/// rather than into a browser. A WebView — what Gmail and Outlook put on a
/// phone — would render more of the web's CSS, and would also put a browser
/// engine, its own scrolling, its own text selection and its own layout pass in
/// the middle of a list that is supposed to feel like the rest of the app. This
/// renders in the app's own frame budget, in the app's own type, and hands
/// anything long to an isolate to parse.
///
/// What is still this app's decision, and not the renderer's:
///
/// * **Remote images are not fetched** unless the setting says so. An
///   `<img src="https://…">` is a read receipt: it tells the sender's server
///   that the message was opened, and from where.
/// * **Only `http`, `https` and `mailto` are ever handed to the platform.**
///   `javascript:`, `data:`, `file:` and arbitrary app schemes are dropped.
/// * **Links are confirmed first**, when the reader asked to be asked.
/// * Nothing here executes anything. Scripts and styles are inert: this draws.
class AceHtml extends StatelessWidget {
  const AceHtml({
    super.key,
    required this.html,
    required this.baseStyle,
    required this.linkColor,
    required this.codeStyle,
    required this.loadRemoteImages,
    this.confirmLink,
  });

  final String html;
  final TextStyle baseStyle;
  final Color linkColor;
  final TextStyle codeStyle;

  /// Whether `<img>` may be fetched from the network.
  final bool loadRemoteImages;

  /// Asked before a link leaves the app. Returning false means the reader said
  /// no, and nothing happens.
  ///
  /// A link in a mail is text the sender chose, and the text need not be what
  /// the link does — `yahoo.com` can point anywhere. Showing the address before
  /// the browser opens is the difference between a decision and a reflex.
  final Future<bool> Function(Uri uri)? confirmLink;

  /// The schemes Ace Mail will hand to the platform. The rule lives in
  /// `util/links.dart` because the assistant's replies obey it too.
  static const Set<String> allowedSchemes = kAllowedLinkSchemes;

  /// Whether [uri] may be handed to the platform.
  static bool mayOpen(Uri uri) => mayOpenLink(uri);

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    // The cap, before the parser sees it: a ten-megabyte HTML part is not a
    // message, it is an attack on the frame budget.
    //
    // Through `truncateSafely`, because a raw `substring` on a boundary inside
    // a surrogate pair leaves half a character, which renders as a replacement
    // glyph at the end of the body. The limit is counted in UTF-16 code units
    // rather than bytes — it is a guard against a part nobody meant to send, not
    // a contract about size, and encoding the string to measure it would cost
    // more than the cap saves.
    final String source = truncateSafely(html, MailLimits.maxHtmlBytes);

    return SizedBox(
      // A definite width, and the whole of the width that is going.
      //
      // This is the line that fixes a body rendering as a column of single
      // letters. The renderer lays out at whatever width it is handed, and it
      // was handed a *loose* box — a `Column` with `CrossAxisAlignment.start`
      // gives its children `minWidth: 0` — so `HtmlWidget` sized itself to its
      // own minimum intrinsic width. Mail written in layout tables, which is
      // most mail, then had `width: 100%` resolve against that minimum: on a
      // Gmail receipt it came out about one character wide, and the body drew
      // as `Y`, `o`, `u` down the middle of the screen.
      //
      // `double.infinity` is not a size here, it is "as much as you are given":
      // inside a bounded box it resolves to the maximum, which is the width the
      // card actually has.
      width: double.infinity,
      child: HtmlWidget(
      source,
      textStyle: baseStyle,
      // Deliberately *not* set. The renderer's own rule is the right one: parse
      // on the frame for anything short, and hand anything past ten thousand
      // characters to an isolate. Forcing it on would spawn an isolate for a
      // one-line reply — a millisecond and a fresh heap for nothing, on the
      // path where speed is most visible.
      //
      // The built tree is kept between rebuilds, so scrolling back up a long
      // message does not rebuild it.
      enableCaching: true,
      // Flip the image setting and the tree is built again, rather than the
      // change waiting for the next message.
      rebuildTriggers: <Object?>[source, loadRemoteImages, baseStyle, linkColor],
      customStylesBuilder: _styles,
      customWidgetBuilder: (dom.Element element) => _blockedImage(element, c),
      onTapUrl: _tapUrl,
      ),
    );
  }

  /// The app's own tokens, where the mail does not have an opinion — and
  /// sometimes where it does. A link has to look like a link, and a code block
  /// has to look like code.
  Map<String, String>? _styles(dom.Element element) {
    switch (element.localName) {
      case 'a':
        return <String, String>{
          'color': _hex(linkColor),
          'text-decoration': 'underline',
        };
      case 'code':
      case 'pre':
        return <String, String>{
          'font-family': 'monospace',
          'font-size': '${(codeStyle.fontSize ?? 14).round()}px',
          'background-color': 'transparent',
        };
      default:
        return null;
    }
  }

  /// A remote image that was not fetched, shown as what it is: something the
  /// sender put there, with whatever they wrote as its description.
  ///
  /// Returning null hands the element back to the renderer, which is what
  /// happens for anything that is not a blocked remote image.
  Widget? _blockedImage(dom.Element element, AstryxColors c) {
    if (element.localName != 'img') return null;
    if (loadRemoteImages) return null; // the renderer fetches it

    final String? src = element.attributes['src']?.trim();
    if (src == null || src.isEmpty) return null;
    final bool remote = src.startsWith('http://') || src.startsWith('https://');
    // `data:` and `cid:` images are already in the message: showing them costs
    // the sender nothing and tells them nothing.
    if (!remote) return null;

    final String alt = (element.attributes['alt'] ?? '').trim();
    return InlineCustomWidget(
      // Inline, because most blocked images are a logo or an icon inside a line
      // of text, and a block placeholder would break the line around it.
      alignment: PlaceholderAlignment.middle,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AstryxSpace.s1),
        padding: const EdgeInsets.symmetric(
          horizontal: AstryxSpace.s2,
          vertical: AstryxSpace.s1,
        ),
        decoration: BoxDecoration(
          color: c.backgroundMuted,
          borderRadius: BorderRadius.circular(AstryxRadius.element),
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AceIconView(icon: AceIcons.image, size: 13, color: c.textSecondary),
            const SizedBox(width: AstryxSpace.s1_5),
            Flexible(
              child: Text(
                alt.isEmpty ? 'Image' : alt,
                style: AstryxText.supporting(c.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hands a link to the platform, after the two checks.
  Future<bool> _tapUrl(String url) async {
    final Uri? uri = Uri.tryParse(url);
    // `true` means "handled". Returning false would let the renderer's default
    // handler at it, and the default handler has no scheme check.
    if (uri == null || !mayOpen(uri)) return true;

    if (confirmLink != null && !await confirmLink!(uri)) return true;

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Nothing installed that can handle it.
    }
    return true;
  }

  static String _hex(Color colour) =>
      '#${(colour.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}

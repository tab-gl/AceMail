import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/mail_highlights.dart';
import '../state/mail_controller.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import 'ace_icon_view.dart';
import 'astryx_widgets.dart';

/// The cards above the list: what is worth doing something about.
///
/// Gmail's version sits at the top of the inbox and says "your package arrives
/// today", "your bill is due". This is the same idea with a narrower promise:
/// each card is one unread message from the last week, sorted into a kind, and
/// tapping it opens that message. Nothing is summarised that the message does
/// not say — the card carries the subject and the sender, so a wrong guess
/// costs a tap rather than a wrong belief.
///
/// It scrolls sideways rather than wrapping into a grid, because the rail is a
/// glance: the list under it is the thing being read, and a rail that grew to
/// two rows would be pushing the mail off the screen to show mail.
class HighlightsRail extends StatelessWidget {
  const HighlightsRail({super.key, required this.highlights});

  final List<MailHighlight> highlights;

  static const double cardWidth = 244;

  /// How tall one card is at the text size it is running at.
  ///
  /// A horizontal list needs a stated height, and cards of different heights in
  /// one row read as a layout mistake — so the height is computed rather than
  /// left to the content. It used to be a constant, and a constant only holds
  /// at one text size: two lines of title and a line of sender at 1.3x are
  /// taller than 118, and a card too short for its own text paints the overflow
  /// stripes across the middle of the list. This is the fixed parts — the
  /// padding, the kind row and the two gaps — plus the text measured in the
  /// type it is actually drawn in.
  static double cardHeight(BuildContext context) {
    final double scale =
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.5);
    const double fixed = 60;
    const double title = AstryxType.sXl * 1.32 * 2;
    const double detail = AstryxType.sXs * 1.45;
    return fixed + (title + detail) * scale;
  }

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    if (highlights.isEmpty) return const SizedBox.shrink();

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: AstryxMotion.of(const Duration(milliseconds: 360)),
      curve: AstryxMotion.emphasizedDecelerate,
      builder: (BuildContext context, double t, Widget? child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 10),
          child: child,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AstryxSpace.s4,
              0,
              AstryxSpace.s4,
              AstryxSpace.s2,
            ),
            child: Row(
              children: <Widget>[
                Text(
                  'HIGHLIGHTS',
                  style: AstryxText.label(c.textSecondary)
                      .copyWith(letterSpacing: 1.1),
                ),
                const Spacer(),
                Text(
                  '${highlights.length}',
                  style: AstryxText.caption(c.textDisabled),
                ),
              ],
            ),
          ),
          SizedBox(
            height: cardHeight(context),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              // The list behind this one scrolls vertically; a horizontal rail
              // inside it must claim the drag first, which the default
              // gesture arena already does for a perpendicular list.
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s4),
              itemCount: highlights.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(width: AstryxSpace.s2),
              itemBuilder: (BuildContext context, int index) => _HighlightCard(
                highlight: highlights[index],
              ),
            ),
          ),
          const SizedBox(height: AstryxSpace.s4),
        ],
      ),
    );
  }
}

/// One card.
class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.highlight});

  final MailHighlight highlight;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final (Color ink, Color fill, AceIcon icon) = _tone(c, highlight.kind);

    return SizedBox(
      width: HighlightsRail.cardWidth,
      child: AceSpringy(
        onTap: () => context.read<MailController>().open(highlight.message),
        semanticLabel: '${highlight.kind.label}: ${highlight.title}',
        builder: (BuildContext context, double press, bool hover) {
          return Transform.scale(
            scale: 1 - 0.015 * press,
            child: Container(
              decoration: BoxDecoration(
                // The same raised surface as a row, so the rail reads as part
                // of the list rather than as a banner above it.
                color: hover ? c.surfaceHighest : c.backgroundSurface,
                borderRadius: BorderRadius.circular(AstryxRadius.lg),
                border: Border.all(color: c.border, width: 1),
              ),
              // A card is a fixed box with text in it, and the two are measured
              // separately. Clipping means a size nobody predicted cuts the last
              // line off rather than painting it outside the card.
              clipBehavior: Clip.antiAlias,
              padding: const EdgeInsets.all(AstryxSpace.s3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: fill,
                          borderRadius:
                              BorderRadius.circular(AstryxRadius.inner),
                        ),
                        child: Center(
                          child: AceIconView(icon: icon, size: 15, color: ink),
                        ),
                      ),
                      const SizedBox(width: AstryxSpace.s2),
                      // Flexible, so the kind label gives way rather than
                      // pushing the row past the edge of the card: it is the
                      // only thing in this row that is not a fixed size, and a
                      // word in a fixed-width card with no way to shrink is an
                      // overflow waiting for a bigger font.
                      Flexible(
                        child: Text(
                          highlight.kind.label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AstryxText.label(ink).copyWith(
                            letterSpacing: 1,
                            fontWeight: AstryxType.semibold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AstryxSpace.s2),
                  Expanded(
                    child: Text(
                      highlight.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: highlight.kind == HighlightKind.code
                          ? AstryxText.heading3(c.textPrimary).copyWith(
                              letterSpacing: 2.4,
                              fontFamily: 'monospace',
                            )
                          : AstryxText.bodyStrong(c.textPrimary),
                    ),
                  ),
                  const SizedBox(height: AstryxSpace.s0_5),
                  Text(
                    highlight.detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AstryxText.caption(c.textSecondary),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Each kind gets its own colour, so the rail can be scanned without reading
  /// it: green for a code you are about to use, red for a security notice, and
  /// the accent's own family for the rest.
  (Color, Color, AceIcon) _tone(AstryxColors c, HighlightKind kind) =>
      switch (kind) {
        HighlightKind.code => (
            c.success,
            c.successMuted,
            AceIcons.password,
          ),
        HighlightKind.security => (c.error, c.errorMuted, AceIcons.shield),
        HighlightKind.delivery => (
            c.accentInk,
            c.accentMuted,
            AceIcons.package,
          ),
        HighlightKind.bill => (
            c.accentInk,
            c.accentMuted,
            AceIcons.receipt,
          ),
        HighlightKind.travel => (
            c.tertiary,
            c.tertiaryContainer,
            AceIcons.flight,
          ),
        HighlightKind.event => (
            c.tertiary,
            c.tertiaryContainer,
            AceIcons.calendar,
          ),
      };
}

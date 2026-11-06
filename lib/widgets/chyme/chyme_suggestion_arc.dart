import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/astryx_tokens.dart';
import 'chyme_prompt.dart';

/// The suggestion cards, fanned along an arc.
///
/// One card per prompt, placed on a circle whose centre is below the sheet: the
/// middle card is upright, each neighbour is turned by a step and pushed down
/// and out along the curve, and the outermost are half off the edge. Which is
/// what makes it read as a hand of cards offered rather than a list to scroll —
/// the shape does the inviting, and the middle card is the one it is offering.
class ChymeSuggestionArc extends StatelessWidget {
  const ChymeSuggestionArc({super.key, required this.prompts, required this.onPick});

  final List<ChymePrompt> prompts;
  final void Function(String prompt) onPick;

  /// How far apart the cards sit, in radians.
  static const double _step = 0.125;

  /// How far away the circle is. Larger is a flatter arc; this one is tight
  /// enough that three cards read as a curve and loose enough that the middle
  /// card is not tilted.
  static const double _radius = 620;

  static const double _height = 210;
  static const double _cardHeight = 168;

  @override
  Widget build(BuildContext context) {
    if (prompts.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: _height,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          final double cardWidth =
              (box.maxWidth * 0.52).clamp(150.0, 200.0);
          final double centre = box.maxWidth / 2;
          final int middle = (prompts.length - 1) ~/ 2;

          // Outer cards first, so the middle one paints on top of its
          // neighbours rather than under them.
          final List<int> order = List<int>.generate(prompts.length, (int i) => i)
            ..sort((int a, int b) =>
                (b - middle).abs().compareTo((a - middle).abs()));

          // Wider than the sheet, and scrollable, so a phone that cannot show
          // five cards in an arc can still reach the ones off the edge. It was
          // a bare Stack: the outermost cards were cut off with no way to get
          // to them, which turned "suggestions" into "the middle one".
          final double reach = centre + _radius * math.sin(
                _step * (prompts.length - 1 - middle),
              ) + cardWidth / 2;

          final Widget arc = SizedBox(
            width: math.max(box.maxWidth, reach * 2),
            height: _height,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                for (final int index in order)
                  _placed(
                    context,
                    index: index,
                    middle: middle,
                    centre: math.max(box.maxWidth, reach * 2) / 2,
                    cardWidth: cardWidth,
                  ),
              ],
            ),
          );

          // Scrolls only when it has to: a wide screen shows the whole arc and
          // a drag there does nothing, which is what a hand of cards should do.
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            // Air at both ends, so the outermost card is not cut by the sheet's
            // own edge when it is scrolled to.
            padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s5),
            child: arc,
          );
        },
      ),
    );
  }

  Widget _placed(
    BuildContext context, {
    required int index,
    required int middle,
    required double centre,
    required double cardWidth,
  }) {
    final int offset = index - middle;
    final double angle = offset * _step;
    final double distance = offset.abs().toDouble();

    // Along the circle: x is the chord, y is how far the curve has dropped.
    final double x = _radius * math.sin(angle);
    final double y = _radius * (1 - math.cos(angle));

    // The outermost cards shrink and fade a little, which is what makes the
    // middle one the one being offered.
    final double scale = (1 - 0.07 * distance).clamp(0.72, 1.0);
    final double opacity = (1 - 0.22 * distance).clamp(0.45, 1.0);

    final ChymePrompt item = prompts[index];

    return Positioned(
      left: centre + x - cardWidth / 2,
      top: y + (_height - _cardHeight) / 2,
      width: cardWidth,
      // Bounded height: the card ends in a Spacer, and a Spacer in an
      // unbounded column is a layout error rather than a card.
      child: SizedBox(
        height: _cardHeight,
        child: Opacity(
          opacity: opacity,
          child: Transform.rotate(
            angle: angle,
            // Turned about its bottom edge, like a card held in a hand.
            alignment: Alignment.bottomCenter,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.bottomCenter,
              child: ChymePromptCard(
                prompt: item,
                width: cardWidth,
                onTap: () => onPick(item.prompt),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

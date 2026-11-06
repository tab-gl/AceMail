import 'package:flutter/material.dart';
import '../../theme/ace_icons.dart';
import '../../theme/astryx_theme.dart';
import '../../theme/astryx_tokens.dart';
import '../ace_icon_view.dart';

/// What happened after a button was pressed.
class ChymeDoneNote extends StatelessWidget {
  const ChymeDoneNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AceIconView(icon: AceIcons.check, size: 15, color: c.textSecondary),
        const SizedBox(width: AstryxSpace.s2),
        Expanded(
          child: Text(text, style: AstryxText.supporting(c.textSecondary)),
        ),
      ],
    );
  }
}

/// The suggestion cards, fanned along an arc.
///
/// One card per prompt, placed on a circle whose centre is below the sheet: the
/// middle card is upright, each neighbour is turned by a step and pushed down
/// and out along the curve, and the outermost are half off the edge. Which is
/// what makes it read as a hand of cards offered rather than a list to scroll —
/// the shape does the inviting, and the middle card is the one it is offering.

import 'package:flutter/material.dart';
import '../../theme/ace_icons.dart';
import '../../theme/astryx_theme.dart';
import '../../theme/astryx_tokens.dart';
import '../ace_icon_view.dart';
import '../astryx_widgets.dart';

/// One thing worth asking, as a card.
class ChymePrompt {
  const ChymePrompt({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.prompt,
  });

  final AceIcon icon;
  final String title;
  final String subtitle;
  final String prompt;
}

class ChymePromptCard extends StatelessWidget {
  const ChymePromptCard({
    super.key,
    required this.prompt,
    required this.onTap,
    this.width = 196,
  });

  final ChymePrompt prompt;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return SizedBox(
      width: width,
      child: AceSpringy(
        onTap: onTap,
        semanticLabel: prompt.title,
        builder: (BuildContext context, double press, bool hover) => MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: AstryxMotion.fast,
            // A card under a pointer has to say so: the border alone was too
            // quiet to notice on a desktop, and this is the one place in the
            // app where hovering is how you find out a card is a button.
            transform: Matrix4.translationValues(0, hover ? -3 : 0, 0),
            padding: const EdgeInsets.all(AstryxSpace.s4),
            decoration: BoxDecoration(
              color: hover ? c.backgroundMuted : c.surfaceHighest,
              borderRadius: BorderRadius.circular(AstryxRadius.lg),
              border: Border.all(
                color: hover ? c.accent : c.border,
              ),
              boxShadow: hover
                  ? <BoxShadow>[
                      BoxShadow(
                        color: c.accent.withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: c.accentMuted,
                  borderRadius: BorderRadius.circular(AstryxRadius.element),
                ),
                child: Center(
                  child: AceIconView(icon: prompt.icon, size: 20, color: c.accent),
                ),
              ),
              const Spacer(),
              Text(
                prompt.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AstryxText.bodyStrong(c.textPrimary),
              ),
              const SizedBox(height: AstryxSpace.s0_5),
              Text(
                prompt.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AstryxText.supporting(c.textSecondary),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Something Chyme wants to do, and has not done.

import 'package:flutter/material.dart';
import '../../services/chyme.dart';
import '../../theme/ace_icons.dart';
import '../../theme/astryx_theme.dart';
import '../../theme/astryx_tokens.dart';
import '../ace_icon_view.dart';
import '../astryx_widgets.dart';

/// The search a reply asked for, offered rather than run.
class ChymeSearchOffer extends StatelessWidget {
  const ChymeSearchOffer({required this.query, required this.onTap});

  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return Padding(
      padding: const EdgeInsets.only(bottom: AstryxSpace.s3),
      child: Container(
        padding: const EdgeInsets.all(AstryxSpace.s3),
        decoration: BoxDecoration(
          color: c.backgroundMuted,
          borderRadius: BorderRadius.circular(AstryxRadius.container),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: <Widget>[
            AceIconView(
              icon: AceIcons.search,
              size: 18,
              color: c.textSecondary,
            ),
            const SizedBox(width: AstryxSpace.s3),
            Expanded(
              child: Text(
                'Search for “$query”',
                style: AstryxText.body(c.textPrimary),
              ),
            ),
            AceButton(
              label: 'Search',
              variant: AceButtonVariant.tonal,
              onPressed: onTap,
            ),
          ],
        ),
      ),
    );
  }
}

/// Chyme with nowhere to ask.

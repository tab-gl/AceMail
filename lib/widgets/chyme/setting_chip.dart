part of '../chyme_sheet.dart';

class _SettingChip extends StatelessWidget {
  const _SettingChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final AceIcon icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AstryxRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AstryxSpace.s2,
          vertical: AstryxSpace.s0_5,
        ),
        decoration: BoxDecoration(
          color: c.backgroundMuted,
          borderRadius: BorderRadius.circular(AstryxRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AceIconView(icon: icon, size: 13, color: c.textSecondary),
            const SizedBox(width: AstryxSpace.s1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AstryxText.supporting(c.textSecondary),
              ),
            ),
            AceIconView(
              icon: AceIcons.chevronDown,
              size: 13,
              color: c.textDisabled,
            ),
          ],
        ),
      ),
    );
  }
}

/// One turn, as a bubble.

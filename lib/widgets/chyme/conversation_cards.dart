part of '../chyme_sheet.dart';

class _Prompt {
  const _Prompt({
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

class _PromptCard extends StatelessWidget {
  const _PromptCard({
    required this.prompt,
    required this.onTap,
    this.width = 196,
  });

  final _Prompt prompt;
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
class _Proposal {
  const _Proposal({
    required this.name,
    required this.argument,
    required this.label,
  });

  final String name;
  final String argument;
  final String label;
}

/// The button that stands between a proposal and the mail.
class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.proposal,
    required this.onConfirm,
    required this.onDismiss,
  });

  final _Proposal proposal;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return Container(
      padding: const EdgeInsets.all(AstryxSpace.s3),
      decoration: BoxDecoration(
        color: c.accentMuted,
        borderRadius: BorderRadius.circular(AstryxRadius.container),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              AceIconView(icon: AceIcons.chyme, size: 16, color: c.accent),
              const SizedBox(width: AstryxSpace.s2),
              Expanded(
                child: Text(
                  'Chyme wants to',
                  style: AstryxText.caption(c.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AstryxSpace.s1),
          Text(proposal.label, style: AstryxText.bodyStrong(c.textPrimary)),
          const SizedBox(height: AstryxSpace.s3),
          Row(
            children: <Widget>[
              AceButton(
                label: 'Do it',
                variant: AceButtonVariant.primary,
                onPressed: onConfirm,
              ),
              const SizedBox(width: AstryxSpace.s2),
              AceButton(
                label: 'No',
                variant: AceButtonVariant.ghost,
                onPressed: onDismiss,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What happened after a button was pressed.
class _DoneNote extends StatelessWidget {
  const _DoneNote({required this.text});

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

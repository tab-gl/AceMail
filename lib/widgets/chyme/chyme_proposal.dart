import 'package:flutter/material.dart';
import '../../theme/ace_icons.dart';
import '../../theme/astryx_theme.dart';
import '../../theme/astryx_tokens.dart';
import '../ace_icon_view.dart';
import '../astryx_widgets.dart';

/// Something Chyme wants to do, and has not done.
class ChymeProposal {
  const ChymeProposal({
    required this.name,
    required this.argument,
    required this.label,
  });

  final String name;
  final String argument;
  final String label;
}

/// The button that stands between a proposal and the mail.
class ChymeProposalCard extends StatelessWidget {
  const ChymeProposalCard({
    super.key,
    required this.proposal,
    required this.onConfirm,
    required this.onDismiss,
  });

  final ChymeProposal proposal;
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

import 'package:flutter/material.dart';
import '../../services/chyme.dart';
import '../../theme/ace_icons.dart';
import '../../theme/astryx_theme.dart';
import '../../theme/astryx_tokens.dart';
import '../astryx_widgets.dart';
import '../chyme_mark.dart';

/// Chyme with nowhere to ask.
class ChymeNotSetUp extends StatelessWidget {
  const ChymeNotSetUp({required this.onConfigure});

  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return Padding(
      padding: const EdgeInsets.all(AstryxSpace.s5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ChymeMark(size: 28, color: c.accent),
          const SizedBox(height: AstryxSpace.s4),
          Text(
            'Chyme needs somewhere to ask',
            style: AstryxText.heading3(c.textPrimary),
          ),
          const SizedBox(height: AstryxSpace.s2),
          Text(
            'There is no Chyme service and no account to make. Point it at any '
            'endpoint that speaks the OpenAI chat API — a hosted one, or a model '
            'running on your own machine — and it will list what it has.',
            style: AstryxText.body(c.textSecondary),
          ),
          const SizedBox(height: AstryxSpace.s4),
          AceButton(
            label: 'Set up Chyme',
            icon: AceIcons.chyme,
            variant: AceButtonVariant.primary,
            expand: true,
            onPressed: onConfigure,
          ),
        ],
      ),
    );
  }
}

/// Asks before it deletes, then moves the open message to the trash.
///
/// Chyme cannot delete anything by itself. It can say it would, and this is what
/// happens next: a question with the subject in it, and a way to say no.
/// Everything here is reversible — it goes to the trash, not away.

part of '../chyme_sheet.dart';

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
Future<void> _confirmDelete(BuildContext context) async {
  final bool yes = await aceConfirm(
    context,
    title: 'Delete this message?',
    body: 'It goes to the trash. You can put it back.',
    confirm: 'Delete',
    cancel: 'Keep',
    destructive: true,
  );
  if (!yes || !context.mounted) return;
  final MailController controller = context.read<MailController>();
  await controller.deleteOpenMessage();
  if (context.mounted) AceSnack.show(context, 'Moved to the trash.');
}

/// One thing worth asking, as a card.

import 'package:flutter/material.dart';

import '../models/message_security.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import 'ace_glass.dart';
import 'ace_icon_view.dart';
import 'astryx_widgets.dart';

/// The sender's authentication, as a pill under their name.
///
/// Gmail's version of this is the little arrow beside the sender that opens a
/// panel saying *signed by* and *mailed by*. This is the same information, said
/// once: the pill carries the one-word answer, and tapping it opens the panel
/// with the detail. The pill is quiet when nothing failed — a lock on every
/// message is a lock nobody sees — and only takes the warning colour when a
/// method actually failed.
class SecurityChip extends StatelessWidget {
  const SecurityChip({super.key, required this.security, this.sender});

  final MessageSecurity security;

  /// The address the message says it is from, shown in the details sheet so the
  /// domain in the headers can be read against it. Null is fine: the sheet says
  /// what it knows and nothing else.
  final String? sender;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final (Color ink, Color fill, AceIcon icon) = _tone(c);

    return AceSpringy(
      onTap: () => showSecuritySheet(context, security, sender: sender),
      semanticLabel: '${security.headline}. Show message security.',
      builder: (BuildContext context, double press, bool hover) {
        final double t = press.clamp(0.0, 1.0);
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AstryxSpace.s2,
            vertical: AstryxSpace.s0_5 + 1,
          ),
          decoration: BoxDecoration(
            color: hover ? ink.withValues(alpha: 0.14) : fill,
            borderRadius: BorderRadius.circular(
              AstryxRadius.full - (t * 4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AceIconView(icon: icon, size: 13, color: ink),
              const SizedBox(width: AstryxSpace.s1_5),
              Flexible(
                child: Text(
                  security.headline,
                  overflow: TextOverflow.ellipsis,
                  style: AstryxText.caption(ink).copyWith(
                    fontWeight: AstryxType.semibold,
                  ),
                ),
              ),
              const SizedBox(width: AstryxSpace.s0_5),
              AceIconView(
                icon: AceIcons.chevronRight,
                size: 12,
                color: ink.withValues(alpha: 0.75),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The ink, the fill and the glyph for the trust level.
  ///
  /// A suspicious sender is the only case that takes the error colour: an
  /// unverified one is not an accusation, and colouring it like one is how a
  /// warning stops meaning anything.
  (Color, Color, AceIcon) _tone(AstryxColors c) => switch (security.trust) {
        SenderTrust.verified => (
            c.success,
            c.successMuted,
            AceIcons.shieldCheck,
          ),
        SenderTrust.suspicious => (c.error, c.errorMuted, AceIcons.warning),
        SenderTrust.unverified => (
            c.textSecondary,
            c.backgroundMuted,
            AceIcons.shield,
          ),
      };
}

/// What the headers said, in full.
///
/// Every line here is a header that arrived with the message, shown with the
/// answer the receiving server gave. The sheet says whose answer it is, because
/// the difference between "this app checked the signature" and "the server that
/// accepted this message checked the signature" is the whole truth of the
/// feature, and only one of those is something this app can do.
Future<void> showSecuritySheet(
  BuildContext context,
  MessageSecurity security, {
  String? sender,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    sheetAnimationStyle: kAceSheetMotion,
    builder: (BuildContext sheetContext) {
      final AstryxColors c = sheetContext.astryx;
      final (Color ink, Color fill, AceIcon icon) = switch (security.trust) {
        SenderTrust.verified => (
            c.success,
            c.successMuted,
            AceIcons.shieldCheck,
          ),
        SenderTrust.suspicious => (c.error, c.errorMuted, AceIcons.warning),
        SenderTrust.unverified => (
            c.textSecondary,
            c.backgroundMuted,
            AceIcons.shield,
          ),
      };

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AstryxSpace.s5,
            0,
            AstryxSpace.s5,
            AstryxSpace.s6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(AstryxRadius.element),
                    ),
                    child: Center(
                      child: AceIconView(icon: icon, size: 22, color: ink),
                    ),
                  ),
                  const SizedBox(width: AstryxSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          security.headline,
                          style: AstryxText.heading3(c.textPrimary),
                        ),
                        if (security.detail != null)
                          Text(
                            security.detail!,
                            style: AstryxText.supporting(c.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AstryxSpace.s5),
              if (sender != null && sender.trim().isNotEmpty)
                _Fact(
                  label: 'From',
                  value: sender.trim(),
                  mono: false,
                ),
              if (security.signedBy != null)
                _Fact(label: 'Signed by', value: security.signedBy!),
              if (security.mailedBy != null)
                _Fact(label: 'Mailed by', value: security.mailedBy!),
              const SizedBox(height: AstryxSpace.s4),
              Divider(height: 1, color: c.border),
              const SizedBox(height: AstryxSpace.s4),
              Text(
                'Authentication',
                style: AstryxText.label(c.textSecondary),
              ),
              const SizedBox(height: AstryxSpace.s2),
              for (final MapEntry<String, AuthVerdict> entry
                  in security.verdicts.entries)
                _Verdict(label: entry.key, verdict: entry.value),
              const SizedBox(height: AstryxSpace.s4),
              Divider(height: 1, color: c.border),
              const SizedBox(height: AstryxSpace.s4),
              Row(
                children: <Widget>[
                  AceIconView(
                    icon: security.encrypted ? AceIcons.lock : AceIcons.warning,
                    size: 16,
                    color: security.encrypted ? c.success : c.warning,
                  ),
                  const SizedBox(width: AstryxSpace.s2),
                  Expanded(
                    child: Text(
                      security.encrypted
                          ? 'Encrypted in transit — fetched over TLS'
                          : 'This message was not fetched over TLS',
                      style: AstryxText.supporting(c.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AstryxSpace.s5),
              Text(
                security.reported
                    ? 'These results are the receiving server\'s, read from the '
                        'message headers. Ace Mail reports them and verifies '
                        'nothing itself — the message is whatever your provider '
                        'handed over.'
                    : 'This message arrived without authentication results, so '
                        'there is nothing to report. That is common for mail '
                        'from an internal server, and it is not by itself a '
                        'sign that anything is wrong.',
                style: AstryxText.caption(c.textDisabled),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// One `label: value` line.
class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.mono = true});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return Padding(
      padding: const EdgeInsets.only(bottom: AstryxSpace.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 92,
            child: Text(label, style: AstryxText.supporting(c.textSecondary)),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: AstryxText.body(c.textPrimary).copyWith(
                fontFamily: mono ? 'monospace' : null,
                fontSize: mono ? AstryxType.sSm : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One authentication method and its verdict.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.label, required this.verdict});

  final String label;
  final AuthVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    final (Color ink, AceIcon icon) = switch (verdict) {
      AuthVerdict.pass => (c.success, AceIcons.checkCircle),
      AuthVerdict.fail ||
      AuthVerdict.permanentError =>
        (c.error, AceIcons.error),
      AuthVerdict.softFail || AuthVerdict.temporaryError => (
          c.warning,
          AceIcons.warning,
        ),
      _ => (c.textDisabled, AceIcons.info),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AstryxSpace.s2),
      child: Row(
        children: <Widget>[
          AceIconView(icon: icon, size: 15, color: ink),
          const SizedBox(width: AstryxSpace.s2),
          SizedBox(
            width: 68,
            child: Text(label, style: AstryxText.bodyStrong(c.textPrimary)),
          ),
          Expanded(
            child: Text(
              verdict.description,
              style: AstryxText.supporting(c.textSecondary),
            ),
          ),
          // The header's own word, for anyone who wants to match it against
          // what their provider's documentation says.
          Text(
            verdict.label,
            style: AstryxText.caption(c.textDisabled).copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

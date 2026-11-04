import 'package:flutter/material.dart';

import '../theme/ace_icons.dart';
import '../theme/astryx_tokens.dart';
import 'astryx_widgets.dart';

/// The microphone, drawn by the app rather than borrowed from a font.
///
/// It pulses while the device is listening. Nothing else on screen changes when
/// a recogniser is open — the speech app is a separate window — so on the way
/// back this is the only thing that says the app is still waiting, and a
/// microphone that gives no sign of being live is a microphone people talk to
/// twice.
///
/// Shared between the search bar and the assistant's composer. The same
/// affordance in two places has to be the same widget, or they drift into two
/// microphones that pulse differently and mean slightly different things.
class VoiceButton extends StatefulWidget {
  const VoiceButton({
    super.key,
    required this.listening,
    required this.onPressed,
    this.size = AstryxSize.touchTarget,
    this.label = 'Search by voice',
  });

  /// Whether the device is listening. Owned by the caller, because the caller
  /// is the one that has to put the words where they belong.
  final bool listening;

  final VoidCallback onPressed;

  /// The button's box, and therefore the glyph inside it — an `AceIconButton`
  /// draws its icon at half its size.
  ///
  /// The search bar wants a control that sits in a row of them. The assistant's
  /// composer wants one that reads as the thing you press when you have decided
  /// to speak rather than type, which is a bigger decision and a bigger button.
  final double size;

  /// What the button says it does when the device is not listening.
  final String label;

  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.listening) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(VoiceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.listening == oldWidget.listening) return;
    if (widget.listening) {
      _pulse.repeat(reverse: true);
    } else {
      // Stopped at zero rather than left where it was, so the ring is gone the
      // moment the listening is.
      _pulse.animateTo(0, duration: AstryxMotion.of(AstryxMotion.fast));
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (BuildContext context, Widget? child) {
        final double t = _pulse.value;
        return Transform.scale(
          scale: 1 + 0.06 * t,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // The ring grows and fades as it pulses, so the button reads as
              // waiting rather than as broken.
              color: widget.listening
                  ? c.accent.withValues(alpha: 0.12 + 0.10 * t)
                  : Colors.transparent,
            ),
            child: child,
          ),
        );
      },
      child: AceIconButton(
        icon: AceIcons.mic,
        size: widget.size,
        // Still tappable while it is live, and does nothing: the listening is
        // happening in the device's speech app, which this cannot reach in to
        // stop. Saying so is better than a button that looks broken.
        tooltip: widget.listening ? 'Listening…' : widget.label,
        onPressed: widget.onPressed,
      ),
    );
  }
}

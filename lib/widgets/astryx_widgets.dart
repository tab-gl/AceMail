import 'dart:async';

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/haptics.dart';
import 'ace_glass.dart';
import 'ace_icon_view.dart';
import 'chyme_mark.dart';
import 'shape_morph.dart';

/// A press that springs, and a shape that morphs while it does.
///
/// This is the interaction primitive Material 3 Expressive is built around:
/// motion comes from a spring rather than a curve, so a press settles with a
/// little life instead of easing flatly. The builder is handed the current
/// press (0 resting, 1 fully pressed, and briefly outside that range on the
/// rebound) and the hover state, so each component can morph its own shape.
class AceSpringy extends StatefulWidget {
  const AceSpringy({
    super.key,
    required this.builder,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.semanticLabel,
  });

  final Widget Function(BuildContext context, double press, bool hover) builder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;

  /// The name a screen reader announces, for a control whose visible content is
  /// only an icon.
  final String? semanticLabel;

  @override
  State<AceSpringy> createState() => _AceSpringyState();
}

class _AceSpringyState extends State<AceSpringy>
    with SingleTickerProviderStateMixin {
  /// Unbounded so the spring can overshoot past its target — that overshoot is
  /// the point.
  late final AnimationController _press =
      AnimationController.unbounded(vsync: this, value: 0);

  bool _hover = false;

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _springTo(double target) {
    _press.animateWith(
      SpringSimulation(
        // Pressing is a spatial move and uses the snappy spring; releasing uses
        // the livelier one so the rebound is visible.
        target > _press.value
            ? AstryxMotion.spatialFast
            : AstryxMotion.press,
        _press.value,
        target,
        _press.velocity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool live = widget.enabled && widget.onTap != null;

    return Semantics(
      // A tap target is a button to a screen reader, whichever component it is
      // — and it stays a button when disabled, just not an enabled one. The
      // label goes on this same node, or the role and the name end up as
      // siblings and neither is announced properly.
      button: true,
      enabled: live,
      label: widget.semanticLabel,
      child: MouseRegion(
      cursor: live ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: live ? (_) => _springTo(1) : null,
        onTapUp: live ? (_) => _springTo(0) : null,
        onTapCancel: live ? () => _springTo(0) : null,
        onTap: live ? widget.onTap : null,
        onLongPress: live ? widget.onLongPress : null,
        child: AnimatedBuilder(
          animation: _press,
          builder: (BuildContext context, _) =>
              widget.builder(context, _press.value, _hover),
        ),
      ),
      ),
    );
  }
}

/// A padded, rounded surface — Astryx's container role, on the tonal ramp.
class AceSurface extends StatelessWidget {
  const AceSurface({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.border = true,
    this.radius = AstryxRadius.container,
    this.squircle = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final bool border;
  final double radius;

  /// Continuous corners, for the large surfaces expressive M3 softens.
  final bool squircle;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final Decoration decoration = BoxDecoration(
      color: color ?? c.backgroundSurface,
      borderRadius: squircle ? null : BorderRadius.circular(radius),
      border: border ? Border.all(color: c.border) : null,
    );

    if (!squircle) {
      // Clipped, so a child with its own rounded background — a selected row in
      // a group, say — cannot spill past the card's corners.
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(padding: padding, decoration: decoration, child: child),
      );
    }

    return ClipPath(
      clipper: const AceSquircleClipper(),
      child: CustomPaint(
        painter: _SquircleSurface(
          color: color ?? c.backgroundSurface,
          border: border ? c.border : null,
        ),
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
  }
}

/// Clips to a continuous corner. Shared by every surface that wants the shape.
class AceSquircleClipper extends CustomClipper<Path> {
  const AceSquircleClipper({this.exponent = 4});

  final double exponent;

  @override
  Path getClip(Size size) =>
      AstryxShape.squircle(Offset.zero & size, exponent: exponent);

  @override
  bool shouldReclip(covariant AceSquircleClipper oldClipper) =>
      oldClipper.exponent != exponent;
}

class _SquircleSurface extends CustomPainter {
  const _SquircleSurface({required this.color, required this.border});

  final Color color;
  final Color? border;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawPath(
      AstryxShape.squircle(rect),
      Paint()..color = color,
    );
    if (border != null) {
      // Inset by a full pixel so the clip does not shave the stroke.
      canvas.drawPath(
        AstryxShape.squircle(rect.deflate(1)),
        Paint()
          ..color = border!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SquircleSurface old) =>
      old.color != color || old.border != border;
}

enum AceButtonVariant { primary, tonal, outlined, ghost, danger, success }

enum AceButtonSize { small, medium, large }

class AceButton extends StatelessWidget {
  const AceButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AceButtonVariant.ghost,
    this.icon,
    this.expand = false,
    this.loading = false,
    this.size = AceButtonSize.medium,
  });

  final String label;
  final VoidCallback? onPressed;
  final AceButtonVariant variant;
  final AceIcon? icon;
  final bool expand;
  final bool loading;
  final AceButtonSize size;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    final (Color background, Color foreground, bool bordered) =
        switch (variant) {
      AceButtonVariant.primary => (c.accent, c.onAccent, false),
      AceButtonVariant.tonal => (
          c.secondaryContainer,
          c.onSecondaryContainer,
          false,
        ),
      AceButtonVariant.outlined => (Colors.transparent, c.textPrimary, true),
      AceButtonVariant.ghost => (Colors.transparent, c.textSecondary, false),
      AceButtonVariant.danger => (c.errorMuted, c.onErrorMuted, false),
      AceButtonVariant.success => (c.successMuted, c.success, false),
    };

    // A button's height is its label's height plus air, and the label grows
    // with the text size while the box did not. The height follows the type:
    // see [scaledForText], which is the same rule the folder bar and the
    // assistant's pill use.
    final double height = scaledForText(
      context,
      switch (size) {
        AceButtonSize.small => AstryxSize.elementMd,
        AceButtonSize.medium => AstryxSize.elementLg,
        AceButtonSize.large => AstryxSize.elementXl,
      },
    );
    final double iconSize = size == AceButtonSize.large ? 21 : 18;

    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (loading)
          Padding(
            padding: const EdgeInsets.only(right: AstryxSpace.s2),
            child: AceLoader(size: iconSize, color: foreground),
          )
        else if (icon != null) ...<Widget>[
          AceIconView(icon: icon!, size: iconSize, color: foreground),
          const SizedBox(width: AstryxSpace.s2),
        ],
        // Flexible, because a plain child of a Row is laid out with an
        // *unbounded* main-axis width and simply draws past the button. The
        // ellipsis was already set and could never fire: a Text with no limit
        // wraps first, and one with an unbounded width does not wrap at all.
        // Flexible gives it the room the button actually has; `maxLines: 1`
        // gives the ellipsis something to truncate.
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            style: AstryxText.bodyStrong(foreground),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    final bool enabled = onPressed != null && !loading;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: AceSpringy(
        enabled: enabled,
        onTap: onPressed,
        builder: (BuildContext context, double press, bool hover) {
          // The shape morph: a stadium at rest, tightening toward a rounded
          // rectangle as it is pressed.
          final double t = press.clamp(0.0, 1.0);
          final BorderRadius shape = BorderRadius.circular(
            lerpDouble(AstryxRadius.full, AstryxRadius.lg, t)!,
          );
          final Color fill = hover && background == Colors.transparent
              ? c.overlayHover
              : background;

          return Transform.scale(
            scale: 1 - 0.045 * press,
            child: Container(
              height: height,
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(
                horizontal: size == AceButtonSize.small
                    ? AstryxSpace.s3
                    : AstryxSpace.s5,
              ),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: shape,
                border: bordered ? Border.all(color: c.borderEmphasized) : null,
              ),
              child: expand
                  ? SizedBox(width: double.infinity, child: content)
                  : content,
            ),
          );
        },
      ),
    );
  }
}

enum AceIconButtonVariant { standard, filled, tonal, danger }

class AceIconButton extends StatelessWidget {
  const AceIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.variant = AceIconButtonVariant.standard,
    this.selected = false,
    this.size = AstryxSize.touchTarget,
    this.markBuilder,
  });

  final AceIcon icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final AceIconButtonVariant variant;
  final bool selected;
  final double size;

  /// Drawn instead of the glyph, and given the colour the button resolved for
  /// its foreground — so a mark can sit in a button and still invert when the
  /// button is selected, which a plain widget could not.
  final Widget Function(Color foreground)? markBuilder;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    final (Color background, Color foreground) = switch (variant) {
      // Selected fills with the accent itself and inverts the icon, rather than
      // tinting it: the hugeicons free set is stroke-only, so there is no filled
      // glyph to swap in, and a shape that fills is what says "this one is on"
      // in a set that has no other way to say it.
      AceIconButtonVariant.standard => (
          selected ? c.accent : Colors.transparent,
          selected ? c.onAccent : c.iconSecondary,
        ),
      AceIconButtonVariant.filled => (
          selected ? c.accent : c.surfaceHighest,
          selected ? c.onAccent : c.textPrimary,
        ),
      AceIconButtonVariant.tonal => (c.accentMuted, c.onAccentMuted),
      AceIconButtonVariant.danger => (c.errorMuted, c.onErrorMuted),
    };

    final Widget button = AceSpringy(
      enabled: onPressed != null,
      onTap: onPressed,
      semanticLabel: tooltip,
      builder: (BuildContext context, double press, bool hover) {
        final double t = press.clamp(0.0, 1.0);
        // A circular button tightens into a squircle as it is pressed — the
        // shape morph, at the smallest scale it happens in the app.
        final BorderRadius shape = BorderRadius.circular(
          lerpDouble(AstryxRadius.full, AstryxRadius.element, t)!,
        );
        return Transform.scale(
          // A press that does not move when motion is off, rather than one that
          // moves faster.
          scale: AstryxMotion.reduced ? 1 : 1 - 0.06 * press,
          child: AnimatedContainer(
            // The fill arrives rather than appearing: at this size a hard cut
            // reads as a repaint, and the eye loses the button it just pressed.
            duration: AstryxMotion.of(AstryxMotion.fast),
            curve: AstryxMotion.emphasized,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: hover && background == Colors.transparent
                  ? c.overlayHover
                  : background,
              borderRadius: shape,
            ),
            // Tweened with the container, so the icon and the shape behind it
            // arrive together.
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: foreground),
              duration: AstryxMotion.of(AstryxMotion.fast),
              curve: AstryxMotion.emphasized,
              builder: (BuildContext context, Color? colour, Widget? child) {
                final Color drawn = colour ?? foreground;
                return markBuilder?.call(drawn) ??
                    // Selection arrives with a small movement. A state that
                    // changes without moving is a state you have to look for,
                    // and on the star it is the whole answer to "did that
                    // work". Subtle on purpose: this is every icon button in
                    // the app, not one of them.
                    AnimatedScale(
                      scale: selected ? 1.15 : 1.0,
                      duration: AstryxMotion.of(AstryxMotion.fast),
                      curve: AstryxMotion.emphasized,
                      child:
                          AceIconView(icon: icon, size: size * 0.5, color: drawn),
                    );
              },
            ),
          ),
        );
      },
    );

    return tooltip == null
        ? button
        : Tooltip(message: tooltip!, child: button);
  }
}

/// The expressive FAB: a pill that springs, and collapses to an icon when
/// there is not room for its label.
class AceFab extends StatelessWidget {
  const AceFab({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.extended = true,
  });

  final String label;
  final AceIcon icon;
  final VoidCallback? onPressed;

  /// Whether the label is showing. It shortens to a circle once the list has
  /// been scrolled — the label is there to teach the button, and by the time
  /// you have scrolled you have learned it.
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    // The FAB is a fixed-height pill with a word in it, so it takes the same
    // rule as every other button rather than relying on its caller to hide the
    // label when the type gets big.
    final double height = scaledForText(context, AstryxSize.elementXl);

    return AceSpringy(
      enabled: onPressed != null,
      onTap: onPressed,
      builder: (BuildContext context, double press, bool hover) {
        final double t = press.clamp(0.0, 1.0);
        final BorderRadius shape = BorderRadius.circular(
          lerpDouble(AstryxRadius.lg, AstryxRadius.full, t)!,
        );
        return Transform.scale(
          scale: 1 - 0.04 * press,
          child: AnimatedContainer(
            duration: AstryxMotion.of(AstryxMotion.medium),
            curve: AstryxMotion.emphasized,
            height: height,
            padding: EdgeInsets.symmetric(
              horizontal: extended ? AstryxSpace.s5 : AstryxSpace.s4,
            ),
            decoration: BoxDecoration(
              // The accent itself, not a tint of it. This is the one button the
              // app is asking you to press, and a muted version of the accent
              // reads as a button that is not available.
              color: c.accent,
              borderRadius: shape,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AceIconView(icon: icon, size: 22, color: c.onAccent),
                // The label slides away rather than vanishing: a width change
                // with nothing in between reads as a glitch, and the eye
                // follows the word out.
                AnimatedSize(
                  duration: AstryxMotion.of(AstryxMotion.medium),
                  curve: AstryxMotion.emphasized,
                  alignment: Alignment.centerLeft,
                  child: extended
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const SizedBox(width: AstryxSpace.s3),
                            Text(
                              label,
                              style: AstryxText.bodyStrong(c.onAccent),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A selectable pill chip.
class AceChip extends StatelessWidget {
  const AceChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final AceIcon? icon;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final Color foreground = selected ? c.onAccentMuted : c.textSecondary;

    return AceSpringy(
      enabled: onTap != null,
      onTap: onTap,
      builder: (BuildContext context, double press, bool hover) {
        final double t = press.clamp(0.0, 1.0);
        final BorderRadius shape = BorderRadius.circular(
          lerpDouble(AstryxRadius.full, AstryxRadius.container, t)!,
        );
        return Transform.scale(
          scale: 1 - 0.04 * press,
          child: Container(
            height: AstryxSize.elementMd,
            padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s3),
            decoration: BoxDecoration(
              color: selected
                  ? c.accentMuted
                  : (hover ? c.surfaceHighest : c.backgroundMuted),
              borderRadius: shape,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  AceIconView(icon: icon!, size: 16, color: foreground),
                  const SizedBox(width: AstryxSpace.s1_5),
                ],
                // One line, and no `Flexible`: a chip lives inside the
                // horizontal scroll views in the sort sheet, where the width is
                // unbounded and a flexible child is an assertion failure rather
                // than a fix.
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AstryxText.label(foreground),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// An expressive list row: springs on press, morphs its corners, and lifts to a
/// tonal surface when selected.
class AceListTile extends StatelessWidget {
  const AceListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return AceSpringy(
      enabled: onTap != null,
      onTap: onTap,
      builder: (BuildContext context, double press, bool hover) {
        final double t = press.clamp(0.0, 1.0);
        final BorderRadius shape = BorderRadius.circular(
          lerpDouble(AstryxRadius.container, AstryxRadius.inner, t)!,
        );
        return Transform.scale(
          scale: 1 - 0.02 * press,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 1),
            padding: padding ??
                const EdgeInsets.symmetric(
                  horizontal: AstryxSpace.s3,
                  vertical: AstryxSpace.s3,
                ),
            decoration: BoxDecoration(
              color: selected
                  ? c.accentMuted
                  : (hover ? c.surfaceHighest : Colors.transparent),
              borderRadius: shape,
            ),
            child: Row(
              children: <Widget>[
                if (leading != null) ...<Widget>[
                  leading!,
                  const SizedBox(width: AstryxSpace.s3),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: selected
                            ? AstryxText.bodyStrong(c.onAccentMuted)
                            : AstryxText.body(c.textPrimary),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AstryxSpace.s0_5),
                          child: Text(
                            subtitle!,
                            overflow: TextOverflow.ellipsis,
                            style: AstryxText.supporting(
                              selected ? c.onAccentMuted : c.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: AstryxSpace.s2),
                  trailing!,
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A floating pill toolbar — the expressive M3 toolbar, docked at the bottom of
/// a surface where a thumb can reach it.
class AceToolbarAction {
  const AceToolbarAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.destructive = false,
  });

  final AceIcon icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;
  final bool destructive;
}

class AceToolbar extends StatelessWidget {
  const AceToolbar({super.key, required this.actions});

  final List<AceToolbarAction> actions;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s2),
      decoration: BoxDecoration(
        color: c.backgroundPopover,
        borderRadius: BorderRadius.circular(AstryxRadius.full),
        border: Border.all(color: c.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: c.overlay.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      // Scrollable, so a toolbar that has grown a button does not overflow a
      // narrow phone: the row is wider than 360dp once there are seven of
      // them, and a RenderFlex overflow is a red bar across the message.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final AceToolbarAction action in actions)
            AceIconButton(
              icon: action.icon,
              tooltip: action.tooltip,
              onPressed: action.onPressed,
              selected: action.selected,
              variant: action.destructive
                  ? AceIconButtonVariant.danger
                  : (action.selected
                      ? AceIconButtonVariant.tonal
                      : AceIconButtonVariant.standard),
            ),
        ],
        ),
      ),
    );
  }
}

/// The Ace Mail mark: a postbox with its flag up and a letter at the front,
/// drawn as an outline on a Milk tile.
///
/// The flag is the one filled part, in the accent orange. Everything else is a
/// Milk fill with an ink outline — the accent means something because it is the
/// only thing wearing it. Same geometry as the launcher icon, at 108 units.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    // The launcher's own foreground, so the mark in the app and the mark on the
    // home screen are the same drawing rather than two that resemble each other.
    return Image.asset(
      'assets/brand/mark.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
    );
  }
}



/// The Material 3 **Expressive** loading indicator: a shape that morphs.
///
/// This is the real thing, not a spinner wearing its name. Expressive loading
/// is one form travelling through Material's shape families — a cookie, a
/// square with rounded corners, a four-pointed star, a pill — holding each
/// briefly before moving on, with the morph interpolated rather than cut. The
/// engine is `shape_morph.dart`, which is an implementation of that
/// specification's polygon morphing, and it is what every loading state in this
/// app draws.
///
/// Flutter's own `CircularProgressIndicator` is a progress ring; it is the right
/// control for *progress*, which is why the pull-to-refresh scrub passes a value
/// here and gets a morph frozen at that point rather than a loop.
class AceLoader extends StatelessWidget {
  const AceLoader({super.key, this.size = 40, this.color, this.progress});

  final double size;
  final Color? color;

  /// When set (0..1), the morph is scrubbed by that value instead of looping —
  /// which is how pull-to-refresh turns a drag into a shape change.
  final double? progress;

  @override
  Widget build(BuildContext context) => AceShapeMorph(
        size: size,
        color: color,
        progress: progress,
      );
}

/// A sender's initials on a tonal tile, used wherever there is no picture.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.initials,
    this.size = 40,
    this.tone,
    this.seed,
  });

  final String initials;
  final double size;
  final Color? tone;

  /// What the tone is derived from — usually the address, so one sender keeps
  /// one colour across the app.
  final String? seed;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final Color background = tone ?? _toneFor(seed ?? initials, c);

    // Clipped round. The painter below draws the squircle, which is the app's
    // own shape and reads well on a card — on an avatar it reads as an
    // unfinished box, and the thing inside it is a person.
    return ClipOval(
      child: CustomPaint(
        painter: _AvatarTile(color: background),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Text(
              initials,
              style: AstryxText.bodyStrong(c.onAccentMuted).copyWith(
                fontSize: size * 0.36,
                color: c.onAccentMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A stable tone per sender, drawn from the scheme's container roles so the
  /// avatars stay inside the expressive palette.
  static Color _toneFor(String seed, AstryxColors c) {
    final int hash = seed.codeUnits.fold<int>(7, (int a, int b) => a * 31 + b);
    final List<Color> tones = <Color>[
      c.accentMuted,
      c.secondaryContainer,
      c.tertiaryContainer,
      c.surfaceHighest,
    ];
    return tones[hash.abs() % tones.length];
  }
}

class _AvatarTile extends CustomPainter {
  const _AvatarTile({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      AstryxShape.squircle(Offset.zero & size),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _AvatarTile old) => old.color != color;
}


/// A switch in the shape Material 3 Expressive gives it: a pill, and a thumb
/// that carries a tick when it is on and a cross when it is off.
///
/// The mark is the point. A switch's position says which way it is set, but
/// position is a thing you have to read; a tick is a thing you recognise. It
/// also means the state survives being glanced at rather than looked at.
class AceSwitch extends StatefulWidget {
  const AceSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  State<AceSwitch> createState() => _AceSwitchState();
}

class _AceSwitchState extends State<AceSwitch>
    with SingleTickerProviderStateMixin {
  /// Drives the thumb, so the movement can overshoot.
  ///
  /// An `AnimatedAlign` gets the thumb there and stops dead. Material 3
  /// Expressive does not: the thumb carries momentum, arrives, and settles —
  /// and a switch that settles reads as a physical thing rather than as a
  /// picture of one.
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: AstryxMotion.of(const Duration(milliseconds: 320)),
    value: widget.value ? 1 : 0,
  );

  @override
  void didUpdateWidget(AceSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == oldWidget.value) return;
    if (widget.value) {
      _slide.forward();
    } else {
      _slide.reverse();
    }
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  void _toggle() {
    final ValueChanged<bool>? changed = widget.onChanged;
    if (changed == null) return;
    // A switch is the smallest decision in the app and the one people flip most
    // often, so it is the one that most needs to feel like it was touched.
    unawaited(AceHaptics.select());
    changed(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final bool enabled = widget.onChanged != null;
    final bool value = widget.value;

    const double trackWidth = 52;
    const double trackHeight = 32;
    const double inset = 4;
    final double thumb = trackHeight - inset * 2;

    return Semantics(
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? _toggle : null,
        child: AnimatedContainer(
          duration: AstryxMotion.of(const Duration(milliseconds: 260)),
          curve: AstryxMotion.emphasized,
          width: trackWidth,
          height: trackHeight,
          decoration: BoxDecoration(
            color: value
                ? (enabled ? c.accent : c.accent.withValues(alpha: 0.4))
                : c.surfaceHighest,
            borderRadius: BorderRadius.circular(trackHeight / 2),
            border: Border.all(
              color: value ? Colors.transparent : c.border,
            ),
          ),
          child: AnimatedBuilder(
            animation: _slide,
            builder: (BuildContext context, Widget? child) {
              // The overshoot: past the end and back. The curve only affects the
              // journey, so the resting position is always exact.
              final double eased =
                  Curves.easeOutBack.transform(_slide.value.clamp(0.0, 1.0));
              final double travel = trackWidth - thumb - inset * 2;
              return Stack(
                children: <Widget>[
                  Positioned(
                    left: inset + travel * eased,
                    top: inset,
                    child: AnimatedContainer(
                      duration: AstryxMotion.of(const Duration(milliseconds: 260)),
                      curve: AstryxMotion.emphasized,
                      width: thumb,
                      height: thumb,
                      decoration: BoxDecoration(
                        color: value ? c.onAccent : c.backgroundCard,
                        shape: BoxShape.circle,
                      ),
                      // The mark turns as it changes rather than being replaced:
                      // a tick appearing out of a cross is one thing becoming
                      // another, and a cut between two pictures is not.
                      child: AnimatedSwitcher(
                        duration: AstryxMotion.of(const Duration(milliseconds: 260)),
                        switchInCurve: AstryxMotion.emphasized,
                        switchOutCurve: AstryxMotion.emphasized,
                        transitionBuilder: (Widget child, Animation<double> a) {
                          return FadeTransition(
                            opacity: a,
                            child: RotationTransition(
                              turns: Tween<double>(begin: -0.35, end: 0)
                                  .animate(a),
                              child: ScaleTransition(
                                scale: Tween<double>(begin: 0.5, end: 1)
                                    .animate(a),
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: AceIconView(
                          key: ValueKey<bool>(value),
                          icon: value ? AceIcons.check : AceIcons.close,
                          size: 15,
                          color: value ? c.accent : c.iconSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The assistant's way in, on the bottom edge.
///
/// A pill in the middle of the screen rather than an icon in the search bar and
/// a bare FAB in the corner: it says what it does, it is the same distance from
/// either thumb, and it does not move as the list scrolls.
class AceAskChyme extends StatelessWidget {
  const AceAskChyme({super.key, required this.onAsk});

  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return AceGlass.material(
      context,
      radius: BorderRadius.circular(AstryxRadius.pill),
      bordered: true,
      opacity: 0.88,
      child: TextButton(
        onPressed: onAsk,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.fromLTRB(
            AstryxSpace.s4,
            AstryxSpace.s2,
            AstryxSpace.s4,
            AstryxSpace.s2,
          ),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ChymeMark(size: 20, color: c.accent),
            const SizedBox(width: AstryxSpace.s2),
            Text('Ask Chyme', style: AstryxText.bodyStrong(c.textPrimary)),
          ],
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/accents.dart';

/// Astryx's type scale, on a geometric ramp.
///
/// Astryx names families per role and leaves loading to the app; its own
/// default is Figtree. This theme uses **Geograph** for every role.
///
/// Geograph ships one weight — Regular. That is a real constraint, not an
/// oversight: hierarchy here is carried by size, tracking and colour, and the
/// weight values are kept so the roles stay faithful to Astryx the moment a
/// weighted companion is bundled alongside it. Material 3 Expressive wants a
/// high-contrast scale, so the display end of this ramp is deliberately further
/// from the body end than a default M3 scale would be.
abstract final class AstryxType {
  static const double base = 14;
  static const double ratio = 1.2;

  static const double s4xs = 6;
  static const double s3xs = 7;
  static const double s2xs = 8;
  static const double sXs = 10;
  static const double sSm = 12;
  static const double sBase = 14;
  static const double sLg = 17;
  static const double sXl = 20;
  static const double s2xl = 24;
  static const double s3xl = 29;
  static const double s4xl = 35;
  static const double s5xl = 42;

  /// Expressive additions — the display end of the ramp.
  static const double s6xl = 50;
  static const double s7xl = 60;

  static const FontWeight normal = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  /// Line height for a given size, kept tight at the display end the way an
  /// expressive scale wants it and looser for body copy.
  static double leading(double size) {
    if (size >= 35) return 1.06;
    if (size >= 24) return 1.14;
    if (size >= 17) return 1.32;
    return 1.45;
  }
}

/// Astryx's spacing scale, in 4s.
abstract final class AstryxSpace {
  static const double s0 = 0;
  static const double s0_5 = 2;
  static const double s1 = 4;
  static const double s1_5 = 6;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s7 = 28;
  static const double s8 = 32;
  static const double s9 = 36;
  static const double s10 = 40;
  static const double s11 = 44;
  static const double s12 = 48;
}

/// Astryx's shape scale, widened with the larger, softer corners Material 3
/// Expressive uses for buttons, sheets and large surfaces.
abstract final class AstryxRadius {
  static const double none = 0;
  static const double inner = 8;
  static const double element = 12;
  static const double container = 16;
  static const double lg = 24;
  static const double chat = 28;
  static const double page = 32;
  static const double xxl = 36;
  static const double full = 9999;

  /// Sheets and dialogs, at the size M3 Expressive gives them.
  static const double sheet = 28;

  /// A stadium: buttons and chips are fully rounded in expressive M3.
  static const double pill = full;
}

/// A stated height, grown with the text size.
///
/// Almost every fixed height in this app is a box with a label in it, and the
/// label follows the device's accessibility setting while the box does not. At
/// 1.5x a 40px button is 40px of text and no air; at 2x it is an overflow
/// stripe across whatever is behind it. The app multiplies the system scale by
/// its own text-size setting, so 2x is a setting somebody has rather than a
/// torture test.
///
/// [growth] is how much of [base] is added at twice the text size. Half suits
/// anything whose height is mostly its label, which is every button here.
///
/// One function rather than the same arithmetic in four widgets: they had
/// drifted into four slightly different versions of "a bit taller", and the one
/// that had not been updated was the one that broke.
double scaledForText(
  BuildContext context,
  double base, {
  double growth = 0.5,
  double ceiling = 2.2,
}) {
  final double scale =
      MediaQuery.textScalerOf(context).scale(1).clamp(1.0, ceiling);
  return base + base * growth * (scale - 1);
}

/// Astryx's element sizes.
abstract final class AstryxSize {
  static const double elementSm = 28;
  static const double elementMd = 32;
  static const double elementLg = 40;
  static const double elementXl = 56;
  static const double touchTarget = 44;
}

/// Continuous corners — the squircle Material 3 Expressive favours for large
/// surfaces.
abstract final class AstryxShape {
  /// A rounded rectangle whose corners are quarter **superellipses** rather
  /// than circular arcs.
  ///
  /// That is what makes the join between a straight edge and the curve
  /// imperceptible, which is the whole point of the shape. It is emphatically
  /// *not* a single superellipse stretched over the rectangle: on a wide, short
  /// card that produces an oval with no straight edges at all, which is the bug
  /// this replaces.
  static Path squircle(
    Rect rect, {
    double? radius,
    double exponent = 4,
    int samples = 10,
  }) {
    final double limit = math.min(rect.width, rect.height) / 2;
    final double r =
        (radius ?? math.min(limit * 0.5, AstryxRadius.xxl)).clamp(0.0, limit);
    if (r <= 0) return Path()..addRect(rect);

    final double l = rect.left;
    final double t = rect.top;
    final double right = rect.right;
    final double bottom = rect.bottom;

    final Path path = Path()..moveTo(l + r, t);
    path.lineTo(right - r, t);
    _corner(path, Offset(right - r, t + r), r, 3 * math.pi / 2, 2 * math.pi, exponent, samples);
    path.lineTo(right, bottom - r);
    _corner(path, Offset(right - r, bottom - r), r, 0, math.pi / 2, exponent, samples);
    path.lineTo(l + r, bottom);
    _corner(path, Offset(l + r, bottom - r), r, math.pi / 2, math.pi, exponent, samples);
    path.lineTo(l, t + r);
    _corner(path, Offset(l + r, t + r), r, math.pi, 3 * math.pi / 2, exponent, samples);
    return path..close();
  }

  /// One quarter superellipse, walked by angle. `exponent` 2 is a circular arc.
  static void _corner(
    Path path,
    Offset centre,
    double radius,
    double from,
    double to,
    double exponent,
    int samples,
  ) {
    final double power = 2 / exponent;
    for (int i = 1; i <= samples; i++) {
      final double angle = from + (to - from) * (i / samples);
      final double cosA = math.cos(angle);
      final double sinA = math.sin(angle);
      path.lineTo(
        centre.dx + radius * cosA.sign * math.pow(cosA.abs(), power).toDouble(),
        centre.dy + radius * sinA.sign * math.pow(sinA.abs(), power).toDouble(),
      );
    }
  }
}

/// A continuous-corner border, for Material widgets that take a [ShapeBorder].
@immutable
class AceSquircleBorder extends OutlinedBorder {
  const AceSquircleBorder({
    super.side = BorderSide.none,
    this.exponent = 4,
  });

  final double exponent;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  AceSquircleBorder scale(double t) =>
      AceSquircleBorder(side: side.scale(t), exponent: exponent);

  @override
  AceSquircleBorder copyWith({BorderSide? side}) =>
      AceSquircleBorder(side: side ?? this.side, exponent: exponent);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      AstryxShape.squircle(rect.deflate(side.width), exponent: exponent);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      AstryxShape.squircle(rect, exponent: exponent);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    canvas.drawPath(getOuterPath(rect), side.toPaint());
  }
}

/// Astryx's motion tokens.
///
/// Material 3 Expressive motion is spring-based rather than curve-based: things
/// that move use a spatial spring, things that only change colour or opacity
/// use an effects spring that never overshoots. Flutter does not ship these, so
/// they live here and are applied by [AceSpringy] and the route transitions.
abstract final class AstryxMotion {
  /// Set from the accessibility setting. When true, movement is taken out of
  /// the app's transitions rather than shortened: someone who has asked for
  /// less motion has asked for less motion, not faster motion.
  ///
  /// The loading indicator is exempt — it is a sign of work in progress, and a
  /// still one would look like a hung app.
  static bool reduced = false;

  /// A duration, or nothing at all when motion is off.
  static Duration of(Duration value) => reduced ? Duration.zero : value;

  /// Moving something small, like a press morph.
  static const SpringDescription spatialFast =
      SpringDescription(mass: 1, stiffness: 1400, damping: 68);

  /// The default for anything that travels.
  static const SpringDescription spatialDefault =
      SpringDescription(mass: 1, stiffness: 700, damping: 48);

  /// Large surfaces, sheets, page-level movement.
  static const SpringDescription spatialSlow =
      SpringDescription(mass: 1, stiffness: 300, damping: 32);

  /// Colour and opacity. Critically damped, so it settles without a wobble.
  static const SpringDescription effectsFast =
      SpringDescription(mass: 1, stiffness: 1400, damping: 75);

  static const SpringDescription effectsDefault =
      SpringDescription(mass: 1, stiffness: 700, damping: 53);

  /// Deliberately under-damped: this is the one that gives a press its life.
  static const SpringDescription press =
      SpringDescription(mass: 1, stiffness: 900, damping: 34);

  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 420);

  /// Material's emphasised easing, for the places an implicit animation is
  /// simpler than a spring.
  static const Curve emphasized = Cubic(0.2, 0, 0, 1);
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1);
  static const Curve emphasizedAccelerate = Cubic(0.3, 0, 0.8, 0.15);
  static const Curve standard = Curves.easeOutCubic;
}

/// Astryx's semantic colour roles.
///
/// This is a **vocabulary over the Material 3 Expressive scheme**, not a
/// parallel palette: the scheme is generated from the Milk & Orange seed with
/// the accent as the source colour, and this class reads from it. The brand
/// lives in the scheme's overridden roles, so the two systems cannot drift
/// apart.
@immutable
class AstryxColors extends ThemeExtension<AstryxColors> {
  const AstryxColors({
    required this.scheme,
    required this.accentInk,
    required this.success,
    required this.successMuted,
    required this.onSuccess,
    required this.warning,
    required this.warningMuted,
    required this.onWarning,
    required this.brandBorder,
  });

  /// The Material 3 Expressive scheme underneath.
  final ColorScheme scheme;

  // --- semantic roles Material's scheme does not carry -------------------

  /// Orange as *text* on the page, which the fill role cannot be: the brand
  /// orange is only 2.8:1 on Milk. This is 5.9:1 there, and 10:1 in dark mode.
  final Color accentInk;
  final Color success;
  final Color successMuted;
  final Color onSuccess;
  final Color warning;
  final Color warningMuted;
  final Color onWarning;
  final Color brandBorder;

  factory AstryxColors.fromScheme(ColorScheme scheme) {
    final bool dark = scheme.brightness == Brightness.dark;

    // The accent as *text* — a link, a chip's label, "Look around first" — has
    // to clear AA on every surface it can land on, not only the page. It used
    // to be one fixed brown: it cleared the page and missed the muted surface
    // by a tenth of a point, for all ten accents, which is the kind of failure
    // no single accent would ever have revealed.
    final Color accentText = readableEverywhere(
      scheme.primary,
      <Color>[
        scheme.surface,
        scheme.surfaceContainerLowest,
        scheme.surfaceContainerLow,
        scheme.surfaceContainerHigh,
        scheme.surfaceContainerHighest,
      ],
      dark: dark,
    );

    return AstryxColors(
      scheme: scheme,
      accentInk: accentText,
      success: dark ? const Color(0xFF9CD8A4) : const Color(0xFF1D6B2F),
      successMuted: dark ? const Color(0xFF20401F) : const Color(0xFFC8E8C6),
      onSuccess: dark ? const Color(0xFF06210B) : const Color(0xFFFFFFFF),
      warning: dark ? const Color(0xFFF3CE6B) : const Color(0xFF6B4E00),
      warningMuted: dark ? const Color(0xFF4A3A10) : const Color(0xFFFFE7A8),
      onWarning: dark ? const Color(0xFF241A00) : const Color(0xFF1A1200),
      brandBorder: scheme.primary.withValues(alpha: dark ? 0.55 : 0.38),
    );
  }

  // --- accent ------------------------------------------------------------
  Color get accent => scheme.primary;
  Color get onAccent => scheme.onPrimary;
  Color get accentMuted => scheme.primaryContainer;
  Color get onAccentMuted => scheme.onPrimaryContainer;
  Color get neutral => scheme.surfaceContainerHighest;

  // --- surfaces, on Material's tonal ramp --------------------------------
  Color get backgroundBody => scheme.surface;
  Color get backgroundSurface => scheme.surfaceContainerLowest;
  Color get backgroundCard => scheme.surfaceContainerLow;
  Color get backgroundPopover => scheme.surfaceContainer;
  Color get backgroundMuted => scheme.surfaceContainerHigh;
  Color get surfaceHighest => scheme.surfaceContainerHighest;
  Color get surfaceBright => scheme.surfaceBright;
  Color get surfaceDim => scheme.surfaceDim;

  // --- state layers ------------------------------------------------------
  Color get overlay => scheme.scrim;
  Color get overlayHover => scheme.onSurface.withValues(alpha: 0.08);
  Color get overlayPressed => scheme.onSurface.withValues(alpha: 0.12);

  // --- content -----------------------------------------------------------
  Color get textPrimary => scheme.onSurface;
  Color get textSecondary => scheme.onSurfaceVariant;
  Color get textDisabled => scheme.outline;
  Color get textAccent => accentInk;
  Color get iconPrimary => scheme.onSurface;
  Color get iconSecondary => scheme.onSurfaceVariant;
  Color get iconDisabled => scheme.outline;

  Color get border => scheme.outlineVariant;
  Color get borderEmphasized => scheme.outline;

  // --- status ------------------------------------------------------------
  Color get error => scheme.error;
  Color get errorMuted => scheme.errorContainer;
  Color get onError => scheme.onError;
  Color get onErrorMuted => scheme.onErrorContainer;

  // --- the brand ramp ----------------------------------------------------
  Color get backgroundOrange => scheme.primaryContainer;
  Color get borderOrange => brandBorder;
  Color get iconOrange => scheme.onPrimaryContainer;
  Color get textOrange => scheme.onPrimaryContainer;

  // --- expressive extras -------------------------------------------------
  Color get tertiary => scheme.tertiary;
  Color get tertiaryContainer => scheme.tertiaryContainer;
  Color get onTertiaryContainer => scheme.onTertiaryContainer;
  Color get secondaryContainer => scheme.secondaryContainer;
  Color get onSecondaryContainer => scheme.onSecondaryContainer;
  Color get inverseSurface => scheme.inverseSurface;
  Color get onInverseSurface => scheme.onInverseSurface;
  Color get inversePrimary => scheme.inversePrimary;

  @override
  AstryxColors copyWith({ColorScheme? scheme}) =>
      AstryxColors.fromScheme(scheme ?? this.scheme);

  @override
  AstryxColors lerp(covariant AstryxColors? other, double t) {
    if (other == null) return this;
    return AstryxColors(
      scheme: ColorScheme.lerp(scheme, other.scheme, t),
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      success: Color.lerp(success, other.success, t)!,
      successMuted: Color.lerp(successMuted, other.successMuted, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningMuted: Color.lerp(warningMuted, other.warningMuted, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      brandBorder: Color.lerp(brandBorder, other.brandBorder, t)!,
    );
  }
}

/// `context.astryx` resolves the active mode's palette from the theme.
extension AstryxContext on BuildContext {
  AstryxColors get astryx =>
      Theme.of(this).extension<AstryxColors>() ??
      AstryxColors.fromScheme(Theme.of(this).colorScheme);
}

/// Walks [ink] along its own lightness until it clears AA against every one of
/// [surfaces].
///
/// The alternative — a colour checked against the page and then used on four
/// other surfaces — is how the accent-as-text ended up readable everywhere
/// except the muted one. Pure, so the walk can be reasoned about on its own.
Color readableEverywhere(
  Color ink,
  List<Color> surfaces, {
  required bool dark,
  double target = 4.5,
}) {
  final Color toward = dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
  Color candidate = ink;
  for (int step = 0; step <= 40; step++) {
    final bool clear = surfaces.every(
      (Color surface) => contrastRatio(candidate, surface) >= target,
    );
    if (clear) return candidate;
    candidate = Color.lerp(candidate, toward, 0.05)!;
  }
  return candidate;
}

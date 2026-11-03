import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/haptics.dart';
import 'ace_glass.dart';
import 'ace_icon_view.dart';

/// One entry in the floating bar.
class AceNavItem<T> {
  const AceNavItem({
    required this.value,
    required this.icon,
    required this.label,
  });

  final T value;
  final AceIcon icon;
  final String label;
}

/// A floating navigation bar, in the shape Material 3 Expressive draws one.
///
/// It floats: a pill of its own surface, clear of the bottom edge, with the
/// page visible on both sides of it. A bar welded to the bottom edge is a
/// region of the screen; a bar that floats is a thing on the screen, which is
/// the difference the shape is there to make.
///
/// The current item is the only one that says its name. Two labels always on
/// screen is a bar that reads like a table of contents; one label, moving,
/// reads like a choice that has been made.
/// The bar's height, and the height of one item inside it.
///
/// Pinned rather than derived. The bar is placed in a `Stack` as a `Positioned`
/// with `left` and `bottom`, which hands it *loose* constraints — and a
/// `Container` with a decoration and no height, in a loose box, is a container
/// whose height is whatever its child decides. The child is a `Row` whose
/// selected item is a filled pill; a pill with no height in a loose box fills
/// what it is given. The result, on a phone, was a nav bar that ran from under
/// the app bar to the bottom of the screen with the labels marooned in the
/// middle of it.
///
/// Two numbers is a cheap price for a bar that is the same size everywhere.
const double _barHeight = 60;
const double _itemHeight = 44;

class AceFloatingNav<T> extends StatelessWidget {
  const AceFloatingNav({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.floating = true,
  });

  final List<AceNavItem<T>> items;
  final T value;
  final ValueChanged<T> onChanged;

  /// Whether the bar places itself — its own safe area, its own edge.
  ///
  /// True where it is the only thing at the bottom of the screen. False where
  /// something else shares that row: a bar that brings its own safe-area
  /// padding into a `Row` sits higher than whatever is beside it, because the
  /// padding is inside its box and the `Row` centres the boxes. The owner of
  /// the row applies the safe area once, for everything in it.
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    final Widget bar = SizedBox(
          height: _barHeight,
          child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AstryxRadius.pill),
            // A soft, wide shadow rather than a hard one: the bar should look
            // lifted off the page, not cut into it.
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: c.textPrimary.withValues(alpha: 0.10),
                blurRadius: 18,
                spreadRadius: -6,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          // The bar is the one surface that is *always* over something — the
          // list scrolls behind it — so it is the one that earns the material.
          // On a device that cannot blur it is the same bar in the same colour.
          child: AceGlass.material(
            context,
            radius: BorderRadius.circular(AstryxRadius.pill),
            bordered: true,
            opacity: 0.78,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AstryxSpace.s2,
                vertical: AstryxSpace.s2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  for (final AceNavItem<T> item in items)
                    _NavButton<T>(
                      item: item,
                      selected: item.value == value,
                      onTap: () {
                        if (item.value == value) return;
                        unawaited(AceHaptics.select());
                        onChanged(item.value);
                      },
                    ),
                ],
              ),
            ),
          ),
          ),
        );

    if (!floating) return bar;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AstryxSpace.s4,
        0,
        AstryxSpace.s4,
        AstryxSpace.s4,
      ),
      // Left-aligned and sized to its own content: the bar hugs the leading
      // edge and never stretches to fill the height it is given.
      child: Align(
        alignment: Alignment.centerLeft,
        widthFactor: 1,
        heightFactor: 1,
        // The height is stated, not inherited from the constraints. See
        // [_barHeight]: the loose constraints a `Positioned` provides are what
        // let this grow to fill the screen.
        child: bar,
      ),
    );
  }
}

class _NavButton<T> extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AceNavItem<T> item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AstryxMotion.of(const Duration(milliseconds: 300)),
          curve: AstryxMotion.emphasized,
          height: _itemHeight,
          padding: const EdgeInsets.symmetric(
            horizontal: AstryxSpace.s3,
            vertical: AstryxSpace.s2,
          ),
          decoration: BoxDecoration(
            // The selection is a fill, which is the only way the stroke-only
            // icon set can say "this one" without a second set of glyphs.
            color: selected ? c.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(AstryxRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              AceIconView(
                icon: item.icon,
                size: 22,
                color: selected ? c.onAccent : c.iconSecondary,
              ),
              // The label is animated rather than switched: it grows out of the
              // icon and collapses back into it, so the bar does not jump.
              AnimatedSize(
                duration: AstryxMotion.of(const Duration(milliseconds: 300)),
                curve: AstryxMotion.emphasized,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: AstryxSpace.s2),
                        child: Text(
                          item.label,
                          style: AstryxText.label(c.onAccent),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

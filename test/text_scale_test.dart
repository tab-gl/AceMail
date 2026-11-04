import 'package:ace_mail/theme/ace_icons.dart';
import 'package:ace_mail/theme/astryx_theme.dart';
import 'package:ace_mail/theme/astryx_tokens.dart';
import 'package:ace_mail/widgets/astryx_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app multiplies the device's text size by its own, so 2x is a setting a
/// person can have — and every fixed height in the app is a box with a label in
/// it. These are the shared controls: fix one here and every screen that uses
/// it stops breaking at once.
void main() {
  Widget host(Widget child, {double textScale = 1}) => MaterialApp(
        theme: buildAstryxTheme(Brightness.light),
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(400, 800),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: Center(child: child),
          ),
        ),
      );

  /// The rule, measured in a real context at a real text size.
  Future<double> measure(WidgetTester tester, double scale) async {
    late double value;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (BuildContext context) {
            value = scaledForText(context, 40);
            return const SizedBox.shrink();
          },
        ),
        textScale: scale,
      ),
    );
    return value;
  }

  group('scaledForText', () {
    testWidgets('is the stated height at the default text size',
        (WidgetTester tester) async {
      expect(await measure(tester, 1), 40);
    });

    testWidgets('is half again at twice the text size',
        (WidgetTester tester) async {
      expect(await measure(tester, 2), 60);
    });

    testWidgets('stops growing at the ceiling', (WidgetTester tester) async {
      // 2.2 is the ceiling: past it the box stops growing, because a label at
      // three times the size is a label that needs a different layout, not a
      // taller button.
      expect(await measure(tester, 3), await measure(tester, 2.2));
    });
  });

  group('the shared buttons', () {
    testWidgets('AceButton grows to hold its label', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          AceButton(
            label: 'Load older messages',
            icon: AceIcons.expandMore,
            onPressed: () {},
          ),
        ),
      );
      final double small = tester.getSize(find.byType(AceButton)).height;

      await tester.pumpWidget(
        host(
          AceButton(
            label: 'Load older messages',
            icon: AceIcons.expandMore,
            onPressed: () {},
          ),
          textScale: 2,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(AceButton)).height,
        greaterThan(small),
      );
    });

    testWidgets('AceFab grows to hold its label', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          AceFab(label: 'Compose', icon: AceIcons.edit, onPressed: () {}),
          textScale: 2,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(AceFab)).height,
        greaterThan(AstryxSize.elementXl),
      );
    });

    testWidgets('a long label ellipsises rather than wrapping out of the box',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 160,
            child: AceButton(
              label: 'A label far too long for the space it has been given',
              onPressed: () {},
            ),
          ),
          textScale: 2,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });

    testWidgets('a chip survives the horizontal scroller it lives in',
        (WidgetTester tester) async {
      // The sort sheet's chips are in a Row inside a horizontal scroll view,
      // where the width is unbounded. A flexible child there is an assertion
      // failure, not a fix — this is the test that would have caught it.
      await tester.pumpWidget(
        host(
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                AceChip(label: 'Unread', selected: true, onTap: () {}),
                const SizedBox(width: 8),
                AceChip(label: 'Flagged', onTap: () {}),
              ],
            ),
          ),
          textScale: 2,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });
  });
}

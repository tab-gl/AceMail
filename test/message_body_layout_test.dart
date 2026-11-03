import 'package:ace_mail/data/preferences.dart';
import 'package:ace_mail/theme/ace_icons.dart';
import 'package:ace_mail/theme/astryx_theme.dart';
import 'package:ace_mail/widgets/ace_floating_nav.dart';
import 'package:ace_mail/widgets/message_html.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Two layout bugs that a screenshot caught and a test should have.
///
/// Both of them were *loose constraints*: a widget placed somewhere that gives
/// it `minWidth: 0` or no height at all, which then decides its own size from
/// its content instead of from the screen. Neither shows up under tight
/// constraints, which is why the app had been passing its tests while drawing
/// a mail body one letter wide.
void main() {
  const Color ink = Color(0xFF1A1A1A);

  group('the message body', () {
    Future<void> pump(WidgetTester tester, String html) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstryxTheme(Brightness.light),
          home: Scaffold(
            body: Column(
              // The box the reader actually puts it in. `start` gives every
              // child a loose width, which is what collapsed the body.
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AceHtml(
                  html: html,
                  baseStyle: AstryxText.body(ink),
                  linkColor: ink,
                  codeStyle: AstryxText.body(ink),
                  loadRemoteImages: false,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('a layout-table body is laid out at the full width',
        (WidgetTester tester) async {
      // A Gmail receipt, reduced to the part that broke: a table with a
      // percentage width. `width: 100%` of a minimum intrinsic width is about
      // one character, and the body drew as one letter per line down the
      // middle of the screen.
      await pump(
        tester,
        '<table width="100%"><tr><td>'
        '<p>Your Google account access to some of your data</p>'
        '</td></tr></table>',
      );

      final double screen = tester.getSize(find.byType(Scaffold)).width;
      final double body = tester.getSize(find.byType(AceHtml)).width;

      expect(body, closeTo(screen, 1));
    });

    testWidgets('a plain paragraph is laid out at the full width',
        (WidgetTester tester) async {
      await pump(tester, '<p>Your Google account access to some of your data</p>');

      final double screen = tester.getSize(find.byType(Scaffold)).width;
      final double body = tester.getSize(find.byType(AceHtml)).width;

      expect(body, closeTo(screen, 1));
    });
  });

  group('the nav bar', () {
    testWidgets('brings no safe area when it shares a row', (WidgetTester tester) async {
      // The bottom of a phone screen holds the tabs, Ask Chyme and Compose. The
      // nav applies the safe area for that row only when it is alone: its own
      // padding inside a `Row` would lift it above whatever sits beside it.
      // The bar is glass, and glass reads its blur and tint from the
      // preferences — so the provider is part of what the app supplies, not a
      // test convenience. Without it the build throws and the size measured is
      // the failed subtree's, which is how this test first passed 600.
      await tester.pumpWidget(
        ChangeNotifierProvider<Preferences>.value(
          value: Preferences(),
          child: MaterialApp(
            theme: buildAstryxTheme(Brightness.light),
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: Row(
                  children: <Widget>[
                    AceFloatingNav<bool>(
                      floating: false,
                      value: false,
                      onChanged: (bool _) {},
                      items: const <AceNavItem<bool>>[
                        AceNavItem<bool>(
                          value: false,
                          icon: AceIcons.inbox,
                          label: 'Mail',
                        ),
                        AceNavItem<bool>(
                          value: true,
                          icon: AceIcons.contacts,
                          label: 'Contacts',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.getSize(find.byType(AceFloatingNav<bool>)).height, 60);
    });
  });
}

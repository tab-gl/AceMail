import 'package:ace_mail/theme/astryx_theme.dart';
import 'package:ace_mail/widgets/astryx_widgets.dart';
import 'package:ace_mail/widgets/voice_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The microphone is shared between the search bar and the assistant's
/// composer, and the two want different sizes out of the same widget. That is
/// the whole reason it is a widget: two microphones written twice drift into
/// two microphones that pulse differently.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool listening,
    double size = 44,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAstryxTheme(Brightness.light),
        home: Scaffold(
          body: Center(
            child: VoiceButton(
              listening: listening,
              size: size,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('is the size it was asked for', (WidgetTester tester) async {
    await pump(tester, listening: false, size: 48);

    // The composer asks for 48 against the 44 every other icon button uses, so
    // the one control that means "speak instead of type" is not the same
    // weight as the ones beside it.
    expect(tester.getSize(find.byType(AceIconButton)), const Size(48, 48));
  });

  testWidgets('says what it is for when it is idle', (WidgetTester tester) async {
    await pump(tester, listening: false);

    expect(find.byTooltip('Search by voice'), findsOneWidget);
  });

  testWidgets('says it is listening while it listens', (WidgetTester tester) async {
    // Nothing else on screen changes when a recogniser is open — the speech app
    // is a separate window — so this is the only sign that the app is still
    // waiting for an answer.
    await pump(tester, listening: true);

    expect(find.byTooltip('Listening…'), findsOneWidget);
  });

  testWidgets('stops pulsing when the listening does', (WidgetTester tester) async {
    await pump(tester, listening: true);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAstryxTheme(Brightness.light),
        home: Scaffold(
          body: Center(
            child: VoiceButton(listening: false, onPressed: () {}),
          ),
        ),
      ),
    );
    // A pulse left running is a widget that never settles, which is a test that
    // hangs rather than fails. Settling is the assertion.
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

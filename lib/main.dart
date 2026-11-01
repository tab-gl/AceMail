import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'util/redact.dart';
import 'data/app_info.dart';
import 'data/firebase_options.dart';
import 'data/local_store.dart';
import 'data/preferences.dart';
import 'theme/custom_appearance.dart';
import 'services/launcher_icon.dart';
import 'services/local_avatars.dart';
import 'services/notification_setup.dart';
import 'state/mail_controller.dart';
import 'state/chyme_conversation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase, when this build was given a project. Deliberately not awaited
  // before the first frame: mail does not depend on it, and a backend that is
  // slow to start must not be the reason the mailbox is slow to open. It never
  // throws — see startFirebase.
  unawaited(startFirebase());

  // Room for decoded images, but not so much that the app is the reason a
  // low-end phone is out of memory. The default is sized for a handful of
  // pictures; a mail reader scrolls through many, so it needs more — 80MB was
  // more than the phones this has to run on can spare, and the cost of being
  // wrong here is not a slow screen, it is the app being killed in the
  // background while somebody is reading their mail.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 48 << 20;

  // The encrypted local store: the draft in progress, and the messages already
  // read. Best effort — a device that will not hand over a directory must not
  // stop the app starting. Without it nothing is cached, which is a working
  // mail client, just a slower one.
  // The pictures people chose for their own addresses. Beside the store
  // because it needs the same directory, and best effort for the same reason.
  await LocalAvatars.init();

  LocalStore? localStore;
  try {
    localStore = await LocalStore.open();
  } catch (error) {
    debugPrint('Ace Mail: no local cache (${Redact.safe(error)})');
  }

  // Created here rather than in a provider callback so the controller can hold
  // the same instance — the reading settings live on it.
  final Preferences preferences = Preferences();
  final MailController controller =
      MailController(preferences: preferences, localStore: localStore);

  // Read the keychain and the settings before the first frame, so the app opens
  // straight into the mailbox or the sign-in screen. There is no intermediate
  // loading screen; the native launch window covers the moment this takes.
  await Future.wait<void>(<Future<void>>[
    preferences.load(),
    controller.restore(),
    AppInfo.load(),
  ]);

  // The user's own font, registered before the first frame so the app never
  // paints in the system face and then swaps. A missing or broken file leaves
  // the family null, which is the same as never having chosen one.
  await CustomAppearance.installFont(preferences.customFontPath);

  // The launcher icon wears the accent. Applied on every start rather than only
  // when the setting changes, because the alias that carries it can be reset by
  // an install over the top of an old build.
  unawaited(
    LauncherIcon.apply(preferences.accent, mark: preferences.launcherMark),
  );

  // Registered before the first frame, so a scheduled check that fires while
  // the app is closed has somewhere to land. Nothing is scheduled unless the
  // setting says so.
  await NotificationSetup.initialise();
  if (preferences.notifyNewMail) {
    // Registered, not asked: a permission prompt at launch is one nobody asked
    // for, and this used to put one on screen every single start on a device
    // that had already refused.
    await NotificationSetup.apply(enabled: true);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<Preferences>.value(value: preferences),
        ChangeNotifierProvider<MailController>.value(value: controller),
        ChangeNotifierProvider<ChymeConversation>(create: (_) => ChymeConversation()),
        Provider<LocalStore?>.value(value: localStore),
      ],
      child: const AceMailApp(),
    ),
  );
}

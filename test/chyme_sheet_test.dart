import 'dart:io';
import 'dart:math';

import 'package:ace_mail/data/account_store.dart';
import 'package:ace_mail/data/preferences.dart';
import 'package:ace_mail/data/vault.dart';
import 'package:ace_mail/models/contact.dart';
import 'package:ace_mail/models/mail_folder.dart';
import 'package:ace_mail/screens/mailbox_screen.dart';
import 'package:ace_mail/screens/settings_screen.dart';
import 'package:ace_mail/services/chyme.dart';
import 'package:ace_mail/services/contacts.dart';
import 'package:ace_mail/services/device_contacts.dart';
import 'package:ace_mail/state/mail_controller.dart';
import 'package:ace_mail/state/chyme_conversation.dart';
import 'package:ace_mail/state/mail_session.dart';
import 'package:ace_mail/theme/astryx_theme.dart';
import 'package:ace_mail/widgets/chyme_pickers.dart';
import 'package:ace_mail/widgets/chyme_sheet.dart';
import 'package:ace_mail/widgets/contacts_panel.dart';
import 'package:ace_mail/widgets/message_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fake_transport.dart';

/// A keychain that is a map, so the store can be tested without a platform.
class MapKeys implements KeyStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// A mailbox that actually has unread mail in it.
///
/// The stock fake reports zero, which is exactly the state the unread counter
/// used to be stuck in — so a test against it would pass whether the counter
/// worked or not.
class UnreadTransport extends FakeTransport {
  UnreadTransport(this.unseen);

  final int unseen;

  @override
  Future<List<MailFolder>> connect(String password) async {
    final List<MailFolder> folders = await super.connect(password);
    return <MailFolder>[
      for (final MailFolder folder in folders)
        folder.role == FolderRole.inbox
            ? folder.copyWith(unseen: unseen)
            : folder,
    ];
  }
}

void main() {
  group('the folder unread count', () {
    test('drops when a message is opened and read', () async {
      final UnreadTransport transport = UnreadTransport(5)
        ..uids.addAll(uidRange(3))
        ..unread.addAll(uidRange(3));
      final MailSession session = MailSession(
        account: accountA,
        password: 'p',
        transport: transport,
      );
      await session.connect();
      expect(session.selectedFolder?.unseen, 5);

      await session.open(session.messages.first);
      expect(session.selectedFolder?.unseen, 4);
    });

    test('comes back when the message is marked unread again', () async {
      final UnreadTransport transport = UnreadTransport(2)
        ..uids.addAll(uidRange(3))
        ..unread.addAll(uidRange(3));
      final MailSession session = MailSession(
        account: accountA,
        password: 'p',
        transport: transport,
      );
      await session.connect();

      await session.open(session.messages.first);
      expect(session.selectedFolder?.unseen, 1);

      await session.markOpenUnread();
      expect(session.selectedFolder?.unseen, 2);
    });

    test('never goes below zero', () async {
      final UnreadTransport transport = UnreadTransport(1)
        ..uids.addAll(uidRange(2))
        ..unread.addAll(uidRange(2));
      final MailSession session = MailSession(
        account: accountA,
        password: 'p',
        transport: transport,
      );
      await session.connect();

      await session.open(session.messages.first);
      await session.open(session.messages[1]);
      expect(session.selectedFolder?.unseen, 0);
    });
  });

  group('importing from the device address book', () {
    test('saves the addresses it is given, and skips what is not one', () async {
      final int changed = await Contacts.importContacts(<Contact>[
        const Contact(email: 'Ann@Example.com', name: 'Ann Example'),
        const Contact(email: 'not-an-address'),
        const Contact(email: ''),
      ]);
      expect(changed, 1);

      final Contact? ann = Contacts.byEmail('ann@example.com');
      expect(ann, isNotNull);
      expect(ann!.name, 'Ann Example');
      expect(ann.saved, isTrue, reason: 'a device contact is a decision');
    });

    test('a second import of the same book changes nothing', () async {
      const Contact ann = Contact(email: 'ann@example.com', name: 'Ann Example');
      expect(await Contacts.importContacts(<Contact>[ann]), 0);
    });

    test('an address with no name yet takes the address book\'s', () async {
      expect(
        await Contacts.importContacts(<Contact>[
          const Contact(email: 'nameless@example.org', name: 'From The Book'),
        ]),
        1,
      );
      expect(Contacts.byEmail('nameless@example.org')?.name, 'From The Book');
    });

    test('an import stops at the cap the list promises', () async {
      // A device book can hold more addresses than the list is allowed to.
      final List<Contact> book = <Contact>[
        for (int i = 0; i < Contacts.limit + 25; i++)
          Contact(email: 'person$i@example.org', name: 'Person $i'),
      ];
      await Contacts.importContacts(book);
      expect(Contacts.all.length, lessThanOrEqualTo(Contacts.limit));
      expect(Contacts.byEmail('person${Contacts.limit + 24}@example.org'), isNull);

      // A name already known is not overwritten by the address book's: the one
      // in the mail is the one the person has been writing to.
      expect(
        await Contacts.importContacts(<Contact>[
          const Contact(email: 'person0@example.org', name: 'Person Zero'),
        ]),
        0,
      );
      expect(Contacts.byEmail('person0@example.org')?.name, 'Person 0');

    });

    test('removing a contact forgets the record entirely', () async {
      await Contacts.remove('ann@example.com');
      expect(Contacts.byEmail('ann@example.com'), isNull);
    });
  });

  group('saved accounts', () {
    test('a password round-trips, and is not on the disk in the clear',
        () async {
      final Directory directory =
          await Directory.systemTemp.createTemp('ace-accounts');
      final File file = File('${directory.path}/credentials.ace');
      final AccountStore store = AccountStore(
        directory: directory,
        vault: AceVault(keys: MapKeys(), random: Random(7)),
        legacy: MapKeys(),
      );

      final String? failure = await store.saveAll(<StoredAccount>[
        (account: accountA, password: 'hunter2-and-a-half'),
      ]);
      expect(failure, isNull);
      expect(await file.exists(), isTrue);

      final AccountLoad load = await store.loadAll();
      expect(load.error, isNull);
      expect(load.accounts.single.account.email, accountA.email);
      expect(load.accounts.single.password, 'hunter2-and-a-half');

      final String raw = String.fromCharCodes(await file.readAsBytes());
      expect(raw.contains('hunter2'), isFalse,
          reason: 'the record is sealed, not stored as JSON');
      expect(raw.contains('imap.example.com'), isFalse);

      await directory.delete(recursive: true);
    });

    test('a record that has been altered does not open', () async {
      final Directory directory =
          await Directory.systemTemp.createTemp('ace-accounts');
      final File file = File('${directory.path}/credentials.ace');
      final MapKeys keys = MapKeys();
      final AccountStore store = AccountStore(
        directory: directory,
        vault: AceVault(keys: keys, random: Random(3)),
        legacy: MapKeys(),
      );
      await store.saveAll(<StoredAccount>[
        (account: accountA, password: 'secret'),
      ]);

      final List<int> bytes = await file.readAsBytes();
      bytes[bytes.length - 1] = bytes.last ^ 0xFF;
      await file.writeAsBytes(bytes, flush: true);

      // No sealed copy and no keychain in a test: the accounts are simply gone
      // rather than silently wrong.
      final AccountLoad load = await store.loadAll();
      expect(load.accounts, isEmpty);

      await directory.delete(recursive: true);
    });
  });

  group('Chyme can do things, not only read', () {
    test('the prompt names every tool the sheet implements', () {
      for (final String tool in <String>[
        'mail_search',
        'message_read',
        'message_star',
        'message_unstar',
        'message_mark_read',
        'message_archive',
        'message_delete',
        'message_reply',
        'contact_search',
        'contact_add',
        'contact_block',
        'contact_delete',
      ]) {
        expect(
          Chyme.systemPrompt.contains(tool),
          isTrue,
          reason: 'the model cannot use a tool it was not told about: $tool',
        );
      }
    });

    test('a tool line is read whatever the name looks like', () {
      final ChymeToolCall? call =
          Chyme.toolFrom('Starring it now.\nTOOL: contact_add Ann | ann@x.com');
      expect(call?.name, 'contact_add');
      expect(call?.argument, 'Ann | ann@x.com');

      final ChymeToolCall? reply =
          Chyme.toolFrom('TOOL: message_reply 12 | Thanks, I will look today.');
      expect(reply?.name, 'message_reply');
      expect(reply?.argument, '12 | Thanks, I will look today.');

      // A tool with no argument at all still parses, rather than being lost.
      expect(Chyme.toolFrom('TOOL: message_read')?.name, 'message_read');
    });

    test('it is told it never sends anything', () {
      expect(Chyme.systemPrompt.contains('never send'), isTrue);
    });
  });

  group('the surfaces exist and compile', () {
    test('settings opens at the Chyme card', () {
      const SettingsScreen screen = SettingsScreen(focus: SettingsFocus.chyme);
      expect(screen.focus, SettingsFocus.chyme);
    });

    test('the reader closes without a back chevron when it is a sheet', () {
      bool closed = false;
      final MessageReader sheet = MessageReader(onDismiss: () => closed = true);
      expect(sheet.onBack, isNull, reason: 'no chevron: the handle is the way out');
      expect(sheet.onDismiss, isNotNull);
      sheet.onDismiss!();
      expect(closed, isTrue);
    });

    test('the contacts panel takes a query and the device import exists', () {
      const ContactsPanel panel = ContactsPanel(query: 'ann');
      expect(panel.query, 'ann');
      // No address book on the machine that runs the tests.
      expect(DeviceContacts.isSupported, isFalse);
    });

    test('the mailbox screen still exists', () {
      expect(MailboxScreen.new, isNotNull);
    });

    test('a folder can be copied with a new count', () {
      const MailFolder folder = MailFolder(
        name: 'Inbox',
        path: 'INBOX',
        role: FolderRole.inbox,
        unseen: 4,
      );
      final MailFolder next = folder.copyWith(unseen: 3);
      expect(next.unseen, 3);
      expect(folder.unseen, 4, reason: 'the original is untouched');
      expect(next.path, folder.path);
    });
  });

  testWidgets('the sheet offers the model and the tone, and changes them',
      (WidgetTester tester) async {
    final Preferences prefs = Preferences();
    final MailController controller = MailController();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Preferences>.value(value: prefs),
          ChangeNotifierProvider<MailController>.value(value: controller),
          ChangeNotifierProvider<ChymeConversation>(create: (_) => ChymeConversation()),
        ],
        child: MaterialApp(
          theme: buildAstryxTheme(Brightness.light),
          home: const Scaffold(body: ChymeSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Both settings are in the header, one tap from the conversation.
    expect(find.text('Choose a model'), findsOneWidget);
    expect(find.text('Neutral'), findsOneWidget);

    await tester.tap(find.text('Neutral'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Brief').last);
    await tester.pumpAndSettle();

    expect(prefs.chymeTone, ChymeTone.brief);
    expect(find.text('Brief'), findsOneWidget);
    expect(chooseChymeTone, isNotNull);
    expect(chooseChymeModel, isNotNull);
  });
}

import 'dart:io';

import 'package:ace_mail/models/contact.dart';
import 'package:ace_mail/services/contacts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late ContactsStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ace-contacts-');
    store = ContactsStore(directory: directory);
  });

  tearDown(() async {
    store.dispose();
    Contacts.resetForTesting();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('saving and unsaving invalidates cached contact lists', () async {
    await store.load();
    final int initial = store.revision;
    await store.setSaved('ann@example.com', true);
    expect(store.revision, initial + 1);
    expect(store.byEmail('ann@example.com')?.saved, isTrue);
    await store.setSaved('ann@example.com', true);
    expect(store.revision, initial + 1, reason: 'no-op writes do not invalidate');
    await store.setSaved('ann@example.com', false);
    expect(store.revision, initial + 2);
  });

  test('imports normalize once and are idempotent', () async {
    await store.load();
    const Contact incoming = Contact(email: 'Ann@Example.com', name: 'Ann');
    expect(await store.importContacts(<Contact>[incoming]), 1);
    expect(await store.importContacts(<Contact>[incoming]), 0);
    expect(store.byEmail('ann@example.com')?.saved, isTrue);
  });

  test('a corrupt contacts file is reported and never overwritten by a read', () async {
    await File('${directory.path}/contacts.json').writeAsString('{broken');
    final errors = <String>[];
    final ContactsStore isolated = ContactsStore(
      directory: directory,
      onError: (String operation, Object error, StackTrace stack) => errors.add(operation),
    );
    await isolated.load();
    expect(errors, contains('decode contacts file'));
    expect(await File('${directory.path}/contacts.json').readAsString(), '{broken');
    isolated.dispose();
  });

  test('block list persists independently from contacts', () async {
    await store.block('Blocked@Example.com');
    expect(store.isBlocked('blocked@example.com'), isTrue);
    final ContactsStore restored = ContactsStore(directory: directory);
    await restored.load();
    expect(restored.isBlocked('blocked@example.com'), isTrue);
    await restored.unblock('BLOCKED@example.com');
    expect(restored.isBlocked('blocked@example.com'), isFalse);
    restored.dispose();
  });
  test('legacy Contacts facade can be injected and reset for tests', () async {
    Contacts.useStoreForTesting(store);
    await Contacts.load();
    await Contacts.add(email: 'injected@example.com', name: 'Injected');
    expect(Contacts.byEmail('injected@example.com')?.saved, isTrue);
    Contacts.resetForTesting();
  });

}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/contact.dart';
import '../util/addresses.dart';
import '../models/full_message.dart';
import '../models/message_summary.dart';
import '../util/redact.dart';

/// One JSON list on disk. Missing files are normal; malformed or unreadable
/// files are surfaced to the store's diagnostic callback and are never replaced
/// by an empty list as a side effect of reading.
class _JsonFileStore {
  _JsonFileStore(this.directory, this.fileName);

  final Directory directory;
  final String fileName;
  Future<File>? _resolved;

  Future<File> get file => _resolved ??= Future<File>(() async {
        await directory.create(recursive: true);
        return File('${directory.path}/$fileName');
      });

  Future<List<dynamic>?> read() async {
    final File target = await file;
    if (!await target.exists()) return null;
    final Object? decoded = jsonDecode(await target.readAsString());
    if (decoded is! List) {
      throw FormatException('$fileName must contain a JSON list.');
    }
    return decoded;
  }

  Future<void> write(List<dynamic> rows) async {
    await (await file).writeAsString(jsonEncode(rows), flush: true);
  }
}

/// A shared two-second debounce with an awaitable flush, including a write
/// that has already started when the app is closing.
class _DebouncedWriter {
  _DebouncedWriter(this.write);

  final Future<void> Function() write;
  Timer? _timer;
  Future<void>? _inFlight;

  void schedule() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () {
      _timer = null;
      _inFlight = write();
      unawaited(_inFlight);
    });
  }

  Future<void> flush() async {
    _timer?.cancel();
    if (_timer != null) {
      _timer = null;
      _inFlight = write();
    }
    await _inFlight;
  }

  void dispose() => _timer?.cancel();
}


/// The block list is a separate concern and file, with its own retryable load
/// and persistence lifecycle.
class BlockListStore {
  BlockListStore({
    Directory? directory,
    void Function(String operation, Object error, StackTrace stackTrace)? onError,
  })  : _directory = directory,
        _onError = onError;

  final Directory? _directory;
  final void Function(String, Object, StackTrace)? _onError;
  final Set<String> _addresses = <String>{};
  _JsonFileStore? _file;
  Future<void>? _loading;

  List<String> get all => _addresses.toList()..sort();
  bool contains(String email) => _addresses.contains(email.trim().toLowerCase());

  void _report(String operation, Object error, StackTrace stack) {
    if (_onError != null) {
      _onError(operation, error, stack);
    } else {
      debugPrint('Ace Mail: $operation failed (${Redact.safe(error)})');
    }
  }

  Future<_JsonFileStore> _store() async {
    final Directory directory = _directory ?? await getApplicationSupportDirectory();
    return _file ??= _JsonFileStore(directory, ContactsStore.blockedFileName);
  }

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final List<dynamic>? rows = await (await _store()).read();
      if (rows != null) {
        _addresses
          ..clear()
          ..addAll(rows.whereType<String>().map((String value) => value.trim().toLowerCase()).where((String value) => value.isNotEmpty));
      }
    } on FileSystemException catch (error, stack) {
      _report('read block list', error, stack);
      _loading = null;
    } on FormatException catch (error, stack) {
      _report('decode block list', error, stack);
      _loading = null;
    } catch (error, stack) {
      _report('load block list', error, stack);
      _loading = null;
    }
  }

  Future<bool> block(String email) async {
    await load();
    final String key = email.trim().toLowerCase();
    if (key.isEmpty || !_addresses.add(key)) return false;
    await _persist();
    return true;
  }

  Future<bool> unblock(String email) async {
    await load();
    if (!_addresses.remove(email.trim().toLowerCase())) return false;
    await _persist();
    return true;
  }

  Future<bool> remove(String email) async {
    await load();
    if (!_addresses.remove(email.trim().toLowerCase())) return false;
    await _persist();
    return true;
  }

  Future<void> _persist() async {
    try {
      await (await _store()).write(all);
    } catch (error, stack) {
      _report('write block list', error, stack);
    }
  }
}

typedef _SeenAddress = ({String email, String name, DateTime? when});

/// The operations the UI and session need from an address book.
abstract interface class ContactsStoreApi {
  int get revision;
  bool get isEmpty;
  List<Contact> get all;
  List<String> get blocked;
  bool isBlocked(String email);
  Future<void> load();
  Future<void> flush();
  List<Contact> search(String query);
  Contact? byEmail(String email);
  Future<void> block(String email);
  Future<void> unblock(String email);
  void observe(List<MessageSummary> messages);
  void recordSent(Iterable<String> addresses, {DateTime? when});
  void observeRecipients(FullMessage message);
  Future<void> setSaved(String email, bool saved);
  Future<Contact> add({required String email, String name = ''});
  Future<void> remove(String email);
  Future<int> importContacts(Iterable<Contact> incoming);
  Future<void> forgetSeen();
}

/// Injectable address-book and block-list storage. A test can provide a
/// temporary directory and diagnostic sink; production uses application
/// support storage. The legacy [Contacts] façade below preserves callers.
class ContactsStore implements ContactsStoreApi {
  ContactsStore({
    Directory? directory,
    void Function(String operation, Object error, StackTrace stackTrace)? onError,
  })  : _directory = directory,
        _onError = onError;

  static const int limit = 600;
  static const String fileName = 'contacts.json';
  static const String blockedFileName = 'blocked.json';

  final Directory? _directory;
  final void Function(String, Object, StackTrace)? _onError;
  final Map<String, Contact> _byEmail = <String, Contact>{};
  _JsonFileStore? _contactsFile;
  Future<void>? _loading;
  late final BlockListStore _blockList = BlockListStore(directory: _directory, onError: _onError);
  int _revision = 0;
  @override
  int get revision => _revision;
  @override
  bool get isEmpty => _byEmail.isEmpty;
  @override
  List<String> get blocked => _blockList.all;

  late final _DebouncedWriter _writer = _DebouncedWriter(_persist);

  void _report(String operation, Object error, StackTrace stackTrace) {
    if (_onError != null) {
      _onError(operation, error, stackTrace);
      return;
    }
    debugPrint('Ace Mail: $operation failed (${Redact.safe(error)})');
  }

  Future<_JsonFileStore> _store() async {
    final Directory directory = _directory ?? await getApplicationSupportDirectory();
    return _contactsFile ??= _JsonFileStore(directory, fileName);
  }

  @override
  List<Contact> get all {
    final List<Contact> contacts = _byEmail.values.toList()
      ..sort((Contact a, Contact b) {
        if (a.saved != b.saved) return a.saved ? -1 : 1;
        final DateTime? x = a.lastSeen;
        final DateTime? y = b.lastSeen;
        if (x == null && y == null) return a.label.toLowerCase().compareTo(b.label.toLowerCase());
        if (x == null) return 1;
        if (y == null) return -1;
        return y.compareTo(x);
      });
    return contacts;
  }

  @override
  Future<void> load() async {
    await Future.wait<void>(<Future<void>>[
      _loading ??= _load(),
      _blockList.load(),
    ]);
  }

  Future<void> _load() async {
    try {
      final List<dynamic>? rows = await (await _store()).read();
      if (rows != null) {
        for (final Object? entry in rows) {
          if (entry is! Map<String, dynamic>) continue;
          final Contact contact = Contact.fromJson(entry);
          if (contact.email.isEmpty) continue;
          _byEmail[contact.email.toLowerCase()] = contact;
        }
      }
    } on FileSystemException catch (error, stack) {
      _report('read contacts file', error, stack);
      _loading = null;
    } on FormatException catch (error, stack) {
      _report('decode contacts file', error, stack);
      _loading = null;
    } catch (error, stack) {
      _report('load contacts', error, stack);
      _loading = null;
    }
  }

  @override
  bool isBlocked(String email) => _blockList.contains(email);

  @override
  Future<void> block(String email) async {
    if (await _blockList.block(email)) _revision++;
  }

  @override
  Future<void> unblock(String email) async {
    if (await _blockList.unblock(email)) _revision++;
  }

  @override
  List<Contact> search(String query) {
    final String needle = query.trim().toLowerCase();
    if (needle.isEmpty) return all;
    return all.where((Contact contact) =>
      contact.email.toLowerCase().contains(needle) || contact.name.toLowerCase().contains(needle)).toList();
  }

  @override
  Contact? byEmail(String email) => _byEmail[email.trim().toLowerCase()];

  void _schedulePersist() => _writer.schedule();

  @override
  Future<void> flush() => _writer.flush();

  Future<void> _persist() async {
    try {
      _trim();
      await (await _store()).write(<Object>[
        for (final Contact contact in all) contact.toJson(),
      ]);
    } catch (error, stack) {
      _report('write contacts file', error, stack);
    }
  }

  void _trim() {
    if (_byEmail.length <= limit) return;
    final List<Contact> droppable = _byEmail.values.where((Contact contact) => !contact.saved).toList()
      ..sort((Contact a, Contact b) {
        final DateTime x = a.lastSeen ?? DateTime.fromMillisecondsSinceEpoch(0);
        final DateTime y = b.lastSeen ?? DateTime.fromMillisecondsSinceEpoch(0);
        return x.compareTo(y);
      });
    for (final Contact contact in droppable) {
      if (_byEmail.length <= limit) break;
      _byEmail.remove(contact.email.toLowerCase());
    }
  }

  bool _record(
    String email,
    String name,
    DateTime? when, {
    bool saved = false,
    bool incrementCount = true,
    bool preserveExistingName = false,
  }) {
    final String key = email.trim().toLowerCase();
    if (key.isEmpty || !key.contains('@') || isMachineAddress(key)) return false;
    final Contact? existing = _byEmail[key];
    final String cleanName = name.trim();
    if (existing == null) {
      _byEmail[key] = Contact(
        email: key,
        name: cleanName,
        count: incrementCount ? 1 : 0,
        lastSeen: when,
        saved: saved,
      );
      return true;
    }
    final String nextName = cleanName.isEmpty || (preserveExistingName && existing.name.trim().isNotEmpty)
        ? existing.name : cleanName;
    final bool nextSaved = saved || existing.saved;
    final int nextCount = existing.count + (incrementCount ? 1 : 0);
    final DateTime? nextSeen = when ?? existing.lastSeen;
    if (nextName == existing.name && nextSaved == existing.saved && nextCount == existing.count && nextSeen == existing.lastSeen) return false;
    _byEmail[key] = existing.copyWith(name: nextName, saved: nextSaved, count: nextCount, lastSeen: nextSeen);
    return true;
  }

  void _recordAll(Iterable<_SeenAddress> seen) {
    bool changed = false;
    for (final _SeenAddress item in seen) {
      changed = _record(item.email, item.name, item.when) || changed;
    }
    if (changed) {
      _revision++;
      _schedulePersist();
    }
  }

  @override
  void observe(List<MessageSummary> messages) => _recordAll(messages.map((MessageSummary message) => (
    email: message.fromEmail, name: message.fromName, when: message.date,
  )));

  @override
  void recordSent(Iterable<String> addresses, {DateTime? when}) => _recordAll(addresses.map((String email) => (
    email: email, name: '', when: when,
  )));

  @override
  void observeRecipients(FullMessage message) => _recordAll(<_SeenAddress>[
    for (final String email in <String>[...message.toEmails.split(','), ...message.ccEmails.split(',')])
      (email: email, name: '', when: message.date),
  ]);

  @override
  Future<void> setSaved(String email, bool saved) async {
    final String key = email.trim().toLowerCase();
    final Contact? existing = _byEmail[key];
    if (existing == null) {
      if (!saved || key.isEmpty || !key.contains('@')) return;
      _byEmail[key] = Contact(email: key, saved: true);
    } else {
      if (existing.saved == saved) return;
      _byEmail[key] = existing.copyWith(saved: saved);
    }
    _revision++;
    await _persist();
  }

  @override
  Future<Contact> add({required String email, String name = ''}) async {
    final String key = email.trim().toLowerCase();
    if (key.isEmpty || !key.contains('@')) throw ArgumentError.value(email, 'email', 'A valid email address is required.');
    final Contact contact = (_byEmail[key] ?? Contact(email: key)).copyWith(name: name.trim(), saved: true);
    _byEmail[key] = contact;
    _revision++;
    await _persist();
    return contact;
  }

  @override
  Future<void> remove(String email) async {
    final String key = email.trim().toLowerCase();
    final bool had = _byEmail.remove(key) != null;
    final bool blocked = await _blockList.remove(key);
    if (!had && !blocked) return;
    _revision++;
    await _persist();
  }

  @override
  Future<int> importContacts(Iterable<Contact> incoming) async {
    int changed = 0;
    for (final Contact contact in incoming) {
      final String key = contact.email.trim().toLowerCase();
      if (key.isEmpty || !key.contains('@')) continue;
      if (!_byEmail.containsKey(key) && _byEmail.length >= limit) continue;
      if (_record(key, contact.name, null, saved: true, incrementCount: false, preserveExistingName: true)) changed++;
    }
    if (changed > 0) {
      _revision++;
      await _persist();
    }
    return changed;
  }

  @override
  Future<void> forgetSeen() async {
    final int before = _byEmail.length;
    _byEmail.removeWhere((_, Contact contact) => !contact.saved);
    if (_byEmail.length == before) return;
    _revision++;
    await _persist();
  }

  void dispose() => _writer.dispose();
}

/// Backwards-compatible application façade. Production code can migrate to an
/// injected [ContactsStore]; existing UI and session call sites remain stable.
abstract final class Contacts {
  static final ContactsStore _default = ContactsStore();
  static const int limit = ContactsStore.limit;
  static int get revision => _default.revision;
  static bool get isEmpty => _default.isEmpty;
  static List<Contact> get all => _default.all;
  static List<String> get blocked => _default.blocked;
  static bool isBlocked(String email) => _default.isBlocked(email);
  static Future<void> block(String email) => _default.block(email);
  static Future<void> unblock(String email) => _default.unblock(email);
  static List<Contact> search(String query) => _default.search(query);
  static Contact? byEmail(String email) => _default.byEmail(email);
  static Future<void> load() => _default.load();
  static Future<void> flush() => _default.flush();
  static void observe(List<MessageSummary> messages) => _default.observe(messages);
  static void recordSent(Iterable<String> addresses, {DateTime? when}) => _default.recordSent(addresses, when: when);
  static void observeRecipients(FullMessage message) => _default.observeRecipients(message);
  static Future<void> setSaved(String email, bool saved) => _default.setSaved(email, saved);
  static Future<Contact> add({required String email, String name = ''}) => _default.add(email: email, name: name);
  static Future<void> remove(String email) => _default.remove(email);
  static Future<int> importContacts(Iterable<Contact> incoming) => _default.importContacts(incoming);
  static Future<void> forgetSeen() => _default.forgetSeen();
}

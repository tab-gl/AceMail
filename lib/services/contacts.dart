import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/contact.dart';
import '../util/addresses.dart';
import '../models/full_message.dart';
import '../models/message_summary.dart';

/// The addresses this app has seen, and the ones the person saved.
///
/// Two kinds of contact, deliberately kept apart in the record and together in
/// the list. **Saved** is a decision — somebody the person chose to keep.
/// **Seen** is a fact — an address that has written to them, or that they have
/// written to. A contact book that only holds what you remembered to add is
/// empty, and one that treats every address as equal is noise; showing both,
/// marked, is what a mail client can actually offer.
///
/// Kept in a plain file rather than the vault. Addresses are not secrets — they
/// are on the envelope of every message — and the vault exists for what is
/// inside. It is bounded, because a mail client that keeps every address it has
/// ever seen forever is a mail client that grows without limit.
abstract final class Contacts {
  /// How many are kept. The most recently seen go first when it is full, so
  /// what is dropped is what has not been used in the longest time.
  static const int limit = 600;

  /// Storage names live here rather than inside the methods that build the
  /// paths, so the two files this book owns are visible in one place.
  static const String fileName = 'contacts.json';
  static const String blockedFileName = 'blocked.json';

  static final _JsonFileStore _store = _JsonFileStore(fileName);
  static final _JsonFileStore _blockedStore = _JsonFileStore(blockedFileName);

  static final Map<String, Contact> _byEmail = <String, Contact>{};

  /// Addresses whose mail is kept out of the list.
  ///
  /// Blocking is a *filter*, not a rule on the server: nothing is moved, deleted
  /// or reported anywhere, and unblocking brings the mail straight back. A block
  /// that destroyed things would be a block nobody dared use.
  static final Set<String> _blocked = <String>{};
  static bool _blockedLoaded = false;
  static bool _loaded = false;

  /// Bumped whenever the book changes in a way a cached list would not see.
  ///
  /// The message list filters blocked senders and is cached between rebuilds;
  /// without a counter, blocking somebody would leave their mail on screen
  /// until something else moved. One integer is cheaper than invalidating every
  /// cache by hand.
  ///
  /// Readers: the message list (blocked senders) and the contacts panel (the
  /// saved/seen marks). Anything that mutates the book must bump it, which is
  /// why the mutations below all go through one place.
  static int _revision = 0;

  /// The counter described above, for caches that need to know it moved.
  static int get revision => _revision;

  /// Whether anything has been loaded or seen. The screen uses this to tell
  /// "no contacts yet" from "not read yet".
  static bool get isEmpty => _byEmail.isEmpty;

  /// Everyone, saved first, then by how recently they were seen.
  ///
  /// Saved first because a decision outranks a coincidence: somebody you chose
  /// to keep should not be pushed below an address that happened to send you a
  /// receipt this morning.
  static List<Contact> get all {
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

  /// Whether [email] is blocked. Case-insensitive, because an address is.
  static bool isBlocked(String email) =>
      _blocked.contains(email.trim().toLowerCase());

  /// Every blocked address, in order.
  static List<String> get blocked => _blocked.toList()..sort();

  /// Keeps [email]'s mail out of the list, from now on.
  static Future<void> block(String email) async {
    await _ensureBlocked();
    final String key = email.trim().toLowerCase();
    if (key.isEmpty || !_blocked.add(key)) return;
    _revision++;
    await _persistBlocked();
  }

  /// Lets it back in. Everything it sent is still there.
  static Future<void> unblock(String email) async {
    await _ensureBlocked();
    if (!_blocked.remove(email.trim().toLowerCase())) return;
    _revision++;
    await _persistBlocked();
  }

  static Future<void> _ensureBlocked() async {
    if (_blockedLoaded) return;
    final List<Object?>? rows = await _blockedStore.readList();
    // The flag used to be set before the read, so one failure left the blocklist
    // "loaded and empty" for the rest of the process and blocked senders came
    // back. A missing file is still a legitimate empty blocklist; a file that is
    // there and would not read leaves the flag down so the next call retries.
    if (rows == null && await _blockedStore.exists()) return;
    _blocked
      ..clear()
      ..addAll((rows ?? const <Object?>[]).whereType<String>().map((String s) => s.toLowerCase()));
    _blockedLoaded = true;
  }

  static Future<void> _persistBlocked() async {
    await _ensureBlocked();
    await _blockedStore.writeList(blocked);
  }

  /// The ones worth showing for [query]. Empty query means everyone.
  static List<Contact> search(String query) {
    final String needle = query.trim().toLowerCase();
    if (needle.isEmpty) return all;
    return all
        .where((Contact c) =>
            c.email.toLowerCase().contains(needle) ||
            c.name.toLowerCase().contains(needle))
        .toList();
  }

  static Contact? byEmail(String email) =>
      _byEmail[email.trim().toLowerCase()];

  /// Reads what was kept. Safe to call more than once.
  static Future<void> load() async {
    if (_loaded) return;
    final List<Object?>? rows = await _store.readList();
    // As with the blocklist: a file that is present but unreadable is retried
    // rather than remembered as an empty book.
    if (rows == null && await _store.exists()) return;
    _loaded = true;
    if (rows == null) return;
    for (final Object? entry in rows) {
      if (entry is! Map<String, dynamic>) continue;
      final Contact contact = Contact.fromJson(entry);
      if (contact.email.isEmpty) continue;
      _byEmail[contact.email.toLowerCase()] = contact;
    }
  }

  /// A write waiting to happen, so that a folder load is one write and not
  /// forty.
  ///
  /// The addresses arrive a page at a time as folders load, and writing the
  /// whole book on every page is the same file rewritten several times a
  /// second for a file that changes slowly. A decision the person made goes
  /// straight to disk; what the mail told us waits a moment.
  static Timer? _writeSoon;

  static void _schedulePersist() {
    _writeSoon?.cancel();
    _writeSoon = Timer(const Duration(seconds: 2), () {
      _writeSoon = null;
      unawaited(_persist());
    });
  }

  /// Writes anything pending, now.
  static Future<void> flush() async {
    if (_writeSoon == null) return;
    _writeSoon!.cancel();
    _writeSoon = null;
    await _persist();
  }

  static Future<void> _persist() async {
    _trim();
    await _store.writeList(<Object>[for (final Contact c in all) c.toJson()]);
  }

  static void _trim() {
    if (_byEmail.length <= limit) return;
    // Saved ones are never dropped; the rest go oldest-first.
    final List<Contact> droppable = _byEmail.values
        .where((Contact c) => !c.saved)
        .toList()
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

  /// Records who a page of mail is from.
  ///
  /// Called as pages load, so the list grows with use rather than needing a
  /// scan of the whole mailbox. Senders only: a summary does not carry the
  /// recipients, and guessing them from a folder would put the account holder
  /// in their own contact list.
  static void observe(List<MessageSummary> messages) {
    _recordAll(<({String email, String name, DateTime? when})>[
      for (final MessageSummary message in messages)
        (email: message.fromEmail, name: message.fromName, when: message.date),
    ]);
  }

  /// Records the people a message was sent to.
  ///
  /// The only place the recipients appear — a list row carries the sender and
  /// nothing else — and they come without names, because the model keeps the
  /// addresses as a plain string. A name arrives later, from mail they send.
  ///
  /// Called when a message goes out, not only when one is opened. Loading the
  /// Sent folder does not do this: every message in it has *you* in the From
  /// line, so a book built from senders learns your own address and none of the
  /// people you actually write to. The addresses you chose at send time are the
  /// only place that information exists.
  static void recordSent(Iterable<String> addresses, {DateTime? when}) {
    _recordAll(<({String email, String name, DateTime? when})>[
      for (final String email in addresses) (email: email, name: '', when: when),
    ]);
  }

  static void observeRecipients(FullMessage message) {
    _recordAll(<({String email, String name, DateTime? when})>[
      for (final String email in <String>[
        ...message.toEmails.split(','),
        ...message.ccEmails.split(','),
      ])
        (email: email, name: '', when: message.date),
    ]);
  }

  /// The one record-and-schedule path the three observers above share.
  static void _recordAll(
      Iterable<({String email, String name, DateTime? when})> seen) {
    bool changed = false;
    for (final ({String email, String name, DateTime? when}) entry in seen) {
      changed |= _record(entry.email, entry.name, entry.when);
    }
    if (!changed) return;
    _revision++;
    _schedulePersist();
  }

  static bool _record(String email, String name, DateTime? when) {
    final String key = email.trim().toLowerCase();
    if (key.isEmpty || !key.contains('@')) return false;
    // An address at your own domain is usually a machine: a receipt, a
    // notification, a mailing list. Not a person to offer to write to.
    if (isMachineAddress(key)) return false;

    final Contact? existing = _byEmail[key];
    final String cleanName = name.trim();
    if (existing == null) {
      _byEmail[key] = Contact(
        email: key,
        name: cleanName,
        count: 1,
        lastSeen: when,
      );
      return true;
    }

    _byEmail[key] = existing.copyWith(
      // A name is kept once found, and replaced only by another name — never
      // wiped by a message that arrived with a bare address.
      name: cleanName.isEmpty ? existing.name : cleanName,
      count: existing.count + 1,
      lastSeen: when ?? existing.lastSeen,
    );
    return true;
  }

  /// Saves or forgets one. Forgetting an address the app has seen leaves it in
  /// the list as an unsaved contact rather than removing it — it is still in
  /// the mail, and pretending otherwise would be a lie the next page undoes.
  static Future<void> setSaved(String email, bool saved) async {
    // A person's decision is written at once; only what the mail volunteered
    // waits.
    final String key = email.trim().toLowerCase();
    final Contact? existing = _byEmail[key];
    if (existing == null) {
      if (!saved) return;
      _byEmail[key] = Contact(email: key, saved: true);
    } else {
      _byEmail[key] = existing.copyWith(saved: saved);
    }
    // Saving or un-saving moves the saved/seen marks the panel draws, so the
    // counter has to move too; every other mutation here already does.
    _revision++;
    await _persist();
  }

  /// Adds an address by hand — from the contact sheet, when somebody types one
  /// the app has never seen.
  static Future<Contact> add({required String email, String name = ''}) async {
    final String key = email.trim().toLowerCase();
    final Contact contact = (_byEmail[key] ?? Contact(email: key))
        .copyWith(name: name.trim(), saved: true);
    _byEmail[key] = contact;
    _revision++;
    await _persist();
    return contact;
  }

  /// Forgets an address completely.
  ///
  /// Distinct from un-saving it: a saved contact that is un-saved goes back to
  /// being one the app merely saw, which is right for "I did not mean to keep
  /// this". This is the other request — "I do not want this person in my list at
  /// all" — and it takes the record out, along with any block on it.
  static Future<void> remove(String email) async {
    final String key = email.trim().toLowerCase();
    final bool had = _byEmail.remove(key) != null;
    final bool blocked = _blocked.remove(key);
    if (!had && !blocked) return;
    _revision++;
    if (blocked) await _persistBlocked();
    await _persist();
  }

  /// Takes a batch of addresses from the device's own address book.
  ///
  /// A contact on the device is a decision somebody made already, so these
  /// arrive **saved** rather than as addresses the app merely noticed. Nothing
  /// is written back to the device: this is an import, not a sync, and an app
  /// that edited your address book because you signed in would be a worse
  /// neighbour than one that only reads it.
  ///
  /// Returns how many records were added or changed.
  ///
  /// Stops adding at [limit]. The cap is the promise this file makes about
  /// growth, and a device address book is the one caller that can arrive with
  /// more addresses than the whole list is allowed to hold — an import that
  /// quietly blew past it would make the bound a lie. Records already here still
  /// get their name and their saved mark, whatever the count.
  static Future<int> importContacts(Iterable<Contact> incoming) async {
    int changed = 0;
    for (final Contact contact in incoming) {
      final String key = contact.email.trim().toLowerCase();
      if (key.isEmpty || !key.contains('@')) continue;
      final String name = contact.name.trim();
      final Contact? existing = _byEmail[key];
      if (existing == null) {
        if (_byEmail.length >= limit) continue;
        _byEmail[key] = Contact(email: key, name: name, saved: true);
        changed++;
        continue;
      }
      final String merged = existing.name.trim().isEmpty ? name : existing.name;
      if (merged != existing.name || !existing.saved) {
        _byEmail[key] = existing.copyWith(name: merged, saved: true);
        changed++;
      }
    }
    if (changed > 0) {
      _revision++;
      await _persist();
    }
    return changed;
  }

  /// Drops the addresses the app merely saw, keeping the saved ones.
  static Future<void> forgetSeen() async {
    _byEmail.removeWhere((_, Contact c) => !c.saved);
    _revision++;
    await _persist();
  }
}

/// One JSON list on disk.
///
/// The address book and the blocklist are the same shape — a file holding a
/// JSON list, read once and rewritten whole — and each used to carry its own
/// copy of the lazy-path / exists / decode / guard / swallow dance. The copy
/// also held the resolved path in a nullable static that was dereferenced after
/// an await; here the path is resolved inside the call that uses it.
class _JsonFileStore {
  _JsonFileStore(this.fileName);

  final String fileName;
  Future<File>? _resolved;

  Future<File> _file() {
    return _resolved ??= () async {
      final Directory directory = await getApplicationSupportDirectory();
      return File('${directory.path}/$fileName');
    }();
  }

  /// Whether the file is on disk, as opposed to absent or unreadable.
  ///
  /// False when the storage directory cannot be resolved at all, which is the
  /// normal answer under a test harness with no path provider.
  Future<bool> exists() async {
    try {
      return await (await _file()).exists();
    } catch (_) {
      return false;
    }
  }

  /// The stored list, or null when there is no file yet or it cannot be read.
  ///
  /// A missing file is normal. A corrupt one is not, and used to be
  /// indistinguishable from an empty book — the next write then overwrote the
  /// evidence. It is reported instead.
  Future<List<Object?>?> readList() async {
    try {
      final File file = await _file();
      if (!await file.exists()) return null;
      final Object? decoded = jsonDecode(await file.readAsString());
      return decoded is List ? decoded : null;
    } on FormatException catch (error) {
      debugPrint('Contacts: $fileName is not valid JSON (${error.message}); starting empty.');
      return null;
    } catch (error) {
      // No storage directory, no permission, an unreadable file: all of them
      // used to disappear into `catch (_)` with no trace at all.
      debugPrint('Contacts: could not read $fileName ($error).');
      return null;
    }
  }

  Future<void> writeList(List<Object?> rows) async {
    try {
      final File file = await _file();
      await file.writeAsString(jsonEncode(rows), flush: true);
    } catch (error) {
      // Losing the file loses the saved marks or the blocklist, which is a real
      // loss but not one worth interrupting anybody over - but it is now
      // visible instead of silent.
      debugPrint('Contacts: could not write $fileName ($error).');
    }
  }
}

import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/launcher_icon.dart';
import 'accents.dart';
import '../theme/custom_appearance.dart';
import '../models/glass_mode.dart';
import '../models/message_sort.dart';
import '../models/swipe_action.dart';
import '../services/chyme.dart';

/// Which appearance the app follows.
enum AceThemeMode {
  system('System'),
  light('Light'),
  dark('Dark');

  const AceThemeMode(this.label);

  final String label;
}

/// How large the app's text is drawn, on top of the system setting.
enum AceTextSize {
  small('Small', 0.9),
  medium('Default', 1.0),
  large('Large', 1.15);

  const AceTextSize(this.label, this.scale);

  final String label;
  final double scale;
}

/// How many messages a page of the list holds.
enum PageSize {
  twenty('20', 20),
  forty('40', 40),
  eighty('80', 80),
  oneFifty('150', 150),
  twoHundred('200', 200);

  const PageSize(this.label, this.count);

  final String label;
  final int count;
}

/// How tightly the message list is packed.
enum ListDensity {
  comfortable('Comfortable', 42, 12),
  compact('Compact', 34, 8);

  const ListDensity(this.label, this.avatarSize, this.verticalPadding);

  final String label;
  final double avatarSize;
  final double verticalPadding;
}

/// Which representation of a message the reader opens with.
/// How long the undo on a snack bar stays offered.
///
/// Long enough to notice a mistake and reach for it, short enough that the bar
/// is gone before it becomes furniture. Six seconds is the default because it is
/// the shortest that reliably survives the beat of "wait — what did that do?".
enum UndoWindow {
  short('4 seconds', 4),
  normal('6 seconds', 6),
  long('10 seconds', 10),
  // For a phone in a pocket: long enough that a mis-tap noticed late is still
  // undoable, which is the whole point of offering the bar at all.
  longer('20 seconds', 20);

  const UndoWindow(this.label, this.seconds);

  final String label;
  final int seconds;

  Duration get duration => Duration(seconds: seconds);
}

/// The app's settings.
///
/// Kept in the same store as the accounts because it is already there and works
/// on every platform — nothing here is a secret. Every value is real: changing
/// one changes behaviour at once and survives a restart.
class Preferences extends ChangeNotifier {
  Preferences({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _keyAvatars = 'ace.showAvatars';
  static const String _keyUpdateCheck = 'ace.updateCheck';
  static const String _keyAutoUpdate = 'ace.autoUpdate';
  static const String _keyCollapsedSections = 'ace.collapsedSections';
  static const String _keyGlassBlur = 'ace.glassBlur';
  static const String _keyGlassTint = 'ace.glassTint';
  static const String _keyGlassInvert = 'ace.glassInvert';
  static const String _keyLastUpdateCheck = 'ace.lastUpdateCheck';
  static const String _keyTheme = 'ace.themeMode';
  static const String _keyTextSize = 'ace.textSize';
  static const String _keyConfirmExit = 'ace.confirmExit';
  static const String _keyMarkRead = 'ace.markAsReadOnOpen';
  static const String _keySignature = 'ace.signature';
  static const String _keySwipeStart = 'ace.swipeStart';
  static const String _keySwipeEnd = 'ace.swipeEnd';
  static const String _keyAutoReconnect = 'ace.autoReconnect';
  static const String _keyPageSize = 'ace.pageSize';
  static const String _keyDensity = 'ace.listDensity';
  static const String _keyConfirmDelete = 'ace.confirmDelete';
  static const String _keyDetectCodes = 'ace.detectCodes';
  static const String _keyMessageSort = 'ace.messageSort';
  static const String _keySortTie = 'ace.sortTie';
  static const String _keyAccent = 'ace.accent';
  static const String _keyCustomAccent = 'ace.customAccent';
  static const String _keyCustomFont = 'ace.customFont';
  static const String _keyRawHeaders = 'ace.rawHeaders';
  static const String _keyDynamicColour = 'ace.dynamicColour';
  static const String _keyWarnEmptySubject = 'ace.warnEmptySubject';
  static const String _keyWarnExternalLinks = 'ace.warnExternalLinks';
  static const String _keyNotifyNewMail = 'ace.notifyNewMail';
  static const String _keyLastSeen = 'ace.lastSeen';
  static const String _keyHaptics = 'ace.haptics';
  static const String _keyOled = 'ace.oled';
  static const String _keyReduceMotion = 'ace.reduceMotion';
  static const String _keyGroupByDate = 'ace.groupByDate';
  static const String _keyFolderCounts = 'ace.folderCounts';
  static const String _keySeenVersion = 'ace.seenVersion';
  static const String _keyQuoteReplies = 'ace.quoteReplies';
  static const String _keySignatureOnReplies = 'ace.signatureOnReplies';
  static const String _keyConfirmArchive = 'ace.confirmArchive';
  static const String _keyUndoWindow = 'ace.undoWindow';
  static const String _keyHighlights = 'ace.highlights';
  static const String _keyBccSelf = 'ace.bccSelf';
  static const String _keyCacheMessages = 'ace.cacheMessages';
  static const String _keyAppLock = 'ace.appLock';
  static const String _keyPrivatePreviews = 'ace.privatePreviews';
  static const String _keyQuietHours = 'ace.quietHours';
  static const String _keyChymeEnabled = 'ace.chymeEnabled';
  static const String _keyChymeEndpoint = 'ace.chymeEndpoint';
  static const String _keyChymeModel = 'ace.chymeModel';
  static const String _keyChymePrompt = 'ace.chymePrompt';
  static const String _keyChymeKey = 'ace.chymeKey';
  static const String _keyChymeReadsMail = 'ace.chymeReadsMail';
  static const String _keyWarnMissingAttachment = 'ace.warnMissingAttachment';
  static const String _keyGlass = 'ace.glass';
  static const String _keyLauncherMark = 'ace.launcherMark';
  static const String _keyChymeTone = 'ace.chymeTone';
  static const String _keyFolderOrder = 'ace.folderOrder';
  static const String _keyLastSeenValidity = 'ace.lastSeenValidity';
  static const String _keyCheckStatus = 'ace.checkStatus';

  static const List<String> _keys = <String>[
    _keyAvatars,
    _keyTheme,
    _keyTextSize,
    _keyConfirmExit,
    _keyMarkRead,
    _keySignature,
    _keySwipeStart,
    _keySwipeEnd,
    _keyAutoReconnect,
    _keyPageSize,
    _keyDensity,
    _keyConfirmDelete,
    _keyDetectCodes,
    _keyMessageSort,
    _keyAccent,
    _keyRawHeaders,
    _keyDynamicColour,
    _keyWarnEmptySubject,
    _keyWarnExternalLinks,
    _keyNotifyNewMail,
    _keyLastSeen,
    _keyLastSeenValidity,
    _keyCheckStatus,
    _keyHaptics,
    _keyOled,
    _keyReduceMotion,
    _keyGroupByDate,
    _keyFolderCounts,
    _keySeenVersion,
    _keyQuoteReplies,
    _keySignatureOnReplies,
    _keyConfirmArchive,
    _keyUndoWindow,
    _keyBccSelf,
    _keyCacheMessages,
    _keyAppLock,
    _keyPrivatePreviews,
    _keyQuietHours,
    _keyChymeEnabled,
    _keyChymeEndpoint,
    _keyChymeModel,
    _keyChymeKey,
    _keyChymeReadsMail,
    _keyWarnMissingAttachment,
    _keyGlass,
    _keyLauncherMark,
    _keyChymeTone,
    _keyFolderOrder,
  ];

  final FlutterSecureStorage _storage;

  // The defaults are deliberately *on*: the app ships with everything it can do
  // switched on, and the settings are there to take things away. The four
  // exceptions each say why they are exceptions.
  //
  // Off because it is a developer's view of the message:
  bool _showRawHeaders = false;
  // Off because it makes the accent the wallpaper's, and a launcher icon cannot
  // follow the wallpaper — the icon would then disagree with the app it opens.
  // One switch, for anyone who wants Material You anyway:
  bool _useDynamicColour = false;

  bool _showAvatars = true;
  AceThemeMode _themeMode = AceThemeMode.system;
  AceTextSize _textSize = AceTextSize.medium;
  bool _confirmExit = true;
  bool _markAsReadOnOpen = true;
  String _signature = '';
  SwipeAction _swipeStart = SwipeAction.toggleRead;
  SwipeAction _swipeEnd = SwipeAction.archive;
  bool _autoReconnect = true;
  PageSize _pageSize = PageSize.forty;
  ListDensity _density = ListDensity.comfortable;
  bool _confirmDelete = true;
  bool _detectCodes = true;
  MessageSort _messageSort = MessageSort.newest;

  /// The key that breaks ties in the list order, or null for none.
  MessageSort? _sortTie;
  final bool _loadRemoteImages = true;
  AceAccent _accent = AceAccent.orange;
  Color? _customAccent;
  String? _customFontPath;
  bool _warnEmptySubject = true;
  bool _warnExternalLinks = true;
  bool _notifyNewMail = true;
  bool _haptics = true;
  bool _oled = true;
  // Off because it is an accessibility preference — one someone has to choose,
  // rather than one that can be chosen for them.
  bool _reduceMotion = false;
  bool _groupByDate = true;
  bool _showFolderCounts = true;
  bool _highlights = true;
  String? _lastSeenVersion;
  bool _quoteReplies = true;
  bool _signatureOnReplies = true;
  bool _confirmArchive = true;
  UndoWindow _undoWindow = UndoWindow.normal;
  bool _bccSelf = true;
  bool _cacheMessages = true;
  // Off because it locks the app for whoever installs it, before they have
  // asked for a lock — and on a device that cannot authenticate, that is a
  // screen with no way past it.
  bool _appLock = false;
  bool _privatePreviews = true;

  /// Whether notifications stay quiet overnight.
  ///
  /// A window rather than a schedule: 22:00 to 07:00, and the app's own idea of
  /// when a day ends. Mail arrives at three in the morning and there is nothing
  /// anybody can do about it then, so the phone does not say so.
  bool _quietHours = false;
  // Chyme ships off, and this is the one setting that does. It cannot do
  // anything at all until somebody gives it an endpoint — a switch that is on
  // and does nothing is exactly what the rest of these defaults exist to
  // avoid.
  /// On by default.
  ///
  /// It used to ship off, on the reasoning that it cannot do anything without
  /// an endpoint. That is true, and it is also why nobody found it: a feature
  /// that is off and mentions an endpoint you do not have is a feature you
  /// never turn on. It is on, the settings offer a provider, and the sheet says
  /// plainly when there is not one yet.
  /// The glass, as the studio left it. Null means "whatever the surface asks
  /// for", which is how the app looked before the studio existed.
  double? _glassBlur;
  double? _glassTint;
  bool _glassInvert = false;

  /// The settings sections somebody has folded away, by title.
  ///
  /// Folding is a decision about *this* screen — which categories you never
  /// touch — and forgetting it on every launch meant making the same decision
  /// every time. Titles rather than indices: a section that is renamed is a
  /// section that opens again, which is the harmless way to be wrong.
  Set<String> _collapsedSections = <String>{};

  /// Whether the app looks for a newer release. On by default: a build that
  /// cannot be updated from anywhere else is a build that should at least say
  /// when there is a new one.
  bool _updateCheck = true;

  /// Whether a newer release is fetched in the background, so the update is
  /// already on the device when somebody taps it.
  bool _autoUpdate = false;

  /// When it last asked. Stored so a launch does not ask again an hour later.
  DateTime? _lastUpdateCheck;

  bool _chymeEnabled = true;
  String _chymeEndpoint = '';
  String _chymeModel = '';

  /// The person's own instructions for Chyme. Empty means the app's.
  String _chymePrompt = '';
  String _chymeKey = '';
  bool _chymeReadsMail = true;
  bool _warnMissingAttachment = true;
  GlassMode _glass = GlassMode.auto;
  LauncherMark _launcherMark = LauncherMark.ink;

  /// How Chyme writes. Neutral is the default: it answers in the register of
  /// whatever it was asked about, which is right more often than any one voice.
  ChymeTone _chymeTone = ChymeTone.neutral;


  Map<String, int> _lastSeen = <String, int>{};

  /// The UIDVALIDITY each saved UID was read under.
  ///
  /// IMAP UIDs are only meaningful inside one mailbox namespace, and a provider
  /// that recreates a mailbox starts numbering again from one. A marker from the
  /// old namespace then sits above every new message, so nothing ever looks new
  /// again — silently, and until the UIDs climb back past it.
  Map<String, int> _lastSeenValidity = <String, int>{};

  /// What the last background check of each account did.
  ///
  /// One short line per address — `<millisecondsSinceEpoch>:<category>` — where
  /// the category is `ok`, `auth`, `connection` or `server`. Deliberately not
  /// the error message: a server's text can quote the command that failed, and
  /// the command can carry a password. A category is enough to tell somebody
  /// "your password was refused" from "it could not reach the server", which is
  /// the whole job.
  Map<String, String> _checkStatus = <String, String>{};

  /// Whether sender pictures are fetched from Gravatar.
  ///
  /// **A disclosure, and it is on.** A Gravatar lookup sends an MD5 of every
  /// sender's address to a third party, and a hash of an address is not
  /// anonymous — addresses are guessable and can be hashed by anyone. It is on
  /// because a list with faces in it is a list you can read at a glance, and
  /// the switch to stop the requests is one tap away. Off means no request is
  /// ever made.
  bool get showAvatars => _showAvatars;

  AceThemeMode get themeMode => _themeMode;

  AceTextSize get textSize => _textSize;

  double get textScale => _textSize.scale;

  /// Whether leaving the mailbox asks first.
  bool get confirmExit => _confirmExit;

  /// Whether opening a message sets `\Seen` on the server.
  bool get markAsReadOnOpen => _markAsReadOnOpen;

  /// Appended to a new message's body.
  String get signature => _signature;

  /// What dragging a message row to the right does.
  SwipeAction get swipeStart => _swipeStart;

  /// What dragging a message row to the left does.
  SwipeAction get swipeEnd => _swipeEnd;

  /// Whether the reader opens formatted or as plain text.

  /// Whether a dropped connection is retried automatically.
  bool get autoReconnect => _autoReconnect;

  /// How many messages a page holds.
  PageSize get pageSize => _pageSize;

  /// How tightly the message list is packed.
  ListDensity get density => _density;

  /// Whether deleting asks first.
  bool get confirmDelete => _confirmDelete;

  /// Whether one-time codes are picked out of messages and shown in the list.
  bool get detectCodes => _detectCodes;

  /// The order the message list is shown in.
  MessageSort get messageSort => _messageSort;

  /// The order that decides ties, when the primary order calls two messages
  /// equal — "by sender, then newest first". Null means the primary decides
  /// everything, which is what most folders want.
  MessageSort? get sortTie => _sortTie;

  /// Whether images in a message are fetched from the sender's server. Off by
  /// default: loading one confirms the message was opened.
  bool get loadRemoteImages => _loadRemoteImages;

  /// The accent the whole app is built from.
  AceAccent get accent => _accent;

  /// A colour the user picked themselves. Null — the normal case — means the
  /// accent above is in charge.
  Color? get customAccent => _customAccent;

  /// The font file they imported, or null for the app's own face.
  String? get customFontPath => _customFontPath;

  /// The family to hand the theme. Only meaningful once the file has been
  /// registered with the engine, which happens at startup and on change.
  String? get customFontFamily =>
      _customFontPath == null ? null : CustomAppearance.fontFamily;

  /// Whether the reader shows the message's raw headers.
  bool get showRawHeaders => _showRawHeaders;

  /// Whether the accent comes from the platform instead of the list — Android's
  /// Monet, and the equivalent elsewhere.
  bool get useDynamicColour => _useDynamicColour;

  /// Whether sending with no subject asks first. A message with no subject is
  /// the one people regret.
  bool get warnEmptySubject => _warnEmptySubject;

  /// Whether a link in a message asks before it leaves the app.
  bool get warnExternalLinks => _warnExternalLinks;

  /// Whether new mail is announced. Off until asked for, and it asks the
  /// platform for permission at that moment rather than at launch.
  bool get notifyNewMail => _notifyNewMail;

  /// Whether taps are felt.
  bool get haptics => _haptics;

  /// True black, for an OLED panel. A pixel that is off draws no power, and on
  /// a dark background the difference between #0E0E0E and #000000 is visible
  /// at the edges of the screen.
  bool get oled => _oled;

  /// Whether the app's transitions move.
  bool get reduceMotion => _reduceMotion;

  /// Whether the list is headed Today, Yesterday, and so on. Off is one
  /// undivided run of messages, for people who would rather see the newest
  /// thing at the top of the screen.
  bool get groupByDate => _groupByDate;

  /// Whether each folder shows how much unread mail is in it.
  bool get showFolderCounts => _showFolderCounts;

  /// Whether the inbox opens with the highlights rail above the list.
  ///
  /// On by default, and off is one switch away: a rail that guesses what a
  /// message is about is worth having only while the guesses are welcome.
  bool get highlights => _highlights;

  /// The version whose release notes have already been shown. Null means the
  /// app has not been through an update yet.
  String? get lastSeenVersion => _lastSeenVersion;

  /// Whether a reply starts with the original message quoted beneath it.
  bool get quoteReplies => _quoteReplies;

  /// Whether the signature is added to replies as well as to new messages.
  bool get signatureOnReplies => _signatureOnReplies;

  /// Whether archiving asks first.
  ///
  /// Off by default: archiving is the routine way to clear the inbox, and a
  /// question in front of a routine action is a question people learn to dismiss
  /// without reading — which is the worst of both worlds.
  bool get confirmArchive => _confirmArchive;

  /// How long the undo on a snack bar stays offered.
  UndoWindow get undoWindow => _undoWindow;

  /// Whether a copy of every message is blind-copied to the sending account.
  bool get bccSelf => _bccSelf;

  /// Whether messages that have been read are kept on the device.
  ///
  /// What is kept is sealed — AES-256-GCM, key in the keychain — but keeping
  /// nothing at all is a legitimate answer to "should this phone hold my
  /// mail", so it is a setting rather than a fact of the app.
  bool get cacheMessages => _cacheMessages;

  /// Whether opening the app asks for a fingerprint or a face first.
  bool get appLock => _appLock;

  /// The blur radius the glass should use, or null for each surface's own.
  double? get glassBlur => _glassBlur;

  /// The tint strength (0–1), or null for each surface's own.
  double? get glassTint => _glassTint;

  /// Whether the tint is inverted — a dark pane where the surface is light.
  bool get glassInvert => _glassInvert;

  Future<void> setGlassBlur(double value) =>
      _write(_keyGlassBlur, '$value', () => _glassBlur = value);

  Future<void> setGlassTint(double value) =>
      _write(_keyGlassTint, '$value', () => _glassTint = value);

  Future<void> setGlassInvert(bool value) =>
      _write(_keyGlassInvert, '$value', () => _glassInvert = value);

  /// Back to the defaults every surface was designed with.
  Future<void> resetGlass() => _write(
        _keyGlassBlur,
        '',
        () {
          _glassBlur = null;
          _glassTint = null;
          _glassInvert = false;
        },
      );

  /// Whether [title]'s section was folded away last time.
  bool sectionCollapsed(String title) => _collapsedSections.contains(title);

  Future<void> setSectionCollapsed(String title, bool collapsed) {
    final Set<String> next = <String>{..._collapsedSections};
    if (collapsed) {
      next.add(title);
    } else {
      next.remove(title);
    }
    if (next.length == _collapsedSections.length &&
        next.containsAll(_collapsedSections)) {
      return Future<void>.value();
    }
    return _write(
      _keyCollapsedSections,
      jsonEncode(next.toList()),
      () => _collapsedSections = next,
    );
  }

  /// Whether the app may look for a newer release.
  bool get updateCheck => _updateCheck;

  /// Whether to download a newer release without being asked.
  ///
  /// Off by default: fetching an installer nobody asked for spends somebody's
  /// data on their behalf. On, it only downloads — installing is always a tap,
  /// and the system's own screen the first time.
  bool get autoUpdate => _autoUpdate;

  /// When it last asked, or null when it never has.
  DateTime? get lastUpdateCheck => _lastUpdateCheck;

  Future<void> setAutoUpdate(bool value) =>
      _write(_keyAutoUpdate, '$value', () => _autoUpdate = value);

  Future<void> setUpdateCheck(bool value) =>
      _write(_keyUpdateCheck, '$value', () => _updateCheck = value);

  Future<void> setLastUpdateCheck(DateTime when) => _write(
        _keyLastUpdateCheck,
        when.toIso8601String(),
        () => _lastUpdateCheck = when,
      );

  /// Whether it is worth asking now: on, and not asked in the last day.
  bool get shouldCheckForUpdates {
    if (!_updateCheck) return false;
    final DateTime? last = _lastUpdateCheck;
    if (last == null) return true;
    return DateTime.now().difference(last) >= const Duration(hours: 24);
  }

  /// Whether Chyme is available at all.
  bool get chymeEnabled => _chymeEnabled;

  /// The API base, as the person typed it. Normalised on use rather than on
  /// save, so what they typed is what they see when they come back.
  String get chymeEndpoint => _chymeEndpoint;

  /// The model to ask. Empty until one is chosen from what the endpoint lists.
  String get chymeModel => _chymeModel;

  /// The instructions Chyme is given, when the person has written their own.
  /// Empty is the ordinary answer and means the app's own prompt is used.
  String get chymePrompt => _chymePrompt;

  /// The key for the endpoint. Kept in the keychain, like the app passwords:
  /// it is a credential, and it is stored where credentials go.
  String get chymeKey => _chymeKey;

  /// Whether Chyme may see the message you have open, and the list you are
  /// looking at. Off means it answers without looking at any mail.
  bool get chymeReadsMail => _chymeReadsMail;

  /// Whether sending a message that talks about an attachment, with nothing
  /// attached, asks first. The mistake it catches is a real one and a common
  /// one: "I've attached the form" and no form.
  bool get warnMissingAttachment => _warnMissingAttachment;

  /// How see-through the floating surfaces are.
  ///
  /// Automatic by default, which means "when the device can afford it": the
  /// blur is a render effect on Android 12 and later and a framebuffer readback
  /// before that, and only one of those is a material.
  GlassMode get glass => _glass;

  /// Whether a notification names the sender and the subject.
  ///
  /// On by default: a notification on a lock screen is read by whoever is
  /// holding the phone, and "you have mail" is enough for most people.
  bool get privatePreviews => _privatePreviews;

  bool get quietHours => _quietHours;

  Future<void> setQuietHours(bool value) =>
      _write(_keyQuietHours, '$value', () => _quietHours = value);

  /// Whether it is currently inside the quiet window.
  ///
  /// Wraps: 22:00 to 07:00 is one window, not two.
  bool isQuietAt(DateTime now) {
    if (!_quietHours) return false;
    final int hour = now.hour;
    return hour >= 22 || hour < 7;
  }

  Future<void> setQuoteReplies(bool value) =>
      _write(_keyQuoteReplies, '$value', () => _quoteReplies = value);

  Future<void> setSignatureOnReplies(bool value) => _write(
      _keySignatureOnReplies, '$value', () => _signatureOnReplies = value);

  Future<void> setConfirmArchive(bool value) =>
      _write(_keyConfirmArchive, '$value', () => _confirmArchive = value);

  Future<void> setUndoWindow(UndoWindow value) =>
      _write(_keyUndoWindow, value.name, () => _undoWindow = value);

  Future<void> setBccSelf(bool value) =>
      _write(_keyBccSelf, '$value', () => _bccSelf = value);

  Future<void> setCacheMessages(bool value) =>
      _write(_keyCacheMessages, '$value', () => _cacheMessages = value);

  Future<void> setAppLock(bool value) =>
      _write(_keyAppLock, '$value', () => _appLock = value);

  Future<void> setPrivatePreviews(bool value) =>
      _write(_keyPrivatePreviews, '$value', () => _privatePreviews = value);

  Future<void> setChymeEnabled(bool value) =>
      _write(_keyChymeEnabled, '$value', () => _chymeEnabled = value);

  Future<void> setChymeEndpoint(String value) =>
      _write(_keyChymeEndpoint, value, () => _chymeEndpoint = value);

  Future<void> setChymePrompt(String value) =>
      _write(_keyChymePrompt, value, () => _chymePrompt = value);

  Future<void> setChymeModel(String value) =>
      _write(_keyChymeModel, value, () => _chymeModel = value);

  Future<void> setChymeKey(String value) =>
      _write(_keyChymeKey, value, () => _chymeKey = value);

  Future<void> setChymeReadsMail(bool value) =>
      _write(_keyChymeReadsMail, '$value', () => _chymeReadsMail = value);

  /// Which mark the launcher icon wears.
  ///
  /// The envelope is the default: it is the mark the app has worn, and a change
  /// of icon is something somebody opts into rather than discovers. The
  /// background is not a setting — it is the accent, and it follows it.
  LauncherMark get launcherMark => _launcherMark;

  ChymeTone get chymeTone => _chymeTone;

  /// The folders in the order the person put them, by path. Folders not in
  /// this list follow in the server's order.
  List<String> _folderOrder = const <String>[];
  List<String> get folderOrder => _folderOrder;

  Future<void> setFolderOrder(List<String> value) => _write(
        _keyFolderOrder,
        jsonEncode(value),
        () => _folderOrder = List<String>.of(value),
      );

  Future<void> setChymeTone(ChymeTone value) =>
      _write(_keyChymeTone, value.name, () => _chymeTone = value);

  Future<void> setLauncherMark(LauncherMark value) => _write(
        _keyLauncherMark,
        value.name,
        () => _launcherMark = value,
      );

  Future<void> setGlass(GlassMode value) =>
      _write(_keyGlass, value.name, () => _glass = value);

  Future<void> setWarnMissingAttachment(bool value) => _write(
        _keyWarnMissingAttachment,
        '$value',
        () => _warnMissingAttachment = value,
      );

  Future<void> setLastSeenVersion(String value) =>
      _write(_keySeenVersion, value, () => _lastSeenVersion = value);

  /// The highest inbox uid seen for an account, so the next check knows what is
  /// new. Kept here rather than in a second storage: it is one small number per
  /// account, and a background isolate can read it the same way the app does.
  int lastSeenUid(String email) => _lastSeen[email.toLowerCase()] ?? 0;

  /// Records what a check of [email] did. See [_checkStatus] for the format.
  Future<void> recordCheck(String email, {required String category}) async {
    _checkStatus[email.toLowerCase()] =
        '${DateTime.now().millisecondsSinceEpoch}:$category';
    await _write(_keyCheckStatus, jsonEncode(_checkStatus), () {});
  }

  /// When [email] was last checked successfully, or null if it never has been.
  DateTime? lastGoodCheck(String email) {
    final String? raw = _checkStatus[email.toLowerCase()];
    if (raw == null) return null;
    final List<String> parts = raw.split(':');
    if (parts.length != 2 || parts[1] != 'ok') return null;
    return _fromMillis(parts[0]);
  }

  /// What the last check of [email] said, as a word worth showing somebody.
  /// Null when it has never been checked.
  String? lastCheckFailure(String email) {
    final String? raw = _checkStatus[email.toLowerCase()];
    if (raw == null) return null;
    final List<String> parts = raw.split(':');
    if (parts.length != 2 || parts[1] == 'ok') return null;
    return switch (parts[1]) {
      'auth' => 'the password was refused',
      'connection' => 'the server could not be reached',
      _ => 'the server refused the check',
    };
  }

  /// When [email] was last checked at all, whatever the answer.
  DateTime? lastCheck(String email) {
    final String? raw = _checkStatus[email.toLowerCase()];
    if (raw == null) return null;
    return _fromMillis(raw.split(':').first);
  }

  static DateTime? _fromMillis(String raw) {
    final int? millis = int.tryParse(raw);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// The namespace [lastSeenUid] was recorded in. Zero means "not known".
  int lastSeenUidValidity(String email) =>
      _lastSeenValidity[email.toLowerCase()] ?? 0;

  Future<void> setLastSeenUid(String email, int uid, {int? validity}) async {
    _lastSeen[email.toLowerCase()] = uid;
    if (validity != null) _lastSeenValidity[email.toLowerCase()] = validity;
    await _write(_keyLastSeen, jsonEncode(_lastSeen), () {});
    await _write(_keyLastSeenValidity, jsonEncode(_lastSeenValidity), () {});
  }

  Future<void> load() async {
    final Map<String, String?> raw = <String, String?>{};
    for (final String key in _keys) {
      try {
        raw[key] = await _storage.read(key: key);
      } catch (_) {
        // A keychain we cannot read means defaults, not a crash.
        raw[key] = null;
      }
    }

    _showAvatars = _decodeBool(raw[_keyAvatars], _showAvatars);
    _confirmExit = _decodeBool(raw[_keyConfirmExit], _confirmExit);
    _markAsReadOnOpen = _decodeBool(raw[_keyMarkRead], _markAsReadOnOpen);
    _themeMode = _decodeEnum(raw[_keyTheme], AceThemeMode.values, _themeMode);
    _textSize = _decodeEnum(raw[_keyTextSize], AceTextSize.values, _textSize);
    _signature = raw[_keySignature] ?? _signature;
    _swipeStart =
        _decodeEnum(raw[_keySwipeStart], SwipeAction.values, _swipeStart);
    _swipeEnd = _decodeEnum(raw[_keySwipeEnd], SwipeAction.values, _swipeEnd);
    _autoReconnect = _decodeBool(raw[_keyAutoReconnect], _autoReconnect);
    _pageSize = _decodeEnum(raw[_keyPageSize], PageSize.values, _pageSize);
    _density = _decodeEnum(raw[_keyDensity], ListDensity.values, _density);
    _confirmDelete = _decodeBool(raw[_keyConfirmDelete], _confirmDelete);
    _detectCodes = _decodeBool(raw[_keyDetectCodes], _detectCodes);
    _messageSort =
        _decodeEnum(raw[_keyMessageSort], MessageSort.values, _messageSort);
    final String tie = raw[_keySortTie] ?? '';
    _sortTie = null;
    for (final MessageSort option in MessageSort.values) {
      if (option.name == tie) _sortTie = option;
    }
    _accent = _decodeEnum(raw[_keyAccent], AceAccent.values, _accent);
    _customAccent = CustomAppearance.parseColour(raw[_keyCustomAccent]);
    final String font = raw[_keyCustomFont] ?? '';
    _customFontPath = font.isEmpty ? null : font;
    _showRawHeaders = _decodeBool(raw[_keyRawHeaders], _showRawHeaders);
    _useDynamicColour =
        _decodeBool(raw[_keyDynamicColour], _useDynamicColour);
    _warnEmptySubject =
        _decodeBool(raw[_keyWarnEmptySubject], _warnEmptySubject);
    _warnExternalLinks =
        _decodeBool(raw[_keyWarnExternalLinks], _warnExternalLinks);
    _notifyNewMail = _decodeBool(raw[_keyNotifyNewMail], _notifyNewMail);
    _lastSeen = _decodeLastSeen(raw[_keyLastSeen]);
    _lastSeenValidity = _decodeLastSeen(raw[_keyLastSeenValidity]);
    _checkStatus = _decodeCheckStatus(raw[_keyCheckStatus]);
    _haptics = _decodeBool(raw[_keyHaptics], _haptics);
    _oled = _decodeBool(raw[_keyOled], _oled);
    _reduceMotion = _decodeBool(raw[_keyReduceMotion], _reduceMotion);
    _groupByDate = _decodeBool(raw[_keyGroupByDate], _groupByDate);
    _showFolderCounts =
        _decodeBool(raw[_keyFolderCounts], _showFolderCounts);
    _highlights = _decodeBool(raw[_keyHighlights], _highlights);
    _quoteReplies = _decodeBool(raw[_keyQuoteReplies], _quoteReplies);
    _signatureOnReplies =
        _decodeBool(raw[_keySignatureOnReplies], _signatureOnReplies);
    _confirmArchive = _decodeBool(raw[_keyConfirmArchive], _confirmArchive);
    _undoWindow =
        _decodeEnum(raw[_keyUndoWindow], UndoWindow.values, _undoWindow);
    _bccSelf = _decodeBool(raw[_keyBccSelf], _bccSelf);
    _cacheMessages = _decodeBool(raw[_keyCacheMessages], _cacheMessages);
    _appLock = _decodeBool(raw[_keyAppLock], _appLock);
    _privatePreviews =
        _decodeBool(raw[_keyPrivatePreviews], _privatePreviews);
    _collapsedSections = _decodeStringSet(raw[_keyCollapsedSections]);
    _glassBlur = double.tryParse(raw[_keyGlassBlur] ?? '');
    _glassTint = double.tryParse(raw[_keyGlassTint] ?? '');
    _glassInvert = _decodeBool(raw[_keyGlassInvert], _glassInvert);
    _updateCheck = _decodeBool(raw[_keyUpdateCheck], _updateCheck);
    _autoUpdate = _decodeBool(raw[_keyAutoUpdate], _autoUpdate);
    _lastUpdateCheck = DateTime.tryParse(raw[_keyLastUpdateCheck] ?? '');
    _chymeEnabled = _decodeBool(raw[_keyChymeEnabled], _chymeEnabled);
    _chymeEndpoint = raw[_keyChymeEndpoint] ?? _chymeEndpoint;
    _chymeModel = raw[_keyChymeModel] ?? _chymeModel;
    _chymePrompt = raw[_keyChymePrompt] ?? _chymePrompt;
    _chymeKey = raw[_keyChymeKey] ?? _chymeKey;
    _chymeReadsMail = _decodeBool(raw[_keyChymeReadsMail], _chymeReadsMail);
    _warnMissingAttachment = _decodeBool(
      raw[_keyWarnMissingAttachment],
      _warnMissingAttachment,
    );
    _glass = _decodeEnum(raw[_keyGlass], GlassMode.values, _glass);
    _chymeTone = _decodeEnum(raw[_keyChymeTone], ChymeTone.values, _chymeTone);
    _folderOrder = _decodeStringList(raw[_keyFolderOrder], _folderOrder);
    _launcherMark = _decodeEnum(
      raw[_keyLauncherMark],
      LauncherMark.values,
      _launcherMark,
    );
    final String? seen = raw[_keySeenVersion];
    _lastSeenVersion = (seen == null || seen.isEmpty) ? null : seen;

    notifyListeners();
  }

  Future<void> setShowAvatars(bool value) =>
      _write(_keyAvatars, '$value', () => _showAvatars = value);

  Future<void> setConfirmExit(bool value) =>
      _write(_keyConfirmExit, '$value', () => _confirmExit = value);

  Future<void> setMarkAsReadOnOpen(bool value) =>
      _write(_keyMarkRead, '$value', () => _markAsReadOnOpen = value);

  Future<void> setThemeMode(AceThemeMode value) =>
      _write(_keyTheme, value.name, () => _themeMode = value);

  Future<void> setTextSize(AceTextSize value) =>
      _write(_keyTextSize, value.name, () => _textSize = value);

  Future<void> setSignature(String value) =>
      _write(_keySignature, value, () => _signature = value);

  Future<void> setSwipeStart(SwipeAction value) =>
      _write(_keySwipeStart, value.name, () => _swipeStart = value);

  Future<void> setSwipeEnd(SwipeAction value) =>
      _write(_keySwipeEnd, value.name, () => _swipeEnd = value);

  Future<void> setAutoReconnect(bool value) =>
      _write(_keyAutoReconnect, '$value', () => _autoReconnect = value);

  Future<void> setPageSize(PageSize value) =>
      _write(_keyPageSize, value.name, () => _pageSize = value);

  Future<void> setDensity(ListDensity value) =>
      _write(_keyDensity, value.name, () => _density = value);

  Future<void> setConfirmDelete(bool value) =>
      _write(_keyConfirmDelete, '$value', () => _confirmDelete = value);

  Future<void> setDetectCodes(bool value) =>
      _write(_keyDetectCodes, '$value', () => _detectCodes = value);

  Future<void> setSortTie(MessageSort? value) => _write(
        _keySortTie,
        value?.name ?? '',
        () => _sortTie = value,
      );

  Future<void> setMessageSort(MessageSort value) =>
      _write(_keyMessageSort, value.name, () => _messageSort = value);


  Future<void> setAccent(AceAccent value) =>
      _write(_keyAccent, value.name, () => _accent = value);

  Future<void> setCustomAccent(Color? value) => _write(
        _keyCustomAccent,
        value == null ? '' : CustomAppearance.encodeColour(value),
        () => _customAccent = value,
      );

  Future<void> setCustomFontPath(String? value) => _write(
        _keyCustomFont,
        value ?? '',
        () => _customFontPath = value,
      );

  Future<void> setShowRawHeaders(bool value) =>
      _write(_keyRawHeaders, '$value', () => _showRawHeaders = value);

  Future<void> setUseDynamicColour(bool value) =>
      _write(_keyDynamicColour, '$value', () => _useDynamicColour = value);

  Future<void> setWarnEmptySubject(bool value) =>
      _write(_keyWarnEmptySubject, '$value', () => _warnEmptySubject = value);

  Future<void> setWarnExternalLinks(bool value) =>
      _write(_keyWarnExternalLinks, '$value', () => _warnExternalLinks = value);

  Future<void> setHaptics(bool value) =>
      _write(_keyHaptics, '$value', () => _haptics = value);

  Future<void> setGroupByDate(bool value) =>
      _write(_keyGroupByDate, '$value', () => _groupByDate = value);

  Future<void> setShowFolderCounts(bool value) =>
      _write(_keyFolderCounts, '$value', () => _showFolderCounts = value);

  Future<void> setHighlights(bool value) =>
      _write(_keyHighlights, '$value', () => _highlights = value);

  Future<void> setReduceMotion(bool value) =>
      _write(_keyReduceMotion, '$value', () => _reduceMotion = value);

  Future<void> setOled(bool value) =>
      _write(_keyOled, '$value', () => _oled = value);

  Future<void> setNotifyNewMail(bool value) =>
      _write(_keyNotifyNewMail, '$value', () => _notifyNewMail = value);

  /// Best effort: a corrupt entry means no memory of what was seen, which costs
  /// one quiet check, not a crash.
  static Map<String, String> _decodeCheckStatus(String? raw) {
    if (raw == null || raw.isEmpty) return <String, String>{};
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, String>{};
      return <String, String>{
        for (final MapEntry<Object?, Object?> e in decoded.entries)
          if (e.value is String) '${e.key}': e.value! as String,
      };
    } catch (_) {
      return <String, String>{};
    }
  }

  static Set<String> _decodeStringSet(String? raw) {
    if (raw == null || raw.isEmpty) return <String>{};
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};
      return decoded.whereType<String>().toSet();
    } catch (_) {
      return <String>{};
    }
  }

  static Map<String, int> _decodeLastSeen(String? raw) {
    if (raw == null || raw.isEmpty) return <String, int>{};
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, int>{};
      return <String, int>{
        for (final MapEntry<Object?, Object?> e in decoded.entries)
          if (e.value is int) '${e.key}': e.value! as int,
      };
    } catch (_) {
      return <String, int>{};
    }
  }

  /// Applies [change] and notifies immediately, then persists. A toggle must
  /// not wait on the keychain before it looks like it worked.
  Future<void> _write(String key, String value, VoidCallback change) async {
    change();
    notifyListeners();
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      // The setting still applies for this session.
    }
  }

  /// A JSON list of strings. Anything else falls back rather than throwing.
  static List<String> _decodeStringList(String? raw, List<String> fallback) {
    if (raw == null) return fallback;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List<dynamic>) {
        return decoded.whereType<String>().toList();
      }
    } catch (_) {
      // A stale or damaged value is the fallback, not a crash at startup.
    }
    return fallback;
  }

  static bool _decodeBool(String? raw, bool fallback) =>
      raw == null ? fallback : raw == 'true';

  /// Unknown or stale stored values fall back rather than throwing.
  static T _decodeEnum<T extends Enum>(String? raw, List<T> values, T fallback) {
    if (raw == null) return fallback;
    for (final T value in values) {
      if (value.name == raw) return value;
    }
    return fallback;
  }
}


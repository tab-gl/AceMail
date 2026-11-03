import 'package:hugeicons/hugeicons.dart';


/// An icon, as Hugeicons hands it over.
///
/// Hugeicons is a widget-based library: an icon is a list of SVG path
/// descriptions, not an `IconData`. That is why this is a list rather than a
/// font code point, and why the call sites build a `HugeIcon` rather than an
/// `Icon`.
typedef AceIcon = List<List<dynamic>>;

/// The app's icons, by meaning.
///
/// Nothing outside this file names a Hugeicons icon directly. That keeps the
/// choice in one place — if a name turns out to be the wrong shape, or the
/// library changes, one line moves rather than ninety call sites.
///
/// Hugeicons' free set is stroke-only, so there is no filled variant: a filled
/// star and an outline star are the same drawing, told apart by colour. That is
/// a real limitation of the set, not an oversight here.
abstract final class AceIcons {
  // --- mail and messages -------------------------------------------------
  static const AceIcon mail = HugeIcons.strokeRoundedMail01;
  static const AceIcon mailOpen = HugeIcons.strokeRoundedMailOpen01;
  static const AceIcon mailUnread = HugeIcons.strokeRoundedMail01;
  static const AceIcon inbox = HugeIcons.strokeRoundedInbox;
  static const AceIcon reply = HugeIcons.strokeRoundedMailReply01;
  static const AceIcon replyAll = HugeIcons.strokeRoundedMailReplyAll01;
  static const AceIcon send = HugeIcons.strokeRoundedSend;
  static const AceIcon schedule = HugeIcons.strokeRoundedClock01;
  static const AceIcon archive = HugeIcons.strokeRoundedArchive01;
  static const AceIcon trash = HugeIcons.strokeRoundedDelete02;
  static const AceIcon star = HugeIcons.strokeRoundedStar;
  static const AceIcon starOff = HugeIcons.strokeRoundedStarOff;
  /// One person, for a contact.
  static const AceIcon user = HugeIcons.strokeRoundedUser;
  /// The address book, for the contacts tab.
  static const AceIcon contacts = HugeIcons.strokeRoundedContactBook;
  static const AceIcon folder = HugeIcons.strokeRoundedFolder01;
  static const AceIcon attachment = HugeIcons.strokeRoundedAttachment01;
  static const AceIcon at = HugeIcons.strokeRoundedAtSign;

  // --- actions -----------------------------------------------------------
  static const AceIcon search = HugeIcons.strokeRoundedSearch01;
  static const AceIcon restore = HugeIcons.strokeRoundedUndo;
  static const AceIcon deleteSweep = HugeIcons.strokeRoundedDelete02;
  static const AceIcon close = HugeIcons.strokeRoundedCancel01;
  static const AceIcon check = HugeIcons.strokeRoundedTick02;
  static const AceIcon checkCircle = HugeIcons.strokeRoundedCheckmarkCircle01;
  static const AceIcon add = HugeIcons.strokeRoundedPlusSign;
  static const AceIcon edit = HugeIcons.strokeRoundedEdit01;
  static const AceIcon copy = HugeIcons.strokeRoundedCopy01;
  static const AceIcon refresh = HugeIcons.strokeRoundedRefresh01;
  static const AceIcon save = HugeIcons.strokeRoundedDownload04;
  static const AceIcon download = HugeIcons.strokeRoundedDownload04;
  static const AceIcon filterOff = HugeIcons.strokeRoundedFilterRemove;
  static const AceIcon expandMore = HugeIcons.strokeRoundedChevronDown;
  static const AceIcon chevronLeft = HugeIcons.strokeRoundedChevronLeft;
  static const AceIcon chevronRight = HugeIcons.strokeRoundedChevronRight;
  static const AceIcon chevronDown = HugeIcons.strokeRoundedChevronDown;
  static const AceIcon unfold = HugeIcons.strokeRoundedUnfoldMore;
  static const AceIcon list = HugeIcons.strokeRoundedLeftToRightListBullet;
  static const AceIcon menu = HugeIcons.strokeRoundedMenu01;

  /// Forwarding a message on. An arrow turning forward, not a mail glyph: the
  /// two reply arrows already look like each other, and a third mail icon would
  /// be a third one to tell apart.
  static const AceIcon forward = HugeIcons.strokeRoundedArrowTurnForward;

  /// The rest of a menu, where the toolbar has run out of room.
  static const AceIcon more = HugeIcons.strokeRoundedMoreHorizontal;

  /// Picking everything in the list.
  static const AceIcon selectAll = HugeIcons.strokeRoundedCheckmarkSquare01;

  /// Marking a whole folder read, which is an open envelope, not a tick: the
  /// tick in this app already means "picked".
  static const AceIcon markAllRead = HugeIcons.strokeRoundedMailOpen02;

  /// The drawer toggle. A hamburger says "a menu"; this says "the sidebar",
  /// which is what it opens.
  static const AceIcon sidebar = HugeIcons.strokeRoundedSidebarLeft;

  // --- settings ----------------------------------------------------------
  static const AceIcon settings = HugeIcons.strokeRoundedSettings01;
  static const AceIcon palette = HugeIcons.strokeRoundedPalette;
  /// A blurred surface, for the see-through setting.
  static const AceIcon blur = HugeIcons.strokeRoundedBlur;
  static const AceIcon density = HugeIcons.strokeRoundedLayoutList;
  static const AceIcon textSize = HugeIcons.strokeRoundedTextFont;
  static const AceIcon brightness = HugeIcons.strokeRoundedSun01;
  static const AceIcon image = HugeIcons.strokeRoundedImage01;
  static const AceIcon password = HugeIcons.strokeRoundedLockPassword;
  static const AceIcon signature = HugeIcons.strokeRoundedPencilEdit02;
  static const AceIcon headers = HugeIcons.strokeRoundedSourceCode;
  static const AceIcon account = HugeIcons.strokeRoundedUserCircle;
  static const AceIcon logout = HugeIcons.strokeRoundedLogout01;
  static const AceIcon visibility = HugeIcons.strokeRoundedEye;
  static const AceIcon visibilityOff = HugeIcons.strokeRoundedEyeOff;
  static const AceIcon reconnect = HugeIcons.strokeRoundedRefresh01;

  // --- gestures and sorting ---------------------------------------------
  static const AceIcon swipeRight = HugeIcons.strokeRoundedSwipeRight01;
  static const AceIcon swipeLeft = HugeIcons.strokeRoundedSwipeLeft01;
  static const AceIcon sort = HugeIcons.strokeRoundedSorting01;
  static const AceIcon sortNewest = HugeIcons.strokeRoundedSortByDown01;
  static const AceIcon sortOldest = HugeIcons.strokeRoundedSortByUp01;
  static const AceIcon sortSender = HugeIcons.strokeRoundedUser;
  static const AceIcon sortSubject = HugeIcons.strokeRoundedText;
  static const AceIcon sortUnread = HugeIcons.strokeRoundedMail01;

  // --- states and misc ---------------------------------------------------
  static const AceIcon info = HugeIcons.strokeRoundedInformationCircle;
  static const AceIcon help = HugeIcons.strokeRoundedHelpCircle;
  static const AceIcon error = HugeIcons.strokeRoundedAlertCircle;
  static const AceIcon warning = HugeIcons.strokeRoundedAlert02;
  static const AceIcon globe = HugeIcons.strokeRoundedGlobe;
  static const AceIcon cloud = HugeIcons.strokeRoundedCloud;
  static const AceIcon shield = HugeIcons.strokeRoundedShield01;
  /// A shield with a tick: a sender the receiving server could vouch for. The
  /// tick is what separates it from [shield] at a glance, which matters on a
  /// chip that is otherwise the same size and shape.
  static const AceIcon shieldCheck = HugeIcons.strokeRoundedShieldCheck;
  static const AceIcon lock = HugeIcons.strokeRoundedLock;

  // --- highlights --------------------------------------------------------
  /// Something on its way, for a delivery highlight.
  static const AceIcon package = HugeIcons.strokeRoundedPackage;
  /// A bill or an invoice.
  static const AceIcon receipt = HugeIcons.strokeRoundedInvoice01;
  /// A flight, for a travel highlight.
  static const AceIcon flight = HugeIcons.strokeRoundedAirplane01;
  /// An invitation or an appointment.
  static const AceIcon calendar = HugeIcons.strokeRoundedCalendar01;
  static const AceIcon fingerprint = HugeIcons.strokeRoundedFingerprintScan;
  /// The search bar's microphone.
  static const AceIcon mic = HugeIcons.strokeRoundedMic01;
  /// Chyme, the assistant.
  static const AceIcon chyme = HugeIcons.strokeRoundedAiBrain01;
  /// Writing with Chyme.
  static const AceIcon chymeWrite = HugeIcons.strokeRoundedAiContentGenerator01;
  static const AceIcon github = HugeIcons.strokeRoundedGithub;
  static const AceIcon openInNew = HugeIcons.strokeRoundedArrowUpRight01;
  static const AceIcon news = HugeIcons.strokeRoundedNews;

  /// The icon for a folder, from its role.
  static AceIcon forFolder(String name, {bool isInbox = false}) {
    final String key = name.toLowerCase();
    if (isInbox || key.contains('inbox')) return inbox;
    if (key.contains('sent')) return send;
    if (key.contains('draft')) return edit;
    if (key.contains('trash') || key.contains('deleted')) return trash;
    if (key.contains('archive') || key.contains('all mail')) return archive;
    if (key.contains('spam') || key.contains('junk')) return warning;
    return folder;
  }
}

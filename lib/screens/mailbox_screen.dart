import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/preferences.dart';
import '../models/mail_folder.dart';
import '../models/message_summary.dart';
import '../services/voice_input.dart';
import '../state/mail_controller.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/ace_snack.dart';
import '../util/haptics.dart';
import '../widgets/astryx_widgets.dart';
import '../widgets/chyme_mark.dart';
import '../widgets/chyme_sheet.dart';
import '../widgets/ace_floating_nav.dart';
import '../widgets/confirm_exit.dart';
import '../widgets/contacts_panel.dart';
import '../widgets/folder_picker.dart';
import '../widgets/folder_rail.dart';
import '../widgets/message_list_panel.dart';
import '../widgets/message_reader.dart';
import 'compose_screen.dart';
import '../widgets/ace_glass.dart';
import '../widgets/ace_icon_view.dart';
import '../services/mailto.dart';
import '../models/message_sort.dart';

/// The three-pane mailbox. Above [_wideBreakpoint] the folder rail, message
/// list and reader sit side by side; below it the reader takes the screen and
/// folders move into a drawer.
///
/// The app bar carries the brand and search. Accounts, help and settings live
/// in the rail, so the top of the screen stays about the mail.
class MailboxScreen extends StatefulWidget {
  const MailboxScreen({super.key});

  static const double _wideBreakpoint = 940;

  @override
  State<MailboxScreen> createState() => _MailboxScreenState();
}

class _MailboxScreenState extends State<MailboxScreen>
    with WidgetsBindingObserver {
  /// Held so the drawer can be opened from the app bar, whose context sits
  /// above the Scaffold — `Scaffold.of` there finds nothing, which is why the
  /// button did nothing at all.
  final GlobalKey<ScaffoldState> _scaffold = GlobalKey<ScaffoldState>();

  /// The app was in the background, and it is back.
  ///
  /// Mail arrives while the phone is in a pocket, and the background check runs
  /// at Android's own floor of fifteen minutes. Coming back to the app is the
  /// moment somebody is looking, and it is the cheapest possible moment to ask
  /// the server what is new: no timer, no wake lock, no battery spent on a
  /// screen nobody is reading. It also covers the case the worker cannot — a
  /// phone that has force-stopped the app, or a session that dropped its
  /// connection while the screen was off.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final MailController? controller = _controller;
    if (controller == null) return;
    if (!controller.isSignedIn) return;
    unawaited(controller.refreshMessages());
  }
  MailController? _controller;
  String? _lastError;

  final TextEditingController _search = TextEditingController();

  /// Whether the search field is live. What the bar's right-hand end shows
  /// depends on it: the microphone when somebody is searching, the assistant
  /// when they are not.
  final FocusNode _searchFocus = FocusNode();
  Timer? _searchDebounce;
  bool _searching = false;

  /// What the contacts list is filtered by. Kept apart from the mail search:
  /// typing a name while looking at contacts must not search the mailbox.
  String _contactQuery = '';

  /// Whether the reader sheet is up on a narrow layout.
  ///
  /// A message on a phone is a sheet over the list, not a page that replaces
  /// it: it arrives from the bottom, it is dismissed by dragging it down, and
  /// there is no back chevron because there is no page to go back to.
  bool _readerSheetOpen = false;

  /// Whether the microphone is listening. The bar says so while it is: a
  /// microphone that gives no sign of being live is a microphone people talk to
  /// twice.
  bool _listening = false;

  /// Asks the device to listen, then searches what it heard.
  ///
  /// The words land in the field and the search runs, because that is what
  /// somebody tapping a microphone in a search bar wants. They can edit them
  /// afterwards — which is the difference between this and a voice command.
  Future<void> _listenForSearch() async {
    if (_listening) return;
    unawaited(AceHaptics.tap());
    setState(() => _listening = true);
    try {
      final String? heard = await VoiceInput.listen();
      if (!mounted || heard == null) return;
      _search.text = heard;
      _search.selection = TextSelection.collapsed(offset: heard.length);
      _onSearchChanged(heard);
      // Deliberately not awaited: the search runs, and the field is already
      // showing the words. Waiting would hold the microphone's spinner on
      // screen for the length of a server round trip.
      unawaited(context.read<MailController>().search(heard));
    } catch (error) {
      if (!mounted) return;
      AceSnack.show(context, '$error');
    } finally {
      if (mounted) setState(() => _listening = false);
    }
  }

  /// Whether the compose button is showing its label.
  ///
  /// It shortens once the list has been scrolled: the label is there to teach
  /// the button, and by the time you have scrolled you have learned it. It comes
  /// back at the top, so it is never a button you have to remember.

  /// The folder the current search belongs to, so a folder change can end it.
  String? _searchFolder;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final MailController controller = context.read<MailController>();
    if (!identical(controller, _controller)) {
      _controller?.removeListener(_onControllerChanged);
      _controller = controller..addListener(_onControllerChanged);
    }
  }

  /// A refresh while somebody is looking at the mail.
  ///
  /// The background worker runs every fifteen minutes, which is the floor
  /// WorkManager allows and is fine for a phone in a pocket. It is not fine for
  /// a phone in a hand: fifteen minutes of staring at a list that is already
  /// out of date. This is the same fetch, on a shorter clock, only while the
  /// screen is up — the worker keeps doing the rest.
  Timer? _foregroundRefresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foregroundRefresh = Timer.periodic(
      const Duration(minutes: 2),
      (Timer _) {
        if (!mounted) return;
        final MailController controller = context.read<MailController>();
        if (!controller.refreshing) controller.refreshMessages();
      },
    );
    // The bar's right-hand end changes with the focus, so the focus has to
    // rebuild it. Tapping is not enough: putting the keyboard away is a way of
    // leaving the search, and the microphone has to leave with it.
    _searchFocus.addListener(() {
      if (!mounted) return;
      // The bar grew when it took focus; when focus goes, the keyboard goes
      // with it. It used to stay up over a collapsed bar — a keyboard for a
      // field nobody was in, which is a keyboard covering the mail.
      if (!_searchFocus.hasFocus) {
        FocusScope.of(context).unfocus();
        SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      }
      setState(() {});
    });
    // A mailto: this launch was opened with. After the first frame, because a
    // sheet needs a context that is already in the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_openPendingMailto());
    });
  }

  /// Opens the composer for a `mailto:` the app was launched with.
  ///
  /// Declaring the filter in the manifest is half of being an email client. The
  /// other half is this: without it the app appears in the "Open with" sheet and
  /// then opens on the inbox, having thrown away the address somebody tapped.
  Future<void> _openPendingMailto() async {
    final MailtoLink? link = await Mailto.take();
    if (link == null || !mounted) return;
    await openComposeSheet(
      context,
      initialTo: link.to,
      initialSubject: link.subject,
      initialBody: link.body,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _foregroundRefresh?.cancel();
    _searchDebounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    _controller?.removeListener(_onControllerChanged);
    super.dispose();
  }

  /// Surfaces a failure that would otherwise be swallowed — a folder that will
  /// not load, a message that will not delete — and closes search when the
  /// ground moves under it.
  void _onControllerChanged() {
    final MailController? controller = _controller;
    if (controller == null) return;

    _syncReaderSheet(controller);

    final String? error = controller.sessionError;
    if (error == null) {
      _lastError = null;
    } else if (error != _lastError) {
      _lastError = error;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AceSnack.show(context, error);
      });
    }

    if (!_searching) return;
    final bool folderMoved = controller.selectedFolder?.path != _searchFolder;
    final bool openedMessage = controller.openSummary != null;
    if (folderMoved || openedMessage) {
      // Cancelled now rather than in the callback below: a debounce with a few
      // milliseconds left on it would otherwise fire between the switch and the
      // frame that ends the search, and search the new folder for the old
      // folder's words.
      _searchDebounce?.cancel();
      // The session has already reset its own query in the folder case, so only
      // the field and the mode need clearing.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _exitSearch(clearQuery: false);
      });
    }
  }

  /// Keeps the reader sheet in step with the message that is open.
  ///
  /// Two things say "a message is open": the controller's state, and the route
  /// that is showing it. Whichever one moved, the other follows — opening a
  /// message raises the sheet, and dragging the sheet away closes the message,
  /// so the list never sits behind a sheet that thinks it is still reading.
  void _syncReaderSheet(MailController controller) {
    if (!mounted) return;
    final bool wide =
        MediaQuery.sizeOf(context).width >= MailboxScreen._wideBreakpoint;
    final bool wanted = !wide && controller.openSummary != null;
    if (wanted == _readerSheetOpen) return;

    if (wanted) {
      unawaited(_showReaderSheet(controller));
    } else {
      // Claimed before the pop: the pop notifies the controller, which comes
      // straight back here, and a second pop would take the mailbox with it.
      _readerSheetOpen = false;
      Navigator.of(context).pop();
    }
  }

  Future<void> _showReaderSheet(MailController controller) async {
    _readerSheetOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        // Full height, because a message is not a glance: the sheet is the
        // reader, and a reader you have to drag up before you can read is a
        // reader that made you do something first.
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: context.astryx.backgroundSurface,
        builder: (BuildContext sheetContext) => FractionallySizedBox(
          heightFactor: 1,
          child: MessageReader(
            // No chevron: the handle is the way out. The actions that end the
            // reading still close it, which is what onDismiss is for.
            onDismiss: () => Navigator.of(sheetContext).pop(),
          ),
        ),
      );
    } finally {
      _readerSheetOpen = false;
    }

    // Dragged away, or dismissed: the message is no longer being read. Guarded
    // on mounted, and on the message still being open, because the other
    // direction — the message closing and popping the sheet — lands here too.
    if (!mounted) return;
    if (controller.openSummary != null) controller.closeMessage();
  }

  bool _onScroll(ScrollNotification notification) => false;

  void _exitSearch({bool clearQuery = true}) {
    _searchDebounce?.cancel();
    _search.clear();
    if (clearQuery) context.read<MailController>().clearSearch();
    if (mounted) setState(() => _searching = false);
  }

  void _onSearchChanged(String value) {
    if (context.read<MailController>().contactsTab) {
      // Filtering a list already in memory: no debounce, no server, no reason
      // to wait.
      setState(() => _contactQuery = value);
      return;
    }
    // The field is always on screen now, so "searching" means "there is a
    // query", not "a search screen is open".
    final bool searching = value.trim().isNotEmpty;
    if (searching && !_searching) {
      _searchFolder = context.read<MailController>().selectedFolder?.path;
    }
    if (searching != _searching) setState(() => _searching = searching);

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      context.read<MailController>().search(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final MailController controller = context.watch<MailController>();
    final bool wide =
        MediaQuery.sizeOf(context).width >= MailboxScreen._wideBreakpoint;
    final bool reading = controller.openSummary != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (_searching) {
          _exitSearch();
          return;
        }
        // On a phone the first back closes the open message, not the app.
        if (!wide && controller.openSummary != null) {
          controller.closeMessage();
          return;
        }
        _confirmExit(context);
      },
      // Pull down to refresh; on a keyboard, Ctrl/Cmd+R does the same, because
      // a drag is awkward with a mouse.
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyR, control: true): () =>
              context.read<MailController>().refreshMessages(),
          const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () =>
              context.read<MailController>().refreshMessages(),
        },
        // Back leaves the search before it leaves the screen. With the bar
        // focused, a back press that closed the folder would throw away the
        // keyboard *and* the place you were standing.
        child: PopScope(
          canPop: !_searchFocus.hasFocus,
          onPopInvokedWithResult: (bool didPop, Object? _) {
            if (didPop) return;
            _searchFocus.unfocus();
            setState(() {});
          },
          child: Scaffold(
        key: _scaffold,
        backgroundColor: c.backgroundBody,
        appBar: controller.selecting
            ? AppBar(
                leading: AceIconButton(
                  icon: AceIcons.close,
                  tooltip: 'Cancel selection',
                  onPressed: () => context.read<MailController>().clearSelection(),
                ),
                title: Text(
                  '${controller.selectedCount} selected',
                  style: AstryxText.heading3(c.textPrimary),
                ),
                actions: <Widget>[
                  if (!controller.allSelected)
                    AceIconButton(
                      icon: AceIcons.selectAll,
                      tooltip: 'Select all',
                      onPressed: () =>
                          context.read<MailController>().selectAll(),
                    ),
                  if (controller.inTrash)
                    AceIconButton(
                      icon: AceIcons.restore,
                      tooltip: 'Restore to inbox',
                      onPressed: () => controller.forEachSelected(
                        (MessageSummary m) => controller.restoreMessage(m),
                      ),
                    ),
                  if (!controller.inTrash)
                    AceIconButton(
                      icon: AceIcons.check,
                      tooltip: 'Mark as read',
                      // Marks read, and leaves read messages alone. This used to
                      // call toggleRead, so "Mark as read" quietly marked the
                      // already-read ones *unread*.
                      onPressed: () => controller.forEachSelected(
                        (MessageSummary m) => controller.markRead(m),
                      ),
                    ),
                  if (!controller.inTrash)
                    AceIconButton(
                      icon: AceIcons.archive,
                      tooltip: 'Archive',
                      onPressed: () => _archiveSelected(context),
                    ),
                  if (!controller.inTrash)
                    AceIconButton(
                      icon: AceIcons.folder,
                      tooltip: 'Move to a folder',
                      onPressed: () => _moveSelected(context),
                    ),
                  AceIconButton(
                    icon: AceIcons.trash,
                    // In the trash this does not move anything — it destroys,
                    // and the tooltip is the only place that can say so before
                    // the fact.
                    tooltip: controller.inTrash
                        ? 'Delete permanently'
                        : 'Delete',
                    onPressed: () => _deleteSelected(context),
                  ),
                  const SizedBox(width: AstryxSpace.s2),
                ],
              )
            : AppBar(
          // Taller than Material's 56, because the search bar lives in the
          // title slot now and it is not a 40px pill.
          toolbarHeight: 68,
          // The list scrolls *under* the bar, and the bar is glass over it —
          // which is what makes the material visible at all. An opaque bar over
          // a static background is a bar, not a pane of anything.
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          flexibleSpace: AceGlass.material(
            context,
            blur: 26,
            opacity: 0.68,
            bordered: false,
            child: const SizedBox.expand(),
          ),
          titleSpacing: AstryxSpace.s2,
          // Ours, not Material's default DrawerButton: the hamburger was the
          // last Material icon left in the app bar, and it was the wrong
          // weight next to everything else.
          // The sidebar folds away the moment the bar has focus, and the bar
          // takes the room it leaves. The icon is the way to the folders; while
          // somebody is typing a search they are not going to the folders, and
          // a bar that stops short of the edge looks like it is still sharing
          // the row with something.
          //
          // An active search keeps the chevron, because that is the way out of
          // the *results* rather than out of the field.
          // No sidebar button. The search bar takes the room, and the drawer is
          // still there for a swipe from the edge — a permanent icon in the
          // corner was costing a tap's worth of width on every screen to say
          // something the swipe already says.
          // The drawer toggle, back where it was. Hiding it to give the search
          // bar the room made the folders reachable only by a swipe nobody is
          // told about — a control you cannot find is not a control you saved
          // space by removing.
          leadingWidth: _searching || _searchFocus.hasFocus ? 0 : null,
          leading: _searching
              ? AceIconButton(
                  icon: AceIcons.chevronLeft,
                  tooltip: 'Clear the search',
                  onPressed: _exitSearch,
                )
              : _searchFocus.hasFocus
                  ? null
                  : AceIconButton(
                      icon: AceIcons.sidebar,
                      tooltip: 'Folders',
                      onPressed: () => _scaffold.currentState?.openDrawer(),
                    ),
          // The search bar, where the folder's name used to be. The name is not
          // lost — the greeting above the list says which folder you are in and
          // what is in it, which is where a person looks anyway — and the space
          // it gave up is the search bar's, which is the thing people reach for
          // far more often.
          title: reading && !wide ? null : _searchBar(c),
          actions: <Widget>[
            // Emptying the trash lives where the trash does, and nowhere else:
            // an action that destroys everything should not be one tap away
            // from a folder where it means nothing.
            if ((controller.inTrash || controller.inJunk) && !_searching)
              AceIconButton(
                icon: AceIcons.deleteSweep,
                tooltip: controller.inJunk ? 'Empty junk' : 'Empty trash',
                onPressed: () =>
                    _confirmEmpty(context, junk: controller.inJunk),
              ),
            // One button for the choices that used to take a row of the list:
            // the filters and the order. It wears the accent when something
            // other than the default is in force, which is what the chips were
            // never able to say.
            const SizedBox(width: AstryxSpace.s2),
          ],
        ),
        // The sidebar on a phone. Without this the rail is unreachable and
        // there is no way to change folder at all.
        drawer: wide
            ? null
            : Drawer(
                width: 304,
                backgroundColor: c.backgroundSurface,
                child: const FolderRail(),
              ),
        // Compose, and only Compose. The assistant lives in the search bar,
        // where it has always been: the bar is where you ask the app to find
        // something, and asking the assistant is the same intention. A second
        // pill along the bottom edge was a second place to look for it.
        //
        // It does not collapse as the list scrolls. A button that changes shape
        // as the list moves is a button reacting to something you are not
        // looking at.
        // No Scaffold FAB. The bottom of a phone screen carries three things —
        // the folder tabs, Ask Chyme and Compose — and they are laid out
        // together by [_BottomBar] in the body's stack. As a Scaffold FAB,
        // Compose was positioned by the Scaffold and the other two were not,
        // so nothing knew where anything else was and on a narrow screen all
        // three landed on the same strip of pixels.
        // Behind the bar, so the glass has the list to blur rather than a flat
        // colour.
        extendBodyBehindAppBar: !(reading && !wide),
        body: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: wide
            ? Row(
                children: <Widget>[
                  const FolderRail(),
                  VerticalDivider(width: 1, color: c.border),
                  // The list slot carries the address book when that is what is
                  // being looked at: on a wide screen the two are the same
                  // column, and swapping what fills it is the whole change.
                  SizedBox(
                    width: 380,
                    child: controller.contactsTab
                        ? ContactsPanel(query: _contactQuery)
                        : const MessageListPanel(),
                  ),
                  VerticalDivider(width: 1, color: c.border),
                  const Expanded(child: MessageReader()),
                ],
              )
            : Stack(
                children: <Widget>[
                  AnimatedSwitcher(
                duration: AstryxMotion.of(const Duration(milliseconds: 240)),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (
                  Widget child,
                  Animation<double> animation,
                ) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.06, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                    // The reader is not one of these on a phone: it comes up
                    // over them as a sheet, so the list stays where it was.
                    child: controller.contactsTab
                        ? ContactsPanel(
                            key: const ValueKey<String>('contacts'),
                            query: _contactQuery,
                          )
                        : const MessageListPanel(
                            key: ValueKey<String>('list'),
                          ),
                  ),
                  // The bar floats over the page rather than sitting under it,
                  // and it is not there while a message is open: reading is a
                  // place you are in, not a tab you are on.
                  if (!reading)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _BottomBar(
                        contacts: controller.contactsTab,
                        onContactsChanged: (bool contacts) {
                          setState(() => _contactQuery = '');
                          controller.showContacts(contacts);
                          // The bar's search is one search bar; leaving the tab
                          // must not leave a filter behind it.
                          _search.clear();
                          _exitSearch();
                        },
                        onAsk: () => ChymeSheet.show(context),
                        onCompose: () => _compose(context),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        ),
      );
  }

  /// The search bar, in the app bar where the folder's name used to be.
  ///
  /// It is not a pill behind an icon any more, and it is not 40px: searching a
  /// folder is something people do constantly, and it is the one thing in the
  /// app bar worth the room. The microphone on its right hands the listening to
  /// the device — see [VoiceInput].
  Widget _searchBar(AstryxColors c) {
    final bool hasText = _search.text.isNotEmpty;
    final Preferences prefs = context.watch<Preferences>();
    // Live means somebody is looking at it: focused, or with something typed.
    // A microphone offered to somebody who is reading the list is a button
    // that competes with the one thing the bar is for.
    final bool live = _searchFocus.hasFocus || hasText;

    return AnimatedContainer(
      duration: AstryxMotion.of(AstryxMotion.fast),
      curve: AstryxMotion.emphasized,
      // Taller than it was, and taller again while it is being used: the bar is
      // the first thing a thumb reaches for, and 52 was a compromise made when
      // it shared the row with the folder's name.
      height: live ? 60 : 56,
      padding: const EdgeInsets.only(
        left: AstryxSpace.s4,
        right: AstryxSpace.s1,
      ),
      decoration: BoxDecoration(
        color: c.backgroundMuted,
        borderRadius: BorderRadius.circular(AstryxRadius.full),
        // The outline takes the accent while the microphone is live, which is
        // the only thing on screen that says the app is listening to the room.
        border: Border.all(
          color: _listening ? c.accent : c.border,
          width: _listening ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          AceIconView(icon: AceIcons.search, size: 20, color: c.iconSecondary),
          const SizedBox(width: AstryxSpace.s3),
          Expanded(
            child: TextField(
              controller: _search,
              focusNode: _searchFocus,
              // Not autofocused: the bar is on screen from the moment a folder
              // opens, and a keyboard that appears by itself is a keyboard you
              // have to dismiss before you can read anything. Tapping it is
              // what makes it live, and that is when the microphone arrives.
              onTap: () => setState(() {}),
              onEditingComplete: () => setState(() {}),
              // Not autofocused: the bar is on screen from the moment a folder
              // opens, and a keyboard that appears by itself is a keyboard you
              // have to dismiss before you can read anything.
              onChanged: _onSearchChanged,
              onSubmitted: (String value) {
                _searchDebounce?.cancel();
                context.read<MailController>().search(value);
              },
              textInputAction: TextInputAction.search,
              style: AstryxText.body(c.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search',
                // Every state, not just the resting one: leaving the focused
                // border unset lets the theme's outline draw inside the pill.
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isDense: true,
                filled: false,
                contentPadding: EdgeInsets.zero,
                hintStyle: AstryxText.body(c.textSecondary),
              ),
            ),
          ),
          // Only when there is something to clear, so the bar never offers a
          // button that does nothing.
          AnimatedSize(
            duration: AstryxMotion.of(AstryxMotion.fast),
            curve: AstryxMotion.emphasized,
            child: hasText
                ? AceIconButton(
                    icon: AceIcons.close,
                    tooltip: 'Clear the search',
                    onPressed: _exitSearch,
                  )
                : const SizedBox.shrink(),
          ),
          // One slot, two occupants, and which one is in it is the whole
          // point: the microphone belongs to searching, and the assistant
          // belongs to everything else. Neither is ever a wasted tap, because
          // neither is there when it is not the thing you are doing.
          AnimatedSwitcher(
            duration: AstryxMotion.of(const Duration(milliseconds: 240)),
            switchInCurve: AstryxMotion.emphasized,
            switchOutCurve: AstryxMotion.emphasized,
            transitionBuilder: (Widget child, Animation<double> animation) =>
                FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.7, end: 1).animate(animation),
                child: child,
              ),
            ),
            child: live || !prefs.chymeEnabled
                ? _MicButton(
                    key: const ValueKey<String>('mic'),
                    listening: _listening,
                    onPressed: _listenForSearch,
                  )
                : AceIconButton(
                    key: const ValueKey<String>('chyme'),
                    icon: AceIcons.chyme,
                    tooltip: 'Chyme',
                    markBuilder: (Color foreground) =>
                        ChymeMark(size: 22, color: foreground),
                    onPressed: () => ChymeSheet.show(context),
                  ),
          ),
          // Beside the microphone, where the controls for the list belong. In
          // the greeting it read as part of the sentence above the mail.
          AceIconButton(
            icon: AceIcons.sort,
            tooltip: 'Sort and filter',
            selected: context.read<MailController>().filter != MessageFilter.all ||
                context.read<MailController>().sort != MessageSort.newest,
            onPressed: () => showSortSheet(context),
          ),
        ],
      ),
    );
  }

  void _compose(BuildContext context) {
    // A sheet, not a pushed screen — see [openComposeSheet].
    unawaited(openComposeSheet(context));
  }

  Future<void> _confirmExit(BuildContext context) async {
    // The user can turn the confirmation off; then leaving just leaves.
    final Preferences prefs = context.read<Preferences>();
    if (prefs.confirmExit && !await confirmExit(context)) return;
    await SystemNavigator.pop();
  }
  /// Asks, then empties. An expunged message is gone from the server rather
  /// than moved, so this is the one action in the app that cannot be undone and
  /// the one that must ask.
  Future<void> _confirmEmpty(BuildContext context, {bool junk = false}) async {
    final MailController controller = context.read<MailController>();
    final String name = junk ? 'junk' : 'trash';
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('Empty the $name?'),
        content: Text(
          'Every message in it is deleted from the server. This cannot be '
          'undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Empty'),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;

    if (junk) {
      await controller.emptyJunk();
    } else {
      await controller.emptyTrash();
    }
    if (!context.mounted) return;
    AceSnack.show(context, junk ? 'Junk emptied.' : 'Trash emptied.');
  }

  /// Deletes everything picked.
  ///
  /// From the Trash that is permanent — it destroys, and there is nothing to
  /// undo — so it asks first, the way the reader and "Empty trash" already do.
  Future<void> _deleteSelected(BuildContext context) async {
    final MailController controller = context.read<MailController>();
    final bool permanent = controller.inTrash;

    if (permanent) {
      final int count = controller.selectedCount;
      if (!await confirmPermanentDelete(context, count: count)) return;
      if (!context.mounted) return;
    }

    await controller.deleteSelected(permanently: permanent);
  }

  /// Files everything picked into a folder the person chooses.
  Future<void> _moveSelected(BuildContext context) async {
    final MailController controller = context.read<MailController>();
    final MailFolder? target = await showFolderPicker(
      context,
      folders: controller.filingFolders,
      currentPath: controller.currentFolderPath,
      title: 'Move ${controller.selectedCount == 1 ? 'this message' : '${controller.selectedCount} messages'}',
    );
    if (target == null || !context.mounted) return;
    await controller.moveSelectedTo(target);
    if (!context.mounted) return;
    AceSnack.show(context, 'Moved to ${target.label}.');
  }

  /// Archives everything picked, asking first when the setting is on.
  Future<void> _archiveSelected(BuildContext context) async {
    final MailController controller = context.read<MailController>();
    if (context.read<Preferences>().confirmArchive &&
        !await confirmArchive(context)) {
      return;
    }
    await controller.archiveSelected();
  }

}

/// The search bar's microphone.
///
/// It pulses while the device is listening. Nothing else on screen changes when
/// a recogniser is open — the speech app is a separate window — so on the way
/// back this is what says the app is still waiting.
class _MicButton extends StatefulWidget {
  const _MicButton({
    super.key,
    required this.listening,
    required this.onPressed,
  });

  final bool listening;
  final VoidCallback onPressed;

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.listening) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.listening == oldWidget.listening) return;
    if (widget.listening) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.animateTo(0, duration: AstryxMotion.of(AstryxMotion.fast));
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (BuildContext context, Widget? child) {
        final double t = _pulse.value;
        return Transform.scale(
          scale: 1 + 0.06 * t,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // The ring grows and fades as it pulses, so the button reads as
              // waiting rather than as broken.
              color: widget.listening
                  ? c.accent.withValues(alpha: 0.12 + 0.10 * t)
                  : Colors.transparent,
            ),
            child: child,
          ),
        );
      },
      child: AceIconButton(
        icon: AceIcons.mic,
        // Still tappable while it is live, and does nothing: the listening is
        // happening in the device's speech app, which this cannot reach in to
        // stop. Saying so is better than a button that looks broken.
        tooltip: widget.listening ? 'Listening…' : 'Search by voice',
        onPressed: widget.onPressed,
      ),
    );
  }
}

/// The bottom of the phone layout: the folder tabs, the assistant and Compose.
///
/// One widget because they share one strip of the screen, and they did not use
/// to. The tabs were positioned from the left, the assistant from the centre,
/// Compose from the right by the Scaffold — three things that did not know
/// where the others were. A phone has no width for three pills in a row, so
/// they drew on top of each other: Ask Chyme half behind Compose, and both of
/// them over the folder tabs.
///
/// The assistant sits *above* Compose rather than beside it. A secondary action
/// stacked over the primary one, both on the trailing edge, is the shape
/// Material already uses for this, and it is the only arrangement that leaves
/// the folder tabs their own width.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.contacts,
    required this.onContactsChanged,
    required this.onAsk,
    required this.onCompose,
  });

  final bool contacts;
  final ValueChanged<bool> onContactsChanged;
  final VoidCallback onAsk;
  final VoidCallback onCompose;

  /// Below this the Compose button gives up its label and becomes a circle.
  ///
  /// The three controls are sized by their own content, and on a 320dp phone
  /// the tabs and an extended Compose together are wider than the screen. A
  /// circle is still the same button, and the icon is the part that was doing
  /// the work anyway.
  static const double _roomForALabel = 360;

  @override
  Widget build(BuildContext context) {
    final bool roomy = MediaQuery.sizeOf(context).width >= _roomForALabel;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AstryxSpace.s4,
        0,
        AstryxSpace.s4,
        AstryxSpace.s4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.centerRight,
            child: AceAskChyme(onAsk: onAsk),
          ),
          const SizedBox(height: AstryxSpace.s3),
          Row(
            children: <Widget>[
              AceFloatingNav<bool>(
                // The safe area is this column's, applied once around all of
                // it: the nav brings its own only when it is alone down here.
                floating: false,
                value: contacts,
                onChanged: onContactsChanged,
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
              const Spacer(),
              AceFab(
                label: 'Compose',
                icon: AceIcons.edit,
                extended: roomy,
                onPressed: onCompose,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

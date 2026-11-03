import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/cupertino.dart'
    show CupertinoSliverRefreshControl, RefreshIndicatorMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../data/preferences.dart';
import '../models/mail_folder.dart';
import '../models/message_group.dart';
import '../services/mail_highlights.dart';
import '../util/ace_snack.dart';
import '../models/message_sort.dart';
import '../models/message_summary.dart';
import '../models/swipe_action.dart';
import '../state/mail_controller.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../services/google_auth.dart';
import '../util/dates.dart';
import '../util/greeting.dart';
import '../util/search_query.dart';
import 'ace_glass.dart';
import 'astryx_widgets.dart';
import 'avatar.dart';
import 'confirm_exit.dart';
import 'highlights_rail.dart';
import 'message_actions.dart';
import 'settings_group.dart';
import 'skeleton.dart';
import 'swipe_action.dart';
import 'ace_icon_view.dart';

/// The message list: a row of filter and sort chips, then the messages.
///
/// The title lives in the app bar, so the space here goes to the controls
/// instead of repeating the folder name.
class MessageListPanel extends StatelessWidget {
  const MessageListPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final MailController controller = context.watch<MailController>();
    final Preferences prefs = context.watch<Preferences>();

    return Container(
      color: c.backgroundBody,
      // Fade through when the folder changes, so the list reads as a new
      // mailbox arriving rather than the same rows being swapped underneath.
      child: AnimatedSwitcher(
        duration: AstryxMotion.of(const Duration(milliseconds: 220)),
        switchInCurve: AstryxMotion.emphasizedDecelerate,
        switchOutCurve: Curves.easeIn,
        child: CustomScrollView(
        key: ValueKey<String>(controller.selectedFolder?.path ?? ''),
        // Bouncing, not the platform default. On Android the default physics
        // *clamps*: the list stops dead at the top instead of overscrolling, so
        // the refresh control never reaches its trigger distance and a pull
        // does nothing at all. Bouncing overscrolls on every platform, which is
        // what makes the pull work.
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: <Widget>[
          CupertinoSliverRefreshControl(
            onRefresh: () => context.read<MailController>().refreshMessages(),
            refreshTriggerPullDistance: 110,
            refreshIndicatorExtent: 58,
            builder: _refreshIndicator,
          ),
          // The bar's own height, because the list runs *behind* it: the glass
          // needs mail to blur, and the price of that is that the first thing in
          // the list would otherwise start underneath it. The greeting was being
          // painted behind the bar, which is why it looked as if it had gone.
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.paddingOf(context).top + 68,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AstryxSpace.s2)),
          // Where you are and what is in it, before the mail itself. It carries
          // the folder's name, which the app bar gave up to the search bar.
          if (controller.searchQuery == null)
            SliverToBoxAdapter(child: _Greeting(controller: controller)),
          // The highlights, between where you are and the mail itself. Only in
          // an inbox, and only when nothing is being searched or picked: this
          // is a shortcut to unread mail from the last week, and in a folder of
          // sent mail or a set of search results it would be a rail of cards
          // about messages the person is not looking for.
          if (prefs.highlights &&
              controller.searchQuery == null &&
              !controller.selecting &&
              _isInbox(controller))
            SliverToBoxAdapter(
              child: HighlightsRail(
                highlights: HighlightScanner.scan(controller.visibleMessages),
              ),
            ),
          ..._slivers(context, controller),
        ],
        ),
      ),
    );
  }

  /// Whether the list is showing an inbox — one account's, or all of them.
  ///
  /// The highlights belong to an inbox the way a doormat belongs to a door: the
  /// two folders where mail arrives. Sent, drafts and the trash get none,
  /// because nothing in them is waiting to be dealt with.
  bool _isInbox(MailController controller) {
    final FolderRole? role = controller.selectedFolder?.role;
    return role == FolderRole.inbox || role == FolderRole.unified;
  }

  /// The pull is a drag, so the indicator is driven by it: the shape morphs as
  /// you pull, and only starts looping once the refresh is actually running.
  Widget _refreshIndicator(
    BuildContext context,
    RefreshIndicatorMode mode,
    double pulled,
    double trigger,
    double extent,
  ) {
    final bool running = mode == RefreshIndicatorMode.refresh ||
        mode == RefreshIndicatorMode.done;

    return SizedBox(
      height: extent,
      child: Center(
        child: AceLoader(
          size: 32,
          progress: running ? null : (pulled / trigger).clamp(0.0, 1.0),
        ),
      ),
    );
  }

  List<Widget> _slivers(BuildContext context, MailController controller) {
    final AstryxColors c = context.astryx;

    if (controller.loadingMessages) {
      // Rows shaped like the ones coming, rather than a spinner on an empty
      // screen.
      return <Widget>[
        SliverToBoxAdapter(
          child: MessageListSkeleton(
            avatarSize: context.watch<Preferences>().density.avatarSize,
          ),
        ),
      ];
    }

    final List<MessageSummary> rows = controller.visibleMessages;

    // A failed fetch used to look like an empty folder. Say what happened.
    final String? error = controller.sessionError;
    if (rows.isEmpty && error != null && controller.messages.isEmpty) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Centred(
            icon: AceIcons.error,
            iconColor: c.error,
            message: error,
            // Google's grant can be withdrawn from the account page, and a
            // token that never covered the mail scope cannot be refreshed into
            // one. Both end the same way — the person has to look at Google's
            // screen once — so the button offers that rather than a retry that
            // would fail identically.
            action: controller.needsGoogleSignIn
                ? AceButton(
                    label: 'Sign in with Google',
                    icon: AceIcons.mailOpen,
                    variant: AceButtonVariant.primary,
                    onPressed: () => _signInWithGoogle(context),
                  )
                : AceButton(
                    label: 'Try again',
                    icon: AceIcons.refresh,
                    variant: AceButtonVariant.tonal,
                    onPressed: () =>
                        context.read<MailController>().refreshMessages(),
                  ),
          ),
        ),
      ];
    }

    if (rows.isEmpty) {
      // Still fetching: the skeleton, not "this folder is empty". Saying a
      // folder is empty before it has been read is the app telling a story it
      // does not know the end of.
      if (controller.loadingMessages) {
        return <Widget>[const MessageListSkeleton()];
      }
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Centred(
            icon: controller.filter == MessageFilter.all
                ? AceIcons.mailOpen
                : AceIcons.filterOff,
            iconColor: c.iconDisabled,
            message: _emptyMessage(controller),
          ),
        ),
      ];
    }

    final Preferences prefs = context.watch<Preferences>();

    // Headings and rows in one list, so the sliver stays lazy. A String is a
    // heading; a summary is a row.
    final List<Object> items = <Object>[];
    if (prefs.groupByDate) {
      for (final MessageGroup group in groupByDate(rows)) {
        items.add(group.label);
        items.addAll(group.messages);
      }
    } else {
      items.addAll(rows);
    }

    // uid -> position, built once per build. The callback below is called for
    // every key in the list on every update, and it used to scan the whole list
    // each time — quadratic, on the very path that exists to make scrolling
    // cheap. A folder of a few hundred messages paid it on every rebuild.
    final Map<int, int> positionOfUid = <int, int>{};
    for (int i = 0; i < items.length; i++) {
      final Object item = items[i];
      if (item is MessageSummary) positionOfUid[item.uid] = i;
    }

    return <Widget>[
      // Mail from the device, not from the server. Said once, above the list: a
      // folder that opens onto yesterday's mail is useful, and one that pretends
      // yesterday's mail is today's is not.
      if (controller.showingSaved)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AstryxSpace.s4,
              AstryxSpace.s2,
              AstryxSpace.s4,
              0,
            ),
            child: Row(
              children: <Widget>[
                AceIconView(
                  icon: AceIcons.cloud,
                  size: 16,
                  color: c.textSecondary,
                ),
                const SizedBox(width: AstryxSpace.s2),
                Expanded(
                  child: Text(
                    'Offline — showing the mail this device already had. '
                    'Pull down to try again.',
                    style: AstryxText.supporting(c.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s3),
        sliver: SliverList.builder(
          itemCount: items.length,
          // The rows carry uid keys, so a rebuild can find the element for a
          // message it already built instead of building it again. Without
          // this, anything that shifts the list re-creates every row below it.
          findChildIndexCallback: (Key key) {
            if (key is! ValueKey<int>) return null;
            return positionOfUid[key.value];
          },
          // Each row already brings its own RepaintBoundary, so the sliver does
          // not need to add a second one — and a row that scrolls off does not
          // need keeping alive, because it has no state worth keeping.
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: false,
          itemBuilder: (BuildContext context, int index) {
            final Object item = items[index];
            if (item is String) return _GroupHeading(label: item);
            final MessageSummary summary = item as MessageSummary;
            return RepaintBoundary(
              // Each row paints on its own layer: scrolling a long list then
              // repaints the rows that move rather than the whole list.
              child: AceSwipeTile(
              key: ValueKey<int>(summary.uid),
              start: prefs.swipeStart,
              end: prefs.swipeEnd,
              startAppearance: swipeAppearance(
                prefs.swipeStart,
                c,
                isSeen: summary.isSeen,
                isFlagged: summary.isFlagged,
              ),
              endAppearance: swipeAppearance(
                prefs.swipeEnd,
                c,
                isSeen: summary.isSeen,
                isFlagged: summary.isFlagged,
              ),
              onAction: (SwipeAction action) =>
                  _applySwipe(context, summary, action),
              child: MessageTile(
                summary: summary,
                index: index,
                density: prefs.density,
                selected: controller.openSummary?.uid == summary.uid,
                picked: controller.isSelected(summary.uid),
                selecting: controller.selecting,
                // Long-press opens the actions, or picks while picking. A
                // press that always started picking assumed the rarer of the
                // two; the sheet offers picking as one of its rows.
                onLongPress: () {
                  final MailController mail = context.read<MailController>();
                  if (mail.selecting) {
                    mail.toggleSelect(summary.uid);
                  } else {
                    showMessageActionsSheet(context, summary);
                  }
                },
                onTap: () {
                  final MailController mail = context.read<MailController>();
                  // While picking, a tap picks; it does not open a message the
                  // reader did not ask for.
                  if (mail.selecting) {
                    mail.toggleSelect(summary.uid);
                  } else {
                    mail.open(summary);
                  }
                },
              ),
              ),
            );
          },
        ),
      ),
      if (controller.hasMore)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AstryxSpace.s6),
            child: Center(
              child: controller.loadingMore
                  ? const AceLoader(size: 34)
                  : AceButton(
                      label: 'Load older messages',
                      icon: AceIcons.expandMore,
                      variant: AceButtonVariant.tonal,
                      onPressed: () =>
                          context.read<MailController>().loadMore(),
                    ),
            ),
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: AstryxSpace.s10)),
    ];
  }

  String _emptyMessage(MailController controller) {
    if (controller.searchQuery != null) {
      // The operators are worth naming exactly where somebody has just found
      // nothing: a search that returns an empty page is the moment you wonder
      // whether you could have been more specific.
      return 'Nothing matched “${controller.searchQuery}”. Try an operator — '
          '${SearchQuery.operatorHints.join(', ')}';
    }
    if (controller.filter != MessageFilter.all) {
      return switch (controller.filter) {
        MessageFilter.unread => 'Everything here has been read.',
        MessageFilter.flagged => 'Nothing here is flagged.',
        MessageFilter.codes => 'No codes in this page.',
        // A period is a window, so an empty one is a window with nothing in
        // it — not a folder that is empty, which is a different sentence.
        MessageFilter.today => 'Nothing from today.',
        MessageFilter.week => 'Nothing from this week.',
        MessageFilter.month => 'Nothing from this month.',
        MessageFilter.all => 'This folder is empty.',
      };
    }
    return 'This folder is empty.';
  }

  Future<void> _applySwipe(
    BuildContext context,
    MessageSummary summary,
    SwipeAction action,
  ) async {
    final MailController controller = context.read<MailController>();
    final Preferences prefs = context.read<Preferences>();
    final Duration window = prefs.undoWindow.duration;

    // Where it was, so an undo can put it back there rather than in the inbox.
    final String? from = controller.currentFolderPath;

    switch (action) {
      case SwipeAction.archive:
        // Archiving is reversible, so it gets an undo on the bar rather than a
        // question — unless the user has asked for the question as well.
        if (prefs.confirmArchive) {
          final bool go = await confirmArchive(context);
          // The dialog is an await, so the row may be gone by the time it
          // answers; nothing after this may touch the context unguarded.
          if (!go || !context.mounted) return;
        }
        unawaited(controller.archive(summary));
        if (from != null) {
          AceSnack.undo(
            context,
            'Archived.',
            duration: window,
            onUndo: () => controller.undoDelete(summary, from),
          );
        } else {
          AceSnack.show(context, 'Archived.');
        }
      case SwipeAction.trash:
        // The mistake is one flick away, so the way back is on the bar.
        unawaited(controller.delete(summary));
        if (from != null) {
          AceSnack.undo(
            context,
            'Moved to trash.',
            duration: window,
            onUndo: () => controller.undoDelete(summary, from),
          );
        } else {
          AceSnack.show(context, 'Moved to trash.');
        }
      case SwipeAction.toggleRead:
        final bool wasSeen = summary.isSeen;
        unawaited(controller.toggleRead(summary));
        AceSnack.undo(
          context,
          wasSeen ? 'Marked unread.' : 'Marked read.',
          duration: window,
          onUndo: () => controller.toggleRead(summary),
        );
      case SwipeAction.flag:
        unawaited(controller.toggleFlag(summary));
        AceSnack.show(context, summary.isFlagged ? 'Star removed.' : 'Starred.');
      case SwipeAction.none:
        break;
    }
  }

}

/// Filter chips, then the sort. One scrollable row, so it never wraps into a
/// block of controls that pushes the mail off the screen.
/// Sort and filter, in one sheet.
///
/// The chips used to sit above the list, always on screen, spending a row of
/// the list's height on a choice most people make once. They are behind a
/// button now — and the button says when something other than the default is in
/// force, which the chips did not.
Future<void> showSortSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    sheetAnimationStyle: kAceSheetMotion,
    builder: (BuildContext sheetContext) {
      final AstryxColors c = sheetContext.astryx;
      final MailController controller = sheetContext.watch<MailController>();
      final Preferences prefs = sheetContext.watch<Preferences>();

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AstryxSpace.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AstryxSpace.s5,
                  0,
                  AstryxSpace.s5,
                  AstryxSpace.s4,
                ),
                child: Text(
                  'Sort & filter',
                  style: AstryxText.heading3(c.textPrimary),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s5),
                child: Text('Show', style: AstryxText.label(c.textSecondary)),
              ),
              const SizedBox(height: AstryxSpace.s2),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s5),
                child: Row(
                  children: <Widget>[
                    for (final MessageFilter filter
                        in MessageFilter.values) ...<Widget>[
                      AceChip(
                        label: filter.label,
                        selected: controller.filter == filter,
                        onTap: () => sheetContext
                            .read<MailController>()
                            .setFilter(filter),
                      ),
                      const SizedBox(width: AstryxSpace.s2),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AstryxSpace.s4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s5),
                child: Text('Order', style: AstryxText.label(c.textSecondary)),
              ),
              const SizedBox(height: AstryxSpace.s1),
              for (final MessageSort sort in MessageSort.values)
                SettingsRow(
                  // Each order has its own icon; they were drawn for this and
                  // were sitting unused.
                  icon: switch (sort) {
                    MessageSort.newest => AceIcons.sortNewest,
                    MessageSort.oldest => AceIcons.sortOldest,
                    MessageSort.sender => AceIcons.sortSender,
                    MessageSort.subject => AceIcons.sortSubject,
                    MessageSort.unread => AceIcons.sortUnread,
                    MessageSort.attachments => AceIcons.attachment,
                  },
                  title: sort.label,
                  trailing: prefs.messageSort == sort
                      ? AceIconView(
                          icon: AceIcons.check,
                          size: 20,
                          color: c.accent,
                        )
                      : null,
                  onTap: () =>
                      sheetContext.read<Preferences>().setMessageSort(sort),
                ),
              const SizedBox(height: AstryxSpace.s4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s5),
                child: Text(
                  'Then by',
                  style: AstryxText.label(c.textSecondary),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AstryxSpace.s5,
                  AstryxSpace.s1,
                  AstryxSpace.s5,
                  AstryxSpace.s2,
                ),
                child: Text(
                  // Said plainly, because it is the whole difference between
                  // this and the list above: one order decides, the other
                  // settles the arguments.
                  'Decides the ties: "by sender, then newest first".',
                  style: AstryxText.supporting(c.textSecondary),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s5),
                child: Row(
                  children: <Widget>[
                    AceChip(
                      label: 'Nothing',
                      selected: prefs.sortTie == null,
                      onTap: () =>
                          sheetContext.read<Preferences>().setSortTie(null),
                    ),
                    for (final MessageSort sort in MessageSort.values) ...<Widget>[
                      const SizedBox(width: AstryxSpace.s2),
                      AceChip(
                        label: sort.label,
                        selected: prefs.sortTie == sort,
                        // Choosing the order already in force as the tie-break
                        // would be a no-op dressed as a choice.
                        onTap: sort == prefs.messageSort
                            ? null
                            : () => sheetContext
                                .read<Preferences>()
                                .setSortTie(sort),
                      ),
                    ],
                  ],
                ),
              ),
              if (controller.filter != MessageFilter.all ||
                  prefs.messageSort != MessageSort.newest ||
                  prefs.sortTie != null)
                SettingsRow(
                  icon: AceIcons.filterOff,
                  title: 'Back to the default',
                  subtitle: 'Newest first, everything shown, no tie-break.',
                  onTap: () {
                    sheetContext
                        .read<MailController>()
                        .setFilter(MessageFilter.all);
                    sheetContext
                        .read<Preferences>()
                        .setMessageSort(MessageSort.newest);
                    sheetContext.read<Preferences>().setSortTie(null);
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _Centred extends StatelessWidget {
  const _Centred({
    required this.icon,
    required this.iconColor,
    required this.message,
    this.action,
  });

  final AceIcon icon;
  final Color iconColor;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    return Padding(
      padding: const EdgeInsets.all(AstryxSpace.s6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          AceIconView(icon: icon, size: 32, color: iconColor),
          const SizedBox(height: AstryxSpace.s3),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AstryxText.body(c.textSecondary),
          ),
          if (action != null) ...<Widget>[
            const SizedBox(height: AstryxSpace.s5),
            action!,
          ],
        ],
      ),
    );
  }
}

/// One message row. Springs on press, morphs its corners, states unread with
/// weight and a dot rather than a colour change alone, and lifts a one-time
/// code to where it can be read and copied without opening the message.
class MessageTile extends StatelessWidget {
  const MessageTile({
    super.key,
    required this.summary,
    required this.index,
    required this.density,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.picked = false,
    this.selecting = false,
  });

  final MessageSummary summary;
  final int index;

  /// Passed in rather than read here: a row that watches the preferences is a
  /// dependency per row, and every settings change then rebuilds the whole list
  /// once per row instead of once.
  final ListDensity density;
  final bool selected;
  final VoidCallback onTap;

  /// Long-press picks a message out; a second one starts a selection.
  final VoidCallback? onLongPress;

  /// Whether this row is one of the picked ones.
  final bool picked;

  /// Whether the list is in selection mode at all.
  final bool selecting;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final ListDensity density = this.density;
    final bool unread = !summary.isSeen;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      // The rows arrive in a short cascade, later rows a beat behind the first.
      // Zeroed under reduce motion, where the rows simply appear.
      duration: AstryxMotion.of(
        Duration(milliseconds: 260 + (index.clamp(0, 8) * 28)),
      ),
      curve: AstryxMotion.emphasizedDecelerate,
      builder: (BuildContext context, double t, Widget? child) => Opacity(
        opacity: t,
        child:
            Transform.translate(offset: Offset(0, (1 - t) * 10), child: child),
      ),
      child: AceSpringy(
        onTap: onTap,
        onLongPress: onLongPress,
        builder: (BuildContext context, double press, bool hover) {
          final double t = press.clamp(0.0, 1.0);
          final BorderRadius shape = BorderRadius.circular(
            lerpDouble(AstryxRadius.lg, AstryxRadius.inner, t)!,
          );

          return Transform.scale(
            scale: 1 - 0.02 * press,
            child: Container(
              // A card needs air around it to read as one: at half a unit the
              // cards touched and the list looked like rows again.
              margin: const EdgeInsets.only(bottom: AstryxSpace.s1_5),
              decoration: BoxDecoration(
                // A card, and visibly one.
                //
                // The fill alone was not enough: `backgroundCard` and the page
                // behind it are a single step apart on Material's tonal ramp,
                // which in a warm light theme is no step at all — the rows read
                // as text on a page. So the card is the *raised* surface, with a
                // hairline edge to give it a boundary, and the gap between cards
                // does the rest. One line per card, not a box to look at.
                color: picked || selected
                    ? c.accentMuted
                    : (hover ? c.surfaceHighest : c.backgroundSurface),
                borderRadius: shape,
                border: Border.all(
                  color: picked || selected ? c.accentMuted : c.border,
                  width: 1,
                ),
              ),
              // No clip and no stack any more: they existed to make the unread
              // strip follow the card's corner, and the strip is gone.
              child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        AstryxSpace.s3,
                        density.verticalPadding,
                        AstryxSpace.s3,
                        density.verticalPadding,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // In selection mode the picture becomes the tick, so
                          // the gesture that started it is visible where it
                          // happened.
                          if (selecting)
                            Padding(
                              padding:
                                  const EdgeInsets.only(right: AstryxSpace.s2),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 160),
                                child: picked
                                    ? HugeIcon(
                                        key: const ValueKey<String>('on'),
                                        icon: AceIcons.checkCircle,
                                        size: density.avatarSize,
                                        color: c.accent,
                                      )
                                    : SizedBox(
                                        key: const ValueKey<String>('off'),
                                        width: density.avatarSize,
                                        height: density.avatarSize,
                                        child: Center(
                                          child: Container(
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: c.border,
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                            )
                          else
                            MailAvatar(
                              email: summary.fromEmail,
                              name: summary.fromName,
                              size: density.avatarSize,
                            ),
                          const SizedBox(width: AstryxSpace.s3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                // Who and when, on one line: the two things a
                                // list is scanned for. The star sits with the
                                // date rather than in front of the subject, so
                                // the subject keeps the whole width it needs.
                                Row(
                                  children: <Widget>[
                                    // Unread, as a dot. The accent ink on the
                                    // name says it too, but a dot is what the
                                    // eye catches while scrolling — and it
                                    // survives the name being long enough to
                                    // ellipsis, which the tint does not.
                                    if (unread)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: AstryxSpace.s1_5,
                                        ),
                                        child: Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: c.accent,
                                          ),
                                        ),
                                      ),
                                    // The sender is the *context*, not the
                                    // point. It was the bold line, which made a
                                    // list of names to be read before you could
                                    // see what any of them said.
                                    Expanded(
                                      child: Text(
                                        summary.fromName,
                                        overflow: TextOverflow.ellipsis,
                                        // Unread is said in the ink, not with
                                        // a bar down the edge: the name is the
                                        // first thing scanned, and a tint on it
                                        // costs the layout nothing.
                                        style: AstryxText.supporting(
                                          unread
                                              ? c.textAccent
                                              : c.textSecondary,
                                        ),
                                      ),
                                    ),
                                    // Something is attached. The flag is
                                    // already on the summary and was never
                                    // shown, which meant the only way to know a
                                    // message carried a file was to open it.
                                    if (summary.hasAttachments) ...<Widget>[
                                      const SizedBox(width: AstryxSpace.s1_5),
                                      AceIconView(
                                        icon: AceIcons.attachment,
                                        size: 14,
                                        color: c.iconSecondary,
                                      ),
                                    ],
                                    if (summary.isFlagged) ...<Widget>[
                                      const SizedBox(width: AstryxSpace.s1_5),
                                      // A one-shot pop as the row is built with
                                      // a star on it — which is the moment a
                                      // message was just flagged, or a folder
                                      // of flagged mail opened.
                                      TweenAnimationBuilder<double>(
                                        tween: Tween<double>(begin: 0.4, end: 1),
                                        duration: AstryxMotion.of(
                                          const Duration(milliseconds: 220),
                                        ),
                                        curve: AstryxMotion.emphasizedDecelerate,
                                        builder: (
                                          BuildContext context,
                                          double t,
                                          Widget? child,
                                        ) =>
                                            Transform.scale(
                                          scale: t,
                                          child: child,
                                        ),
                                        child: AceIconView(
                                          icon: AceIcons.star,
                                          size: 14,
                                          color: c.tertiary,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(width: AstryxSpace.s2),
                                    Text(
                                      formatListDate(summary.date),
                                      style: AstryxText.supporting(
                                        c.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AstryxSpace.s0_5),
                                Text(
                                  // Two lines, not one. There is no snippet to
                                  // scan — the summaries are header-only on
                                  // purpose — so the subject is the only thing
                                  // saying what the message is about, and one
                                  // line cut "[acestheticsx/surf] Run failed:
                                  // Build Surf A…" before it said anything.
                                  summary.subject,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  // The point of the row, and drawn like it.
                                  // Unread keeps the ink; read steps back a
                                  // shade rather than going grey.
                                  style: unread
                                      ? AstryxText.bodyStrong(c.textPrimary)
                                      : AstryxText.body(c.textSecondary),
                                ),
                                if (summary.otp != null) ...<Widget>[
                                  const SizedBox(height: AstryxSpace.s1_5),
                                  _OtpChip(code: summary.otp!),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A one-time code, one tap from the clipboard. Shown in the list so the code
/// can be used without opening the mail, which is the entire point of it.
class _OtpChip extends StatelessWidget {
  const _OtpChip({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return AceSpringy(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: code));
        if (!context.mounted) return;
        AceSnack.show(context, 'Code $code copied');
      },
      semanticLabel: 'Copy code $code',
      builder: (BuildContext context, double press, bool hover) {
        final double t = press.clamp(0.0, 1.0);
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AstryxSpace.s3,
            vertical: AstryxSpace.s1,
          ),
          decoration: BoxDecoration(
            color: c.accentMuted,
            borderRadius: BorderRadius.circular(
              lerpDouble(AstryxRadius.full, AstryxRadius.element, t)!,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AceIconView(icon: 
                AceIcons.password,
                size: 14,
                color: c.onAccentMuted,
              ),
              const SizedBox(width: AstryxSpace.s2),
              Text(
                code,
                style: AstryxText.bodyStrong(c.onAccentMuted).copyWith(
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(width: AstryxSpace.s2),
              AceIconView(icon: 
                AceIcons.copy,
                size: 13,
                color: c.onAccentMuted,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A small heading over a run of messages, the way the settings screen heads a
/// section.
class _GroupHeading extends StatelessWidget {
  const _GroupHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AstryxSpace.s3,
        AstryxSpace.s5,
        AstryxSpace.s3,
        AstryxSpace.s2,
      ),
      child: Text(
        label.toUpperCase(),
        style: AstryxText.label(c.textSecondary).copyWith(letterSpacing: 1.1),
      ),
    );
  }
}

/// The line above the list: where you are, and what is in it.
///
/// It is the first thing on the screen and it is not mail, so it has one job —
/// to say the app knows where it is — and it does it in two lines. It arrives
/// rather than appearing, because a heading that pops in under a list that is
/// still fading reads as a repaint.
class _Greeting extends StatelessWidget {
  const _Greeting({required this.controller});

  final MailController controller;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final String folder = controller.selectedFolder?.label ?? 'Mail';
    final String? query = controller.searchQuery;
    // Under the greeting there is a line only while a search is up, because a
    // search needs saying: how much of the folder matched. Otherwise the hero is
    // the greeting and nothing else — the folder's name was the line that read
    // "Mail" before the first folder had loaded, and a heading that says "Mail"
    // above a list of mail is a heading that says nothing.
    final String? summary = query == null
        ? null
        : searchSummary(folder, controller.visibleMessages.length, query);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: AstryxMotion.of(const Duration(milliseconds: 420)),
      curve: AstryxMotion.emphasizedDecelerate,
      builder: (BuildContext context, double t, Widget? child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AstryxSpace.s4,
          AstryxSpace.s2,
          AstryxSpace.s4,
          AstryxSpace.s4,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    greetingFor(DateTime.now(), name: controller.displayName),
                    // A heading, not a poster. At display size a normal name
                    // wraps to three lines on a phone, and three lines of
                    // greeting is the whole screen before any mail.
                    style: AstryxText.heading2(c.textPrimary),
                  ),
                  if (summary != null) ...<Widget>[
                    const SizedBox(height: AstryxSpace.s0_5),
                    Text(
                      summary,
                      style: AstryxText.body(c.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            // Sorting lives here now, not in the app bar: it is a choice about
            // The sort control lives in the search bar now, beside the
            // microphone. It is the same kind of thing — a control for the list
            // you are looking at — and it was sitting in the greeting, where it
            // read as part of the sentence above the mail.
          ],
        ),
      ),
    );
  }
}

/// Asks Google for consent again, then reconnects.
///
/// Signing in is only half of it: the mailbox is still disconnected, and the
/// person asked to read their mail, not to see a permission screen. So the
/// connection is retried as soon as the token exists.
Future<void> _signInWithGoogle(BuildContext context) async {
  final MailController controller = context.read<MailController>();
  try {
    await GoogleAuth.signIn();
  } on GoogleAuthException catch (error) {
    if (context.mounted) AceSnack.show(context, error.message);
    return;
  }
  if (!context.mounted) return;
  await controller.reconnect();
}

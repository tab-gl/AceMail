import 'dart:async';

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import '../data/accents.dart';
import '../data/app_info.dart';
import '../data/local_store.dart';
import '../data/preferences.dart';
import '../models/glass_mode.dart';
import '../services/app_lock.dart';
import '../services/chyme.dart';
import '../services/launcher_icon.dart';
import '../services/local_avatars.dart';
import '../services/platform_caps.dart';
import '../widgets/avatar.dart';
import '../widgets/appearance_sheet.dart';
import '../state/mail_controller.dart';
import '../services/notification_setup.dart';
import '../services/notifications.dart';
import '../models/swipe_action.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/ace_snack.dart';
import '../widgets/about_dialog.dart';
import 'changelog_screen.dart';
import '../widgets/ace_glass.dart';
import '../models/chyme_template.dart';
import '../widgets/diagnostics_sheet.dart';
import '../widgets/glass_studio.dart';
import '../widgets/update_sheet.dart';
import '../widgets/chyme_mark.dart';
import '../widgets/chyme_pickers.dart';
import '../widgets/legal_sheet.dart';
import '../widgets/account_sheet.dart';
import '../widgets/astryx_widgets.dart';
import '../widgets/settings_group.dart';

import '../widgets/ace_icon_view.dart';
import '../widgets/ace_slider.dart';

/// A part of the settings screen that something else can open it at.
///
/// Chyme's own sheet has a settings button, and a button called "Chyme
/// settings" that lands at the top of Settings makes the person scroll past
/// fourteen unrelated rows to reach the five they asked for. The name is a
/// promise; this is what keeps it.
enum SettingsFocus { chyme }

/// The app's settings. Every row here changes something real.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.focus});

  /// The card to open at, when the caller is opening this screen *for* it.
  final SettingsFocus? focus;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Anchors the Chyme card, so the screen can be scrolled to it.
  final GlobalKey _chymeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.focus == null) return;
    // After the first frame: the card does not exist until it has been built,
    // and a context that is not in the tree yet cannot be scrolled to.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final BuildContext? target = _chymeKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: AstryxMotion.of(const Duration(milliseconds: 420)),
        curve: AstryxMotion.emphasized,
        alignment: 0.02,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final Preferences prefs = context.watch<Preferences>();

    return Scaffold(
      backgroundColor: c.backgroundBody,
      appBar: AppBar(
        title: Text('Settings', style: AstryxText.heading3(c.textPrimary)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: AstryxSpace.s8),
          children: <Widget>[
            _section(
              prefs,
              'Account',
              children: <Widget>[
                SettingsRow(
                  icon: AceIcons.at,
                  title: 'Manage accounts',
                  subtitle: 'Add, switch or remove accounts',
                  onTap: () => showAccountSheet(context),
                ),
                SettingsRow(
                  icon: AceIcons.image,
                  // The picture itself, not an icon standing in for it. A row
                  // called "Your picture" that shows a generic glyph is a row
                  // that answers its own question wrong — and the whole point of
                  // the row is to see whether the picture you set is the one
                  // that came back.
                  leading: MailAvatar(
                    email: context.watch<MailController>().account?.email ?? '',
                    name: context.watch<MailController>().account?.email ?? '',
                    size: 34,
                    isSelf: true,
                  ),
                  title: 'Your picture',
                  // Named for where it comes from, because that is the question
                  // this row exists to answer: the app cannot set it at your
                  // provider, so it has to say where it *can* be set.
                  subtitle: 'No mail provider lets an app change your picture. '
                      'Gravatar is the one that shows everywhere — pick one '
                      'here and it is yours on this device only.',
                  value: LocalAvatars.has(
                    context.watch<MailController>().account?.email ?? '',
                  )
                      ? 'Changed here'
                      : 'From Gravatar',
                  onTap: () => _choosePicture(
                    context,
                    context.read<MailController>().account?.email ?? '',
                  ),
                ),
                SettingsSwitchRow(
                  icon: AceIcons.reconnect,
                  title: 'Reconnect automatically',
                  subtitle: 'Retry once, after a backoff, when the connection '
                      'drops rather than the command failing.',
                  value: prefs.autoReconnect,
                  onChanged: prefs.setAutoReconnect,
                ),
                SettingsSwitchRow(
                  icon: AceIcons.account,
                  title: 'Sender pictures',
                  subtitle: 'Sends a hash of every sender\'s address to '
                      'gravatar.com to find a picture. A hash of an address is '
                      'not anonymous, so this is a disclosure — off means no '
                      'request is ever made.',
                  value: prefs.showAvatars,
                  onChanged: prefs.setShowAvatars,
                ),
              ],
            ),
            _section(
              prefs,
              'Reading',
              children: <Widget>[
                SettingsSwitchRow(
                  icon: AceIcons.mailOpen,
                  title: 'Mark as read when opened',
                  subtitle: prefs.markAsReadOnOpen
                      ? 'Opening a message sets it read on the server.'
                      : 'Messages keep their unread state until you say so.',
                  value: prefs.markAsReadOnOpen,
                  onChanged: prefs.setMarkAsReadOnOpen,
                ),
                SettingsRow(
                  icon: AceIcons.folder,
                  title: 'Messages per page',
                  subtitle: 'How many load before "Load older messages".',
                  value: prefs.pageSize.label,
                  onTap: () => _choosePageSize(context, prefs),
                ),
                SettingsSwitchRow(
                  icon: AceIcons.headers,
                  title: 'Show raw headers',
                  subtitle: 'Show the message headers as the server sent them, '
                      'at the foot of the message.',
                  value: prefs.showRawHeaders,
                  onChanged: prefs.setShowRawHeaders,
                ),
                SettingsSwitchRow(
                  icon: AceIcons.check,
                  title: 'Vibration',
                  subtitle: 'A tick when a swipe arms, a knock when something '
                      'is about to be thrown away.',
                  value: prefs.haptics,
                  onChanged: prefs.setHaptics,
                ),
                SettingsSwitchRow(
                  icon: AceIcons.openInNew,
                  title: 'Ask before opening links',
                  subtitle: 'A link\u2019s text is the sender\u2019s, and need '
                      'not be what the link does. This shows the address first.',
                  value: prefs.warnExternalLinks,
                  onChanged: prefs.setWarnExternalLinks,
                ),
                SettingsSwitchRow(
                  icon: AceIcons.warning,
                  title: 'Warn on an empty subject',
                  subtitle: 'Ask before sending a message with no subject.',
                  value: prefs.warnEmptySubject,
                  onChanged: prefs.setWarnEmptySubject,
                ),
                SettingsSwitchRow(
                  icon: AceIcons.password,
                  title: 'Show one-time codes',
                  subtitle: 'Pick codes out of messages and show them in the '
                      'list, so they can be used without opening the mail.',
                  value: prefs.detectCodes,
                  onChanged: prefs.setDetectCodes,
                ),
                SettingsSwitchRow(
                  icon: AceIcons.trash,
                  title: 'Ask before deleting',
                  subtitle: 'A permanent delete always asks, whatever this is '
                      'set to.',
                  value: prefs.confirmDelete,
                  onChanged: prefs.setConfirmDelete,
                  // A permanent delete always asks. The switch is shown so the rule is
                  // visible, and locked because turning it off would mean offering to
                  // destroy mail without a question.
                  locked: true,
                ),
                SettingsRow(
                  icon: AceIcons.signature,
                  title: 'Signature',
                  subtitle: prefs.signature.isEmpty
                      ? 'Not set'
                      : 'Added to new messages',
                  value: prefs.signature.isEmpty ? 'None' : 'Set',
                  onTap: () => _editSignature(context, prefs),
                ),
              ],
            ),
            _section(
              prefs,
              'Notifications',
              children: <Widget>[
                SettingsSwitchRow(
                  icon: AceIcons.mailUnread,
                  title: 'Notify me about new mail',
                  subtitle: 'Checked in the background about every fifteen '
                      'minutes. On iPhone the system decides the exact time, '
                      'so a check can come later. Nothing is sent anywhere: '
                      'the check talks to your provider and tells you.',
                  value: prefs.notifyNewMail,
                  onChanged: (bool value) async {
                    // Asked here, because here is where somebody said they
                    // wanted notifications.
                    final bool scheduled = await NotificationSetup.apply(
                      enabled: value,
                      askPermission: value,
                    );
                    await prefs.setNotifyNewMail(scheduled);
                    if (scheduled && !await AceNotifications.hasPermission()) {
                      // Scheduled, but the platform will not show it. Saying so
                      // is the difference between "the app is broken" and
                      // "notifications are off in the system settings".
                      if (context.mounted) {
                        AceSnack.show(
                          context,
                          'Notifications are blocked for Ace Mail in the '
                          'system settings.',
                        );
                      }
                    }
                  },
                ),

                SettingsSwitchRow(
                  icon: AceIcons.schedule,
                  title: 'Quiet overnight',
                  subtitle: 'No notifications between 22:00 and 07:00. Mail '
                      'still arrives and is still counted — only the phone '
                      'stays quiet.',
                  value: prefs.quietHours,
                  onChanged: (bool value) async {
                    await prefs.setQuietHours(value);
                    // Re-registered, not re-asked: quiet hours have nothing to
                    // do with permission, and this switch used to prompt for it.
                    await NotificationSetup.apply(
                      enabled: prefs.notifyNewMail,
                    );
                  },
                ),
                SettingsSwitchRow(
                  icon: AceIcons.visibilityOff,
                  title: 'Private notification previews',
                  subtitle: 'A notification says that mail has arrived, not who '
                      'sent it or what it says. A lock screen is read by '
                      'whoever is in the room.',
                  value: prefs.privatePreviews,
                  onChanged: prefs.setPrivatePreviews,
                ),
              ],
            ),
            _section(
              prefs,
              'Writing',
              children: <Widget>[
                SettingsSwitchRow(
                  icon: AceIcons.at,
                  title: 'Blind-copy yourself',
                  subtitle: 'Send every message with a hidden copy to the '
                      'account it goes from, so a sent message reaches your own '
                      'inbox and not only the Sent folder.',
                  value: prefs.bccSelf,
                  onChanged: prefs.setBccSelf,
                ),
                SettingsSwitchRow(
                  icon: AceIcons.reply,
                  title: 'Quote the original in replies',
                  subtitle: prefs.quoteReplies
                      ? 'A reply carries the message it answers beneath it.'
                      : 'A reply starts empty, with no quoted original.',
                  value: prefs.quoteReplies,
                  onChanged: prefs.setQuoteReplies,
                ),
                SettingsSwitchRow(
                  icon: AceIcons.signature,
                  title: 'Signature on replies',
                  subtitle: 'New messages always carry the signature; this '
                      'adds it to replies too, above the quoted text.',
                  value: prefs.signatureOnReplies,
                  onChanged: prefs.setSignatureOnReplies,
                ),
              ],
            ),
            _section(
              prefs,
              'Gestures',
              children: <Widget>[
                SettingsRow(
                  icon: AceIcons.swipeRight,
                  title: 'Swipe right',
                  subtitle: 'Across a message in the list',
                  value: prefs.swipeStart.label,
                  onTap: () => _chooseSwipe(context, prefs, start: true),
                ),
                SettingsRow(
                  icon: AceIcons.swipeLeft,
                  title: 'Swipe left',
                  subtitle: 'Across a message in the list',
                  value: prefs.swipeEnd.label,
                  onTap: () => _chooseSwipe(context, prefs, start: false),
                ),
                SettingsSwitchRow(
                  icon: AceIcons.archive,
                  title: 'Ask before archiving',
                  subtitle: 'A confirmation before a message leaves the inbox '
                      'for Archive.',
                  value: prefs.confirmArchive,
                  onChanged: prefs.setConfirmArchive,
                ),
                SettingsSwitchRow(
                  icon: AceIcons.attachment,
                  title: 'Warn when an attachment is promised',
                  subtitle: 'Asks before sending a message that says it has '
                      'something attached, when nothing is.',
                  value: prefs.warnMissingAttachment,
                  onChanged: prefs.setWarnMissingAttachment,
                ),
                SettingsRow(
                  icon: AceIcons.restore,
                  title: 'Undo window',
                  subtitle: 'How long an undo stays on the bar after a swipe.',
                  value: prefs.undoWindow.label,
                  onTap: () => _chooseUndoWindow(context, prefs),
                ),
              ],
            ),
            _section(
              prefs,
              'Appearance',
              children: <Widget>[
                SettingsSwitchRow(
                  icon: AceIcons.list,
                  title: 'Group by date',
                  subtitle: 'Headings for Today, Yesterday and so on. Off is '
                      'one undivided run of messages.',
                  value: prefs.groupByDate,
                  onChanged: prefs.setGroupByDate,
                ),
                SettingsSwitchRow(
                  icon: AceIcons.folder,
                  title: 'Unread counts on folders',
                  subtitle: 'How much is waiting, on the folder itself.',
                  value: prefs.showFolderCounts,
                  onChanged: prefs.setShowFolderCounts,
                ),
                SettingsSwitchRow(
                  icon: AceIcons.package,
                  title: 'Highlights',
                  subtitle: 'Cards above the inbox for codes, deliveries, bills '
                      'and security notices. Each one opens the message it '
                      'came from.',
                  value: prefs.highlights,
                  onChanged: prefs.setHighlights,
                ),
                SettingsSwitchRow(
                  icon: AceIcons.brightness,
                  title: 'True black (OLED)',
                  subtitle: 'The dark theme goes to #000000. A pixel that is off '
                      'draws no power, and on an OLED panel the difference is '
                      'visible at the edges.',
                  value: prefs.oled,
                  onChanged: prefs.setOled,
                ),
                SettingsRow(
                  icon: AceIcons.brightness,
                  title: 'Theme',
                  value: prefs.themeMode.label,
                  onTap: () async {
                    // OLED is a property of the dark theme, so it belongs in
                    // the sheet where the dark theme is chosen rather than on
                    // the list beside it.
                    final AceThemeMode? chosen =
                        await showChoiceSheet<AceThemeMode>(
                      context,
                      title: 'Theme',
                      current: prefs.themeMode,
                      choices: <SettingsChoice<AceThemeMode>>[
                        for (final AceThemeMode mode in AceThemeMode.values)
                          SettingsChoice<AceThemeMode>(mode, mode.label),
                      ],
                    );
                    if (chosen != null) await prefs.setThemeMode(chosen);
                  },
                ),
                SettingsSwitchRow(
                  icon: AceIcons.brightness,
                  title: 'Use my system colours',
                  subtitle: 'Take the accent from the device — Android\u2019s '
                      'wallpaper colours, and the equivalent elsewhere. The '
                      'whole theme follows, surfaces included.',
                  value: prefs.useDynamicColour,
                  onChanged: prefs.setUseDynamicColour,
                ),
                SettingsRow(
                  icon: AceIcons.palette,
                  title: 'Accent',
                  value: prefs.accent.label,
                  trailing: _AccentSwatch(accent: prefs.accent),
                  onTap: () => _chooseAccent(context, prefs),
                ),
                SettingsRow(
                  icon: AceIcons.palette,
                  title: 'Custom colour & font',
                  value: prefs.customAccent == null && prefs.customFontPath == null
                      ? 'Default'
                      : 'Custom',
                  onTap: () => showAppearanceSheet(context, prefs),
                ),
                // Android's launcher, Android's icon. On the desktop build
                // this row would be a setting for something that does not
                // exist.
                if (PlatformCaps.isAndroid)
                  SettingsRow(
                    icon: AceIcons.image,
                    title: 'Launcher icon',
                  subtitle: 'Which mark it wears. The background is the accent, '
                      'and follows it.',
                  value: prefs.launcherMark.label,
                  trailing: _MarkPreview(mark: prefs.launcherMark, accent: prefs.accent),
                  onTap: () async {
                    final LauncherMark? mark = await showChoiceSheet<LauncherMark>(
                      context,
                      title: 'Launcher icon',
                      current: prefs.launcherMark,
                      choices: <SettingsChoice<LauncherMark>>[
                        for (final LauncherMark m in LauncherMark.values)
                          SettingsChoice<LauncherMark>(
                            m,
                            m.label,
                            description: m.description,
                            leading: _MarkPreview(mark: m, accent: prefs.accent),
                          ),
                      ],
                    );
                    if (mark == null) return;
                    await prefs.setLauncherMark(mark);
                    // Applied straight away: an icon setting that needs a
                    // restart is a setting nobody believes took.
                    await LauncherIcon.apply(prefs.accent, mark: mark);
                  },
                ),
                if (AceGlass.capable)
                  SettingsRow(
                    icon: AceIcons.blur,
                    title: 'Glass studio',
                    subtitle: 'Blur, tint, and smoked instead of frosted — with '
                        'a preview of the real material.',
                    onTap: () => GlassStudio.show(context),
                  ),
                SettingsRow(
                  icon: AceIcons.blur,
                  title: 'See-through surfaces',
                  subtitle: AceGlass.limitation,
                  value: prefs.glass.label,
                  onTap: () async {
                    final GlassMode? chosen = await showChoiceSheet<GlassMode>(
                      context,
                      title: 'See-through surfaces',
                      current: prefs.glass,
                      choices: <SettingsChoice<GlassMode>>[
                        for (final GlassMode mode in GlassMode.values)
                          SettingsChoice<GlassMode>(
                            mode,
                            mode.label,
                            description: switch (mode) {
                              GlassMode.auto => AceGlass.capable
                                  ? 'Blur where the device can afford it'
                                  : 'This device cannot, so the surfaces stay flat',
                              GlassMode.always => 'Blur wherever possible',
                              GlassMode.never => 'Flat surfaces everywhere',
                            },
                          ),
                      ],
                    );
                    if (chosen != null) await prefs.setGlass(chosen);
                  },
                ),
                SettingsRow(
                  icon: AceIcons.density,
                  title: 'List density',
                  value: prefs.density.label,
                  onTap: () async {
                    final ListDensity? chosen =
                        await showChoiceSheet<ListDensity>(
                      context,
                      title: 'List density',
                      current: prefs.density,
                      choices: <SettingsChoice<ListDensity>>[
                        for (final ListDensity density in ListDensity.values)
                          SettingsChoice<ListDensity>(
                            density,
                            density.label,
                            description: density == ListDensity.compact
                                ? 'More messages on screen'
                                : null,
                          ),
                      ],
                    );
                    if (chosen != null) await prefs.setDensity(chosen);
                  },
                ),
                SettingsRow(
                  icon: AceIcons.textSize,
                  title: 'Text size',
                  value: prefs.textSize.label,
                  onTap: () => _chooseTextSize(context, prefs),
                ),
                SettingsSwitchRow(
                  icon: AceIcons.logout,
                  title: 'Ask before exiting',
                  subtitle: 'Show a confirmation before the app closes.',
                  value: prefs.confirmExit,
                  onChanged: prefs.setConfirmExit,
                ),
              ],
            ),
            _section(
              prefs,
              'Privacy',
              children: <Widget>[
                SettingsSwitchRow(
                  icon: AceIcons.shield,
                  title: 'Keep messages on this device',
                  subtitle: 'A message you have read, and the draft you are '
                      'writing, are kept encrypted — AES-256-GCM, with the key '
                      'in the keychain — so they open without the network. Off '
                      'means nothing is kept.',
                  value: prefs.cacheMessages,
                  onChanged: (bool value) => _setCaching(context, prefs, value),
                ),
                // A fingerprint or a face, which is the only way in this app
                // locks. Offered where there is one to offer.
                if (PlatformCaps.supportsBiometrics)
                  SettingsSwitchRow(
                    icon: AceIcons.lock,
                    title: 'Require unlock',
                  subtitle: prefs.appLock
                      ? 'A fingerprint or a face opens the app, and it locks '
                          'again whenever it is left.'
                      : 'Ask for a fingerprint or a face before the app opens. '
                          'Takes effect the next time the app is left or '
                          'started.',
                  value: prefs.appLock,
                  onChanged: (bool value) => _setAppLock(context, prefs, value),
                ),
                const _CacheRow(),
              ],
            ),
            _section(
              prefs,
              'Chyme',
              key: _chymeKey,
              children: <Widget>[
                SettingsSwitchRow(
                  icon: AceIcons.chyme,
                  // Drawn in the row's own icon colour. The artwork is white
                  // with transparency, so left untinted it is white on a light
                  // row — a mark that is not there.
                  leading: ChymeMark(size: 22, color: c.iconSecondary),
                  title: 'Chyme',
                  subtitle: 'An experimental assistant that reads the mail — '
                      'summarises a message, finds one, drafts a reply. Pick a '
                      'provider below and it is ready.',
                  value: prefs.chymeEnabled,
                  onChanged: prefs.setChymeEnabled,
                ),
                if (prefs.chymeEnabled) ...<Widget>[
                  SettingsRow(
                    icon: AceIcons.globe,
                    title: 'Provider',
                    subtitle: 'Fills in the endpoint for you. The model list '
                        'comes from whatever you point it at.',
                    value: ChymeTemplate.forEndpoint(prefs.chymeEndpoint).label,
                    onTap: () async {
                      final ChymeTemplate? chosen = await _pickProvider(
                        context,
                        prefs,
                      );
                      if (chosen == null) return;
                      if (chosen.needsTyping) {
                        // "Something else" clears it so the field is the next
                        // thing tapped, rather than leaving the last provider's
                        // URL in place to be edited by hand.
                        await prefs.setChymeEndpoint('');
                        await prefs.setChymeModel('');
                        return;
                      }
                      // A model id belongs to the provider that served it, so
                      // changing the provider has to drop it: keeping it would
                      // leave a name no endpoint here recognises.
                      if (ChymeTemplate.forEndpoint(prefs.chymeEndpoint) !=
                          chosen) {
                        await prefs.setChymeModel('');
                      }
                      await prefs.setChymeEndpoint(chosen.endpoint);
                    },
                  ),
                  SettingsRow(
                    icon: AceIcons.edit,
                    title: 'Instructions',
                    subtitle: 'What Chyme is told about itself and its rules. '
                        'Empty uses the app\'s own — which are what make it '
                        'refuse to invent a sender, a date or an address.',
                    value: prefs.chymePrompt.trim().isEmpty
                        ? 'The app\'s own'
                        : 'Edited',
                    onTap: () => _editChymeText(
                      context,
                      prefs,
                      title: 'Instructions',
                      hint: Chyme.systemPrompt,
                      current: prefs.chymePrompt,
                      save: prefs.setChymePrompt,
                      multiline: true,
                    ),
                  ),
                  SettingsRow(
                    icon: AceIcons.cloud,
                    title: 'Endpoint',
                    subtitle: 'The API base, like https://api.openai.com/v1. Any '
                        'endpoint that speaks the OpenAI chat API works — '
                        'including one on your own machine.',
                    value: prefs.chymeEndpoint.isEmpty
                        ? 'Not set'
                        : prefs.chymeEndpoint,
                    onTap: () => _editChymeText(
                      context,
                      prefs,
                      title: 'Endpoint',
                      hint: 'https://api.openai.com/v1',
                      current: prefs.chymeEndpoint,
                      save: prefs.setChymeEndpoint,
                    ),
                  ),
                  SettingsRow(
                    icon: AceIcons.password,
                    title: 'API key',
                    subtitle: _chymeKeyHint(
                      ChymeTemplate.forEndpoint(prefs.chymeEndpoint),
                    ),
                    value: prefs.chymeKey.isEmpty ? 'Not set' : '••••••',
                    onTap: () => _editChymeText(
                      context,
                      prefs,
                      title: 'API key',
                      hint: 'sk-…',
                      current: prefs.chymeKey,
                      obscure: true,
                      save: prefs.setChymeKey,
                    ),
                  ),
                  SettingsRow(
                    icon: AceIcons.chyme,
                    title: 'Tone',
                    subtitle: 'How it writes when you ask it to draft something.',
                    value: prefs.chymeTone.label,
                    onTap: () => chooseChymeTone(context, prefs),
                  ),
                  SettingsRow(
                    icon: AceIcons.chyme,
                    title: 'Model',
                    subtitle: 'What answers. The list is whatever the endpoint '
                        'offers.',
                    value: prefs.chymeModel.isEmpty ? 'None chosen' : prefs.chymeModel,
                    onTap: () => chooseChymeModel(context, prefs),
                  ),
                  SettingsSwitchRow(
                    icon: AceIcons.mail,
                    title: 'Let Chyme read your mail',
                    subtitle: 'What is on screen: the folder, the messages in '
                        'it, and the one you have open. Off means it answers '
                        'without looking at any mail.',
                    value: prefs.chymeReadsMail,
                    onChanged: prefs.setChymeReadsMail,
                  ),
                ],
              ],
            ),
            _section(
              prefs,
              'Accessibility',
              children: <Widget>[
                SettingsSwitchRow(
                  icon: AceIcons.visibility,
                  title: 'Reduce motion',
                  subtitle: 'Transitions stop moving rather than moving faster. '
                      'The loading indicator still turns, because a still one '
                      'looks like a hung app.',
                  value: prefs.reduceMotion,
                  onChanged: prefs.setReduceMotion,
                ),
              ],
            ),
            _section(
              prefs,
              'Support',
              children: <Widget>[
                SettingsRow(
                  icon: AceIcons.help,
                  title: 'Help & Feedback',
                  subtitle: 'hello@ace-base.cc',
                  // Opens the mail app rather than a form, because there is no
                  // form: a person with a problem is better served by an address
                  // that reaches somebody than by a screen that reaches nobody.
                  onTap: () => _mailSupport(context),
                ),
                SettingsSwitchRow(
                  icon: AceIcons.save,
                  title: 'Download updates in the background',
                  subtitle: 'Fetches a newer release as soon as it is found, so '
                      'the update is already on the device. Installing is still '
                      'a tap, and Android asks once whether Ace Mail may '
                      'install apps.',
                  value: prefs.autoUpdate,
                  onChanged: prefs.setAutoUpdate,
                ),
                SettingsSwitchRow(
                  icon: AceIcons.refresh,
                  title: 'Check for updates',
                  subtitle: 'Asks GitHub once a day for the newest release and '
                      'shows what changed. Nothing about you is sent — it is a '
                      'plain request for a public list.',
                  value: prefs.updateCheck,
                  onChanged: prefs.setUpdateCheck,
                ),
                if (prefs.updateCheck)
                  SettingsRow(
                    icon: AceIcons.info,
                    title: 'Check now',
                    subtitle: prefs.lastUpdateCheck == null
                        ? 'Not checked yet'
                        : 'Last checked ${_shortDate(prefs.lastUpdateCheck!)}',
                    onTap: () => checkForUpdatesNow(context),
                  ),
                SettingsRow(
                  icon: AceIcons.restore,
                  title: 'Changelog',
                  subtitle: 'Every version, and what it changed',
                  onTap: () => ChangelogScreen.show(context),
                ),
                SettingsRow(
                  icon: AceIcons.password,
                  title: 'Terms of use',
                  onTap: () =>
                      LegalSheet.show(context, startAt: LegalDocument.terms),
                ),
                SettingsRow(
                  icon: AceIcons.shield,
                  title: 'Privacy policy',
                  subtitle: 'What is kept on this device, and what leaves it',
                  onTap: () =>
                      LegalSheet.show(context, startAt: LegalDocument.privacy),
                ),
                SettingsRow(
                  icon: AceIcons.info,
                  title: 'Diagnostics',
                  subtitle: 'What the app is doing, and what it is keeping',
                  onTap: () => DiagnosticsSheet.show(context),
                ),
                SettingsRow(
                  icon: AceIcons.info,
                  title: 'About Ace Mail',
                  // Read from the installed package, so it cannot drift from
                  // what is actually on the device.
                  value: AppInfo.label,
                  onTap: () => showAceAbout(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// One settings card, with its folded state remembered.
  ///
  /// Every section goes through here, so "which categories do I keep closed?"
  /// is answered in one place for all of them, and the answer survives the
  /// screen being closed.
  Widget _section(
    Preferences prefs,
    String title, {
    Key? key,
    required List<Widget> children,
  }) {
    return SettingsSection(
      key: key,
      title: title,
      initiallyOpen: !prefs.sectionCollapsed(title),
      onToggle: (bool open) => prefs.setSectionCollapsed(title, !open),
      children: children,
    );
  }

  /// Ten accents, as a grid of swatches — a colour is easier to pick by eye
  /// than by name.
  /// Turning the cache off should not leave behind what was already kept.
  /// One text field, in a dialog, for the Chyme settings that are a string.
  Future<void> _editChymeText(
    BuildContext context,
    Preferences prefs, {
    required String title,
    required String hint,
    required String current,
    required Future<void> Function(String) save,
    bool multiline = false,
    bool obscure = false,
  }) async {
    final TextEditingController controller =
        TextEditingController(text: current);
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: obscure,
          // The instructions are a page of prose, not a URL: they need room to
          // be read while being edited.
          maxLines: multiline ? 12 : 1,
          minLines: multiline ? 6 : 1,
          keyboardType: obscure || multiline
              ? TextInputType.multiline
              : TextInputType.url,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) await save(multiline ? value : value.trim());
  }

  Future<void> _setCaching(
    BuildContext context,
    Preferences prefs,
    bool value,
  ) async {
    await prefs.setCacheMessages(value);
    if (value || !context.mounted) return;
    await context.read<LocalStore?>()?.clear();
  }

  /// Turning the lock on checks the device can answer *before* the switch is
  /// allowed to say yes. A switch that does nothing is worse than no switch,
  /// and a lock that cannot be asked for is exactly that.
  Future<void> _setAppLock(
    BuildContext context,
    Preferences prefs,
    bool value,
  ) async {
    if (!value) {
      await prefs.setAppLock(false);
      return;
    }

    final bool possible = await AppLock.available();
    if (!context.mounted) return;
    if (!possible) {
      AceSnack.show(
        context,
        'This device has no fingerprint or face unlock set up.',
      );
      return;
    }

    await prefs.setAppLock(true);
    if (!context.mounted) return;
    AceSnack.show(context, 'Ace Mail will ask for unlock from now on.');
  }

  Future<void> _chooseAccent(BuildContext context, Preferences prefs) async {
    final AceAccent? chosen = await showModalBottomSheet<AceAccent>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                'Accent',
                style: AstryxText.heading3(sheetContext.astryx.textPrimary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s5),
              child: Wrap(
                spacing: AstryxSpace.s3,
                runSpacing: AstryxSpace.s3,
                children: <Widget>[
                  for (final AceAccent accent in AceAccent.values)
                    AceSpringy(
                      onTap: () => Navigator.of(sheetContext).pop(accent),
                      semanticLabel: accent.label,
                      builder: (BuildContext context, double press, bool hover) {
                        final bool selected = accent == prefs.accent;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: AstryxMotion.emphasizedDecelerate,
                          width: 52 + press * -4,
                          height: 52 + press * -4,
                          decoration: BoxDecoration(
                            color: accent.seed,
                            borderRadius: BorderRadius.circular(
                              selected
                                  ? AstryxRadius.container
                                  : AstryxRadius.full,
                            ),
                          ),
                          child: selected
                              ? AceIconView(icon: 
                                  AceIcons.check,
                                  color: contrastingInk(accent.seed),
                                )
                              : null,
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: AstryxSpace.s6),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    await prefs.setAccent(chosen);
    // The launcher icon wears the accent, so it is repainted with it. Best
    // effort: a launcher that will not co-operate leaves the old icon, and
    // nothing else notices.
    // Re-applied, because the icon's background *is* the accent: changing the
    // accent is changing the icon, whether or not that was the intent.
    await LauncherIcon.apply(chosen, mark: prefs.launcherMark);
  }

  Future<void> _chooseSwipe(
    BuildContext context,
    Preferences prefs, {
    required bool start,
  }) async {
    final SwipeAction? chosen = await showChoiceSheet<SwipeAction>(
      context,
      title: start ? 'Swipe right' : 'Swipe left',
      current: start ? prefs.swipeStart : prefs.swipeEnd,
      choices: <SettingsChoice<SwipeAction>>[
        for (final SwipeAction action in SwipeAction.values)
          SettingsChoice<SwipeAction>(
            action,
            action.label,
            description: switch (action) {
              SwipeAction.archive => 'Move it out of the inbox',
              SwipeAction.trash => 'Move it to Trash',
              SwipeAction.toggleRead => 'Without opening it',
              SwipeAction.flag => 'Star it, or clear the star',
              SwipeAction.none => 'Leave this direction alone',
            },
          ),
      ],
    );
    if (chosen == null) return;
    if (start) {
      await prefs.setSwipeStart(chosen);
    } else {
      await prefs.setSwipeEnd(chosen);
    }
  }

  Future<void> _editSignature(
    BuildContext context,
    Preferences prefs,
  ) async {
    final TextEditingController controller =
        TextEditingController(text: prefs.signature);
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Signature'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          minLines: 2,
          decoration: const InputDecoration(
            hintText: 'Sent from Ace Mail',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) await prefs.setSignature(result);
  }

}

/// The current accent, as a swatch in the row.
class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({required this.accent});

  final AceAccent accent;

  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: accent.seed,
          shape: BoxShape.circle,
        ),
      );
}

/// What the encrypted cache costs, and the one-tap way to stop paying.
///
/// Stateful rather than a FutureBuilder: a builder that makes a new future on
/// every build would rebuild on every completion, which is a loop.
class _CacheRow extends StatefulWidget {
  const _CacheRow();

  @override
  State<_CacheRow> createState() => _CacheRowState();
}

class _CacheRowState extends State<_CacheRow> {
  int? _entries;

  @override
  void initState() {
    super.initState();
    _count();
  }

  Future<void> _count() async {
    final LocalStore? store = context.read<LocalStore?>();
    if (store == null) return;
    final int entries = store.entries;
    if (mounted) setState(() => _entries = entries);
  }

  Future<void> _clear() async {
    final LocalStore? store = context.read<LocalStore?>();
    if (store == null) return;

    final bool go = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Clear cached content?'),
            content: const Text(
              'The draft you are writing and the messages kept for reading '
              'offline are removed from this device. Your mail on the server '
              'is not touched.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Keep'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Clear'),
              ),
            ],
          ),
        ) ??
        false;
    if (!go || !mounted) return;

    await store.clear();
    if (!mounted) return;
    AceSnack.show(context, 'Cached content cleared.');
    await _count();
  }

  @override
  Widget build(BuildContext context) {
    final int? entries = _entries;
    return SettingsRow(
      icon: AceIcons.deleteSweep,
      title: 'Clear cached content',
      subtitle: 'The draft in progress and the messages kept for reading '
          'offline.',
      value: entries == null ? null : (entries == 0 ? 'Empty' : '$entries'),
      onTap: _clear,
    );
  }
}

/// What to say under the API key row.
///
/// It names where the key comes from, because "paste your API key" with no
/// answer to "from where" is the same wall as the endpoint field was.
String _chymeKeyHint(ChymeTemplate template) {
  final String? url = template.keyUrl;
  if (url == null) {
    return template == ChymeTemplate.local
        ? 'Not needed for something on this machine.'
        : 'Kept in the keychain, like an app password.';
  }
  return 'From ${url.replaceFirst(RegExp(r'^https?://'), '')} — kept in the '
      'keychain, like an app password.';
}

/// Pick, remove, or go and change it for everybody.
///
/// The third option is the honest one. Mail has no protocol for setting an
/// avatar, so a picture chosen here is local; Gravatar is the only standard the
/// other clients read, and it is a different service with its own account. A
/// row that offered only "change" would be promising something the app cannot
/// do.
Future<void> _choosePicture(BuildContext context, String email) async {
  if (email.isEmpty) return;

  final bool has = LocalAvatars.has(email);
  final String? action = await showChoiceSheet<String>(
    context,
    title: 'Your picture',
    current: '',
    choices: <SettingsChoice<String>>[
      const SettingsChoice<String>(
        'pick',
        'Choose a picture',
        description: 'Shown on this device, wherever your address appears.',
      ),
      if (has)
        const SettingsChoice<String>(
          'clear',
          'Remove it',
          description: 'Goes back to whatever can be looked up.',
        ),
      const SettingsChoice<String>(
        'gravatar',
        'Change it everywhere',
        description: 'Opens gravatar.com — the picture other mail apps read.',
      ),
    ],
  );
  if (action == null || !context.mounted) return;

  switch (action) {
    case 'pick':
      final XFile? picked = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[
          XTypeGroup(
            label: 'Images',
            extensions: <String>['png', 'jpg', 'jpeg', 'webp', 'gif'],
          ),
        ],
      );
      if (picked == null || !context.mounted) return;
      try {
        await LocalAvatars.set(email, File(picked.path));
        if (!context.mounted) return;
        AceSnack.show(context, 'Picture set.');
      } on LocalAvatarException catch (error) {
        if (!context.mounted) return;
        AceSnack.show(context, error.message);
      }
    case 'clear':
      await LocalAvatars.clear(email);
      if (!context.mounted) return;
      AceSnack.show(context, 'Picture removed.');
    case 'gravatar':
      final Uri uri = Uri.parse(
        'https://gravatar.com/emails/',
      );
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // Nothing installed that can open a browser.
      }
  }
}

/// Writes to the address in the row.
Future<void> _mailSupport(BuildContext context) async {
  final Uri uri = Uri(
    scheme: 'mailto',
    path: 'hello@ace-base.cc',
    query: 'subject=Ace Mail feedback',
  );
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    if (context.mounted) AceSnack.show(context, 'hello@ace-base.cc');
  }
}

/// Text size, as a slider rather than a list of three names.
///
/// A slider is the right control for something you judge by looking at it: the
/// mail behind the sheet is already re-rendering at the new size as you drag,
/// which is the only honest way to answer "is this too big". Three names in a
/// list made somebody choose, dismiss, look, and come back.
Future<void> _chooseTextSize(BuildContext context, Preferences prefs) async {
  final AstryxColors c = context.astryx;
  int index = prefs.textSize.index;
  final int last = AceTextSize.values.length - 1;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => StatefulBuilder(
      builder: (BuildContext sheetContext, StateSetter setSheetState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AstryxSpace.s5,
            0,
            AstryxSpace.s5,
            AstryxSpace.s5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Text size', style: AstryxText.heading4(c.textPrimary)),
              const SizedBox(height: AstryxSpace.s3),
              AceSlider(
                value: index.toDouble(),
                max: last.toDouble(),
                divisions: last,
                semanticLabel: 'Text size',
                onChanged: (double value) {
                  final int next = value.round().clamp(0, last);
                  if (next == index) return;
                  setSheetState(() => index = next);
                  unawaited(prefs.setTextSize(AceTextSize.values[next]));
                },
              ),
              const SizedBox(height: AstryxSpace.s1),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  for (final AceTextSize size in AceTextSize.values)
                    Text(
                      size.label,
                      style: AstryxText.supporting(c.textSecondary),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The provider picker, as a sheet of cards rather than a list of names.
///
/// Each one is a decision with a description attached — "generous on the free
/// tier" is the reason somebody picks Groq over OpenAI — and a choice sheet
/// that showed only the name was hiding the part that helps. The tick is on the
/// one currently in use, and the key link is where you get one.
Future<ChymeTemplate?> _pickProvider(
  BuildContext context,
  Preferences prefs,
) {
  final AstryxColors c = context.astryx;
  final ChymeTemplate current = ChymeTemplate.forEndpoint(prefs.chymeEndpoint);

  return showModalBottomSheet<ChymeTemplate>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AstryxSpace.s5,
                0,
                AstryxSpace.s5,
                AstryxSpace.s3,
              ),
              child: Text(
                'Where Chyme points',
                style: AstryxText.heading4(c.textPrimary),
              ),
            ),
            // Rows written out rather than ListTile. A ListTile inside a
            // Column inside a sheet laid its title out one character wide —
            // "G r o q" down the left edge — because nothing in that chain
            // gave it a width to fill. An Expanded does.
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: AstryxSpace.s4),
                itemCount: ChymeTemplate.values.length,
                itemBuilder: (BuildContext context, int index) {
                  final ChymeTemplate template = ChymeTemplate.values[index];
                  final bool isCurrent = template == current;
                  return InkWell(
                    onTap: () => Navigator.of(sheetContext).pop(template),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AstryxSpace.s5,
                        vertical: AstryxSpace.s3,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  template.label,
                                  style: AstryxText.bodyStrong(
                                    isCurrent ? c.accent : c.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: AstryxSpace.s0_5),
                                Text(
                                  template.description,
                                  style: AstryxText.supporting(c.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          if (isCurrent)
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: AstryxSpace.s3),
                              child: AceIconView(
                                icon: AceIcons.checkCircle,
                                size: 20,
                                color: c.accent,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Messages per page, as a slider.
///
/// Three names in a list made a choice out of something continuous — and the
/// number is the point, so the control should show the number moving.
Future<void> _choosePageSize(BuildContext context, Preferences prefs) async {
  final AstryxColors c = context.astryx;
  int index = prefs.pageSize.index;
  final int last = PageSize.values.length - 1;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => StatefulBuilder(
      builder: (BuildContext sheetContext, StateSetter setSheetState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AstryxSpace.s5,
            0,
            AstryxSpace.s5,
            AstryxSpace.s5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Messages per page', style: AstryxText.heading4(c.textPrimary)),
              const SizedBox(height: AstryxSpace.s3),
              AceSlider(
                value: index.toDouble(),
                max: last.toDouble(),
                divisions: last,
                semanticLabel: 'Messages per page',
                onChanged: (double value) {
                  final int next = value.round().clamp(0, last);
                  if (next == index) return;
                  setSheetState(() => index = next);
                  unawaited(prefs.setPageSize(PageSize.values[next]));
                },
              ),
              const SizedBox(height: AstryxSpace.s1),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  for (final PageSize size in PageSize.values)
                    Text(
                      size.label,
                      style: AstryxText.supporting(c.textSecondary),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The model list, with a search field.
///
/// An endpoint can offer a hundred models and the list arrived unsorted and
/// unfiltered, so finding one meant scrolling past every embedding model to
/// reach the chat one. Typing three characters is faster than reading a hundred.
/// How long undo stays offered, as a slider.
///
/// The same reasoning as page size: the number is the thing being chosen, so
/// the control shows the number moving rather than offering three words.
Future<void> _chooseUndoWindow(
  BuildContext context,
  Preferences prefs,
) async {
  final AstryxColors c = context.astryx;
  int index = prefs.undoWindow.index;
  final int last = UndoWindow.values.length - 1;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => StatefulBuilder(
      builder: (BuildContext sheetContext, StateSetter setSheetState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AstryxSpace.s5,
            0,
            AstryxSpace.s5,
            AstryxSpace.s5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Undo window', style: AstryxText.heading4(c.textPrimary)),
              const SizedBox(height: AstryxSpace.s3),
              AceSlider(
                value: index.toDouble(),
                max: last.toDouble(),
                divisions: last,
                semanticLabel: 'Undo window',
                onChanged: (double value) {
                  final int next = value.round().clamp(0, last);
                  if (next == index) return;
                  setSheetState(() => index = next);
                  unawaited(prefs.setUndoWindow(UndoWindow.values[next]));
                },
              ),
              const SizedBox(height: AstryxSpace.s1),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  for (final UndoWindow window in UndoWindow.values)
                    Text(
                      window.label,
                      style: AstryxText.supporting(c.textSecondary),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// `3 Oct 2026, 09:12` — enough to answer "when did it last look?" without a
/// clock somebody has to read twice.
String _shortDate(DateTime when) {
  const List<String> months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final String hour = when.hour.toString().padLeft(2, '0');
  final String minute = when.minute.toString().padLeft(2, '0');
  return '${when.day} ${months[when.month - 1]} ${when.year}, $hour:$minute';
}

/// The mark as the launcher draws it, on the accent it will wear.
///
/// The picker used to offer four words. A launcher icon is a picture, and the
/// only way to choose one is to see it — at the size and on the background it
/// will actually appear.
class _MarkPreview extends StatelessWidget {
  const _MarkPreview({required this.mark, required this.accent});

  final LauncherMark mark;
  final AceAccent accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: accent.seed,
        borderRadius: BorderRadius.circular(AstryxRadius.inner),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(mark.asset, fit: BoxFit.cover),
    );
  }
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';

import '../data/preferences.dart';
import '../models/contact.dart';
import '../models/full_message.dart';
import '../models/message_summary.dart';
import '../screens/compose_screen.dart';
import '../screens/settings_screen.dart';
import '../services/chyme.dart';
import '../services/chyme_context.dart';
import '../services/chyme_tools.dart';
import '../services/contacts.dart';
import '../services/voice_input.dart';
import '../state/mail_controller.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/ace_snack.dart';
import '../util/haptics.dart';
import '../util/routes.dart';
import 'ace_confirm.dart';
import 'ace_form_field.dart';
import 'ace_icon_view.dart';
import 'ace_glass.dart';
import 'astryx_widgets.dart';
import 'chyme_mark.dart';
import 'chyme_pickers.dart';
import 'markdown_view.dart';
import 'voice_button.dart';

/// Chyme, as a sheet.
///
/// A sheet rather than a screen, for the same reason the composer is one: you
/// ask about the mail in front of you, and the mail stays in front of you.
///
/// What Chyme can see is assembled **here**, not fetched by the model. The app
/// already knows what is on screen; a model with a tool that can ask for more
/// mail is a model that can ask for all of it, and the difference matters more
/// than the convenience. What it can *do*, though, it does through the same
/// [MailController] the buttons use — one path, one set of rules, and the
/// destructive half of it always asks first.
class ChymeSheet extends StatefulWidget {
  const ChymeSheet({super.key, this.seed});

  /// A prompt to open with, when the caller already knows what it wants —
  /// "write this reply" from the composer.
  final String? seed;

  static Future<void> show(BuildContext context, {String? seed}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      sheetAnimationStyle: kAceSheetMotion,
      builder: (BuildContext sheetContext) => ChymeSheet(seed: seed),
    );
  }

  @override
  State<ChymeSheet> createState() => _ChymeSheetState();
}

class _ChymeSheetState extends State<ChymeSheet> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  /// The conversation, without the system turn — that is rebuilt per request,
  /// so a setting changed mid-conversation takes effect on the next question.
  final List<ChymeTurn> _turns = <ChymeTurn>[];

  bool _busy = false;
  String? _error;

  /// Whether the device is listening for a question.
  bool _listening = false;

  /// The search the last reply asked for, if it asked for one.
  String? _search;

  @override
  void initState() {
    super.initState();
    // Pick up where the last opening left off — a second question almost always
    // refers to the first answer — but only inside the hour. `current` empties
    // a conversation that has expired, which is what replaced the "start over"
    // button: the sheet tidies itself instead of asking somebody to.
    _turns.addAll(ChymeMemory.current);
    final String? seed = widget.seed;
    if (seed != null && seed.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(seed));
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Dictates the question instead of typing it.
  ///
  /// The words land in the field rather than being sent. Speech recognition
  /// mishears — a name, a number, a word that sounds like another word — and a
  /// question that goes to the assistant exactly as the device heard it is a
  /// question the person cannot fix before it costs them an answer. They can
  /// read it, change it, then send it.
  Future<void> _listen() async {
    if (_listening) return;
    unawaited(AceHaptics.tap());
    setState(() => _listening = true);
    try {
      final String? heard = await VoiceInput.listen();
      if (!mounted || heard == null) return;
      _input.text = heard;
      _input.selection = TextSelection.collapsed(offset: heard.length);
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      AceSnack.show(context, '$error');
    } finally {
      if (mounted) setState(() => _listening = false);
    }
  }

  /// What Chyme is told about the screen.
  ///
  /// A summary, and a deliberately short one: the sender, the subject and the
  /// date of the messages in view, and the body of the one that is open. Not the
  /// mailbox, not the attachments, not the other folders.
  ///
  /// Each message carries its uid in brackets, because Chyme now acts on
  /// messages and a tool needs to name one. The number is the only handle the
  /// model is given, and it is the one the list is already keyed by.
  Future<void> _send(String text) async {
    final String prompt = text.trim();
    if (prompt.isEmpty || _busy) return;

    final Preferences prefs = context.read<Preferences>();
    if (prefs.chymeEndpoint.trim().isEmpty || prefs.chymeModel.trim().isEmpty) {
      setState(() => _error = 'Chyme has no endpoint or model yet.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _search = null;
      _turns.add(ChymeTurn('user', prompt));
    });
    _input.clear();
    _scrollToEnd();

    try {
      final MailController controller = context.read<MailController>();
      final List<ChymeTurn> request = <ChymeTurn>[
        ChymeTurn(
          'system',
          '${Chyme.systemPromptFor(prefs.chymeTone, custom: prefs.chymePrompt)}\n'
          '${ChymeContext.forMail(
            visible: controller.visibleMessages,
            open: controller.openMessage,
            readsMail: prefs.chymeReadsMail,
          )}',
        ),
        ..._turns,
      ];

      // A loop, not one request: Chyme asks to read something, the app reads it,
      // and the answer goes back into the conversation. Anything that *changes*
      // mail is proposed instead, and waits for a button below the answer.
      final ChymeRun run = await Chyme.run(
        endpoint: prefs.chymeEndpoint,
        apiKey: prefs.chymeKey,
        model: prefs.chymeModel,
        turns: request,
        tools: _tools(controller),
      );
      if (!mounted) return;
      setState(() {
        _turns.add(ChymeTurn('assistant', run.reply));
        _search = Chyme.searchFrom(run.reply);
        ChymeMemory.remember(_turns);
      });
      _scrollToEnd();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// What Chyme has proposed and the person has not answered yet.
  final List<_Proposal> _pending = <_Proposal>[];

  /// What was actually done, once somebody said yes.
  final List<String> _done = <String>[];

  /// The tools Chyme is given: reads run, writes wait for a button.
  Map<String, ChymeTool> _tools(MailController controller) {
    final Map<String, ChymeTool> real = _perform(controller);
    return <String, ChymeTool>{
      for (final MapEntry<String, ChymeTool> entry in real.entries)
        entry.key: ChymeTools.mutates(entry.key)
            ? (String argument) async {
                _propose(entry.key, argument);
                return 'Proposed to the person. Nothing has been done yet — '
                    'they have a button for it.';
              }
            : entry.value,
    };
  }

  void _propose(String name, String argument) {
    if (_pending.any((_Proposal p) => p.name == name && p.argument == argument)) {
      return;
    }
    _pending.add(_Proposal(
      name: name,
      argument: argument,
      label: _proposalLabel(name, argument),
    ));
  }

  String _proposalLabel(String name, String argument) {
    final String subject = _subjectFor(argument);
    return switch (name) {
      'star' => subject.isEmpty ? 'Star it' : 'Star “$subject”',
      'unstar' => subject.isEmpty ? 'Remove the star' : 'Unstar “$subject”',
      'seen' => subject.isEmpty ? 'Mark it read' : 'Mark “$subject” read',
      'archive' => subject.isEmpty ? 'Archive it' : 'Archive “$subject”',
      'delete' => subject.isEmpty ? 'Delete it' : 'Delete “$subject”',
      'reply' => 'Open this reply in the composer',
      'contact_add' => 'Save this address to contacts',
      'contact_block' => 'Block ${argument.split('|').last.trim()}',
      'contact_delete' => 'Forget ${argument.split('|').last.trim()}',
      _ => name,
    };
  }

  String _subjectFor(String argument) {
    final MailController controller = context.read<MailController>();
    final MessageSummary? message = _find(controller, argument);
    final String subject = message?.subject.trim() ?? '';
    if (subject.isEmpty) return '';
    return subject.length > 34 ? '${subject.substring(0, 33)}…' : subject;
  }

  /// Runs one proposal, because somebody pressed its button.
  Future<void> _confirmProposal(_Proposal proposal) async {
    final MailController controller = context.read<MailController>();
    setState(() {
      _pending.remove(proposal);
      _busy = true;
    });
    try {
      final ChymeTool? tool = _perform(controller)[proposal.name];
      final String result = (tool == null
              ? 'There is no tool called ${proposal.name}.'
              : await tool(proposal.argument)) ??
          'Done.';
      if (!mounted) return;
      setState(() => _done.add(result));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _dismissProposal(_Proposal proposal) {
    setState(() {
      _pending.remove(proposal);
      _done.add('Left it alone.');
    });
  }

  /// Everything Chyme may do, and what it is told afterwards.
  ///
  /// Read-only tools run silently, because reading is what it was asked to do.
  /// The rest are reached only through [_confirmProposal], which is a button.
  Map<String, ChymeTool> _perform(MailController controller) {
    return <String, ChymeTool>{
      // The message on screen, in full. The prompt already carries a shortened
      // copy so a question about it needs no tool at all; this is for the long
      // one, where the answer is further down than the excerpt.
      'read': (String argument) async {
        final MessageSummary? summary = _find(controller, argument);
        final FullMessage? open = controller.openMessage;
        if (summary == null && open == null) return 'No message is open.';
        if (summary != null && open != null && summary.uid == open.uid) {
          return _describe(open);
        }
        if (summary == null) return _describe(open!);
        // A row that is not open has no body in memory; opening it is what the
        // person would do, and it is what this does — through the controller,
        // so the reader follows.
        await controller.open(summary);
        final FullMessage? loaded = controller.openMessage;
        if (loaded == null) return 'That message could not be opened.';
        return _describe(loaded);
      },
      'search': (String argument) async {
        final String needle = argument.toLowerCase().trim();
        if (needle.isEmpty) return 'No words to search for.';
        final List<MessageSummary> hits = controller.visibleMessages
            .where(
              (MessageSummary message) =>
                  message.subject.toLowerCase().contains(needle) ||
                  message.fromName.toLowerCase().contains(needle) ||
                  message.fromEmail.toLowerCase().contains(needle),
            )
            .take(8)
            .toList();
        if (hits.isEmpty) {
          final String where = controller.selectedFolder?.name ?? 'this folder';
          return 'Nothing in $where matches "$argument".';
        }
        return hits
            .map((MessageSummary m) =>
                '[${m.uid}] ${m.fromName} — ${m.subject}')
            .join('\n');
      },
      'star': (String argument) async {
        final MessageSummary? message = _find(controller, argument);
        if (message == null) return 'No message with that number.';
        if (message.isFlagged) return 'Already starred: ${message.subject}.';
        await controller.toggleFlag(message);
        return 'Starred "${message.subject}".';
      },
      'unstar': (String argument) async {
        final MessageSummary? message = _find(controller, argument);
        if (message == null) return 'No message with that number.';
        if (!message.isFlagged) return 'Not starred: ${message.subject}.';
        await controller.toggleFlag(message);
        return 'Removed the star from "${message.subject}".';
      },
      'seen': (String argument) async {
        final MessageSummary? message = _find(controller, argument);
        if (message == null) return 'No message with that number.';
        if (message.isSeen) return 'Already read: ${message.subject}.';
        await controller.markRead(message);
        return 'Marked "${message.subject}" read.';
      },
      'archive': (String argument) async {
        final MessageSummary? message = _find(controller, argument);
        if (message == null) return 'No message with that number.';
        await controller.archive(message);
        return 'Archived "${message.subject}".';
      },
      'delete': (String argument) async {
        final MessageSummary? message = _find(controller, argument);
        if (message == null) return 'No message with that number.';
        if (!mounted) return 'The sheet closed; nothing was deleted.';
        final bool yes = await _ask(
          title: 'Delete this message?',
          body: '\u201C${message.subject}\u201D goes to the trash. You can put '
              'it back.',
          confirm: 'Delete',
          cancel: 'Keep',
        );
        if (!yes) return 'The person kept "${message.subject}".';
        await controller.delete(message);
        return 'Moved "${message.subject}" to the trash.';
      },
      'reply': (String argument) async {
        final List<String> parts = argument.split('|');
        final String body = parts.length > 1
            ? parts.sublist(1).join('|').trim()
            : '';
        final MessageSummary? message = _find(controller, parts.first);
        if (message == null) return 'No message with that number.';
        if (body.isEmpty) {
          return 'A reply needs a message number and a body, like: '
              'reply 12 | Thanks, I will look at it today.';
        }
        if (!mounted) return 'The sheet closed; no draft was opened.';
        final FullMessage? open = controller.openMessage;
        final bool threaded = open != null && open.uid == message.uid;
        await openComposeSheet(
          context,
          initialTo: message.fromEmail,
          initialSubject: message.subject.toLowerCase().startsWith('re:')
              ? message.subject
              : 'Re: ${message.subject}',
          initialBody: body,
          inReplyTo: threaded ? open.messageId : null,
          references: threaded ? open.references : null,
        );
        return 'Opened a reply to ${message.fromName}, in their composer, with '
            'that draft. They read it and send it.';
      },
      'contacts': (String argument) async {
        final String needle = argument.trim().toLowerCase();
        if (needle.isEmpty) return 'No name to look for.';
        final List<Contact> hits = Contacts.search(needle).take(8).toList();
        if (hits.isEmpty) return 'Nobody in their contacts matches "$argument".';
        return hits
            .map((Contact c) =>
                '${c.label} <${c.email}>'
                '${c.saved ? ' · saved' : ''}'
                '${Contacts.isBlocked(c.email) ? ' · blocked' : ''}')
            .join('\n');
      },
      'contact_add': (String argument) async {
        final List<String> parts = argument.split('|');
        final String name = parts.first.trim();
        final String email =
            (parts.length > 1 ? parts[1] : parts.first).trim().toLowerCase();
        if (!email.contains('@')) {
          return 'That is not an address. Use: contact_add Name | a@b.com';
        }
        final Contact contact = await Contacts.add(
          email: email,
          name: email == name ? '' : name,
        );
        return 'Saved ${contact.label} <${contact.email}>.';
      },
      'contact_block': (String argument) async {
        final String email = argument.trim().toLowerCase();
        if (!email.contains('@')) return 'That is not an address.';
        if (Contacts.isBlocked(email)) return '$email is already blocked.';
        if (!mounted) return 'The sheet closed; nothing was blocked.';
        final bool yes = await _ask(
          title: 'Block this address?',
          body: 'Mail from $email stops appearing in the list. Nothing is '
              'deleted, and unblocking brings it all back.',
          confirm: 'Block',
          cancel: 'Cancel',
        );
        if (!yes) return 'The person did not block $email.';
        await Contacts.block(email);
        return 'Blocked $email. Their mail is hidden from the list.';
      },
      'contact_delete': (String argument) async {
        final String email = argument.trim().toLowerCase();
        if (!email.contains('@')) return 'That is not an address.';
        if (!mounted) return 'The sheet closed; nothing was removed.';
        final bool yes = await _ask(
          title: 'Forget this contact?',
          body: '$email is removed from your contacts here. Mail from them is '
              'untouched.',
          confirm: 'Forget',
          cancel: 'Cancel',
        );
        if (!yes) return 'The person kept $email.';
        await Contacts.remove(email);
        return 'Removed $email from their contacts.';
      },
    };
  }

  /// The message a tool argument names, or null.
  ///
  /// Tolerant on purpose: a model will write `12`, `#12`, `[12]` and
  /// `uid 12`, and all four mean the same message. "open" means the one on
  /// screen, which is the only name that survives a list that has moved.
  MessageSummary? _find(MailController controller, String argument) {
    final String cleaned = argument.trim().toLowerCase();
    final MessageSummary? open = controller.openSummary;
    if (cleaned == 'open' || cleaned == 'current') return open;
    final String digits = cleaned.replaceAll(RegExp(r'[^0-9]'), '');
    final int? uid = int.tryParse(digits);
    if (uid == null) return open;
    if (open?.uid == uid) return open;
    for (final MessageSummary message in controller.visibleMessages) {
      if (message.uid == uid) return message;
    }
    return null;
  }

  String _describe(FullMessage message) {
    final String body = message.textBody.trim();
    final String html = message.htmlSource ?? '';
    final String text = body.isNotEmpty ? body : html;
    if (text.isEmpty) return 'The message has no readable body.';
    return 'From ${message.fromName} \u2014 ${message.subject}\n\n'
        '${text.length > 6000 ? '${text.substring(0, 6000)}\u2026' : text}';
  }

  /// A question with the detail in it, answered before anything is destroyed.
  Future<bool> _ask({
    required String title,
    required String body,
    required String confirm,
    required String cancel,
  }) =>
      aceConfirm(
        context,
        title: title,
        body: body,
        confirm: confirm,
        cancel: cancel,
        destructive: true,
      );

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: AstryxMotion.of(const Duration(milliseconds: 220)),
        curve: AstryxMotion.emphasized,
      );
    });
  }

  /// Runs the search the reply asked for — after the person taps it, not
  /// instead of them asking.
  void _applySearch(String query) {
    final NavigatorState navigator = Navigator.of(context);
    context.read<MailController>().search(query);
    // Said before the sheet goes, not after: the snack belongs to the screen
    // underneath, and a message raised from a context that has just been popped
    // is a message raised from a widget that is no longer in the tree.
    AceSnack.show(context, 'Searching for “$query”');
    navigator.pop();
  }

  /// Starts a reply to the open message with what Chyme wrote in it.
  Future<void> _replyWith(String body) async {
    final MailController controller = context.read<MailController>();
    final MessageSummary? summary = controller.openSummary;
    final FullMessage? open = controller.openMessage;
    if (summary == null) {
      AceSnack.show(context, 'Open a message first — there is nobody to reply to.');
      return;
    }
    await openComposeSheet(
      context,
      initialTo: summary.fromEmail,
      initialSubject: summary.subject.toLowerCase().startsWith('re:')
          ? summary.subject
          : 'Re: ${summary.subject}',
      initialBody: body,
      inReplyTo: open?.messageId,
      references: open?.references,
    );
  }

  /// Settings, opened at the Chyme card rather than at the top of the list.
  Future<void> _openSettings() async {
    final NavigatorState navigator = Navigator.of(context);
    navigator.pop();
    await navigator.push(
      aceRoute(const SettingsScreen(focus: SettingsFocus.chyme)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final Preferences prefs = context.watch<Preferences>();
    final bool configured =
        prefs.chymeEndpoint.trim().isNotEmpty &&
        prefs.chymeModel.trim().isNotEmpty;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController sheetController) {
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AstryxSpace.s5,
                0,
                AstryxSpace.s5,
                AstryxSpace.s3,
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: c.accentMuted,
                      borderRadius: BorderRadius.circular(AstryxRadius.element),
                    ),
                    child: Center(
                      // Chyme arrives rather than being there. A mark that is
                      // simply present reads as an icon; one that lands reads as
                      // something that just turned up, which is what opening
                      // this sheet is.
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: AstryxMotion.of(
                          const Duration(milliseconds: 520),
                        ),
                        curve: Curves.easeOutBack,
                        builder:
                            (BuildContext context, double t, Widget? child) =>
                                Transform.rotate(
                                  angle: (1 - t) * -0.6,
                                  child: Transform.scale(
                                    scale: 0.5 + t * 0.5,
                                    child: child,
                                  ),
                                ),
                        child: ChymeMark(size: 20, color: c.onAccentMuted),
                      ),
                    ),
                  ),
                  const SizedBox(width: AstryxSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Chyme',
                          style: AstryxText.heading3(c.textPrimary),
                        ),
                        const SizedBox(height: AstryxSpace.s0_5),
                        // The two settings that change what an answer is, in
                        // the header, one tap from the conversation. Going to
                        // Settings to change the tone and coming back is four
                        // taps to answer a question asked in the middle of
                        // typing.
                        Row(
                          children: <Widget>[
                            _SettingChip(
                              label: prefs.chymeModel.isEmpty
                                  ? 'Choose a model'
                                  : prefs.chymeModel,
                              icon: AceIcons.chyme,
                              onTap: () => chooseChymeModel(context, prefs),
                            ),
                            const SizedBox(width: AstryxSpace.s1_5),
                            _SettingChip(
                              label: prefs.chymeTone.label,
                              icon: AceIcons.signature,
                              onTap: () => chooseChymeTone(context, prefs),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  AceIconButton(
                    icon: AceIcons.settings,
                    tooltip: 'Chyme settings',
                    onPressed: _openSettings,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.border),
            Expanded(
              child: !configured
                  ? _NotSetUp(onConfigure: _openSettings)
                  : ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(
                        AstryxSpace.s5,
                        AstryxSpace.s4,
                        AstryxSpace.s5,
                        AstryxSpace.s4,
                      ),
                      children: <Widget>[
                        if (_turns.isEmpty)
                          _suggestions(c, context.read<MailController>()),
                        for (final ChymeTurn turn in _turns)
                          _Bubble(
                            turn: turn,
                            onReply: _replyWith,
                            canReply: context
                                    .watch<MailController>()
                                    .openSummary !=
                                null,
                          ),
                        for (final _Proposal proposal in _pending) ...<Widget>[
                          const SizedBox(height: AstryxSpace.s3),
                          _ProposalCard(
                            proposal: proposal,
                            onConfirm: () => _confirmProposal(proposal),
                            onDismiss: () => _dismissProposal(proposal),
                          ),
                        ],
                        for (final String note in _done) ...<Widget>[
                          const SizedBox(height: AstryxSpace.s2),
                          _DoneNote(text: note),
                        ],
                        if (_search != null)
                          _SearchOffer(
                            query: _search!,
                            onTap: () => _applySearch(_search!),
                          ),
                        if (_busy) _thinking(c),
                        if (_error != null) ...<Widget>[
                          const SizedBox(height: AstryxSpace.s3),
                          AceErrorBox(message: _error!),
                        ],
                      ],
                    ),
            ),
            if (configured)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AstryxSpace.s5,
                  0,
                  AstryxSpace.s4,
                  AstryxSpace.s4,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _input,
                        onSubmitted: _send,
                        textInputAction: TextInputAction.send,
                        style: AstryxText.body(c.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Ask about your mail, or ask it to write',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AstryxRadius.full,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AstryxSpace.s2),
                    // Voice, at the size of a decision rather than the size of
                    // an icon in a row of them. Speaking a question instead of
                    // typing it is what a phone assistant is for, and this is
                    // the control that had to stay big when it arrived here
                    // from the search bar: 48 against the 44 of every other
                    // icon button, so it reads as the second way to ask rather
                    // than as decoration beside the field.
                    VoiceButton(
                      size: 48,
                      label: 'Ask by voice',
                      listening: _listening,
                      onPressed: _listen,
                    ),
                    const SizedBox(width: AstryxSpace.s2),
                    AceIconButton(
                      icon: AceIcons.send,
                      tooltip: 'Send',
                      variant: AceIconButtonVariant.filled,
                      onPressed: _busy ? null : () => _send(_input.text),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  /// What to ask, when somebody has opened Chyme and does not know what to ask.
  ///
  /// A hero and a row of cards, because the first thing this sheet says decides
  /// whether it is an assistant or a settings page: a paragraph of explanation
  /// and seven underlined prompts is a menu, and nobody reads a menu.
  Widget _suggestions(AstryxColors c, MailController controller) {
    final bool hasOpen = controller.openMessage != null;

    final List<_Prompt> prompts = <_Prompt>[
      if (hasOpen)
        _Prompt(
          icon: AceIcons.mailOpen,
          title: 'What is this asking for?',
          subtitle: 'Read it, and tell me',
          prompt: 'What is this actually asking me for?',
        ),
      if (hasOpen)
        _Prompt(
          icon: AceIcons.reply,
          title: 'Draft a reply',
          subtitle: 'Opens in your composer',
          prompt: 'Draft a reply saying I will look at it tomorrow.',
        ),
      _Prompt(
        icon: AceIcons.inbox,
        title: 'What needs answering?',
        subtitle: 'Today, in one list',
        prompt: 'What needs answering today?',
      ),
      _Prompt(
        icon: AceIcons.search,
        title: 'Find an invoice',
        subtitle: 'Search your mail',
        prompt: 'Find the last invoice or receipt.',
      ),
      _Prompt(
        icon: AceIcons.shield,
        title: 'Anything from my bank?',
        subtitle: 'This week',
        prompt: 'Anything from my bank this week?',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: AstryxSpace.s6),
        Center(child: ChymeMark(size: 62, color: c.accent)),
        const SizedBox(height: AstryxSpace.s4),
        Text(
          'What needs doing?',
          textAlign: TextAlign.center,
          style: AstryxText.heading2(c.textPrimary),
        ),
        const SizedBox(height: AstryxSpace.s2),
        Text(
          'Chyme reads the mail in front of you. It can propose a star, an '
          'archive, a reply — and it asks before any of them happens.',
          textAlign: TextAlign.center,
          style: AstryxText.supporting(c.textSecondary),
        ),
        const SizedBox(height: AstryxSpace.s5),
        // An arc, not a row. The cards sit on a circle — the middle one
        // upright and nearest, its neighbours turned outward and lower, the
        // outermost half off the edge — which is a shape you read as a hand of
        // cards being offered rather than a list you scroll.
        _SuggestionArc(
          prompts: prompts,
          onPick: (String prompt) => _send(prompt),
        ),
      ],
    );
  }

  Widget _thinking(AstryxColors c) {
    return Padding(
      padding: const EdgeInsets.only(top: AstryxSpace.s3),
      child: Row(
        children: <Widget>[
          const SizedBox(width: 6, height: 6, child: AceLoader(size: 6)),
          const SizedBox(width: AstryxSpace.s3),
          Text('Thinking…', style: AstryxText.supporting(c.textSecondary)),
        ],
      ),
    );
  }
}

/// One of the header's two settings, as a chip.
class _SettingChip extends StatelessWidget {
  const _SettingChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final AceIcon icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AstryxRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AstryxSpace.s2,
          vertical: AstryxSpace.s0_5,
        ),
        decoration: BoxDecoration(
          color: c.backgroundMuted,
          borderRadius: BorderRadius.circular(AstryxRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AceIconView(icon: icon, size: 13, color: c.textSecondary),
            const SizedBox(width: AstryxSpace.s1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AstryxText.supporting(c.textSecondary),
              ),
            ),
            AceIconView(
              icon: AceIcons.chevronDown,
              size: 13,
              color: c.textDisabled,
            ),
          ],
        ),
      ),
    );
  }
}

/// One turn, as a bubble.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.turn,
    required this.onReply,
    this.canReply = false,
  });

  final ChymeTurn turn;

  /// Opens the composer with this text in it, as a reply to the open message.
  final Future<void> Function(String body) onReply;

  /// Whether there is a message to reply to.
  final bool canReply;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final bool mine = turn.role == 'user';
    final String text = mine
        ? turn.content
        : Chyme.withoutSearchLine(turn.content);

    return Padding(
      padding: const EdgeInsets.only(bottom: AstryxSpace.s3),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: <Widget>[
          // What Chyme wrote is the useful part, and there are only ever three
          // things anybody wants to do with it: keep it, reply with it, or
          // start a new message with it. All are one tap rather than a
          // selection and a long press.
          if (!mine)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                AceIconButton(
                  icon: AceIcons.copy,
                  tooltip: 'Copy',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) AceSnack.show(context, 'Copied.');
                  },
                ),
                if (canReply)
                  AceIconButton(
                    icon: AceIcons.reply,
                    tooltip: 'Reply with this',
                    onPressed: () => onReply(text),
                  ),
                AceIconButton(
                  icon: AceIcons.edit,
                  tooltip: 'Start a message with this',
                  onPressed: () => openComposeSheet(context, initialBody: text),
                ),
                // Only when the reply asked to delete, and only as a question.
                // A model may propose; the app asks; the person decides.
                if (Chyme.deleteFrom(text))
                  AceIconButton(
                    icon: AceIcons.trash,
                    tooltip: 'Delete this message',
                    onPressed: () => _confirmDelete(context),
                  ),
              ],
            ),
          Row(
            mainAxisAlignment: mine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: <Widget>[
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AstryxSpace.s4,
                    vertical: AstryxSpace.s3,
                  ),
                  decoration: BoxDecoration(
                    color: mine ? c.accent : c.backgroundMuted,
                    borderRadius: BorderRadius.circular(AstryxRadius.container),
                  ),
                  // What Chyme writes is Markdown, and it reads as Markdown when it
                  // is rendered as Markdown. What the person types is not, and is
                  // shown exactly as typed.
                  child: mine
                      ? SelectableText(text, style: AstryxText.body(c.onAccent))
                      : MarkdownView(
                          source: text,
                          onLink: (String url) =>
                              openMarkdownLink(context, url),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The search a reply asked for, offered rather than run.
class _SearchOffer extends StatelessWidget {
  const _SearchOffer({required this.query, required this.onTap});

  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return Padding(
      padding: const EdgeInsets.only(bottom: AstryxSpace.s3),
      child: Container(
        padding: const EdgeInsets.all(AstryxSpace.s3),
        decoration: BoxDecoration(
          color: c.backgroundMuted,
          borderRadius: BorderRadius.circular(AstryxRadius.container),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: <Widget>[
            AceIconView(
              icon: AceIcons.search,
              size: 18,
              color: c.textSecondary,
            ),
            const SizedBox(width: AstryxSpace.s3),
            Expanded(
              child: Text(
                'Search for “$query”',
                style: AstryxText.body(c.textPrimary),
              ),
            ),
            AceButton(
              label: 'Search',
              variant: AceButtonVariant.tonal,
              onPressed: onTap,
            ),
          ],
        ),
      ),
    );
  }
}

/// Chyme with nowhere to ask.
class _NotSetUp extends StatelessWidget {
  const _NotSetUp({required this.onConfigure});

  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return Padding(
      padding: const EdgeInsets.all(AstryxSpace.s5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ChymeMark(size: 28, color: c.accent),
          const SizedBox(height: AstryxSpace.s4),
          Text(
            'Chyme needs somewhere to ask',
            style: AstryxText.heading3(c.textPrimary),
          ),
          const SizedBox(height: AstryxSpace.s2),
          Text(
            'There is no Chyme service and no account to make. Point it at any '
            'endpoint that speaks the OpenAI chat API — a hosted one, or a model '
            'running on your own machine — and it will list what it has.',
            style: AstryxText.body(c.textSecondary),
          ),
          const SizedBox(height: AstryxSpace.s4),
          AceButton(
            label: 'Set up Chyme',
            icon: AceIcons.chyme,
            variant: AceButtonVariant.primary,
            expand: true,
            onPressed: onConfigure,
          ),
        ],
      ),
    );
  }
}

/// Asks before it deletes, then moves the open message to the trash.
///
/// Chyme cannot delete anything by itself. It can say it would, and this is what
/// happens next: a question with the subject in it, and a way to say no.
/// Everything here is reversible — it goes to the trash, not away.
Future<void> _confirmDelete(BuildContext context) async {
  final MailController controller = context.read<MailController>();
  final MessageSummary? open = controller.openSummary;
  if (open == null) {
    AceSnack.show(context, 'Open the message first — there is nothing to delete.');
    return;
  }
  final bool yes = await aceConfirm(
    context,
    title: 'Delete this message?',
    body: '\u201C${open.subject}\u201D goes to the trash. You can put it back.',
    confirm: 'Delete',
    cancel: 'Keep',
    destructive: true,
  );
  if (!yes || !context.mounted) return;
  await controller.delete(open);
  if (context.mounted) AceSnack.show(context, 'Moved to the trash.');
}

/// One thing worth asking, as a card.
class _Prompt {
  const _Prompt({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.prompt,
  });

  final AceIcon icon;
  final String title;
  final String subtitle;
  final String prompt;
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({
    required this.prompt,
    required this.onTap,
    this.width = 196,
  });

  final _Prompt prompt;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return SizedBox(
      width: width,
      child: AceSpringy(
        onTap: onTap,
        semanticLabel: prompt.title,
        builder: (BuildContext context, double press, bool hover) => MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: AstryxMotion.fast,
            // A card under a pointer has to say so: the border alone was too
            // quiet to notice on a desktop, and this is the one place in the
            // app where hovering is how you find out a card is a button.
            transform: Matrix4.translationValues(0, hover ? -3 : 0, 0),
            padding: const EdgeInsets.all(AstryxSpace.s4),
            decoration: BoxDecoration(
              color: hover ? c.backgroundMuted : c.surfaceHighest,
              borderRadius: BorderRadius.circular(AstryxRadius.lg),
              border: Border.all(
                color: hover ? c.accent : c.border,
              ),
              boxShadow: hover
                  ? <BoxShadow>[
                      BoxShadow(
                        color: c.accent.withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: c.accentMuted,
                  borderRadius: BorderRadius.circular(AstryxRadius.element),
                ),
                child: Center(
                  child: AceIconView(icon: prompt.icon, size: 20, color: c.accent),
                ),
              ),
              const Spacer(),
              Text(
                prompt.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AstryxText.bodyStrong(c.textPrimary),
              ),
              const SizedBox(height: AstryxSpace.s0_5),
              Text(
                prompt.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AstryxText.supporting(c.textSecondary),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Something Chyme wants to do, and has not done.
class _Proposal {
  const _Proposal({
    required this.name,
    required this.argument,
    required this.label,
  });

  final String name;
  final String argument;
  final String label;
}

/// The button that stands between a proposal and the mail.
class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.proposal,
    required this.onConfirm,
    required this.onDismiss,
  });

  final _Proposal proposal;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return Container(
      padding: const EdgeInsets.all(AstryxSpace.s3),
      decoration: BoxDecoration(
        color: c.accentMuted,
        borderRadius: BorderRadius.circular(AstryxRadius.container),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              AceIconView(icon: AceIcons.chyme, size: 16, color: c.accent),
              const SizedBox(width: AstryxSpace.s2),
              Expanded(
                child: Text(
                  'Chyme wants to',
                  style: AstryxText.caption(c.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AstryxSpace.s1),
          Text(proposal.label, style: AstryxText.bodyStrong(c.textPrimary)),
          const SizedBox(height: AstryxSpace.s3),
          Row(
            children: <Widget>[
              AceButton(
                label: 'Do it',
                variant: AceButtonVariant.primary,
                onPressed: onConfirm,
              ),
              const SizedBox(width: AstryxSpace.s2),
              AceButton(
                label: 'No',
                variant: AceButtonVariant.ghost,
                onPressed: onDismiss,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What happened after a button was pressed.
class _DoneNote extends StatelessWidget {
  const _DoneNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AceIconView(icon: AceIcons.check, size: 15, color: c.textSecondary),
        const SizedBox(width: AstryxSpace.s2),
        Expanded(
          child: Text(text, style: AstryxText.supporting(c.textSecondary)),
        ),
      ],
    );
  }
}

/// The suggestion cards, fanned along an arc.
///
/// One card per prompt, placed on a circle whose centre is below the sheet: the
/// middle card is upright, each neighbour is turned by a step and pushed down
/// and out along the curve, and the outermost are half off the edge. Which is
/// what makes it read as a hand of cards offered rather than a list to scroll —
/// the shape does the inviting, and the middle card is the one it is offering.
class _SuggestionArc extends StatelessWidget {
  const _SuggestionArc({required this.prompts, required this.onPick});

  final List<_Prompt> prompts;
  final void Function(String prompt) onPick;

  /// How far apart the cards sit, in radians.
  static const double _step = 0.125;

  /// How far away the circle is. Larger is a flatter arc; this one is tight
  /// enough that three cards read as a curve and loose enough that the middle
  /// card is not tilted.
  static const double _radius = 620;

  static const double _height = 210;
  static const double _cardHeight = 168;

  @override
  Widget build(BuildContext context) {
    if (prompts.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: _height,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          final double cardWidth =
              (box.maxWidth * 0.52).clamp(150.0, 200.0);
          final double centre = box.maxWidth / 2;
          final int middle = (prompts.length - 1) ~/ 2;

          // Outer cards first, so the middle one paints on top of its
          // neighbours rather than under them.
          final List<int> order = List<int>.generate(prompts.length, (int i) => i)
            ..sort((int a, int b) =>
                (b - middle).abs().compareTo((a - middle).abs()));

          // Wider than the sheet, and scrollable, so a phone that cannot show
          // five cards in an arc can still reach the ones off the edge. It was
          // a bare Stack: the outermost cards were cut off with no way to get
          // to them, which turned "suggestions" into "the middle one".
          final double reach = centre + _radius * math.sin(
                _step * (prompts.length - 1 - middle),
              ) + cardWidth / 2;

          final Widget arc = SizedBox(
            width: math.max(box.maxWidth, reach * 2),
            height: _height,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                for (final int index in order)
                  _placed(
                    context,
                    index: index,
                    middle: middle,
                    centre: math.max(box.maxWidth, reach * 2) / 2,
                    cardWidth: cardWidth,
                  ),
              ],
            ),
          );

          // Scrolls only when it has to: a wide screen shows the whole arc and
          // a drag there does nothing, which is what a hand of cards should do.
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            // Air at both ends, so the outermost card is not cut by the sheet's
            // own edge when it is scrolled to.
            padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s5),
            child: arc,
          );
        },
      ),
    );
  }

  Widget _placed(
    BuildContext context, {
    required int index,
    required int middle,
    required double centre,
    required double cardWidth,
  }) {
    final int offset = index - middle;
    final double angle = offset * _step;
    final double distance = offset.abs().toDouble();

    // Along the circle: x is the chord, y is how far the curve has dropped.
    final double x = _radius * math.sin(angle);
    final double y = _radius * (1 - math.cos(angle));

    // The outermost cards shrink and fade a little, which is what makes the
    // middle one the one being offered.
    final double scale = (1 - 0.07 * distance).clamp(0.72, 1.0);
    final double opacity = (1 - 0.22 * distance).clamp(0.45, 1.0);

    final _Prompt item = prompts[index];

    return Positioned(
      left: centre + x - cardWidth / 2,
      top: y + (_height - _cardHeight) / 2,
      width: cardWidth,
      // Bounded height: the card ends in a Spacer, and a Spacer in an
      // unbounded column is a layout error rather than a card.
      child: SizedBox(
        height: _cardHeight,
        child: Opacity(
          opacity: opacity,
          child: Transform.rotate(
            angle: angle,
            // Turned about its bottom edge, like a card held in a hand.
            alignment: Alignment.bottomCenter,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.bottomCenter,
              child: _PromptCard(
                prompt: item,
                width: cardWidth,
                onTap: () => onPick(item.prompt),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
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
import '../util/routes.dart';
import '../util/haptics.dart';
import 'ace_confirm.dart';
import 'ace_form_field.dart';
import 'ace_glass.dart';
import 'astryx_widgets.dart';
import 'chyme_mark.dart';
import 'chyme_pickers.dart';
import 'voice_button.dart';
import 'chyme/chyme_setting_chip.dart';
import 'chyme/chyme_bubble.dart';
import 'chyme/chyme_search_offer.dart';
import 'chyme/chyme_not_set_up.dart';
import 'chyme/chyme_prompt.dart';
import 'chyme/chyme_proposal.dart';
import 'chyme/chyme_done_note.dart';
import 'chyme/chyme_suggestion_arc.dart';

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
  final List<ChymeProposal> _pending = <ChymeProposal>[];

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
    if (_pending.any((ChymeProposal p) => p.name == name && p.argument == argument)) {
      return;
    }
    _pending.add(ChymeProposal(
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
  Future<void> _confirmProposal(ChymeProposal proposal) async {
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

  void _dismissProposal(ChymeProposal proposal) {
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
                            ChymeSettingChip(
                              label: prefs.chymeModel.isEmpty
                                  ? 'Choose a model'
                                  : prefs.chymeModel,
                              icon: AceIcons.chyme,
                              onTap: () => chooseChymeModel(context, prefs),
                            ),
                            const SizedBox(width: AstryxSpace.s1_5),
                            ChymeSettingChip(
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
                  ? ChymeNotSetUp(onConfigure: _openSettings)
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
                          ChymeBubble(
                            turn: turn,
                            onReply: _replyWith,
                            canReply: context
                                    .watch<MailController>()
                                    .openSummary !=
                                null,
                          ),
                        for (final ChymeProposal proposal in _pending) ...<Widget>[
                          const SizedBox(height: AstryxSpace.s3),
                          ChymeProposalCard(
                            proposal: proposal,
                            onConfirm: () => _confirmProposal(proposal),
                            onDismiss: () => _dismissProposal(proposal),
                          ),
                        ],
                        for (final String note in _done) ...<Widget>[
                          const SizedBox(height: AstryxSpace.s2),
                          ChymeDoneNote(text: note),
                        ],
                        if (_search != null)
                          ChymeSearchOffer(
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

    final List<ChymePrompt> prompts = <ChymePrompt>[
      if (hasOpen)
        ChymePrompt(
          icon: AceIcons.mailOpen,
          title: 'What is this asking for?',
          subtitle: 'Read it, and tell me',
          prompt: 'What is this actually asking me for?',
        ),
      if (hasOpen)
        ChymePrompt(
          icon: AceIcons.reply,
          title: 'Draft a reply',
          subtitle: 'Opens in your composer',
          prompt: 'Draft a reply saying I will look at it tomorrow.',
        ),
      ChymePrompt(
        icon: AceIcons.inbox,
        title: 'What needs answering?',
        subtitle: 'Today, in one list',
        prompt: 'What needs answering today?',
      ),
      ChymePrompt(
        icon: AceIcons.search,
        title: 'Find an invoice',
        subtitle: 'Search your mail',
        prompt: 'Find the last invoice or receipt.',
      ),
      ChymePrompt(
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
        ChymeSuggestionArc(
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

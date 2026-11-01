import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';

import '../data/preferences.dart';
import '../models/full_message.dart';
import '../models/message_summary.dart';
import '../screens/compose_screen.dart';
import '../screens/settings_screen.dart';
import '../services/chyme.dart';
import '../services/chyme_prompt.dart';
import '../services/chyme_tools.dart';
import '../services/chyme_tool_registry.dart';
import '../state/mail_controller.dart';
import '../state/chyme_conversation.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/ace_snack.dart';
import '../util/routes.dart';
import 'ace_confirm.dart';
import 'ace_form_field.dart';
import 'ace_icon_view.dart';
import 'ace_glass.dart';
import 'astryx_widgets.dart';
import 'chyme_mark.dart';
import 'chyme_pickers.dart';
import 'markdown_view.dart';

part 'chyme/setting_chip.dart';
part 'chyme/bubble.dart';
part 'chyme/offers.dart';
part 'chyme/conversation_cards.dart';
part 'chyme/suggestion_arc.dart';

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
  late final ChymeConversation _conversation;

  bool _busy = false;
  String? _error;

  /// The search the last reply asked for, if it asked for one.
  String? _search;

  @override
  void initState() {
    super.initState();
    _conversation = context.read<ChymeConversation>();
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
    final ChymeConfig config = ChymeConfig.fromPreferences(prefs);
    if (!config.isConfigured) {
      setState(() => _error = 'Chyme has no endpoint or model yet.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _search = null;
    });
    _conversation.add(ChymeTurn('user', prompt));
    _input.clear();
    _scrollToEnd();

    try {
      final MailController controller = context.read<MailController>();
      final List<ChymeTurn> request = <ChymeTurn>[
        ChymeTurn(
          'system',
          ChymePrompt.forMail(
            preferences: prefs,
            visible: controller.visibleMessages,
            open: controller.openMessage,
          ),
        ),
        ..._conversation.turns,
      ];

      // A loop, not one request: Chyme asks to read something, the app reads it,
      // and the answer goes back into the conversation. Anything that *changes*
      // mail is proposed instead, and waits for a button below the answer.
      final ChymeRun run = await Chyme.run(
        endpoint: config.endpoint,
        apiKey: config.apiKey,
        model: config.model,
        turns: request,
        tools: _tools(controller),
      );
      if (!mounted) return;
      _conversation.add(ChymeTurn('assistant', run.reply));
      setState(() => _search = ChymeReply.parse(run.reply).search);
      _scrollToEnd();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error is ChymeException || error is ChymeNotConfigured
          ? error.toString()
          : 'Chyme could not complete that request. Check the endpoint and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// What Chyme has proposed and the person has not answered yet.
  final List<_Proposal> _pending = <_Proposal>[];

  /// What was actually done, once somebody said yes.
  final List<String> _done = <String>[];

  /// The tools Chyme is given: reads run, writes wait for a button.
  ChymeToolRegistry _toolRegistry(MailController controller) => ChymeToolRegistry(
        controller: controller,
        confirm: _ask,
        openReply: _openReply,
        isMounted: () => mounted,
      );

  Map<String, ChymeTool> _tools(MailController controller) {
    final Map<String, ChymeTool> real = _toolRegistry(controller).build();
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
      ChymeToolNames.star => subject.isEmpty ? 'Star it' : 'Star “$subject”',
      ChymeToolNames.unstar => subject.isEmpty ? 'Remove the star' : 'Unstar “$subject”',
      ChymeToolNames.seen => subject.isEmpty ? 'Mark it read' : 'Mark “$subject” read',
      ChymeToolNames.archive => subject.isEmpty ? 'Archive it' : 'Archive “$subject”',
      ChymeToolNames.delete => subject.isEmpty ? 'Delete it' : 'Delete “$subject”',
      ChymeToolNames.reply => 'Open this reply in the composer',
      ChymeToolNames.contactAdd => 'Save this address to contacts',
      ChymeToolNames.contactBlock => 'Block ${(ChymeToolArgument.parse(argument).tail ?? ChymeToolArgument.parse(argument).head)}',
      ChymeToolNames.contactDelete => 'Forget ${(ChymeToolArgument.parse(argument).tail ?? ChymeToolArgument.parse(argument).head)}',
      _ => name,
    };
  }

  String _subjectFor(String argument) {
    final MailController controller = context.read<MailController>();
    final MessageSummary? message = _toolRegistry(controller).find(argument);
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
      final ChymeTool? tool = _toolRegistry(controller).build()[proposal.name];
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
  /// A question with the detail in it, answered before anything is destroyed.
  Future<bool> _ask({
    required String title,
    required String body,
    required String confirm,
    required String cancel,
  }) => aceConfirm(context, title: title, body: body, confirm: confirm, cancel: cancel, destructive: confirm == 'Delete' || confirm == 'Forget');

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

  Future<void> _openReply({required MessageSummary message, required String body}) async {
    final MailController controller = context.read<MailController>();
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
    final List<ChymeTurn> turns = context.watch<ChymeConversation>().turns;
    final AstryxColors c = context.astryx;
    final Preferences prefs = context.watch<Preferences>();
    final bool configured = Chyme.isConfigured(prefs);
    final MailController controller = context.watch<MailController>();

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
                        if (turns.isEmpty)
                          _suggestions(c, controller),
                        for (final ChymeTurn turn in turns)
                          ChymeBubble(
                            turn: turn,
                            onReply: _replyWith,
                            canReply: controller.openSummary != null,
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

/// One of the header's two settings, as a chip.

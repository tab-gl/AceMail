import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/mail_providers.dart';
import '../data/preferences.dart';
import '../models/ace_account.dart';
import '../models/sign_in_form.dart';
import '../services/google_auth.dart';
import '../state/mail_controller.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/redact.dart';
import '../util/routes.dart';
import '../widgets/ace_form_field.dart';
import '../widgets/legal_sheet.dart';
import '../widgets/advanced_server_panel.dart';
import '../widgets/astryx_widgets.dart';
import '../widgets/confirm_exit.dart';
import '../widgets/settings_group.dart';
import 'tutorial_screen.dart';
import '../widgets/ace_icon_view.dart';

/// The app's front door, and the entry point for adding a second account.
///
/// In [isAdding] mode it sits on top of an existing session and can be
/// dismissed; otherwise back asks whether to quit.
///
/// Failures are shown in exactly one place — the inline box below the fields.
/// Validation problems and connection errors both land there, so a rejected
/// password does not look different depending on which layer rejected it.
class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    this.isAdding = false,
    this.googleSignIn,
  });

  /// True when this is a second (or third) account being added on top of an
  /// existing session, in which case the screen can be dismissed.
  final bool isAdding;

  /// Injectable so the sign-in flow can be tested without opening a real
  /// Google account chooser. Production screens use [GoogleAuth.signIn].
  final Future<GoogleCredential> Function()? googleSignIn;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late final SignInFormModel _form;

  /// The most recent validation failure. Cleared on the next attempt.
  String? _validationError;

  /// Google auth begins before the mail connection, so the controller's
  /// connecting flag alone cannot prevent repeated taps during OAuth.
  bool _googleSigningIn = false;

  @override
  void initState() {
    super.initState();
    // Prefill the last address used, unless we are adding a second account.
    _form = SignInFormModel(
      initialEmail: widget.isAdding
          ? ''
          : (context.read<MailController>().lastEmail ?? ''),
    );
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  /// Whether the welcome panel is still showing.
  ///
  /// Not one of the steps: it has no fields and nothing to validate, and the
  /// step dots would be counting a screen that is not part of the form. Adding
  /// an account skips it — you already know what this app is.
  late bool _welcome = !widget.isAdding;

  /// 0 is the welcome panel, 1 is the address, 2 is the password. Adding an
  /// account skips the welcome panel because the person has already signed in.
  late int _step = widget.isAdding ? 1 : 0;

  void _nextStep() {
    final String? problem = _form.addressProblem();
    if (problem != null) {
      setState(() => _validationError = problem);
      return;
    }
    setState(() {
      _validationError = null;
      _step = 2;
    });
  }

  /// Off the welcome panel and into the form.
  void _getStarted() => setState(() {
        _welcome = false;
        _step = 1;
      });

  Future<void> _submit() async {
    final SignInOutcome outcome = _form.build();
    setState(() {
      _validationError = outcome.error;
      if (outcome.needsAdvanced) _form.advanced = true;
    });

    final AceAccount? account = outcome.account;
    if (account == null) return;

    final bool ok =
        await context.read<MailController>().signIn(account, _form.password.text);
    if (!mounted) return;
    if (ok) {
      TextInput.finishAutofillContext();
      if (widget.isAdding) Navigator.of(context).pop();
    }
  }

  /// Signs in through Google, and adds whichever account it returns.
  ///
  /// The account that gets added is Google's answer, not the address typed on
  /// the first step: the two can differ, and the mailbox that authorised is the
  /// one that will work. The token comes back with it, so the first connection
  /// does not wait for a second round trip.
  Future<void> _continueWithGoogle() async {
    final MailController controller = context.read<MailController>();
    if (_googleSigningIn || controller.connecting) return;

    setState(() {
      _googleSigningIn = true;
      _validationError = null;
    });

    try {
      final GoogleCredential credential =
          await (widget.googleSignIn ?? GoogleAuth.signIn)();
      final AceAccount? account = _form.googleAccount(credential.email);
      if (account == null) {
        if (mounted) {
          setState(() => _validationError =
              'That is not a mailbox address Ace Mail knows the servers for.');
        }
        return;
      }

      final bool ok = await controller.signIn(account, credential.token);
      if (!mounted) return;
      if (ok) {
        if (widget.isAdding) Navigator.of(context).pop();
      } else {
        setState(() => _validationError =
            controller.errorMessage ?? 'Could not reach that mailbox.');
      }
    } on GoogleAuthException catch (error) {
      if (mounted) setState(() => _validationError = error.message);
    } catch (error) {
      // Platform-channel and unexpected failures should produce an actionable
      // inline error, not an uncaught Flutter exception. Keep logs credential-safe.
      debugPrint('Ace Mail: Google sign-in failed (${Redact.safe(error)})');
      if (mounted) {
        setState(() => _validationError =
            'Google sign-in could not be completed. Check your connection and '
            'Google sign-in configuration, then try again.');
      }
    } finally {
      if (mounted) setState(() => _googleSigningIn = false);
    }
  }

  void _openTutorial() {
    Navigator.of(context).push(aceRoute(const TutorialScreen()));
  }

  Future<void> _handleBack() async {
    if (widget.isAdding) {
      Navigator.of(context).pop();
      return;
    }
    // The user can turn the confirmation off; then leaving just leaves.
    final Preferences prefs = context.read<Preferences>();
    if (prefs.confirmExit && !await confirmExit(context)) return;
    if (!mounted) return;
    final NavigatorState nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final MailController controller = context.watch<MailController>();
    final bool connecting = controller.connecting;
    final bool googleBusy = _googleSigningIn || connecting;
    final String? error = _validationError ?? controller.errorMessage;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: <Color>[c.accentMuted, c.backgroundBody, c.backgroundMuted],
            ),
          ),
          child: SafeArea(
            // The page, not a card on it.
            //
            // It was a centred, 520-wide, rounded, frosted panel — which is a
            // *web* sign-in form, and it read as one. A phone screen is not a
            // browser: there is no page behind this to float over, the fields
            // belong at the edges, and the way to look like the system is to
            // stop drawing a box around yourself.
            //
            // The width is capped and left-aligned rather than centred, so a
            // tablet gets a readable column against the edge instead of a
            // floating island in the middle.
            child: Align(
              alignment: Alignment.topLeft,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AstryxSpace.s6,
                  AstryxSpace.s7,
                  AstryxSpace.s6,
                  AstryxSpace.s6,
                ),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  builder: (BuildContext context, double t, Widget? child) =>
                      Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, (1 - t) * 14),
                      child: child,
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: _SignInSheet(
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _header(context, c),
                            const SizedBox(height: AstryxSpace.s6),
                            if (!_welcome)
                              _StepTrail(
                                step: _step - 1,
                                google: _form.isGoogle,
                              ),
                            const SizedBox(height: AstryxSpace.s4),
                            AnimatedSize(
                              duration: AstryxMotion.medium,
                              curve: AstryxMotion.emphasized,
                              alignment: Alignment.topCenter,
                              child: AnimatedSwitcher(
                                duration: AstryxMotion.medium,
                                switchInCurve: AstryxMotion.emphasizedDecelerate,
                                switchOutCurve: Curves.easeIn,
                                transitionBuilder: (
                                  Widget child,
                                  Animation<double> animation,
                                ) {
                                  final bool forward = _step == 1;
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: Offset(forward ? 0.12 : -0.12, 0),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                                child: _step == 2
                                    ? Column(
                                        key: const ValueKey<int>(2),
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          // Only for a Google address. A
                                          // Google button offered to somebody
                                          // who has just typed their work
                                          // address at a company that runs its
                                          // own mail is a button that cannot
                                          // work, and one that fails loudly on
                                          // the screen where they are trying to
                                          // sign in.
                                          if (_form.isGoogle) ...<Widget>[
                                            Text(
                                              'Ace Mail opens Google\u2019s own '
                                              'sign-in. It never sees your '
                                              'password, and there is nothing '
                                              'to store afterwards — the '
                                              'mailbox is reached with a token '
                                              'that expires.',
                                              style: AstryxText.supporting(
                                                  c.textSecondary),
                                            ),
                                            const SizedBox(
                                                height: AstryxSpace.s5),
                                            // The white one with Google's own
                                            // mark on it, not a themed button:
                                            // a Google sign-in button looks
                                            // like this everywhere, and one
                                            // that has been restyled is a
                                            // button people hesitate over.
                                            _GoogleButton(
                                              busy: googleBusy,
                                              onPressed: googleBusy
                                                  ? null
                                                  : _continueWithGoogle,
                                            ),
                                            const SizedBox(
                                                height: AstryxSpace.s4),
                                            // And the other way in, said to be
                                            // the other way in rather than left
                                            // as a second set of fields.
                                            Row(
                                              children: <Widget>[
                                                const Expanded(
                                                    child: Divider()),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: AstryxSpace.s3,
                                                  ),
                                                  child: Text(
                                                    'or use an app password',
                                                    style: AstryxText.supporting(
                                                        c.textSecondary),
                                                  ),
                                                ),
                                                const Expanded(
                                                    child: Divider()),
                                              ],
                                            ),
                                            const SizedBox(
                                                height: AstryxSpace.s4),
                                          ],
                                          AcePasswordField(
                                              label: 'Password / app password',
                                              controller: _form.password,
                                              obscure: _form.obscure,
                                              autofillHints: const <String>[
                                                AutofillHints.password,
                                              ],
                                              onToggleObscure: () => setState(
                                                () => _form.obscure =
                                                    !_form.obscure,
                                              ),
                                            ),
                                            const SizedBox(
                                                height: AstryxSpace.s3),
                                            AdvancedServerPanel(
                                              form: _form,
                                              onToggle: () => setState(
                                                () => _form.advanced =
                                                    !_form.advanced,
                                              ),
                                            ),
                                            const SizedBox(
                                                height: AstryxSpace.s5),
                                            AceButton(
                                              label: connecting
                                                  ? 'Connecting…'
                                                  : 'Connect',
                                              variant: AceButtonVariant.primary,
                                              size: AceButtonSize.large,
                                              loading: connecting,
                                              expand: true,
                                              onPressed:
                                                  connecting ? null : _submit,
                                            ),
                                          ],
                                      )
                                    : _step == 1
                                    ? Column(
                                        key: const ValueKey<int>(1),
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          // Side by side, and the second one
                                          // is the provider's own mark rather
                                          // than its domain written out.
                                          //
                                          // It was a text field showing
                                          // `@gmail.com`, sharing the width
                                          // with the username, and it lost:
                                          // the text came out `@gmail.c`, cut
                                          // off mid-word with no ellipsis to
                                          // say so. A mark is a fixed size and
                                          // cannot be cut off — and it says
                                          // which provider you picked better
                                          // than the domain does, because you
                                          // picked it by its mark a screen
                                          // ago.
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: <Widget>[
                                              Expanded(
                                                child: AceFormField(
                                                  label: 'Username',
                                                  controller: _form.username,
                                                  hint: 'you',
                                                  keyboard: TextInputType
                                                      .emailAddress,
                                                  autofillHints: const <String>[
                                                    AutofillHints.username,
                                                    AutofillHints.email,
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(
                                                  width: AstryxSpace.s3),
                                              _DomainField(
                                                form: _form,
                                                onChanged: () =>
                                                    setState(() {}),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: AstryxSpace.s5),
                                          AceButton(
                                            label: 'Continue',
                                            variant: AceButtonVariant.primary,
                                            size: AceButtonSize.large,
                                            icon: AceIcons.chevronRight,
                                            expand: true,
                                            onPressed: _nextStep,
                                          ),
                                          const SizedBox(height: AstryxSpace.s2),
                                          Center(
                                            child: TextButton(
                                              onPressed: () => context
                                                  .read<MailController>()
                                                  .startExploring(),
                                              child: Text(
                                                'Look around first',
                                                style: AstryxText.body(
                                                    c.textAccent),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : _welcomePanel(c),
                              ),
                            ),
                            const SizedBox(height: AstryxSpace.s3),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.topCenter,
                              // Step 2 only. The error used to be rendered
                              // outside the step switcher, so a Google
                              // sign-in failure appeared on the address step as
                              // well — a red box on a screen with no Google
                              // button and nothing that could have failed.
                              child: error == null || _step != 2
                                  ? const SizedBox(width: double.infinity)
                                  : Padding(
                                      padding: const EdgeInsets.only(
                                        top: AstryxSpace.s4,
                                      ),
                                      child: AceErrorBox(
                                        message: error,
                                        action: AceButton(
                                          label: 'How to fix this',
                                          icon: AceIcons.help,
                                          onPressed: _openTutorial,
                                        ),
                                      ),
                                    ),
                            ),
                            // A paragraph that tells you to read something is a
                            // dead end at exactly the moment somebody is stuck.
                            // It is a row now, and the thing it names is one tap
                            // away.
                            if (_form.isGoogle)
                              Text(
                                'Gmail signs in through Google rather than with '
                                'a password, so there is nothing to create, '
                                'remember or store.',
                                style: AstryxText.supporting(c.textSecondary),
                              )
                            else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      'These providers want an app password '
                                      'here, not your normal login. Your '
                                      'password stays in this device\'s '
                                      'keychain and goes only to your provider.',
                                      style: AstryxText.supporting(
                                          c.textSecondary),
                                    ),
                                  ),
                                  const SizedBox(width: AstryxSpace.s2),
                                  TextButton(
                                    onPressed: _openTutorial,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AstryxSpace.s2,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'How to sign in',
                                      style: AstryxText.bodyStrong(
                                          c.textAccent),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The first thing anybody sees.
  ///
  /// It says what the app is, what it will do with your mail, and what it will
  /// not do — in three lines, because that is the whole pitch of a mail client
  /// you sign into with an app password. The legal footer is here rather than
  /// buried in Settings: this is the screen where somebody decides to trust it
  /// with a credential.
  /// Takes a provider's first domain and moves on to the address.
  void _pickProvider(MailProvider provider) {
    _form.domain = provider.domains.first;
    // Fills the server fields, so the common case never opens the advanced
    // panel — the same thing the domain picker on the next step does.
    _form.applyProvider();
    _getStarted();
  }

  Widget _welcomePanel(AstryxColors c) {
    return Column(
      key: const ValueKey<int>(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // One phrase in the accent. "terms" is the promise; the rest is the
        // sentence around it, and colouring the word is how a headline says
        // which word it means.
        Text.rich(
          TextSpan(
            style: AstryxText.display3(c.textPrimary),
            children: <InlineSpan>[
              const TextSpan(text: 'Your mail,\non your '),
              TextSpan(
                text: 'terms.',
                style: TextStyle(color: c.accent),
              ),
            ],
          ),
        ),
        const SizedBox(height: AstryxSpace.s3),
        Text(
          'Any provider that speaks IMAP and SMTP. No account to make here, no '
          'server in the middle, and nothing to sign up for.',
          style: AstryxText.body(c.textSecondary),
        ),
        const SizedBox(height: AstryxSpace.s6),

        // The providers, first, as themselves.
        //
        // This used to be a "Get started" button, which asked for nothing and
        // told you nothing: you pressed it to find out what the next screen
        // wanted, and the next screen wanted to know where your mail is. Asking
        // that question here is the same amount of work for somebody who knows
        // the answer, and it answers itself for the majority who are about to
        // type one of six addresses.
        //
        // No Google button here. It lives on the credentials step, where the
        // address has been chosen and the app knows whether this is a Google
        // account — offering it in two places, one of them before the question
        // has been asked, is how you end up with two buttons that do the same
        // thing and an error message on a screen with nothing to fail.
        Text('Where is your mail?', style: AstryxText.heading4(c.textPrimary)),
        const SizedBox(height: AstryxSpace.s1),
        Text(
          'Choose your email provider to get started.',
          style: AstryxText.body(c.textSecondary),
        ),
        const SizedBox(height: AstryxSpace.s4),
        // Three to a row, as cards. The marks are the answer to the question,
        // and a grid of six is a question you can answer without reading.
        for (int row = 0; row < kProviderChoices.length; row += 3) ...<Widget>[
          // IntrinsicHeight, because stretch inside a scroll view has no
          // height to stretch to — the row is in a Column that scrolls, so its
          // height is unbounded and "match the tallest" needs to be measured.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
              for (int i = row; i < row + 3; i++) ...<Widget>[
                if (i > row) const SizedBox(width: AstryxSpace.s2),
                Expanded(
                  child: i < kProviderChoices.length
                      ? _ProviderCard(
                          provider: kProviderChoices[i],
                          onTap: () => _pickProvider(kProviderChoices[i]),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
          ),
          const SizedBox(height: AstryxSpace.s2),
        ],
        _OtherProviderCard(onTap: _getStarted),
        const SizedBox(height: AstryxSpace.s6),

        // The reasons, after the way in rather than before it. Somebody who has
        // already decided does not want to read three paragraphs first, and
        // somebody who has not will scroll anyway.
        for (int i = 0; i < _points.length; i++) ...<Widget>[
          if (i > 0)
            Divider(
              height: AstryxSpace.s5,
              color: c.border.withValues(alpha: 0.5),
            ),
          _Point(
            icon: _points[i].icon,
            title: _points[i].title,
            body: _points[i].body,
          ),
          if (i < _points.length - 1) const SizedBox(height: AstryxSpace.s4),
        ],
        const SizedBox(height: AstryxSpace.s1),
        Center(
          child: TextButton(
            onPressed: () => context.read<MailController>().startExploring(),
            child: Text(
              'Look around first',
              style: AstryxText.body(c.textAccent),
            ),
          ),
        ),
        const SizedBox(height: AstryxSpace.s2),
        // The consent line. Both halves are one tap from here, because a policy
        // you cannot read is not a policy you agreed to.
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              'By continuing you agree to the ',
              style: AstryxText.supporting(c.textSecondary),
            ),
            _LegalLink(
              label: 'Terms',
              onTap: () => LegalSheet.show(context, startAt: LegalDocument.terms),
            ),
            Text(
              ' and the ',
              style: AstryxText.supporting(c.textSecondary),
            ),
            _LegalLink(
              label: 'Privacy Policy',
              onTap: () =>
                  LegalSheet.show(context, startAt: LegalDocument.privacy),
            ),
            Text('.', style: AstryxText.supporting(c.textSecondary)),
          ],
        ),
      ],
    );
  }

  /// The Google sign-in button.
  ///
  /// Its own widget rather than an [AceButton] because the mark is the
  /// provider's own artwork, and a button that takes an icon can only take
  /// ours. It is also the one place in the app that is deliberately white: a
  /// Google sign-in button looks like this everywhere, and inventing a themed
  /// one would be a button people hesitate over.
  ///
  /// The three things worth saying before a password is typed.
  static const List<({AceIcon icon, String title, String body})> _points =
      <({AceIcon icon, String title, String body})>[
    (
      icon: AceIcons.lock,
      title: 'Your password stays in the keychain',
      body: 'The app password goes into the device keychain, never to us — '
          'there is nowhere for it to go.',
    ),
    (
      icon: AceIcons.image,
      title: 'Nothing is loaded behind your back',
      body: 'Remote images are a read receipt, so they are a choice. So is '
          'looking up a sender\'s picture.',
    ),
    (
      icon: AceIcons.shield,
      title: 'What is kept is encrypted',
      body: 'Drafts and messages you have read are sealed with AES-256-GCM on '
          'this device, and can be cleared in one tap.',
    ),
  ];

  Widget _header(BuildContext context, AstryxColors c) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const BrandMark(),
        const SizedBox(width: AstryxSpace.s4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Ace Mail', style: AstryxText.display3(c.textPrimary)),
              const SizedBox(height: AstryxSpace.s0_5),
              Text(
                widget.isAdding
                    ? 'Add another account'
                    : 'Any IMAP · any SMTP · any device',
                style: AstryxText.body(c.textSecondary),
              ),
            ],
          ),
        ),
        AceIconButton(
          icon: AceIcons.help,
          tooltip: 'How to sign in',
          onPressed: _openTutorial,
        ),
        if (widget.isAdding)
          AceIconButton(
            icon: AceIcons.close,
            tooltip: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),
      ],
    );
  }
}

/// The domain half of the address: a picker for the providers we know, and a
/// plain field for anything else.
///
/// Picking a known domain is what fills in the IMAP and SMTP servers, so the
/// common case never opens the advanced panel at all.
class _DomainField extends StatefulWidget {
  const _DomainField({required this.form, required this.onChanged});

  final SignInFormModel form;
  final VoidCallback onChanged;

  @override
  State<_DomainField> createState() => _DomainFieldState();
}

class _DomainFieldState extends State<_DomainField> {
  // The controller that used to live here rendered the domain as text in the
  // field this widget no longer has — it draws the provider's mark instead, so
  // there is nothing for a controller to hold.

  @override
  Widget build(BuildContext context) {
    if (widget.form.customDomain) {
      return AceFormField(
        label: 'Domain',
        controller: widget.form.domainField,
        hint: 'example.com',
        keyboard: TextInputType.url,
        trailing: AceIconButton(
          icon: AceIcons.list,
          tooltip: 'Pick a provider',
          onPressed: () => _pick(context),
        ),
      );
    }

    final AstryxColors c = context.astryx;
    final MailProvider? known = _knownProvider;

    // The provider's own mark, at a fixed size, instead of its domain written
    // out. A mark cannot be cut off, and it answers the question the row is
    // asking better than the text did — this is the provider that was picked,
    // by the same picture that was used to pick it.
    return Semantics(
      button: true,
      label: known == null ? 'Choose a provider' : 'Change provider',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('Provider', style: AstryxText.supporting(c.textSecondary)),
          const SizedBox(height: AstryxSpace.s1),
          InkWell(
            onTap: () => _pick(context),
            borderRadius: BorderRadius.circular(AstryxRadius.inner),
            child: Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: c.backgroundMuted,
                borderRadius: BorderRadius.circular(AstryxRadius.inner),
                border: Border.all(color: c.border),
              ),
              child: known == null
                  ? AceIconView(
                      icon: AceIcons.at,
                      size: 20,
                      color: c.textSecondary,
                    )
                  : SvgPicture.asset(known.logo, fit: BoxFit.contain),
            ),
          ),
        ],
      ),
    );
  }

  /// The provider whose domain this is, if it is one we know.
  MailProvider? get _knownProvider {
    for (final MailProvider provider in kProviderChoices) {
      if (provider.domains.contains(widget.form.domain)) return provider;
    }
    return null;
  }

  Future<void> _pick(BuildContext context) async {
    final String? chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: AstryxSpace.s4),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AstryxSpace.s5,
                0,
                AstryxSpace.s5,
                AstryxSpace.s3,
              ),
              child: Text(
                'Your mail provider',
                style: AstryxText.heading3(sheetContext.astryx.textPrimary),
              ),
            ),
            for (final MailProvider provider in kProviderChoices)
              SettingsRow(
                icon: AceIcons.at,
                leading: _ProviderTile(provider: provider),
                title: provider.label,
                // Every domain the provider hands out, not just the first:
                // Gmail hands out two, and people use the one they were given.
                subtitle: provider.domains.join('  ·  '),
                trailing: provider.domains.contains(widget.form.domain)
                    ? AceIconView(
                        icon: AceIcons.check,
                        size: 20,
                        color: sheetContext.astryx.accent,
                      )
                    : null,
                onTap: () => chooseProvider(sheetContext, provider),
              ),
            const Divider(height: 1),
            SettingsRow(
              icon: AceIcons.edit,
              title: 'Other',
              subtitle: 'Type your own domain and servers',
              onTap: () => Navigator.of(sheetContext).pop(_kCustomDomain),
            ),
          ],
        ),
      ),
    );

    if (chosen == null) return;
    if (chosen == _kCustomDomain) {
      widget.form.customDomain = true;
      widget.form.advanced = true;
    } else {
      widget.form.customDomain = false;
      widget.form.domain = chosen;
      // Selecting a domain fills the servers from the table.
      widget.form.applyProvider();
    }
    widget.onChanged();
  }
}

/// Marks the "type your own" row, which is not a domain.
const String _kCustomDomain = '\u0000custom';

/// Which of the two steps you are on. Two dots, because two steps.
/// Where you are in the two steps, named.
///
/// It was a pair of dots with a floating label, which says "there is more" and
/// nothing else — not what the steps are, not which one you are on, and not
/// that the second one is called something different depending on the address
/// you just typed. A trail of named steps says all three, and it is the same
/// height.
class _StepTrail extends StatelessWidget {
  const _StepTrail({required this.step, required this.google});

  final int step;

  /// Whether the address on the first step is a Google one, which decides what
  /// the second step is called.
  final bool google;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final List<String> labels = <String>[
      'Address',
      google ? 'Google' : 'Password',
    ];

    return Row(
      children: <Widget>[
        for (int i = 0; i < labels.length; i++) ...<Widget>[
          _StepChip(
            number: i + 1,
            label: labels[i],
            active: i == step,
            done: i < step,
          ),
          if (i == 0)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AstryxSpace.s2,
                ),
                child: AnimatedContainer(
                  duration: AstryxMotion.medium,
                  curve: AstryxMotion.emphasized,
                  height: 2,
                  color: step > 0 ? c.accent : c.border,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// One step: a number that becomes a tick, and its name.
class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.number,
    required this.label,
    required this.active,
    required this.done,
  });

  final int number;
  final String label;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    // Done is not the same as active: one is behind you, one is where you are,
    // and a trail that drew them the same way would leave you guessing.
    final Color fill = done
        ? c.accentMuted
        : active
            ? c.accent
            : c.backgroundMuted;
    final Color ink = done
        ? c.onAccentMuted
        : active
            ? c.onAccent
            : c.textSecondary;

    // A 24px circle with a number in it is 24px of circle and no room for the
    // number at any text size but the default. Both follow the type, and the
    // name beside it gives way rather than pushing the trail off the edge.
    final double dot = scaledForText(context, 24, growth: 0.75);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnimatedContainer(
          duration: AstryxMotion.medium,
          curve: AstryxMotion.emphasized,
          width: dot,
          height: dot,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
          child: done
              ? AceIconView(icon: AceIcons.check, size: 14, color: ink)
              : Text('$number', style: AstryxText.label(ink)),
        ),
        const SizedBox(width: AstryxSpace.s2),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: active
                ? AstryxText.bodyStrong(c.textPrimary)
                : AstryxText.body(c.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// The provider's tile: its own logo, on a plain tile.
///
/// The tile is white so the mark's own colours are the only colours on it. A
/// logo tinted to the theme would be a logo that is subtly wrong, and a
/// provider's mark is the one thing in this row the app does not get to
/// restyle.
class _ProviderTile extends StatelessWidget {
  const _ProviderTile({required this.provider});

  final MailProvider provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AstryxRadius.inner),
        border: Border.all(color: const Color(0x1A000000)),
      ),
      child: SvgPicture.asset(provider.logo, fit: BoxFit.contain),
    );
  }
}

/// Picking a provider, and then an address if it hands out more than one.
///
/// Gmail gives you gmail.com and googlemail.com, Yahoo yahoo.com and yahoo.in,
/// and people use whichever they were handed. Silently taking the first would
/// sign someone in as an address they do not use, and they would only find out
/// when a reply went to the wrong place.
Future<void> chooseProvider(
  BuildContext sheetContext,
  MailProvider provider,
) async {
  if (provider.domains.length == 1) {
    Navigator.of(sheetContext).pop(provider.domains.first);
    return;
  }

  final String? domain = await showModalBottomSheet<String>(
    context: sheetContext,
    showDragHandle: true,
    builder: (BuildContext inner) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AstryxSpace.s5,
              0,
              AstryxSpace.s5,
              AstryxSpace.s3,
            ),
            child: Text(
              'Which ${provider.label} address?',
              style: AstryxText.heading3(inner.astryx.textPrimary),
            ),
          ),
          for (final String domain in provider.domains)
            SettingsRow(
              icon: AceIcons.at,
              leading: _ProviderTile(provider: provider),
              title: domain,
              onTap: () => Navigator.of(inner).pop(domain),
            ),
          const SizedBox(height: AstryxSpace.s3),
        ],
      ),
    ),
  );

  if (domain == null) return;
  if (!sheetContext.mounted) return;
  Navigator.of(sheetContext).pop(domain);
}

/// One line of the welcome panel.
class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.title, required this.body});

  final AceIcon icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // A plain mark, not a chip. Three coloured squares stacked up read as
        // three buttons; these are three sentences with a picture beside them.
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: AceIconView(icon: icon, size: 26, color: c.textPrimary),
        ),
        const SizedBox(width: AstryxSpace.s4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: AstryxText.bodyStrong(c.textPrimary)),
              const SizedBox(height: AstryxSpace.s0_5),
              Text(body, style: AstryxText.supporting(c.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

/// A tappable word inside a sentence.
class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AstryxRadius.inner),
      child: Text(
        label,
        style: AstryxText.supporting(c.textAccent).copyWith(
          decoration: TextDecoration.underline,
          decorationColor: c.textAccent,
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final bool enabled = onPressed != null;

    return Semantics(
      button: true,
      label: 'Continue with Google',
      child: AceSpringy(
        onTap: onPressed,
        builder: (BuildContext context, double press, bool hover) {
          return AnimatedContainer(
            duration: AstryxMotion.of(AstryxMotion.fast),
            curve: AstryxMotion.emphasized,
            height: AstryxSize.elementXl,
            decoration: BoxDecoration(
              // White in both themes. The mark is Google's, and it is drawn for
              // a white field.
              color: enabled ? const Color(0xFFFFFFFF) : c.backgroundMuted,
              borderRadius: BorderRadius.circular(AstryxRadius.pill),
              border: Border.all(color: c.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (busy)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.textSecondary,
                    ),
                  )
                else
                  SvgPicture.asset(
                    'assets/providers/gmail.svg',
                    width: 22,
                    height: 22,
                  ),
                const SizedBox(width: AstryxSpace.s3),
                Text(
                  busy ? 'Signing in…' : 'Continue with Google',
                  style: AstryxText.bodyStrong(const Color(0xFF1F1F1F)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The sign-in form, as a sheet.
///
/// Rounded at the top only, because that is the edge you can see: the other
/// three are against the screen. A handle at the top is the whole of what makes
/// something read as a sheet — it is a grip that says "this came up, and it can
/// go back down" without a word or a button.
///
/// The material is the app's own, so on a device that blurs, the gradient
/// behind shows through it; on one that cannot, it is the same sheet in the
/// same colour.
class _SignInSheet extends StatelessWidget {
  const _SignInSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // No glass, no corner, no border: the screen *is* the surface. A frosted
    // panel is the app's own material and it belongs on things that sit over
    // other things — a sheet, a bar, a card in a list. On a screen with nothing
    // behind it, it is a box drawn around a form for no reason, and a box drawn
    // around a form is what a web page looks like.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[Flexible(child: child)],
    );
  }
}

/// A provider as a card: the mark, a chevron, the name underneath.
///
/// The mark answers the question before the label is read, which is why it is
/// the biggest thing on the card and the name is the caption.
class _ProviderCard extends StatelessWidget {
  const _ProviderCard({required this.provider, required this.onTap});

  final MailProvider provider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    return Semantics(
      button: true,
      label: provider.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AstryxRadius.element),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AstryxSpace.s3,
            AstryxSpace.s3,
            AstryxSpace.s2,
            AstryxSpace.s3,
          ),
          decoration: BoxDecoration(
            color: c.surfaceHighest,
            borderRadius: BorderRadius.circular(AstryxRadius.element),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _ProviderTile(provider: provider),
                  const Spacer(),
                  AceIconView(
                    icon: AceIcons.chevronRight,
                    size: 16,
                    color: c.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: AstryxSpace.s2),
              Text(provider.label, style: AstryxText.bodyStrong(c.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The way out, as a full-width card — because it is a different kind of answer.
class _OtherProviderCard extends StatelessWidget {
  const _OtherProviderCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AstryxRadius.element),
      child: Container(
        padding: const EdgeInsets.all(AstryxSpace.s3),
        decoration: BoxDecoration(
          color: c.surfaceHighest,
          borderRadius: BorderRadius.circular(AstryxRadius.element),
        ),
        child: Row(
          children: <Widget>[
            AceIconView(icon: AceIcons.globe, size: 24, color: c.textPrimary),
            const SizedBox(width: AstryxSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Other', style: AstryxText.bodyStrong(c.textPrimary)),
                  const SizedBox(height: AstryxSpace.s0_5),
                  Text(
                    'Use any IMAP/SMTP provider',
                    style: AstryxText.supporting(c.textSecondary),
                  ),
                ],
              ),
            ),
            AceIconView(
              icon: AceIcons.chevronRight,
              size: 16,
              color: c.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

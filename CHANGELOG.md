# Changelog

Notable changes, newest first. Versions follow `pubspec.yaml`; the build number
after the `+` is the Android version code.

## 0.6.2+109

### Added
- **Ask Chyme by voice.** A microphone beside the field in the assistant's
  composer, at 48 against the 44 of every other icon button — speaking a
  question instead of typing it is the reason a phone assistant exists, and it
  should not arrive as the smallest thing in the row. What it hears lands in the
  field rather than being sent: recognition mishears, and a question that goes
  off exactly as the device heard it is one you cannot fix before it costs you
  an answer.

### Changed
- **The assistant's mark has left the search bar.** Ask Chyme has a pill along
  the bottom edge, so the second door to the same room — a small mark inside a
  search field — was two taps for one intention and one of them in the wrong
  place. The microphone keeps the slot, and is now there whether or not somebody
  is typing.

## 0.6.2+108

### Changed
- **The APKs are published as APKs.** They were only ever available as a build
  artifact, and an artifact is always a zip — there is no way to upload a bare
  file to Actions. They now go onto the rolling `apk-latest` release the moment
  the Android build finishes, as two separate assets you can tap and install,
  without waiting for the desktop or iOS builds and without unpacking anything.
  The release keeps only the current build; last version's files are cleared.

### Fixed
- **Highlights cards and the bottom bar hold their text at any text size.** Both
  were boxes with a fixed height and text inside them, which is right at the
  default size and an overflow at 1.3x — and the app multiplies the device's
  text size by its own, so 2x is a setting somebody has. The card, the folder
  bar and the room the bar takes out of the list now follow the type, the
  Compose button drops its label when the width runs out, and the tabs scale
  down rather than painting stripes through the screen.
- **The security sheet's labels no longer run into their values.** "Signed by"
  and "DMARC" were in fixed-width columns, which is the same fixed-size mistake
  one level down.

## 0.6.2+107

### Fixed
- **A mail body renders at the width of the screen again.** The HTML renderer
  was handed a loose box — a column with `CrossAxisAlignment.start` gives its
  children `minWidth: 0` — so it sized itself to its own minimum intrinsic
  width, and `width: 100%` in the sender's layout tables then resolved against
  that minimum. On a Gmail receipt it came out about one character wide and the
  body drew as `Y`, `o`, `u` down the middle of the screen. The body now takes
  the width it is given, and there is a test that lays one out in the box the
  reader actually uses.
- **Ask Chyme, Compose and the folder tabs are no longer on top of each other.**
  They were three things positioned by three different owners — the tabs from
  the left, the assistant from the centre, Compose from the right by the
  Scaffold — and a phone has no width for three pills in a row, so they drew
  over one another. One bar lays out all three now, with the assistant above
  Compose on the trailing edge, and the list keeps clearance for it.

### Changed
- **One artifact per APK.** Both APKs used to arrive in a single artifact, which
  GitHub hands over as a zip to be unpacked and chosen from. Each ABI is its own
  artifact now — `AceMail-0.6.2-arm64-v8a.zip` holds the one file that installs
  on that phone — and the iOS build is named the same way. On a release each one
  is a separate asset.

## 0.6.2+106

### Added
- **Highlights, above the inbox.** Codes, deliveries, bills, travel and
  security notices, as a row of cards you can tap straight into. Each card is
  one unread message from the last week and says only what that message says —
  the subject and the sender — so a wrong guess costs a tap rather than a wrong
  belief. Inbox and All inboxes only; Settings → Appearance turns it off.
- **The sender's authentication, where Gmail puts it.** A pill under the name in
  the reader: *signed by*, *mailed by*, and the SPF, DKIM and DMARC verdicts the
  receiving server recorded, with the header's own words beside each one. It
  reports what your provider said and verifies nothing itself, and it says so.
  A failed method takes the warning colour; a `softfail` does not, because that
  is what every forwarded message looks like.

### Changed
- **Unread mail has a dot again.** The accent ink on the sender said it too, but
  a dot survives a name long enough to ellipsis, and it is what the eye catches
  while scrolling.
- **A paperclip on any message with an attachment.** The flag was already on the
  summary and was never drawn, so the only way to know a message carried a file
  was to open it.

## 0.6.2+105

### Changed
- **Each message is a card you can see.** The fill was one step up Material's
  tonal ramp from the page, which in a warm light theme is no step at all — the
  rows read as text on a page rather than as separate things. The card is the
  raised surface now, with a hairline edge and the gap between cards doing the
  rest.
- **"Ask Chyme" is back on the bottom edge, in the middle.** It says what it
  does, it is the same distance from either thumb, and it does not move as the
  list scrolls. Compose keeps the right-hand corner.

## 0.6.2+104

### Fixed
- **The greeting is visible again.** It was being painted behind the top bar:
  the list runs *behind* the bar so the glass has mail to blur, and nothing was
  holding the first row down. The list starts below the bar's own height now.
- **A dial's value sits beside its name.** Stretched to opposite ends of the row,
  "Blur" and "24" read as two unrelated things with a screen between them, and
  the number you are dragging towards is the one place your eye should stay.

## 0.6.2+103

### Added
- **Firebase is wired in, and inert until it is configured.** `firebase_core` is
  a dependency and `startFirebase()` runs before the first frame, but the options
  come from the build rather than from a committed `firebase_options.dart`: a
  build with no project behind it starts exactly as it did before, and says so in
  the log. Wiring a project is `flutterfire configure --project=tab-gl` and then
  passing the values as `--dart-define`s, or keeping the generated file and
  returning it from `DefaultFirebaseOptions`.

## 0.6.2+102

### Added
- **Mail opens when the network does not answer.** The page a folder showed is
  written to the device as it loads — summaries only, the bodies were already
  cached separately — and a folder whose fetch fails now opens onto that mail
  with a line saying where it came from and a pull-down to try again. A folder
  that opens onto yesterday's mail and says so is worth more than one that opens
  onto an error.

### Changed
- **The reader is a card.** One message, on a raised surface with a corner and
  air around it, rather than the mail and the app sharing one sheet. The next
  message is a different card — which is the point.

## 0.6.2+101

### Changed
- **The assistant is back in the search bar.** It moved to a pill on the bottom
  edge for one build, which was one place too many to look for it: the bar is
  where you ask the app to find something, and asking the assistant is the same
  intention. The bar's right-hand slot is the assistant, and a microphone while
  you are searching. Compose has the bottom corner to itself again, and still
  does not collapse on scroll.

## 0.6.2+100

### Fixed
- **Coming back from the recents list no longer asks you to sign in.** A cold
  start is the worst moment to ask the keychain anything: the process is young,
  the credential service is still waking, and a read that fails there is
  indistinguishable from a device with no accounts. The read is retried once,
  after a short pause, before the sign-in screen is allowed to say somebody is
  signed out.
- **The assistant sits on the screen's centre line.** It was centred on whatever
  was beside it, so Compose sharing the slot pushed it left of centre.

## 0.6.2+99

### Changed
- **Chyme lives at the bottom of the screen now, in the middle.** It was an icon
  inside the search bar: it moved when the bar grew, vanished while searching, and
  could not be found by anybody who had not read the toolbar. It is a pill in the
  centre of the bottom edge — the mark to type, a microphone to speak — and it
  never collapses on scroll.
- **Speaking to it carries the message with it.** The microphone opens the same
  recogniser the search field uses, and what it hears is sent as the question with
  the message on screen already in the assistant's context.
- **The compose button no longer shrinks as the list scrolls.** A button that
  changes shape as the list moves is a button reacting to something you are not
  looking at.

### Fixed
- **The settings that protect something cannot be switched off.** A permanent
  delete always asks; that is a promise the app makes, and offering it as a
  switch offered a way to break it. Locked switches are drawn on, inert, and say
  why in the line beside them.

## 0.6.2+98

### Changed
- **Chyme's mark is the artwork again.** It was redrawn as a ring and a dot for a
  build, on the reasoning that a taper does not survive 20px. It does — and a
  mark that changes shape is a mark that has to be learned twice.
- **The reader's toolbar is about the message again.** The Chyme button and the
  floating Summarise button are gone: the assistant has one way in, the bar, and
  a reader with two of its controls in it was a toolbar about the app.
- **The message list is cards again.** The gap between rows was half a unit,
  which is not a gap — the cards touched and the list read as rows. They have air
  between them and a larger corner now, so each message is one thing.
- **Chyme's suggestion arc has room.** A wider arc, a gentler step, taller cards
  and padding at both ends, so the outermost card is not cut by the sheet's edge.

### Added
- **Chyme's instructions are editable.** A row in its settings opens the prompt —
  what it is told about itself and its rules — with the app's own as the hint.
  Empty means the app's; anything else replaces it, because two sets of
  instructions that disagree is an assistant arguing with itself.
- **The version is in the rail.** Name and build at the foot of the folder list,
  because a bug report that says "0.6.2" cannot be matched to the code that
  shipped it.

### Fixed
- **Losing focus puts the keyboard away.** It used to stay up over a collapsed
  search bar — a keyboard for a field nobody was in, covering the mail.

## 0.6.2+97

### Added
- **Updates install from the app.** "Update now" fetches the release and hands
  the APK to the system installer, with a progress bar while it comes down and a
  line saying what happened. The first time, Android shows its own screen asking
  whether Ace Mail may install apps — that screen *is* the permission, and there
  is no version of this that skips it: an app that can replace itself without
  asking is an app that can be made to replace itself.
- **Download updates in the background.** A switch, off by default, that fetches
  a newer release as soon as the daily check finds one, so the update is already
  on the device when you tap it. Fetching spends your data, so it is your choice;
  installing is always a tap.
- **The mailbox refreshes the moment you come back to it.** Mail arrives while
  the phone is in a pocket, and Android's background floor is fifteen minutes.
  Returning to the app is when somebody is looking, so it asks the server right
  then — no timer, no wake lock. It also covers what the worker cannot: a phone
  that force-stopped the app, or a session that dropped while the screen was off.

## 0.6.2+96

### Fixed
- **The glass works, on every phone.** The blur was gated on "iOS, macOS, or
  Android 12+" — on the reasoning that a real backdrop blur needs Android's
  `RenderEffect`. That is true of a native view and irrelevant here: Flutter's
  `ImageFilter.blur` is a shader in the engine's own pass and has worked on every
  Android version Flutter supports. So the switch was on, the surfaces were
  built, and the capability said no — which is why the setting did nothing. Every
  platform Flutter draws on can blur now; the one that cannot is the web build.
- **The top bar is glass, and the mail scrolls under it.** An opaque bar over a
  flat background is a bar, not a pane of anything — the material only shows when
  there is something behind it. The list now runs behind the bar and the bar
  blurs it.

### Changed
- **Every screen transition is iOS's.** The app had two ideas of what opening a
  screen looks like: a fade-and-scale on Android, a slide on Apple's platforms.
  It is the slide everywhere now — the new screen from the right, the one beneath
  it a third as far and dimmed, the shadow between them, and the left-edge swipe
  to go back.
- **Sheets come up like iOS sheets.** Fast, decelerating, and gone faster than
  they arrived; Material's default curve made them feel like drawers rather than
  panes. The Chyme, sort and update sheets use it.

## 0.6.2+95

### Fixed
- **Release notes render on the phone.** They were written as a GitHub
  accordion — `<details>`, `<summary>`, `<b>` — and the app's notes view has no
  HTML in it by design, so those tags arrived as literal text. The generator
  writes plain markdown now, and anything already published is stripped on the
  way in, so an old release reads the same as a new one.
- **"You are on 0.6.0+1091" was a version string that does not exist.** A
  platform that already carries the build in its version name produced
  `0.6.0+10+91`, which the sheet then flattened into one impossible number. The
  build is only appended when the name does not already have one, and the sheet
  names the version the way the About screen does.

### Changed
- **The mark-all-read button is gone from the bar.** Marking a whole folder read
  is a rare, blunt action, and it was sitting between search and sort on every
  screen. It is still in the selection bar, where it acts on what you chose.
- **Contacts left the folder rail.** Contacts is not a folder, and the rail is a
  list of folders. It is still where it is useful — the recipient field's
  suggestions, and the assistant's address book.
- **Chyme has no "+" button.** A chat that lives forever becomes a document
  nobody tidied: the context grows and the sheet opens onto yesterday. The
  conversation now expires after an hour, which is what the button was really
  for — and it happens without being asked.

## 0.6.2+94

### Fixed
- **The open envelope that meant "mark all read" is a tick.** An envelope for
  "mark everything read" is the same picture as "open mail", and it was the one
  control in the bar nobody could name. The per-selection version had the same
  problem and got the same fix.
- **Chyme's mark is drawn, not sampled.** The artwork was a 512px swoosh of
  dozens of tapering arcs, which at 20px in a settings row and 22px in the search
  bar blurred into a smudge — that is what made the button unreadable. It is a
  thick open ring with rounded ends and a dot in the gap now: two strokes, clean
  from 16px to 64px, and it takes the colour it is given.
- **The suggestion cards scroll, and they answer a pointer.** The arc was a bare
  stack, so the cards off the edge of a phone were unreachable; it scrolls
  horizontally when it has to and stays still when it does not. Hovering now
  lifts a card, tints it and shows the accent border — on a desktop that is how
  you find out it is a button.

### Added
- **"Then by": a second sort key.** One order cannot say "by sender, then newest
  first", and that is the order a longer folder actually wants. The sort sheet
  has a tie-break row — nothing, or any of the six orders — and it only ever
  decides what the primary key left equal.
- **More room in the two limits.** The undo bar can stay for 20 seconds, and the
  page size goes up to 150 and 200 messages for the folders where scrolling is
  the point.

## 0.6.1+93

### Changed
- **Chyme's tools are one table, not two descriptions of one contract.** The list
  of tools existed twice — as prose in the system prompt and as a map inside the
  sheet — and the failure when they drifted was silent: the model was told about a
  tool the app did not have, or had one it was never told about. `ChymeTools` is
  now the table both read, with `mutates` deciding which calls run and which wait
  for a button.
- **What Chyme is told about your mail moved out of the widget.**
  `ChymeContext.forMail` builds it from the list, the open message and the
  setting, with the twenty-five-message and six-thousand-character caps in one
  place — testable with three lists instead of by pumping a sheet.
- **One confirm dialog instead of five.** `aceConfirm` is the shape the Chyme
  sheet used twice and the exit sheet three more times; a question about deleting
  mail now looks the same wherever it comes from.
- **The Google client ID is build configuration.** `GOOGLE_CLIENT_ID` at build
  time, defaulting to this project's web client, which is what the desktop client
  already did. And the null-address path in `GoogleAuth.token` is gone: every
  caller has an address, and the fallback it removed was the last way to hand one
  account's token to another.

## 0.6.1+92

### Fixed
- **The update check no longer goes quiet for a day on a failed request.** The
  time of the check was recorded whether or not GitHub answered, so one launch
  without a network — or one rate-limited request — silenced the check until the
  next day. Only a real answer counts now, and the failure is retried at the next
  launch.
- **The update check asks for the release list when `/latest` has nothing.** That
  endpoint skips drafts and pre-releases, which is right for "the newest thing to
  offer" and is also how the check could sit on an old answer forever: the
  rolling `apk-latest` release is a pre-release. The list is asked instead, and
  the newest real release is picked out of it.
- **A refused notification permission no longer switches the background check
  off.** Scheduling and permission were one question, so declining the Android 13
  prompt also stopped the fifteen-minute check — which is what also sends
  scheduled mail and keeps the badge honest. They are separate now: the check is
  registered either way, and permission is asked once, from the settings switch
  that turns notifications on.
- **Launching the app does not ask for notification permission.** It did, on
  every start, on a device that had already refused. The switch asks; the launch
  only registers.
- **The notification switch says when the platform is blocking it.** Scheduled
  but blocked in the system settings used to look identical to working.
- **A dropped notification now says why.** A plugin that failed to initialise
  meant every notification was discarded with no trace; that is one line in the
  log now, and the background isolate registers its plugins explicitly before
  using any.

## 0.6.0+91

### Changed
- **Chyme's suggestion cards are fanned along an arc.** They were a horizontal
  row to scroll; they now sit on a circle — the middle card upright and nearest,
  its neighbours turned outward and pushed down the curve, the outermost half off
  the edge and slightly faded. The shape reads as a hand of cards being offered
  rather than a list to flick through, and the middle card is the one it is
  offering.

## 0.6.0+90

### Fixed
- **Signing out clears the cached Google tokens.** They were stored per address
  and `forget()` deleted only the email and the name, so an hour's worth of
  usable tokens stayed on the device after a sign-out. Cleanup now enumerates the
  keychain instead of guessing at one account's key.
- **Removing one Google mailbox no longer disturbs another.** `removeAccount`
  clears that address's cached token and nothing else; signing out of the last
  account is the only thing that clears them all.
- **A keychain that will not answer is not a signed-out person.** A failed read
  and a missing token were both `null`, so a locked or unavailable credential
  store produced a sign-in prompt. They are different answers now, and the
  storage failure is reported as one.
- **A refused write is no longer reported as a save.** The token cache write
  returns whether it worked, and says so in the log when it did not, instead of
  failing silently and looking like a cache that is there.
- **Desktop keeps one refresh token per Google account.** The keys were global,
  so adding a second Google account overwrote the first one's refresh token and
  the first was asked to sign in again within the hour. Refresh tokens, access
  tokens, sign-out and revocation are all per address now.

### Added
- **`SecretStore`, and tests for the failures that matter.** The keychain sits
  behind a two-method-deep interface so a test can make it fail on purpose:
  cached tokens are cleared per account and in bulk, an unreadable store is
  reported rather than treated as a missing session, and an empty store is still
  an ordinary "nobody signed in".

## 0.6.0+89

### Changed
- **Sending is instant to the touch.** The composer closes the moment you press
  Send; the handshake and the transfer happen behind the mail you are already
  back in. A failure arrives as a bar with the reason in it and a **Retry** that
  sends the same message again, and the draft is still on the device until the
  server has taken it.
- **The hero is the greeting.** The line under it — "Inbox", and "Mail" before
  the first folder had loaded — is gone. It comes back only while a search is
  running, because a search needs saying: how much of the folder matched.

### Fixed
- **Folders show their counts.** The rail asked for `messagesExists`, which a
  plain LIST does not carry, so every folder said zero and the pill never
  appeared. The listing now asks for the counts with LIST-STATUS — one command,
  no extra round trips — and folders the server leaves out are filled in one at a
  time in the background, so the rail fills in a moment after the mail does
  rather than holding it up.

## 0.6.0+88

### Fixed
- **The launcher marks fill their tile.** Every drawing sat at half the canvas,
  which is why the picker showed four small stamps in four large squares: the
  artwork is scaled to the adaptive-icon safe zone now (60% of the canvas), and
  the preview beside each name is larger so the drawing is legible.
- **One Chyme call to action in the reader, not two.** The toolbar's *Reply with
  Chyme* and the More menu's *Ask Chyme about this* were the same button in two
  places; the menu entry is gone and the toolbar keeps it.

### Changed
- **The loading indicator is the real M3 Expressive morph again.** It was a
  progress ring for a build, which is the right control for progress and the
  wrong one for waiting: expressive loading is one shape travelling through
  Material's families, interpolated rather than cut, and that engine is what
  every loading state draws. Pull-to-refresh still scrubs it with a value.
- **Sending and signing in are faster** — carried over from the previous build,
  which this one supersedes: the SMTP connection is kept and warmed instead of
  opened per message, the copy in Sent is filed behind the composer rather than
  in front of it, and sign-in returns as soon as the login is accepted instead of
  waiting for SELECT, SEARCH and a forty-message FETCH.

## 0.6.0+87

### Fixed
- **Sending no longer pays for a connection it already has.** Every message
  opened a fresh SMTP connection — DNS, TCP, TLS, EHLO, STARTTLS, EHLO, AUTH —
  and none of that depends on the message. It is opened once, warmed when the
  mailbox connects, reused while it answers, and reopened when it has gone stale.
- **The copy in Sent is filed behind the composer, not in front of it.** A send
  used to wait for an IMAP APPEND, through the mailbox queue, after the server
  had already accepted the message. It runs in the background now; a failure
  there still cannot make a delivered message look unsent.
- **Signing in stops waiting for the first page.** `connect` used to run SELECT,
  SEARCH and a forty-message FETCH before it returned, and the sign-in screen
  waited for all of it. It returns as soon as the server has accepted the login,
  and the inbox loads behind the list's skeleton — which is what the skeleton is
  for.
- **The love envelope is drawn properly.** The mark was a small, muddy scan: the
  heart sat off its flap and the themed-icon layer was unusable, so on Android 13
  with themed icons the "Heart" mark came out blank. Redrawn — cream envelope,
  centred red heart, and a real monochrome silhouette with the heart cut out of
  it.

## 0.6.0+86

### Changed
- **Chyme proposes; you decide.** Star, unstar, mark read, archive, delete,
  reply, and the three contact actions are no longer carried out when it asks
  for them. Each one arrives as a card — *Chyme wants to · Star "Re: invoice"* —
  with **Do it** and **No**, and nothing touches the mail until one is pressed.
  Reading (`search`, `read`, `contacts`) still runs, because reading is what it
  was asked to do and changes nothing.
- **Chyme's first screen is a hero, not a menu.** A mark, "What needs doing?",
  and a row of cards to flick through — each with an icon, a title and what it
  will do — instead of a paragraph of explanation and seven underlined prompts.
- **The hero no longer counts.** "Inbox · nothing unread" is "Inbox": the list
  below already says what is unread, and the count was the one part of the line
  that could be stale.
- **Folders show how much mail they hold**, capped at **999+**, in a pill that is
  accent-coloured only when something in that folder is unread. A count is what
  a list of folders is for; unread is already said by the rows.

### Added
- **Glass studio.** Blur, tint strength and an inverted tint — smoked glass
  instead of frosted — with a preview that is the real material, drawn by the
  same code as every other surface, over a backdrop worth blurring. Reachable
  from Settings → Appearance, only on devices that can blur.
- **The launcher marks are previewed.** The picker draws each mark at 38px on
  the accent it will wear, in the row and in the list, instead of offering four
  words.

### Fixed
- **A thousand messages are cached, not five hundred.** Opening a folder you have
  read should not wait on the network; the byte bound went up with it, because
  the count alone is not what keeps the cache honest.
- **Credentials do not ride an automatic backup.** Android's backup can restore a
  sealed record whose key — held in the device keystore — never came back, which
  produces exactly one symptom: signed out, every launch. `allowBackup` is off.
- **A save is now read back before it is called a save.** The store opens the
  record it just wrote; if it does not open, the failure is reported then,
  instead of appearing as a sign-in prompt at the next start.

## 0.6.0+85

### Changed
- **Linux ships an AppImage, Windows an .exe installer.** The .deb only installs
  on the Debian family and an RPM only on Red Hat's; an AppImage carries its own
  libraries and runs on any distribution, which is what "compatible" has to mean
  for a download page. The Windows build is now an Inno Setup installer — a
  Start-menu entry, an uninstaller and a desktop shortcut you can tick — instead
  of a folder to unzip and a guess about which of the .exe files in it is the
  app.

### Added
- **A download table in the README.** One file per platform, in the format that
  platform installs, and what to do with it — including that the Apple builds
  are unsigned and the AppImage is the Linux one to take.

### Verified
- **The AppImage recipe, end to end.** The AppDir assembly, the `AppRun` wrapper
  and `appimagetool --appimage-extract-and-run` were run here against a stub
  bundle: the tool produced a valid AppImage, and running it passed its
  arguments through to the binary inside. That is the part of the packaging that
  could not be checked by reading it.

### Fixed
- **The release page lists what it actually builds.** With the formats changed,
  the file patterns the publish job attaches were pointing at a .deb and a .zip
  that no longer exist.
- **The Windows installer no longer fails over a missing icon.** `flutter create`
  writes `windows/runner/resources/app_icon.ico`, and the Inno Setup script asked
  for it unconditionally: a runner that generated the project differently would
  have failed the whole Windows job over a picture. The line is included only
  when the file is there.

## 0.6.0+84

### Changed
- **Material 3's own slider and progress indicator.** Both were hand-drawn
  replications — `AceSlider` copied the Expressive slider, `AceLoader` morphed
  through Material's shape families — because Flutter's widgets were the older
  design. Flutter's slider has been the updated M3 one since 3.29, and a second
  implementation of a component the framework owns is the one that goes stale: it
  misses the framework's timing, its reduced-motion behaviour and its
  accessibility. The 2024 appearance is now opted into once, on the theme
  (`SliderThemeData` and `ProgressIndicatorThemeData`, `year2023: false`), and
  `AceSlider`/`AceLoader` are thin names over `Slider` and
  `CircularProgressIndicator`.
- **Packages, not zips.** Linux now ships a **.deb** (installed with one command,
  an entry in the menu) beside the tarball, macOS a **.dmg**, and iOS an
  **.ipa** — the same bytes as the old zip, in the shape each platform's tooling
  expects. Windows still ships a zip: there is no installer path I can verify
  from here, and a build I cannot test is worse than an honest zip.

### Fixed
- **Liquid glass on macOS.** `supportsBlur` answered for iOS and Android 12+ and
  not for macOS, so the setting was on, the surfaces were built, and the
  capability said no. It answers for macOS now, and the "not supported" line
  names what the platform actually is instead of claiming no hardware blur.
- **A reader that stayed on its skeleton.** Closing a message while it was still
  loading bumped the token, and the in-flight fetch then skipped the line that
  clears `loadingMessage` — so the reader kept showing the skeleton. Closing a
  message, and switching folders, now clear it.
- **Errors that say what is wrong.** "Not a valid email address" told you nothing
  you could act on. The validator now names the fault — no @, more than one @, a
  space where a comma belongs, a domain with no dot — and the sign-in form says
  which of its fields is at fault: a server that was pasted as a URL, a port that
  is not a number, a port outside 1–65535.
- **Fields that behave like fields.** Server names and addresses no longer get
  autocorrected or auto-capitalised, and a field's error is drawn under it with
  an icon and announced through a live region instead of being left to the
  decoration's own red line.

## 0.6.0+83

### Changed
- **The launcher marks are named for what they are.** The picker offered "A",
  "Sealed" and "Open envelope" for drawings that are a red heart on a cream
  envelope, a bear sticker on a brown one, and a hand-drawn pink heart — names
  left over from artwork they no longer matched. They are **Ink**, **Heart**,
  **Bear** and **Doodle** now, each with a line saying what the drawing is. The
  alias suffixes are unchanged, so an icon already on a home screen stays where
  it is.
- **Long-press opens a message's actions instead of starting a selection.**
  Reply, Forward, mark read or unread, star, archive, move to a folder, spam,
  delete, *Ask Chyme about this*, and **Select** — picking is now something you
  choose rather than something a press assumes. While a selection is up, a
  long-press still picks, so the gesture that started it still works.

### Added
- **Chyme, from more places.** The message list's long-press sheet and the
  reader's More menu both offer *Ask Chyme about this* — what the message wants,
  and what a reply would say — without opening it first, because Chyme reads the
  message itself by uid.

### Smoother
- **Unread is said in the ink, not in a bar.** The three-pixel accent strip down
  the left of every card is gone: an unread sender's name is tinted and the
  subject keeps its weight, which costs the layout nothing and stops every row
  in the list from carrying a line down its edge.
- **The row is a padded card again.** The clip and the stack around each message
  existed only to round the corners of that strip.
- **Settings remembers which sections you folded.** Folding a category was a
  decision you had to make again on every visit; it is kept now, by title, and a
  section that is renamed simply opens again.

## 0.6.0+82

The build that goes with the `v0.6.0+82` release: everything below is in it, and
the release notes on the release page are generated from this section.

### Added
- **Forward.** The reader sends a message on with its headers quoted under a
  `---------- Forwarded message ----------` line, and **carries the attachments
  across** — they are written to a temporary directory so the composer takes them
  the same way it takes a file from the picker. A subject that already says
  `Fwd:` is not prefixed twice.
- **Move to a folder.** Filing was the one thing this app could not do: archive
  went to one fixed folder and everything else was the app's decision. The
  reader's More menu and the selection bar now offer every folder the account
  has, minus the one the message is already in.
- **Mark as spam, and Not spam.** One action moves a message to Junk; from Junk
  the same action puts it back in the inbox. Nothing is reported to anybody — the
  move is all this app can honestly do, and it says so.
- **Mark all read.** The whole folder, not the page: one SEARCH for the UIDs,
  then one STORE per two hundred of them, and the count goes to zero only after
  the server has agreed. In the all-inboxes view it marks every account's inbox,
  because that is the number the button sits above.
- **Select all**, in the selection bar, for the page on screen.
- **Empty junk**, the same command as emptying the trash and behind the same
  question.
- **Address suggestions while typing.** The composer completes To, Cc and Bcc
  from the contacts the app already has: two characters and the people whose
  name or address matches appear as chips under the field you are typing in, a
  tap drops in `Name <address>, ` and the next one is ready. Prefix matches come
  first, saved people before ones the mail merely mentioned, the addresses
  already in the line are never offered twice, and the account you are writing
  from is never suggested to itself. There was a picker sheet before this, which
  is fine when you cannot remember a name and useless when you can remember the
  first three letters.
- **An update checker.** Settings → Support now has *Check for updates*: once a
  day, on launch, the app asks GitHub for the latest release and — only when it
  is newer than what is installed — shows the release notes with a link to the
  page. Off means no request is ever made; nothing about the person or the
  install is sent, because it is a plain request for a public list. *Check now*
  is the same thing on demand, and it answers either way: newer, up to date, or
  could not reach the list. Versions are compared by name and then by build
  number, so 0.6.0+83 is an update on 0.6.0+82 — and a version it cannot read is
  never an update.

### Smoother
- **The page is filtered and sorted once, not per read.** The list, the
  selection bar and the assistant all ask for the visible messages, several
  times a frame, and each ask was a filter and a sort over the whole page. It is
  cached now, keyed on the list and the four things that change the answer —
  including a contacts revision, so blocking a sender still shows at once.
- **The composer only rebuilds when the suggestions change.** A keystroke that
  leaves the same five people on screen no longer rebuilds the form; moving
  between fields always does, because the chips belong under the field with the
  cursor.
- **A Bcc controller that was never disposed.** It leaked with every composer
  that was opened.

### Fixed
- **A snack raised from the reader after filing the open message.** Moving the
  open message closes the reader, and the confirmation was being raised from a
  context that had just gone. The messenger is taken before the move now.
- **Mark all read in the all-inboxes view** would have marked only the first
  account's inbox while the merged count on screen was the sum.

## 0.6.0+81

### Fixed
- **Being signed out for no reason.** The record and its key are two writes, and
  a process killed between them — or a keychain that answered once and then did
  not — left the key without its marker. The next start read "no key version",
  minted version 1 over the key that was already there, and every record sealed
  with it stopped opening: the app came up at the sign-in screen with nothing
  wrong that anybody could see. A missing or unreadable marker now adopts the key
  that is on the device instead of replacing it, and minting never writes over a
  key that already exists — which also closes the same race between the app and
  its background worker, two isolates with a guard each.
- **A save that had no password in it blanked the one on the device.** A session
  that has not been handed a password yet — a reconnect, an account switch, a
  save after removing another account — used to write an empty password into the
  record. The next start read it back as an account it could not restore, and
  asked for the password again. A save now keeps the password already stored for
  that address rather than overwriting it with nothing.
- **The key file is repaired while the keychain can still answer.** The key is
  written to the keychain and to a file beside the record; if a write reached
  only one of them, the next read now puts the other back, so a keychain that
  fails later still has something to fall back on.
- **A record that will not open is kept, not overwritten.** It is moved to
  `credentials.ace.kept` and named in the error, so a key that comes back — a
  restored keychain, a fixed build — can still open it, and the next sign-in
  writes beside it rather than over it. The old keychain layout is tried once
  more first, for a device whose update never finished migrating.
- **A snack raised from a sheet that was closing.** Chyme's "Searching for …"
  was shown from a context that had just been popped, which is a lookup on a
  widget no longer in the tree.

## 0.6.0+80

### Added
- **Chyme acts, not only reads.** It has twelve tools — search the loaded mail,
  read a message, star and unstar, mark read, archive, delete, reply, and look
  up, add, block and forget contacts — and every one of them goes through the
  same `MailController` the buttons use, so a star from Chyme is the same star as
  the toolbar's. Each message in the list it is shown carries its uid, which is
  the only handle it needs to name one.
- **Reply with Chyme.** A button in the reader asks for a reply in the tone you
  are set to; the draft opens in the composer, addressed to the sender and
  threaded under the message with `In-Reply-To` and `References` set. Every answer
  in the sheet has *Reply with this* beside Copy. Chyme never sends anything: a
  reply it writes waits for your finger on Send, and the three things that cannot
  be undone — delete, block, forget a contact — ask first, with the subject or the
  address in the question.
- **The model and the tone are in Chyme's own header.** Two chips, one tap each:
  the model list is whatever the endpoint offers, the tone is the register it
  writes in. Going to Settings to change either and coming back was four taps to
  answer a question asked in the middle of typing.
- **Chyme settings opens at the Chyme card.** The sheet's settings button used to
  land at the top of Settings; it now opens the screen and scrolls to the card it
  named.
- **Import contacts from the device.** The Contacts tab reads the address book
  behind a button — permission asked for at that moment, after a line saying what
  is read and what is kept, and nothing written back. Imported addresses arrive
  marked as saved, because a contact on the device is a decision already made.
  New dependency `flutter_contacts`, and `READ_CONTACTS` in the manifest; the
  button hides where there is no address book to read.

### Fixed
- **The tone list scrolls.** Nine tones in a sheet that sized itself to its
  content overflowed on a short screen, which put the last two out of reach.
- **The reader's toolbar scrolls rather than overflowing** now that it carries
  seven actions.
- **A contact can be forgotten outright**, not only un-saved or blocked.

## 0.6.0+79

### Changed
- **A message opens as a sheet, not a page.** On a phone the reader comes up
  over the list, full height, and is dismissed by dragging it down or swiping it
  away. The back chevron is gone with the page it belonged to; on a wide window
  the reader is still the third pane, and nothing about it moved.

### Fixed
- **The unread count follows the mail.** Reading a message, deleting one,
  archiving one or marking one unread moved the row and left the count where the
  last folder listing had put it, so the greeting above the list — and the badge
  in the rail — kept claiming unread mail you had already read. The count now
  moves with the action, and the server's own number replaces it at the next
  listing.
- **The greeting says what is on screen while a search is up.** It used to sit
  above four search results announcing the whole folder's unread count, which
  read as a stale counter rather than as a fact about the mailbox. It now says
  how many matched.
- **A message from a sender with no display name says who it is from.** The name
  line was left blank and the address demoted to the second line; the address
  takes the name line now, and the second line appears only when it adds
  something.
- **Saved accounts survive the keychain.** Accounts and their passwords were one
  keychain entry each, and a keychain that would not answer — a desktop session
  before the keyring unlocks, a keystore that refuses at boot — meant signing in
  again on every start. They are now one file on the device, sealed with
  AES-256-GCM, with the key in the keychain and a key file beside the record for
  when the keychain will not answer. The old keychain entries are read once and
  moved across, so an update does not sign anyone out.

## 0.6.0

### Added
- **A changelog screen.** Settings → Support → Changelog shows every version,
  newest first. The sheet after an update shows only what changed since you last
  looked; this is for the release you skipped.
- **Three new launcher marks** — a bear, a heart and a hand-drawn heart — replacing
  the old monogram, sealed and open envelopes. Drawn artwork, cut out on
  transparency and fitted to the adaptive-icon safe zone.
- **Swipe between messages.** A flick sideways in the reader moves to the next
  message or the one before.
- **Settings categories fold.** Tap a heading and it closes.
- **Sliders** for messages per page and the undo window, where the number is the
  thing being chosen.
- **Search in the model list.** An endpoint can offer a hundred models, unsorted.
- **Folders can be reordered** by long-press and drag, and the order survives a
  restart.
- **Chyme remembers the conversation** between openings, and has a Start over
  button. Four more tones: warm, direct, apologetic, enthusiastic.
- **Batch delete and archive** — one UID set, one copy, one flag, one expunge per
  folder, instead of a round-trip per message.

### Fixed
- **"Sign-in was cancelled" when it had not been.** `authenticate()` is
  Credential Manager's *button* flow — it answers "who are you" — and it was being
  handed `https://mail.google.com/`, a restricted Gmail scope, which makes the
  consent request it sends invalid. Google closed the sheet with `canceled` and
  the app reported a cancellation nobody had performed. The mail scope is
  requested separately now, by `authorizationClient.authorizeScopes`.
- **A failed sign-in now carries Google's own description** when it has one, and
  names the registration fault when it does not. `canceled` is what the plugin
  reports for both a dismissed sheet and a credential it could not produce at
  all, and the two are indistinguishable without that text.
- **Bulk actions leave the list at once**, rather than one row per round-trip.
- **Codes written with spaces are found** — `4 4 5 5 6 6` and `445-566`.
- **The provider picker no longer lays its text out one character wide.** A
  `ListTile` inside a `Column` inside a sheet had nothing giving it a width.
- **Signing in again after the app had been closed.** The device's already-granted
  accounts are restored silently at startup.
- **The reader's toolbar sits in its own top row**, above the message, instead of
  floating over the subject and sender.

### Known limitation
- **A Google token still cannot be refreshed silently forever.** `google_sign_in`
  keeps the granted authorization in the plugin's memory, so after the app is
  killed it is gone, and `attemptLightweightAuthentication` only ever returns one
  account. Doing better needs a refresh token, which needs the web client's
  secret at token-exchange time — the Android build has the client ID but not the
  secret.

## 0.5.14

### Added
- **Device lock actually opens.** The Android activity is a `FragmentActivity`,
  which the unlock prompt needs before it can be shown at all.

## 0.5.13

### Added
- **The onboarding, as drawn.** Providers are cards three to a row — the mark, a
  chevron, the name underneath — and "Other" is a full-width card because it is a
  different kind of answer. "terms." carries the accent, because colouring the
  word is how a headline says which word it means. The three promises are a
  divided list with a plain mark each, not three coloured chips.

## 0.5.12

### Changed
- The provider picker shows what it is asking you to choose: the description, not
  just the name, with a tick on the one in use.

## 0.5.10

### Fixed
- **Signing in again after the app had been closed.** The map of Google accounts
  was memory, so it was empty on every cold start and the only fallback was a
  stored token that lives an hour.

## 0.5.9

### Fixed
- **Swipe navigation named a method that does not exist** (`openMessage` rather
  than `open`), and the settings chevron named an icon and a colour that did not
  exist either.

## 0.5.8

### Added
- **Quiet hours**, so notifications stop overnight.

### Fixed
- The foreground refresh guard named a getter that does not exist. The one that
  does is `refreshing`, which is also the more accurate word.

### Changed
- **Flat rows** in the message list instead of forty outlined boxes. The list
  already separates rows by the space between them.
- The list refreshes every two minutes while the screen is up, and stops when it
  goes away.

## 0.5.7

### Added
- **Windows and macOS builds**, in CI and on the release.
- **Chyme is a loop**: it can search your mail and read the open message, up to
  three steps.
- **Chyme can delete** — it proposes, and the sheet turns that into a button, a
  question with the subject in it, and a way to say no.
- **A real time picker** for scheduled sending.

### Fixed
- **Every row stopped looking unread.** `isSeen` reads the parsed message's flags
  and returns false on an envelope-only fetch; the flags are read directly now.
- **The reader's top bar is gone**, with the back arrow moved into the toolbar.
- The sidebar button is back, as `SidebarLeft`.

## 0.5.6

### Added
- **Chyme can delete — by asking.** It writes a `DELETE:` line when it thinks
  that is what you want, and the sheet turns that into a button, a question with
  the subject in it, and a way to say no. It goes to the trash, not away. A model
  that removes mail on its own is one you would be right not to trust, so it
  proposes and you decide.

### Fixed
- **Every message looked unread.** The row's mark came from enough_mail's
  `isSeen`, which reads the *parsed message's* flags and comes back false on a
  fetch that asks for envelopes rather than full messages — so every row carried
  the unread stripe while the folder's own count, which comes from the server's
  STATUS, said there was nothing unread. It reads the flags directly now.
- **The release notes scroll with a thumb**, like the legal sheets. Notes that
  scroll and give no sign of it read as notes that end.

## 0.5.5

The last planned update.

### Added
- **Windows and macOS.** The runners are generated at build time by
  `tool/desktop/setup_desktop.sh`, the way the iOS one already was — a template
  committed to the repository is a template nobody updates, and it rots against
  each Flutter release while the phone builds keep moving. The macOS build gets
  the network client entitlement it needs to reach an IMAP server at all, and
  both get a window wide enough for the rail and the list side by side.

### Fixed
- **Every Google account can be refreshed quietly, not just the last one.** The
  stored token was per address; the *account* that mints a new one was not. With
  two accounts, one could refresh itself and the other fell through to a token
  that expires in an hour — so an hour after signing in, the second account was
  asked to sign in again while the first was fine. That is the "sign in again to
  reach this mailbox" banner.
- **A Bcc field that went nowhere.** The send passed an empty string unless the
  *setting* was on, so the field did nothing. It is wired now, and it combines
  with the self-copy rather than replacing it.

### Changed
- **The splash is milk, always**, with the Ace Base emblem above the name —
  drawn as one rendered image in Geograph, because a launch window can never use
  a *font* but it can show a picture.
- **One addressing row in the composer.** Cc and Bcc were a row each above the
  subject, which is two rows of nothing before you can start writing; they are
  folded behind a word now. Subject is inline under a divider.
- **The greeting is a heading, not a poster.** At display size a normal name
  wrapped to three lines, which is the whole screen before any mail.
- **The subject is the line and the sender is the context**, in the list.

## 0.5.4

### Added
- **Summarise, on the message itself.** Reading something you have not read is
  the moment you want it in three lines, and asking for that from a menu of six
  icons is asking somebody to find it first.
- **A text-size slider**, drawn as Material 3 Expressive: a thin track, a gap
  either side of a tall handle, and a stop indicator at the end. The mail behind
  the sheet re-renders as you drag, which is the only honest way to answer "is
  this too big".
- **Pick a recipient from contacts**, in the composer. Appends rather than
  replaces: a message to two people is one message.

### Changed
- **The launch window is the app's own.** The accent ground and the name in milk,
  drawn in Geograph — the typeface the app uses, which a launch window can never
  have as a *font*. It is a rendered image, so it can be drawn in anything.
- **The reader's toolbar is at the top right**, under the back button, instead of
  a bar along the bottom you had to reach past the message for.
- **The sidebar button is gone.** The search bar takes the room and the drawer
  still opens on an edge swipe. A permanent icon in the corner cost a tap's worth
  of width on every screen to say something the swipe already says.
- **The subject is the line, and the sender is the context.** The sender was the
  bold one, which made a list of *names* to be read before you could see what any
  of them said.
- **The onboarding is a page, not a card on one.** It was a centred, rounded,
  frosted panel — which is a *web* sign-in form, and it read as one.
- **Greetings with a voice**, still chosen by the day so they hold still.

### Fixed
- **The changelog never appeared.** A fresh install had no "seen" version to
  compare against and recorded nothing, so the next update found nothing either.
  The notes only ever reached somebody who had already seen them once.
- **Signing in after switching accounts.** One key held one token, so the second
  Google account's overwrote the first's and the first was asked to sign in again
  every hour.
- **The unified inbox** was compared by identity, and it is built fresh on every
  read because it carries a live unread count — so the check could never be true.
- **Gmail's folders** listed one. `listMailboxes()` does not recurse by default
  and every one of Gmail's is a child of the "[Gmail]" container.
- **Spam under any name for it.** Yahoo calls the folder "Bulk", and a junk
  folder that arrives as an ordinary one is a folder nobody knows to check.
- **The trash the app could not find.** The role was guessed from the folder's
  name; it reads the server's own flags first now, which is what RFC 6154 is for.
- **The splash could not inflate.** A bitmap wrapping a vector, which threw
  before Flutter existed — so the app did not open at all.

## 0.5.3

### Added
- **Sign in with Google, in Credential Manager's own sheet.** The sign-in screen
  asks for `GetSignInWithGoogleOption`, which is the bottom sheet with "Sign in
  with Google" on it — the one the rest of the system shows. The account is also
  remembered for the session, so refreshing a token on the reconnect path no
  longer asks the plugin anything: that call tries quietly and then *prompts*,
  so a sheet could appear while you were opening a folder.
- **A launcher icon with both layers as settings.** The foreground is the
  envelope or the monogram; the background is any of the fifteen accents or
  "Same as the app", which is the default. They were one setting before, so
  changing how the app looked changed the icon whether you wanted it to or not.
- **An onboarding that asks where your mail is, on the first screen.** The six
  providers are their own marks, with "Other" beside them, and tapping one fills
  in the servers before the next screen opens. It used to be a "Get started"
  button that asked for nothing and told you nothing — you pressed it to find
  out what the next screen wanted. The form is a sheet now, and the three
  reasons moved below the marks.
- **Links in plain-text mail are tappable.** The formatted path already handed
  URLs to the platform; the plain-text path drew them as text and did nothing.
  `mailto:` and bare addresses count, because in a mail client "write to
  hi@example.com" is how people give you an address.

### Changed
- **The link confirmation leads with the host.** It always showed the address
  rather than the sender's words, so a deceptive label was handled — but a long
  URL buries the host, and burying it is what a deceptive link relies on. The
  whole address is still there underneath.
- **Transport security is a setting.** IMAP and SMTP each carry a mode —
  implicit TLS or STARTTLS — instead of inferring it from the port inline. A
  server that will not encrypt is refused rather than downgraded, and the
  certificate is validated either way.

### Fixed
- **A server that offers IMAP only on port 143 could not be reached at all.**
  The connection was `isSecure: true` unconditionally: right for 993, wrong for
  143, where the server waits for STARTTLS and gets a TLS handshake instead.
- **New-mail notifications could go silent after a mailbox was recreated.** The
  checker remembered the highest UID and compared against it, but a UID means
  nothing outside its mailbox namespace — a provider that starts numbering again
  from one left the marker above every new message, so nothing ever looked new.
- **Two first writes to the cache could make a record unopenable.** Both found
  an empty vault, both minted key version 1, and the second replaced the key the
  first had already sealed with. One mint at a time now.
- **The domain field clipped its text.** `@gmail.com` came out as `@gmail.c`,
  cut off mid-word with no ellipsis to say so, because the field was sharing the
  width with the username and the text is not small. The provider's own mark is
  there now, at a fixed size: a mark cannot be cut off, and it says which
  provider you picked better than the domain did — it is the same picture you
  picked it by, one screen earlier.
- **A background check that could not ask is no longer reported as one that
  found nothing.** The worker returned success unconditionally, so a device that
  lost its network mid-check never triggered a retry. Failures are separated
  into those worth retrying and those that are not.
- **Caching a message no longer stats the whole cache.** The byte count walked
  the directory and was checked on the way out of every write, so the cost grew
  with the cache. It is a running total now.
- **The star drew the same glyph starred and unstarred**, and a trash swipe now
  shreds the row instead of removing it instantly.

## 0.5.2

### Added
- **Split APKs, and two more platforms.** Android now ships one APK per ABI —
  `armeabi-v7a` and `arm64-v8a` — because one APK carrying both is about twice
  the size of either and every phone downloads the half it cannot run. The
  signature is verified on both, since a split is where an APK that was never
  signed can hide behind one that was. Linux and iOS are built too: Linux on
  every run, so the desktop target cannot rot unnoticed, and iOS unsigned on a
  macOS runner, which is the check that it compiles and links for iPhone.
- **Sorting by attachment, and filtering by period.** "Attachments first" puts
  the ones with something on them at the top — what it is for is finding the
  thing somebody sent you when the subject has been forgotten and the date has
  not. Today, This week and This month are rolling windows rather than calendar
  ones, because "this week" that empties on Sunday night is not what somebody
  looking for last Tuesday's receipt wants.
- **See-through surfaces, decided by the device.** Android 12 and later blurs a
  backdrop with a render effect the compositor does; iOS has done it in hardware
  for a decade and gets a heavier blur over a thinner fill, which is as close to
  Liquid Glass as Flutter can reach. Android 11 and older, and Linux, blur by
  reading the framebuffer back every frame — which is not a material, it is a
  stall — so they get a flat opaque surface in the same colour. The setting says
  which one you are getting, because "Always" that behaves like "Never" is a
  setting that looks broken.

- **A Contacts tab.** A floating navigation bar in the shape Material 3
  Expressive draws one — clear of the bottom edge, the current item the only one
  that says its name — switching between the mail and the address book. The
  addresses come from the mail: everyone who writes to you, and everyone you
  write to, so the list arrives full instead of waiting to be built by hand.
  The ones you chose to keep are marked and float to the top. Tapping one opens
  a sheet with their name, their address and a **Send** button, because the
  reason to open somebody's details in a mail client is almost always to write
  to them. On a wide window the rail carries the same switch, since a wide
  window has no floating bar and a view with no way in is not a view.
- **Markdown, rendered.** Chyme's replies are written in it, so they are shown
  in it: headings, lists, quotes, code, bold, italic and links that carry the
  accent and obey the same scheme rules as a link in a message. Written here
  rather than pulled in, because what it has to survive is a chat reply rather
  than a document — and a dependency that renders tables and footnotes would be
  one more thing to drift.
- **Your name, in the greeting.** "Good morning, Yash". Google says outright;
  every other provider is asked, because the one place a person writes their own
  name is in the mail they send — so the newest message in Sent carries it in
  its `From` header. Looked up once, in the background: the mail does not wait
  for a greeting.

- **Gmail signs in with Google.** Gmail stopped accepting app passwords for IMAP
  and SMTP in 2022, which made it the one provider this app could not offer at
  all. It can now: the sign-in screen shows *Continue with Google* instead of a
  password field, and the mailbox is reached with an OAuth access token over
  SASL XOAUTH2.
  The nicest part is what is *not* stored — no password and no refresh token, so
  there is no credential on the device to leak. The token lives about an hour and
  a new one is fetched whenever a connection needs it, including on a reconnect,
  which is why nothing is remembered. The account record says how it signs in, so
  the keychain is not asked for a password that was never there.
  Setting it up needs four things in the Google Cloud project — an Android client
  for the package and signing certificate, a web client as `serverClientId`, the
  Gmail API enabled, and the mail scope on the consent screen with test users
  while unverified. The README has all four, with the SHA-1s, because every
  mistake here looks like the same generic sign-in failure and the plugin's own
  message does not say which one it is. The app names the one it is:
  `clientConfigurationError` is the client registration, `providerConfigurationError`
  is the project.

- **Chyme, an experimental assistant.** Point it at any endpoint that speaks
  the OpenAI chat API — a hosted one, or a model on your own machine — and it
  lists what it has; pick one and it can summarise the message you have open,
  draft a reply, and find mail. It is the one thing here that is **off by
  default**, because it cannot do anything at all until somebody gives it an
  endpoint, and a switch that is on and does nothing is exactly what the rest of
  these defaults exist to avoid. The key goes in the keychain like an app
  password, and a setting decides whether it may read what is on screen at all.
  There is no Chyme service: the app posts to your endpoint, with your key, and
  nothing about it passes through anything of ours — there is nothing of ours.
  It writes into the composer rather than sending anything, and when it finds
  mail it offers the search rather than running it.
- **A warning when an attachment is promised.** "I've attached the form", and no
  form. It asks once, and only for the words people actually write when they mean
  it.

- **A welcome step.** The first screen says what the app is, what it will do
  with your mail and what it will not, in three lines — then the form. Adding a
  second account skips it.
- **Terms of use and a privacy policy, as a sheet.** One sheet, two tabs, from
  the welcome screen and from Settings. Short sections and plain sentences, and
  every statement in it is a statement about what the code does: where the
  password goes, what is kept on the device and how it is sealed, and — named,
  one by one — the five things that ever leave it.

- **The local cache is encrypted.** Drafts, cached message bodies and the
  metadata that goes with them are sealed with **AES-256-GCM** before they touch
  the disk, with the key in the platform keychain. A fresh 12-byte nonce per
  record, drawn from the platform CSPRNG and stored beside the ciphertext; the
  record carries its format version and its key version, so keys can be rotated
  without making anything already written unreadable. Records are bound to where
  they belong with authenticated associated data — a body to its folder and uid
  — so one message's body cannot be served as another's, and a record that has
  been altered fails to open instead of opening as something else. The store is
  bounded, and "Clear cached content" deletes the keys as well as the files.
- **Drafts survive leaving the screen.** What you were writing is autosaved
  while you type and offered back the next time you start a new message. A reply
  never picks one up: it already has a body, and filling it from an unrelated
  draft is how you send the wrong thing to the wrong person.
- **Read messages open without the network.** A message you have read comes back
  from the encrypted cache first. Anything with an attachment is deliberately
  not cached, so a cache hit always has everything the message arrived with.
- **Optional app lock.** A fingerprint or a face before the app opens — and
  again whenever it is left, because a lock that only runs at launch is not much
  of a lock. The switch checks the device can answer before it lets itself be
  turned on, and the device passcode is an accepted fallback so a scratched
  sensor cannot lock you out of your own mail.
- **Private notification previews, on by default.** A notification says mail has
  arrived, not who sent it or what it says. A lock screen is read by whoever is
  in the room. Notification visibility is private either way.

### Fixed
- **iCloud's logo was a CloudFlare logo.** The file came from Wikimedia Commons
  under the name `ICloud_logo.svg`, and its own metadata says `CloudFlare
  logo.svg` — the wrong artwork, mislabelled at the source, showing up as a
  generic blue cloud next to Gmail's envelope. It is Apple's own iCloud mark
  now. The test that would have caught it checks that every provider logo is
  valid XML with a `viewBox` and something to draw — and it immediately found a
  second one: `yandex.svg` had no `viewBox`, so it could not scale.
- **Contrast is now a test, not a hope.** Every text role against every surface,
  for both brightnesses and all ten accents, at 4.5:1; icons and fills at 3:1.
  The accent is generated to clear AA, and this is what holds it to that.
- **Chyme's mark was invisible on a light row.** The artwork is white with
  transparency, so a row that did not tint it drew white on white.
- The rule about which links may be opened lives in one place, shared by the
  message renderer and the assistant's replies.

- **The release notes now appear after an update that only changes the build
  number.** The sheet compared version *names*, so 0.5.1+33 to 0.5.1+34 — a
  whole new section of notes — announced nothing at all. It compares the whole
  version now, and a test pins the heading rule that made the two sections
  distinguishable in the first place.
- **0.5.1's APK could not be installed, and this is why.** The version was
  written as `0.5.1` without a build number, and Flutter turns that into Android
  `versionCode 1` — a *downgrade* from the 30 that 0.5.0 shipped with, which
  Android refuses with "App not installed." It is `0.5.1+33` now, and a test
  fails the build if the build number ever goes missing again. The signing key
  was never the problem: all three APKs carry the same certificate.
- **The dead second activity is gone.** `dev/acebase/ace_mail` was a leftover
  from the template: the namespace is `app.tab.mail`, so it could never have run.

- **The app lock cannot lock you out.** It used to engage on a device that
  cannot authenticate at all, which is a screen with no way past it. An
  impossible lock is no longer a lock.

- **A refused move no longer leaves a duplicate.** The deletion-safety check ran
  *after* the copy, so a move the server could not complete had already put a
  copy in the target folder — and the user was told nothing had happened. The
  check is now the first step, and a test pins the order without needing a mail
  server.
- **Servers without UIDPLUS are refused, not guessed at.** The old rule asked
  whether any *other* message was flagged `\Deleted` and allowed the
  mailbox-wide `EXPUNGE` when none was. Another client can flag a message
  between that check and the expunge, so it was a race, not a guarantee. Now the
  answer depends only on UIDPLUS — the one thing that makes removing a single
  message safe — and the refusal says why. On such a server, deleting or
  archiving a message reports that it cannot be done and changes nothing.
- **The attachment count is the message's, not the dialog's.** Ten files three
  times was allowed, because each picker only ever counted its own ten. The cap
  is now measured against what the message already carries, re-checked against
  the same total just before attaching, guarded against a second picker opening
  over the first, and enforced once more in the sending service.

### Changed
- **The search bar is bigger, and it carries both of the things that belong to
  it.** It is 56px at rest and 60 while it is live, where it was 52. The
  microphone appears when the field is focused or has something in it — a
  microphone offered to somebody who is reading the list competes with the one
  thing the bar is for — and Chyme sits in that same slot the rest of the time,
  so neither is ever a wasted tap.
- **Sorting moved out of the app bar and into the greeting.** It is a choice
  about the list, and the greeting is the line that introduces the list. The
  button lights when something other than the default order or filter is in
  force, which is the one thing the always-on chips could never say.

- **Chyme reads the mail, not the screen.** It used to be told the folder, the
  filter and what was selected — things the *app* knows and the model has no use
  for, which invite answers about the interface instead of about the mail. What
  goes in now is what a person would hand over: who wrote, what they wrote, when,
  and the whole of the message that is open.
- **The switches move like switches.** The thumb overshoots and settles rather
  than arriving and stopping dead, the tick turns into the cross instead of
  being replaced by it, and the whole thing ticks under a thumb. A switch is the
  smallest decision in the app and the one people flip most, so it is the one
  that most needs to feel touched.
- **Google sign-in recovers.** A grant can be withdrawn from the account page,
  and a token that never covered the mail scope cannot be refreshed into one.
  Both used to end as an error with no way out; the screen now offers the sign-in
  again and reconnects afterwards.
- The selected entry in the rail fills, the way the current folder does.

- **The sign-in screen knows what it is asking for.** A Gmail address gets
  *Continue with Google* instead of a password field and no server panel, and the
  step heading and the footer note say why rather than talking about app
  passwords that Gmail will not accept.

- **The app bar's folder name is gone, and the search bar is in its place.** The
  name is not lost: the greeting above the list says which folder you are in and
  what is waiting in it, which is where a person looks anyway. The room it gave
  up is the search bar's, which is the thing people reach for far more often —
  and beside it sit the sort button and Chyme.
- **The search bar has a microphone.** It hands the listening to the device's own
  speech app — on a phone with Google services, Google's recogniser — and what
  comes back is text in the field with the search already run. The audio never
  reaches Ace Mail, and the app never asks for the microphone permission, because
  it never records anything itself.
- **A greeting before the mail.** "Good morning · Inbox · 3 unread", above the
  list, from the clock rather than a setting.

- **The compose button wears the accent**, and shortens to a circle once the
  list has been scrolled — the label is there to teach the button, and by the
  time you have scrolled you have learned it.
- **The search bar is always there, and taller.** It used to be a 40px pill
  behind a search icon in the app bar's title slot; searching a folder is
  something people do constantly.
- **The filter chips moved behind a Sort button.** They used to spend a row of
  the list on a choice most people make once. The button lights up when
  something other than the default order or filter is in force, which the chips
  could never say.
- **The launcher icon wears the accent.** A launcher icon is fixed at install
  time, so the app ships fifteen of them — one per accent, as activity aliases —
  and points the launcher at the one matching the setting. The new alias is
  enabled before the old ones are disabled, and the default is enabled in the
  manifest, so a failed switch can leave two icons for a moment but can never
  leave none. The monochrome layer is wired up too, so Android 13's themed icons
  tint it with the system accent.
- **Selected things fill.** The hugeicons free set is stroke-only, so there is no
  filled glyph to swap in — the selected folder in the rail, and a lit app-bar
  toggle, fill with the accent and invert what sits on them, and the change
  animates. The star on a flagged message pops as its row is built, and the
  reader's view toggle shows its fill moving.
- **Settings are grouped and named.** Account, Reading, Notifications, Writing,
  Appearance, Privacy, Chyme, Accessibility, Support. Notifications were a few
  rows in the middle of Reading; the composer's settings are under Writing, which
  is what they are about.

- **The HTML renderer is a maintained one.** Message bodies are rendered by
  `flutter_widget_from_html_core` — the renderer the Flutter ecosystem settled
  on — rather than by the hand-written one that used to live in
  `lib/util/html_render.dart`. Mail HTML is a museum of it: layout tables inside
  layout tables, inline styles, unclosed tags, quoted-printable soft breaks, and
  a `<style>` block that contradicts all of it. The custom renderer handled a
  subset of that and got the rest wrong; this one has a real CSS cascade and is
  still being maintained.

  Not a WebView, which is what Gmail and Outlook put on a phone. A WebView
  renders more of the web's CSS and would also put a browser engine, its own
  scrolling, its own text selection and its own layout pass in the middle of a
  list that is supposed to feel like the rest of the app. This renders in the
  app's own frame budget, in the app's own type, and is parsed off the frame for
  anything long.

  Everything the app decided before, it still decides: remote images are not
  fetched unless the setting says so; only `http`, `https` and `mailto` are ever
  handed to the platform; links are confirmed first when that setting is on;
  nothing executes.
- **The composer is a sheet, with an account picker.** Writing a message is
  something you do *over* the mail you were reading — the message you are
  answering stays behind it, and the sheet is one gesture from being gone. The
  picker names the account the message will leave from, and its default is
  **Automatic**: the mailbox you are reading, which is the account a reply
  belongs to and the one a message written from here most likely means.
- **The defaults are on.** The app ships with everything it can do switched on,
  and the settings are there to take things away. Four exceptions, each for a
  reason written next to it in `lib/data/preferences.dart`: raw headers (a
  developer's view of a message), reduce motion (an accessibility preference,
  which someone has to choose for themselves), the app lock (it would lock the
  app for whoever installs it, before they asked for a lock), and dynamic
  colour (it makes the accent the wallpaper's, which a launcher icon cannot
  follow).
- **The app icon wears the accent.** The adaptive icon's background is now the
  brand accent — the deep end is `AceAccent.orange` exactly, which is what the
  flat legacy icons already were — so the tile on the home screen is the same
  colour as the app it opens.
- **Themed icons are wired up.** The monochrome layer points at the envelope
  silhouette that was drawn for it and was not being used, instead of at the
  colour artwork. On Android 13+ with themed icons on, the launcher tints the
  icon with the system accent like every other icon.

- **Message cards.** Unread is a strip down the edge rather than a dot in the
  corner — visible at a glance without spending a line of text — and the star
  sits with the date instead of in front of the subject, so the subject keeps
  the width it needs. The unread mark's width is always reserved, so read and
  unread rows line up.
- **Nothing sensitive is logged.** Failures are scrubbed before they are
  printed: a failed `LOGIN` or `AUTHENTICATE` has its arguments taken out, as
  does anything written as `password=`, `token:` or `Authorization: Bearer`, and
  a sender's address is logged as `y***@example.com`. The protocol log — which
  prints the whole `LOGIN` command — stays off in every build, and a test fails
  the build if a certificate-validation escape hatch ever appears.

### Removed
- **Stale code, found by looking for what nothing names.** The
  first-connection splash screen, which nothing has imported since the launch
  window took over from it; six icons nothing referred to; and two token classes
  nothing used — one of which, `AstryxBrand`, carried an orange that disagreed
  with the app's accent, so it was a trap rather than a reference. The five
  per-order sort icons were being ignored too; the sort sheet uses them now.

### Faster
- **The message list's key lookup is a map, not a scan.** `findChildIndexCallback`
  exists to stop a rebuild re-creating rows, and it was called once per key per
  update while scanning the whole list each time — quadratic, on the path that
  exists to make scrolling cheap. A folder of a few hundred messages paid it on
  every rebuild.
- **The brand-logo caches evict the oldest entry rather than everything.**
  Clearing the lot at the limit meant the next few hundred rows each did their
  own DNS and HTTPS lookup again, so the cache became a stampede exactly when it
  was needed most.

- **Builds.** Gradle ran its tasks one at a time with no build cache — the
  Flutter template's defaults — and CI did not cache Gradle's dependencies, so
  every run re-resolved the Android Gradle plugin. Tasks now run in parallel,
  a task whose inputs have not changed is not run again, CI keeps Gradle's
  caches between runs, and the release build has 4 GB of heap instead of 1.5.
- The microphone pulses while the device is listening, and the search bar's
  outline takes the accent — the speech app is a separate window, so on the way
  back this is the only thing that says the app is still waiting.
- The greeting arrives rather than appearing, the search bar's clear button
  animates in and out, and the composer's attach row and the settings rows keep
  their spring.

- The message list passes its density down instead of every row watching the
  preferences for itself, so a settings change rebuilds the list once rather
  than once per row.
- Rows carry uid keys and the list can now *find* the element for a message it
  has already built, instead of building every row below a change again.
- A folder's one-time-code pass copies the cached page once, at the end,
  instead of once per code it finds.

Version 0.5.2.

## 0.5.0+30

### Fixed
- **The message list no longer crashes while loading.** The loading placeholder
  was a `ListView` inside a `SliverToBoxAdapter`, which lays its child out with
  an unbounded extent — a nested vertical viewport given infinite height, and a
  thrown exception. It draws exactly when a folder with no cached page is
  opened, which is the first open after launch. The placeholder is a column of
  rows now; nothing there scrolled anyway.
- **Deleting from the Trash asks first.** The selection toolbar expunged the
  selected messages permanently with no confirmation — one tap, no way back, and
  the only permanent-delete path that did not ask.
- **A file picked behind an oversized one is no longer dropped.** The picker
  stopped the whole selection at the first file that did not fit, so choosing a
  2 MB photo, a 30 MB video and a 1 MB PDF attached only the photo — and the
  screen could not say what had gone, because the picker had already discarded
  it. The byte cap now belongs to the planner, which skips an oversized file
  individually; the picker counts what the file-count cap leaves off; and the
  compose screen names every omission — too large, too many, or unreadable.
- **A delete can no longer take a message it was not asked to.** On a server
  without UIDPLUS the only expunge is mailbox-wide, and it removes *every*
  message carrying `\Deleted` — including ones another app flagged and has not
  finished with. The mailbox is now checked before anything is flagged, and the
  delete is refused with an explanation rather than expunging someone else's
  pending deletion.
- **Deleting an open message from the Trash deletes it.** The reader asked
  "Move to Trash?" and did a non-permanent delete *into the folder the message
  was already in* — which left a duplicate, left the message in the Trash, and
  made its row vanish from the list as if it had worked.
- **"Mark as read" marks read.** It called the toggle, so the messages that were
  already read came back unread — the opposite of what the label and the icon
  promise.
- **Nested tables render as they were written.** Rows were collected with a
  descendant search, so the rows of a table inside a cell were counted as rows
  of the outer grid and then rendered again inside that cell. A
  `text-transform` on an ancestor is inherited again instead of being dropped at
  the first nested tag, and the link recognisers created inside table cells are
  disposed with the rest rather than leaking for the life of the process.
- **Switching folders clears the selection.** A uid is unique only within a
  folder, so a selection carried across a folder change left the list in
  selection mode and let Archive or Delete act on whatever messages in the new
  folder happened to share a uid.
- **A one-time code is cached per folder, not per uid.** The cache was
  session-wide, so a code found in one folder could be shown — and copied — on a
  different message with the same uid in another folder. A wrong code is worse
  than none.
- **A file that cannot be read is no longer attached as an empty one.** A failed
  size check used to count as zero bytes.

### Removed
- **"Preview lines."** It was a shipped control that changed nothing: the list
  is header-only by design, so there was no body to preview. A switch that does
  nothing is worse than no switch — and wiring it would mean pulling bodies for
  the whole page, which is the cost the list is built to avoid.

### Changed
- **"Unread counts on folders" hides the badges.** It only ever changed its own
  state; the rail now reads it where the badges are drawn.
- **Dependencies brought up to date.** `flutter_lints` 4 → 6,
  `package_info_plus` 8 → 9 and `flutter_secure_storage` 9 → 10, each merged on
  its own and checked by CI. The two runtime majors were read against how the
  app actually uses them — `PackageInfo.fromPlatform()`, and `read` / `write` /
  `delete` — which is all unchanged. The secure-storage bump is the one worth
  watching on a real device: an upgrade has to keep reading the credentials the
  previous version wrote.
- **Release notes are generated, and fold open.** The release body is built from
  this changelog at release time rather than typed into the workflow, so it
  cannot drift from what the app shows. It opens with an overview and keeps each
  section in an accordion.
- **Validation and publishing are separated in CI.** A pull request builds and
  uploads the **debug** APK and never sees the release secrets; only a tag or a
  manual run builds the signed release APK.
- **The signer check fails closed.** A publishing run now requires
  `ANDROID_KEY_SHA256` and fails if the APK's certificate cannot be read, rather
  than skipping the comparison when the secret is missing. Fingerprints are
  compared with separators and case normalised.
- The sending service enforces the attachment limit itself, so a caller that
  does not go through the compose screen cannot send an unbounded message.

### Noted
- Regression tests cover the attachment picker's caps, the expunge rule (with
  and without UIDPLUS), and the exact reported case — a 30 MB file no longer
  dropping the 1 MB file behind it.

Version 0.5.0+30.

## 0.5.0+29

### Removed
- **Five providers that can no longer work.** The picker offered ten; six
  remain, and every one of them will actually let this app in — **free**, over
  IMAP/SMTP, with an **app password**. A provider that cannot work is a dead
  end the user only discovers after typing a password.
  - **Outlook, Hotmail, Live** — Microsoft retired basic authentication for
    personal accounts in September 2024. App passwords no longer work over
    IMAP; the account needs OAuth, which this app does not implement.
  - **Proton** — its IMAP/SMTP bridge is a paid feature, so a free Proton
    account has no IMAP at all.
  - **Fastmail** — there is no free tier, and even the paid Basic plan excludes
    IMAP and app passwords.
  - **Rediffmail** — IMAP is a paid Rediffmail Pro feature; a free account
    offers only POP3, which this app does not speak.

  Zoho stays, with a caveat: an existing free account can still switch IMAP on,
  but Zoho has stopped granting IMAP access to newly signed-up free users.

### Added
- **Real logos for the last two providers.** Zoho and GMX now show their own
  marks, so every provider in the picker wears its real logo and the drawn
  glyphs are gone entirely.
- **Five more settings**, each wired to real behaviour rather than a switch that
  changes nothing:
  - **Blind-copy yourself** — a hidden copy of every message to the account it
    goes from.
  - **Quote the original in replies**, on by default.
  - **Signature on replies** as well as on new messages.
  - **Ask before archiving.**
  - **Undo window** — how long an undo stays on the bar: 4, 6 or 10 seconds.

### Changed
- **The swipe says what it will do.** The reveal carries a word — Archive,
  Trash, Read — beside its mark, fades its colour in as it is pulled, and turns
  fully opaque at exactly the point the swipe commits, so "armed" is something
  you can see and not only feel. The tick now fires as the line is crossed
  rather than when the finger lifts, which is what it was always described as
  doing.
- **Archiving offers an undo.** It moves the message to Archive and puts an undo
  on the bar, the way a delete already did, instead of reporting it and moving
  on.
- **Reduce motion reaches the routes.** A pushed screen no longer scales and
  fades when the setting is on; the transitions are taken out rather than
  shortened. The same for the list's entrance cascade and the folder
  cross-fade.
- Every transient message goes through the one helper now, including the two
  that had been left calling `ScaffoldMessenger` directly.

### Fixed
- **The domain field leaked a controller on every frame.** The read-only
  "Domain" box built a fresh `TextEditingController` inside `build` and never
  disposed it — a slow leak with a cursor that reset under the reader. It is
  held by the field now, and updated rather than rebuilt.
- **GMX's outgoing server was wrong.** It was `smtp.gmx.com`; GMX's own
  documentation gives `mail.gmx.com` on 587 with STARTTLS.

Version 0.5.0+29.

## 0.5.0+28

### Fixed
- **No assets were bundled at all.** The pubspec declared fonts but had no
  `assets:` block, so the in-app mark, the provider logos and the changelog
  never reached the app. Flutter bundles only what is declared, and a missing
  asset is a runtime exception rather than a build error — which is why it got
  as far as a release.
- A test now reads the pubspec and every `assets/...` path in `lib/`, and fails
  if one is used but not declared, or declared but missing. That is the test
  that should have existed before the first asset did.

## 0.5.0+27

### Added
- **Real provider logos.** Gmail, Outlook, Yahoo, iCloud, Yandex and Rediffmail
  now show the providers' own marks, taken from Wikimedia Commons, which hosts
  the official files. Proton, Zoho, Fastmail and GMX keep the drawn glyph —
  their logos could not be obtained, and a wrong logo is worse than a shape that
  is honest about being a shape.
- **What's new.** The first time a new version runs it says what changed, read
  from the changelog this repo already keeps rather than a second list that
  would drift from it. A fresh install says nothing: a wall of release notes is
  a poor introduction.
- **Preview lines** in the settings — none, one, two or three.
- **About** now lists the **source**, **Bluesky @ace-base.cc** and
  **hello@ace-base.cc**.

### Changed
- **The snackbar wears the accent**, with the accent's own readable ink, so it
  looks like it came from the app rather than from Android.
- The README no longer tells you to create the project as `dev.acebase`.

### Removed
- The old `SplashScreen`, which had been unreferenced since the launch window
  stopped drawing a mark.

## 0.4.9+26

### Added
- **The trash does something now.** In the Trash folder the actions change:
  messages are **restored to the inbox** or **deleted permanently**, and there
  is an **Empty trash** action where the trash is and nowhere else — an action
  that destroys everything should not be one tap away from a folder where it
  means nothing. Emptying asks first, because an expunged message is gone from
  the server rather than moved, and it is the one action in the app that cannot
  be undone.
- **Two more settings**: group the list by date, and unread counts on folders.
- **Undo on the snackbar.** A swipe that deletes now offers to take it back, and
  the undo returns the message to the folder it came from rather than to the
  inbox. The mistake is one flick away, so the way back is on the bar.

### Changed
- **Every transient message goes through one helper**, so they have the same
  shape and the same place on screen. A message is recognised before it is read.
- **The package is `app.tab.mail`.** A different application id means a separate
  app: this installs *alongside* the old one rather than over it, and the old one
  keeps its mail. Uninstall it when you are satisfied the new one works.

### Noted
- `restore` on the controller already meant "restore the accounts from
  storage", so the message one is `restoreMessage`. Two things with one name is
  how a method ends up doing the wrong one.

## 0.4.8+25

### Why it felt laggy
Two causes, both found by reading rather than guessing:

- **One folder load rebuilt the list a dozen times.** Code detection applied
  each code and notified after every one, so a page of twelve messages meant
  twelve full rebuilds of the whole list. It notifies once per pass now.
- **Every row decoded a full-size avatar.** A 200px Gravatar in a 40px row is
  four times the pixels for none of the detail, on every row, while scrolling.
  Images are decoded at the size they are drawn.

### Changed
- **Rows are cards.** A surface of their own, a corner, and air around them.
  Bare rows on a flat page run together and each one is harder to pick out than
  the last.
- **Swipes arm sooner.** The threshold was a quarter of the row's width; it is
  under a fifth now, and the reveal follows the finger more closely.
- **The switch is Material 3 Expressive's**: a tick when it is on, a cross when
  it is off. Position is a thing you read; a tick is a thing you recognise.
- **OLED moved in with the theme**, where the dark theme is chosen.
- **The empty state waits.** A folder still being fetched shows the skeleton
  rather than "this folder is empty" — saying a folder is empty before it has
  been read is the app telling a story it does not know the end of.

### Added
- **A new icon**, built from the envelope artwork: the adaptive foreground, the
  square and round tiles, the in-app mark and the notification icon are all the
  same drawing now. The notification icon is the art flattened to one colour,
  because Android tints it and anything with colour in it comes out as a blob.

### Removed
- **Linux.** The desktop runner and its CI job are gone with it.

## 0.4.7+24

### Removed
- **The launch screen with the mark on it.** It drew the app's icon centred on
  the page, which is a splash screen by another name — a second thing to look at
  before the app appears. The native window is a plain fill now, in the colour
  the app opens onto, so it and the first Flutter frame are the same surface.

### Changed
- **OLED moved to Appearance**, where the rest of the theming lives.
- **iOS-style switches.** Cupertino's switch, because it is the one people
  already know — the shape and the travel are the same everywhere they have seen
  it, and it reads as a setting rather than a control.
- **The defaults show the mail.** Sender pictures and remote images are on.
  These are the two I had kept off, and they are the two that leak: a remote
  image tells the sender's server the message was opened, and a Gravatar lookup
  tells a third party who is in your mail. Both still have switches, and the
  warnings that matter — links and empty subjects — stay on. The test that
  asserted the old defaults was named "privacy-first"; it is now named for what
  it actually checks, because a test that lies about its own intent is worse
  than no test.

### Added
- **Provider marks in the domain picker**, drawn here rather than taken from
  anyone: an envelope, a cloud, a shield. A real provider logo is a trademark,
  and shipping the artwork would mean shipping licensed assets; a shape that
  says what kind of provider it is reads at a glance and belongs to nobody.
- **Reduce motion**, in a new Accessibility section. Transitions stop moving
  rather than moving faster — someone who asked for less motion asked for less
  motion. The loading indicator is exempt, because a still one looks like a hung
  app.

### Performance
- The list no longer keeps scrolled-off rows alive, and no longer adds a second
  repaint boundary to rows that already have one.
- The image cache is 80 MB rather than the default, which is sized for a phone
  showing a handful of pictures. Re-decoding the same attachment on every pass
  is the kind of cost that shows up as jank.

## 0.4.6+23

### Fixed
- **The reader collapsed to a column at the right edge.** My table change put a
  horizontal scroll view inside a widget span, and a span is laid out with
  unbounded width — so it asked for infinite width and the whole message fell
  apart. No scroller now, and `IntrinsicColumnWidth(flex: 1)` so a table sizes
  to its content, shares out the leftover, and shrinks rather than overflowing.
  That regression was mine, from 0.4.5, and the screenshot caught it.
- **The sidebar button did nothing.** It called `Scaffold.of(context)` with the
  app bar's context, which sits *above* the Scaffold, so it found nothing. A
  `GlobalKey<ScaffoldState>` now, and the drawer opens.

### Added
- **True black for OLED panels.** The dark theme goes to #000000, with the
  raised surfaces at #070707 through #1A1A1A. A pixel that is off draws no
  power, and on an OLED panel the difference is visible at the edges.
- **Mild haptics.** A tick when a swipe crosses its line — once per gesture, not
  once per frame — and a heavier knock for the destructive ones. Off switch
  included, because a mail client is used dozens of times a day and anything
  louder becomes noise.
- **Provider tiles in the domain picker**, and **every address a provider hands
  out**. Proton gives you proton.me, protonmail.com and pm.me; picking one
  silently would sign you in as an address you do not use, and you would only
  find out when a reply went to the wrong place. GMX and Yandex joined the list
  — and a test now fails if a provider is offered without IMAP/SMTP settings
  behind it, which is how I caught that I had added two without them.

### Removed
- **The splash screen.** It was a second loading screen for something the
  mailbox already shows: the list has a skeleton while it loads and the app bar
  says which folder is coming. Two of them meant waiting twice.

## 0.4.5+22

### Fixed
- **Tables render as grids.** Cells used to be joined with a few spaces, which
  is why a status table arrived as "Status Job Annotations" on one line and the
  columns meant nothing. Mail is laid out in tables more than in anything else,
  so this was most of what "renders badly" was. A `<table>` becomes a real
  `Table` now, each cell rendered with the renderer's own rules — so a link in a
  cell is still a link, a script in a cell still contributes nothing, and a
  table with no rows falls back to text rather than vanishing.
- **The sidebar icon is the sidebar icon.** The drawer toggle was a hamburger,
  which says "a menu". It is Hugeicons' `SidebarLeft`, which says what it opens.
- **The mark is back to the milk envelope on orange** — the launcher icon, the
  splash and the in-app mark. Restored from the commit that had it rather than
  redrawn, so it is the same drawing and not an approximation of it.

### Changed
- **The list is grouped, like the settings screen.** Messages are headed Today,
  Yesterday, This week, This month, Earlier, with no date dropped. A list of
  forty identical rows tells you nothing about where to start; the same rows
  under headings tell you immediately. The order of the headings is fixed, so
  they do not shuffle as mail arrives, and an empty group is not shown.

### Improved
- Opening the app clears the notification for that account: you have seen it, so
  it is no longer news.

## 0.4.4+21

New-mail notifications, which had been outstanding for three passes.

### Added
- **Notifications for new mail**, checked in the background. `workmanager`
  schedules a periodic task at Android's floor of fifteen minutes, so the check
  runs when the app is closed rather than only while you are looking at your
  mail — which is what a foreground timer would have given, and what would have
  looked like it worked.
- The background task runs in its own isolate with no widget tree, so it reads
  everything from storage: the accounts and their passwords from the keychain,
  the highest uid seen per account from the settings. It connects, lists the
  inbox, and compares.
- **The first check says nothing.** With no record of what was seen, every
  message in the mailbox is technically new — reporting that would be a
  notification storm on the first run rather than a delivery. It records and
  stays quiet.
- **Deletions are not news.** Uids only climb, so a mailbox with fewer messages
  is not a delivery, and a message that arrived and was deleted between two
  checks is not announced — nobody wants to be told about mail they can no
  longer see. Seven tests cover these cases.
- The setting asks the platform for permission **at the moment it is turned on**,
  not at launch, and the switch shows what actually happened: a refused
  permission leaves it off rather than showing a state that did not occur.

### Notes
- `flutter_local_notifications` needs core library desugaring on Android. Without
  it the release build fails while dexing, with a message that never mentions
  notifications — so the Gradle change is in the diff next to the reason.
- The last-seen uid lives in the app's existing storage rather than a second
  one: it is one small number per account, and a background isolate can read it
  the same way the app does.

## 0.4.4+20

The icon bug, properly this time.

### Fixed
- **Icons rendered at the size of whatever box they sat in, not the size they
  were given.** A `Container` with a width and height hands its child *tight*
  constraints, so the `SizedBox.square(13)` inside a 44px button could not be
  13 — it was stretched to 44. Every icon inside a button, a chip, a list row or
  an app-bar slot was drawn at the full size of that box.
  This is why four passes at making the icons smaller changed nothing: the size
  was being overwritten every time, and the optical corrections I kept tuning
  were applied to a number that was then discarded. Measured, not guessed —
  `AceIconView size=18.48 rendered=Size(44.0, 44.0)`.
  The icon is centred in its box now, which gives it loose constraints and lets
  it be the size it asked for. With that fixed the scale could be set sensibly
  rather than compensatorily: optical correction 0.72 -> 0.85, a circular button
  draws at half its box, a button's own icon is 21/18.
- Four tests in `test/icon_size_test.dart` pin it, including the two shapes that
  were broken: an icon inside a button, and one in an app-bar slot. They measure
  rendered sizes, which is what the previous passes never did.

### Still outstanding
- **New-mail notifications.** Named again rather than quietly skipped. What it
  needs: `flutter_local_notifications`, an Android channel and permission, and a
  background service (WorkManager or a foreground service) to poll while the app
  is closed. A foreground timer would notify you only while you were already
  looking at your mail, which looks like it works and does not.

## 0.4.4+19

### Fixed
- **Icons, smaller again.** The optical correction went 0.78 -> 0.72, a circular
  button draws at 0.42 of its box, and a button's own icon is 19/16 rather than
  22/18. Third pass at this; the sizes are now in one place, so the next one is
  a single number.
- **The sidebar icon is ours.** The app bar's hamburger was Material's default
  `DrawerButton` — the last Material icon in the app, and the wrong weight
  beside everything else. It is a Hugeicon now. The last two raw `IconButton`s
  went the same way.
- **Fifteen accents, not sixteen.** Pink and rose were both in the list and look
  the same at a glance, which is a choice that does not mean anything. Rose is
  gone.

### Added
- **A warning before a link leaves the app.** A link's text is the sender's and
  need not be what the link does — `yahoo.com` can point anywhere. The address
  is shown first, with the scheme allowlist still in force underneath. On by
  default, with a switch.
- **A page cache.** Opening a folder you have already opened shows the last page
  immediately and refreshes behind you, instead of a blank list and a wait. A
  flag or read change updates the cache, so going back does not undo it.

### Not done, and why
- **JavaScript in messages.** Not a size problem — a decision. A mail body is
  attacker-controlled content, and running its script inside the app gives the
  sender code in the app's own context. Every serious client refuses it, and the
  renderer has refused it since the first audit. The need behind the request —
  a message that only renders with script — is better served by opening it in a
  browser, where the script runs under the browser's sandbox rather than ours.
- **New-mail notifications.** Still outstanding, and still needs a background
  service rather than a timer that dies with the app.

## 0.4.3+18

### Fixed
- **The sign-in sheet showed its fields twice.** The two-step change added the
  address row inside the new step but left the original above it, so Username
  and Domain appeared twice with the step indicator between them.
- **The navigation bar was black.** Nothing ever set the system bars, so Android
  drew its own default — a black band under a cream page. Both bars now follow
  the theme, in both modes.
- Icons are a touch smaller again: the optical correction went from 0.82 to
  0.78, and a circular button draws its icon at 0.46 of its box rather than
  0.50. Hugeicons still read fuller than Material glyphs at the same size.

### Added
- **Sixteen accents**, and **dynamic colour**. The system-colours switch takes
  the accent from the platform — Android's Monet, and the equivalent elsewhere —
  and feeds it through the same pipeline as a listed accent, so the contrast
  walk, the tinted surfaces and the readable inks all still apply. `dynamic_color`
  is pinned below 2.0: from 2.0 it depends on `material_ui`, a parallel Material
  implementation whose `ColorScheme` is a different type from Flutter's, which
  makes it unusable with a normal `MaterialApp`.
- **The mark follows the accent.** The flag in the app's own mark wears the
  theme colour now. The launcher icon cannot — Android draws it before the app
  exists — but everything inside the app can.
- Two settings: warn before sending with an empty subject (it asks once, then
  sends), and the system-colours switch above.

### HTML and CSS
- `display: none` and `visibility: hidden` are honoured. Mail hides its
  preheader this way, and ignoring it put a stray line of preview text at the
  top of every message.

### Still not done
- New-mail notifications. Named rather than left to be discovered.

## 0.4.2+17

### Fixed
- **Icons were oversized.** A Hugeicon fills its 24-unit grid much more
  completely than a Material glyph does, because a Material icon carries its own
  padding inside the box. At the same nominal size the new icons read about a
  fifth larger, which is why the reader's toolbar looked like it was shouting.
  Every icon now goes through `AceIconView`, which applies that correction in
  one place and also raises the stroke weight a little at small sizes, where a
  1.5-unit stroke goes spidery.
- The folder rail showed a dot beside each folder, which said nothing except
  that you had picked it. It shows the folder's own icon now — an inbox looks
  like an inbox, Sent like a paper plane, Trash like a bin.
- The "How to sign in" walkthrough is hidden once an account is connected: an
  app-password guide is clutter when mail is already flowing.

### Added
- **The app opens without an account.** "Look around first" on the sign-in
  screen goes straight to the mailbox, which is empty and says so. A sign-in
  screen that cannot be dismissed is a wall, and there is a whole app behind it.
- **Sign-in is two steps**, animated: your address, then your password and the
  servers. The address comes first because picking a provider is what fills the
  server fields in, so the second step usually has nothing to fill. A two-dot
  indicator shows where you are, and the panels slide in the direction you are
  travelling.

### Still not done
- New-mail notifications, and the CSS work beyond what 0.4.1 added. Both are
  named here rather than left to be discovered.

## 0.4.1+16

### Added
- **Hugeicons, throughout.** Every icon in the app is a Hugeicon now — 57
  distinct icons across 92 call sites. They go through `lib/theme/ace_icons.dart`,
  which names them by meaning (`AceIcons.search`, `AceIcons.trash`) and is the
  only file that names a Hugeicons icon, so the choice lives in one place.
  Hugeicons is a widget-based library rather than a font, so the icon parameters
  on the app's own widgets changed type with it.
- **CSS in the HTML renderer.** `<style>` blocks are read and applied, along
  with the `style` attribute: tag, class and id selectors, the last part of a
  descendant selector, later rules winning, and declarations beating the tag's
  own default the way a browser resolves them. Weight, italic, underline,
  colour (hex, `rgb()`, a few names), `font-size` as a multiplier capped at 2×,
  and `text-transform`. Still no JavaScript, and a `url()` in a rule never
  becomes a request.
- **Long-press to select.** Long-press picks a message out; the list goes into
  selection mode, a tap then picks rather than opens, and the app bar becomes a
  selection bar with mark-as-read, archive and delete. Bulk actions run one at a
  time and leave anything that failed selected, so a partial failure is visible
  rather than silent.

### Note on what the migration cost
Three bugs in my own tooling, all caught before shipping: the migration script
built its edits and never wrote them; the import rewriter dropped the
continuation line of a multi-line import; and the style blocks were being
ignored because `<style>` lives in the head and the renderer only walked the
body — which the CSS tests caught, not the analyzer.

### Still not done
- The sorting and folder pass, and the gesture-navigation pass.

## 0.4.0+15

The first 0.4. Patches follow from here until asked otherwise.

### Added
- **Raw headers**, behind a setting. The message's headers as the server sent
  them, at the foot of the reader in a box that scrolls on its own — for the
  Received chain, the authentication results, the unsubscribe address. Capped at
  16 KB: a header block can be longer than the body.
- **Choosing the account to send from.** With more than one account signed in,
  Compose shows a From row and the message is routed to the account you picked.
  A message sent from the wrong address is the kind of mistake you only notice
  when the reply comes back.
- **Your own picture**, in the account switcher and the rail, looked up even
  when third-party lookups are off — it is your address, and you are the one
  looking at it. Sender pictures keep the chain they had: BIMI, then Gravatar,
  then initials.
- The website, `ace-base.cc`, in About.

### Changed
- **The theme carries the accent's hue.** The surfaces were tinted 4.5%; they
  are tinted 11% (16% on the muted steps), so a brown theme gives a beige page
  rather than a grey one with brown buttons. That moved every contrast ratio, so
  the inks are now walked along their own lightness until they are readable on
  the surface they actually sit on — and the contrast test, which covers all ten
  accents in both modes, is what demanded it.
- **The tonal button belongs to the accent.** Material's expressive variant puts
  secondary a long way from the seed: with an orange accent, `secondaryContainer`
  came out *green*, which is why the Close button in About was green. Secondary
  and tertiary are the accent at two strengths now.
- **Back is a chevron, not an arrow.**
- **The loading lines are plain, current English.** They were in a period voice —
  "Prithee, a moment" — which is a joke that wears off in about a second, on a
  screen you see every launch.

### Not done
- Hugeicons: the package is a `HugeIcon` widget rather than `IconData`, so every
  icon call site changes shape and ~60 Material icons need matching by name.
- CSS in the HTML renderer: `<style>` blocks and class rules are still ignored.
- Long-press to select, sorting and folder work, and the gesture-navigation pass.

## 0.3.10+14

### Added
- **Geograph**, from the Typace foundry, as the app's typeface — replacing
  Questrial, which stays registered as the fallback because Geograph is a Latin
  face and a subject line can arrive in any script. Checked before wiring it in:
  87 KB, a real TrueType file (magic `00 01 00 00`, 18 tables), family name
  "Geograph Edit", full basic Latin plus €, •, — and ’, and the Latin-1
  accented range. Two glyphs the app used are not in it — `→`, which the tutorial
  used between steps, is now `›`, and `θ` appears only in a comment.

### Note
- The font could not be fetched from `typace.ace-base.cc`: this sandbox's egress
  proxy denies the host (`X-Squid-Error: ERR_ACCESS_DENIED`), so the earlier
  reading that the *server* refused was wrong. It was recovered from the
  `aceyash-dev/Typace` repository instead, which is the same asset.

## 0.3.9+13

### Fixed
- **Turning on "load images in messages" did nothing.** The setting never
  reached the renderer — the parameter was added to the wrong construction site
  — and the body was only re-rendered when the message changed, so switching it
  on did not load the images in the message already open. Both fixed.
- **BIMI profile pictures never appeared.** They were gated behind the Gravatar
  switch, which is off by default. BIMI is a DNS record the sender's own domain
  publishes and the logo is served from that same domain — a domain that already
  knows it emailed you — so it needs no opt-in. Gravatar still does.
- A protocol-relative image source (`//cdn.example/logo.png`, which most mail
  with a CDN uses) was treated as unfetchable and shown as a placeholder.
- A 1×1 tracking pixel produced an "Image" placeholder in the middle of messages
  that have no images in them at all.
- **The theme was not global.** Every surface role was pinned to a Milk or Ink
  constant, so changing the accent changed the buttons and left the page looking
  identical. Surfaces are now the accent-tinted tones — by hand, because
  Material's tonal palette desaturates them almost to grey. The accent is
  re-checked against the tinted page it actually sits on, since a dark accent on
  a dark page pulled towards it stops reading as a shape.
- `ic_launcher_round` was missing at every density, and the manifest never
  declared it. Built from the same art, with `android:roundIcon` set.

### Changed
- The ramp from `surfaceContainerLowest` to `surfaceContainerHighest` is
  asserted to stay distinct and to run light to dark, so tinting cannot flatten
  elevation.

## 0.3.8+12

### Fixed
- **Pulling didn't refresh.** The list used `AlwaysScrollableScrollPhysics`,
  which on Android resolves to *clamping* physics: a clamped list never
  overscrolls, so `CupertinoSliverRefreshControl` never reached its trigger
  distance and a pull did nothing. Bouncing physics now, on every platform, and
  a test drags past the trigger and asserts the folder reloads.
- **"Other" in the sign-in form silently kept the previous provider's servers.**
  Typing a username filled the servers from the default domain; switching to a
  custom domain left them in place, so the account would have signed in to the
  wrong server. Servers we filled are now cleared when the domain stops
  matching, and hand-entered ones are left alone.

### Added
- **Ten accents**, in Settings, with the whole app re-themed in place.
- **About is a sheet**, with the version, what the app does with your
  credentials, and where to find us: GitHub `@tab-gl`, Instagram `@tab.gl`.
- **The address is entered as username @ domain**, with a picker for the
  providers whose servers we know and a custom option for the rest.

### Changed
- The mark is redrawn to the reference: a curved postbox, a hooked flag in the
  accent, a letter in front with speed lines, a grey back and a ground line.
- The list fetches `HEADER.FIELDS (FROM SUBJECT DATE)` rather than the whole
  header block, and each row paints on its own layer.

## 0.3.7+11

### Fixed
- **The sidebar was gone.** Replacing the app bar spanned from `appBar:` to
  `floatingActionButton:` and swallowed the `drawer:` line between them, so on a
  phone there was no way to reach another folder at all. Restored, and the
  drawer is wider with the app's own surface colour.
- **Images broke the layout.** A picture rendered as a bracket of alt text
  dropped into the middle of a sentence. It is a placeholder now, in the shape's
  place, with the alt text inside it — and a remote image is only fetched when
  the reader asks, because loading one reports the open to the sender.
- A 300-character tracking URL ran off the side of the reader; long tokens get a
  zero-width space to wrap at.

### Changed
- **The loading indicator is a real Material shape morph.** Each family is a
  radial profile sampled at 128 angles and morphing interpolates all of them, so
  the shape passes through the intermediate forms. Each one is held briefly
  before travelling, which is what makes it read as a sequence of shapes.
- **The mark is an outline drawing** with the flag as the one filled, accented
  part — the accent, rather than the whole mark wearing it.
- The top bar no longer carries a refresh button. Pull down to refresh, or
  Ctrl/Cmd+R; the indicator is the shape morph scrubbed by the drag.

### Added
- A folder-change transition on the list, and a switch for loading images.

## 0.3.6+10

### Fixed
- **Refreshing blanked the list.** `openFolder` cleared the rows unconditionally,
  so a refresh emptied the screen and showed a skeleton. Reloading the folder
  already on screen keeps its contents until the new page arrives; only switching
  folders clears, because those rows belong to a different mailbox.
- The search field drew the theme's focus outline *inside* the pill, because
  only the resting border was unset.

### Added
- **One-time codes in the list**, without opening the mail: from the subject as
  each row is built, and from a bounded body preview for mail whose subject
  talks about a code but does not contain one. Tap to copy. Off-switch in
  settings.
- **Sort and filter chips**: newest, oldest, sender, subject, unread first; all,
  unread, flagged, codes.
- **About in the sidebar**, sharing one dialog with Settings.
- The top bar shows the current folder rather than the app icon, with refresh
  (which becomes the shape morph while it runs) beside search.

### Changed
- The launcher mark is a postbox with its flag up and a letter in front, in the
  accent orange on a Milk tile — the foreground and background swap places from
  the previous icon.
- The HTML renderer separates table cells and breaks rows, honours emphasis
  stated in a `style` attribute, and stops at a nesting depth rather than
  recursing through whatever a sender sent.
- The one-time-code rule takes the number *closest* to the words describing it,
  not the first one with any context nearby.

## 0.3.5+9

### Fixed
- **Search returned the wrong messages, or none.** `search()` ran a plain
  `SEARCH`, which answers with *sequence numbers* — positions in the mailbox —
  and then handed those to a UID fetch. It is a `UID SEARCH` now, so the results
  are the identifiers the rest of the app uses.
- **Deleting a message expunged the whole mailbox.** A bare `EXPUNGE` removes
  every message flagged `\Deleted`, including anything another client flagged
  and has not finished with. It now uses `UID EXPUNGE` when the server
  advertises UIDPLUS, and only falls back to the mailbox-wide form where the
  protocol offers nothing else.
- **Removing an account above the active one silently switched mailboxes.**
  The active index was clamped rather than decremented, so the account that was
  in front became a different account. Removing the account in front still moves
  to the next one, which is what it should do.
- **Email validation on the sign-in form was `contains('@')`.** It now uses the
  same validator as the compose screen.
- **The attachment size guard counted characters, not bytes**, and attached the
  oversized files anyway. It reads real file sizes and leaves off what does not
  fit, saying how many were left.
- Light-mode `onPrimary` on the brand orange was 2.87:1, failing AA on every
  filled button, badge and toggle. It is 5.7:1 now. Hint text and disabled ink
  were around 2.5:1; both are above 5:1.

### Added
- Reconnection: a dropped connection is retried once after an exponential
  backoff with jitter. Rejections and unknown delivery outcomes are never
  retried.
- A per-client request queue, so two operations cannot interleave a `SELECT`
  with a `FETCH` and read from the wrong folder.
- A typed error hierarchy — auth, connection, rejected, unknown outcome, server
  — replacing substring matching, with SMTP status codes used where the
  protocol provides them.
- Skeleton placeholders shaped like the message list and the reader.
- Six more shape-morph forms: rounded triangle, flower, square, star.
- Settings: messages per page, list density, ask before deleting, reconnect
  automatically, message view, and configurable swipe actions either way.
- Accessibility: buttons carry a button role, form fields carry their label.
- A Linux desktop build job in CI, and `dependabot.yml` for Dart packages and
  the workflow's own actions.

### Changed
- CI is read-only by default. Publishing is a separate job that asks for
  `contents: write` and never runs on a pull request; PRs are built with the
  debug key and never touch the release secrets.

## 0.3.4+8

### Added
- BIMI: sender logos are looked up via DNS-over-HTTPS at
  `default._bimi.<domain>`, falling back to Gravatar, then initials.
- Swipe actions on message rows, both directions configurable.
- Pull-to-refresh driven by the shape morph rather than a spinner.
- A splash with a rotating line while the first mailbox opens.

### Fixed
- Rounded rectangles used one superellipse stretched over the whole shape, so a
  wide, short card rendered as an oval. Corners are superelliptical now; the
  edges between them are straight.
- About reported a version typed into the source rather than the installed one.

## 0.3.3+7

### Fixed
- The Compose FAB sat on top of the reader's floating toolbar.
- A selected row inside a grouped card spilled past the card's corners.
- Whitespace-only content between blocks stretched a short message over
  several screens.

### Changed
- The loading indicator is the Material 3 Expressive shape morph, not a spinner.
- The launcher mark is a milk envelope on the brand orange, with the flap cut
  through it.

## 0.3.2+6

### Added
- Material 3 Expressive colour (Material's own `expressive` scheme variant,
  seeded from the brand orange), spring motion, squircle shape, and a shape
  morph on press.

## 0.3.1+5

### Added
- Settings with grouped sections, a grouped-list widget, and real preferences:
  theme, text size, mark-as-read, signature, ask before exiting.

### Changed
- The account switcher and help moved off the top bar; search took its place.

## 0.3.0+4

### Fixed
- Fourteen findings from a code audit, including delete safety, a link scheme
  allowlist, HTML parsing with a real parser, size limits, request generations,
  atomic connection, and a fail-closed release build.

## 0.2.0+3

### Added
- A release signing key, wired into CI with a signer check.
- Multi-account support, profile pictures, gesture navigation.

## 0.1.0+1

- First working client: IMAP/SMTP, folder rail, message list, reader, compose.

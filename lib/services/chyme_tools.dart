abstract final class ChymeToolNames {
  static const String search = 'mail_search';
  static const String read = 'message_read';
  static const String star = 'message_star';
  static const String unstar = 'message_unstar';
  static const String seen = 'message_mark_read';
  static const String archive = 'message_archive';
  static const String delete = 'message_delete';
  static const String reply = 'message_reply';
  static const String contacts = 'contact_search';
  static const String contactAdd = 'contact_add';
  static const String contactBlock = 'contact_block';
  static const String contactDelete = 'contact_delete';
}

class ChymeToolArgument {
  const ChymeToolArgument(this.head, this.tail);
  final String head;
  final String? tail;

  /// Split only at the first pipe. Reply bodies may themselves contain pipes.
  static ChymeToolArgument parse(String value) {
    final int separator = value.indexOf('|');
    if (separator < 0) return ChymeToolArgument(value.trim(), null);
    return ChymeToolArgument(
      value.substring(0, separator).trim(),
      value.substring(separator + 1).trim(),
    );
  }
}

/// The tools Chyme may ask for, in one table.
///
/// The list used to exist twice: as prose inside the system prompt, and as a
/// `Map<String, ChymeTool>` inside the sheet. They are two descriptions of the
/// same contract written in two places, and the failure when they drift is
/// silent — the model is told about a tool the app does not have, or has a tool
/// it was never told about, and either way the answer is "I can't do that" for
/// something the app can do perfectly well.
///
/// One table, read by both: [promptList] is what the model is told, and
/// [mutates] is what decides whether a call runs or waits for a button.
class ChymeToolSpec {
  const ChymeToolSpec(
    this.name,
    this.argument,
    this.description, {
    this.mutates = false,
  });

  /// The name the model writes after `TOOL:`.
  final String name;

  /// What the argument looks like, for the prompt.
  final String argument;

  /// One line, imperative, in the model's own instructions.
  final String description;

  /// Whether this changes the mailbox.
  ///
  /// A mutating tool is **proposed**, never run: it arrives as a card with a
  /// button, because an assistant that archives your mail while you read the
  /// sentence about archiving it is an assistant you stop letting near your
  /// mail. Reading tools run, because reading is what it was asked to do.
  final bool mutates;

  /// The line the prompt shows for this tool.
  String get line => '  ${name.padRight(24)}$description';
}

abstract final class ChymeTools {
  /// Every tool, in the order the prompt lists them.
  ///
  /// Reading first, then the things that change mail, then contacts: the model
  /// reads its instructions in order, and the safest tools are the ones it
  /// should reach for first.
  static const List<ChymeToolSpec> all = <ChymeToolSpec>[
    ChymeToolSpec(
      ChymeToolNames.search,
      '<words>',
      'look through the mail already loaded',
    ),
    ChymeToolSpec(
      ChymeToolNames.read,
      '<uid>',
      'the whole body of one message',
    ),
    ChymeToolSpec(
      ChymeToolNames.star,
      '<uid>',
      'flag it',
      mutates: true,
    ),
    ChymeToolSpec(
      ChymeToolNames.unstar,
      '<uid>',
      'remove the flag',
      mutates: true,
    ),
    ChymeToolSpec(
      ChymeToolNames.seen,
      '<uid>',
      'mark it read',
      mutates: true,
    ),
    ChymeToolSpec(
      ChymeToolNames.archive,
      '<uid>',
      'move it out of the folder',
      mutates: true,
    ),
    ChymeToolSpec(
      ChymeToolNames.delete,
      '<uid>',
      'move it to the trash',
      mutates: true,
    ),
    ChymeToolSpec(
      ChymeToolNames.reply,
      '<uid> | <body>',
      'open a reply to it, in the person\'s composer',
      mutates: true,
    ),
    ChymeToolSpec(
      ChymeToolNames.contacts,
      '<words>',
      'look somebody up in their address book',
    ),
    ChymeToolSpec(
      ChymeToolNames.contactAdd,
      '<Name> | <email>',
      'save them to it',
      mutates: true,
    ),
    ChymeToolSpec(
      ChymeToolNames.contactBlock,
      '<email>',
      'keep their mail out of the list',
      mutates: true,
    ),
    ChymeToolSpec(
      ChymeToolNames.contactDelete,
      '<email>',
      'forget them entirely',
      mutates: true,
    ),
  ];

  /// The spec for [name], or null when the app has no such tool.
  static ChymeToolSpec? byName(String name) {
    for (final ChymeToolSpec spec in all) {
      if (spec.name == name) return spec;
    }
    return null;
  }

  /// Whether [name] changes mail, and so waits for a button.
  ///
  /// An unknown name is treated as mutating: a tool nobody wrote down must not
  /// be the one that runs without being asked about.
  static bool mutates(String name) => byName(name)?.mutates ?? true;

  /// Every name, for a test that pins the registry to the prompt.
  static List<String> get names =>
      <String>[for (final ChymeToolSpec spec in all) spec.name];

  static List<String> missingHandlers(Iterable<String> handlerNames) {
    final Set<String> handlers = handlerNames.toSet();
    return all.map((ChymeToolSpec spec) => spec.name)
        .where((String name) => !handlers.contains(name)).toList();
  }

  /// The tool list as the prompt shows it.
  static String get promptList =>
      <String>[for (final ChymeToolSpec spec in all) spec.line].join('\n');
}

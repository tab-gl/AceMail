import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../data/preferences.dart';
import 'chyme_tools.dart';

/// One turn of a conversation.
class ChymeTurn {
  const ChymeTurn(this.role, this.content);

  /// `system`, `user` or `assistant` — the names the chat-completions API uses.
  final String role;
  final String content;

  Map<String, Object?> toJson() => <String, Object?>{
        'role': role,
        'content': content,
      };
}

/// Chyme was asked to do something without being configured.
class ChymeNotConfigured implements Exception {
  const ChymeNotConfigured(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The endpoint answered, and the answer was not usable.
class ChymeException implements Exception {
  const ChymeException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One validated snapshot of the Chyme preferences used for a request.
class ChymeConfig {
  const ChymeConfig({
    required this.endpoint,
    required this.apiKey,
    required this.model,
    required this.tone,
    required this.customPrompt,
    required this.readsMail,
  });

  factory ChymeConfig.fromPreferences(Preferences preferences) => ChymeConfig(
        endpoint: preferences.chymeEndpoint.trim(),
        apiKey: preferences.chymeKey,
        model: preferences.chymeModel.trim(),
        tone: preferences.chymeTone,
        customPrompt: preferences.chymePrompt,
        readsMail: preferences.chymeReadsMail,
      );

  final String endpoint;
  final String apiKey;
  final String model;
  final ChymeTone tone;
  final String customPrompt;
  final bool readsMail;

  bool get isConfigured => endpoint.isNotEmpty && model.isNotEmpty;
}

/// Chyme: the assistant, which talks to an endpoint **you** point it at.
///
/// There is no Chyme service and no Chyme account. The endpoint, the key and the
/// model are all yours — the app posts to whatever you configured, with your
/// key, and nothing about it passes through anything of ours, because there is
/// nothing of ours. That is also why it ships switched off: it cannot do
/// anything until somebody tells it where to ask.
///
/// The wire format is the one every provider has converged on — OpenAI's
/// `/chat/completions`, which Ollama, LM Studio, llama.cpp, OpenRouter, Groq,
/// Together and most of the rest all speak. So "configure Chyme" means one
/// field, not one integration per provider.
///
/// The parsing is separated from the asking, so every rule about what a reply
/// may contain can be tested against a captured response.
/// The register Chyme writes in.
enum ChymeTone {
  neutral('Neutral', 'Match the register of the mail being answered.'),
  formal(
    'Formal',
    'Write as a professional: no contractions, no exclamation marks, no slang.',
  ),
  friendly(
    'Friendly',
    'Write warmly and plainly, the way a colleague you like would write.',
  ),
  brief(
    'Brief',
    'Say it in as few words as it can be said. One or two sentences at most.',
  ),
  warm(
    'Warm',
    'Write to somebody you like. Plain words, a little care, no flourishes.',
  ),
  direct(
    'Direct',
    'Lead with the answer, then the reason. No preamble, no hedging.',
  ),
  apologetic(
    'Apologetic',
    'Take responsibility plainly and say what happens next. Do not grovel.',
  ),
  enthusiastic(
    'Enthusiastic',
    'Say yes with some energy. Still short, still a person.',
  );

  const ChymeTone(this.label, this.instruction);

  final String label;
  final String instruction;
}

abstract final class Chyme {
  static bool isConfigured(Preferences preferences) => ChymeConfig.fromPreferences(preferences).isConfigured;

  static const Duration _timeout = Duration(seconds: 90);
  static const int maxBodyCharacters = 6000;

  static String truncateBody(String value) => value.length <= maxBodyCharacters
      ? value
      : '${value.substring(0, maxBodyCharacters)}…';

  /// What the assistant is told about itself, and what it is allowed to assume.
  ///
  /// Written as rules rather than as a personality, because the failure that
  /// matters here is an assistant that invents a sender or a date and sounds
  /// confident about it. Mail is a place where being wrong is expensive.
  /// How Chyme should sound.
  ///
  /// A line in the system prompt rather than a second request: the tone of a
  /// draft is part of writing it, not a pass over it afterwards, and a model
  /// asked to rewrite in a tone rewrites the meaning as often as the register.
  /// The instructions, with the tone appended — and with the person's own
  /// words in place of the default ones when they have written any.
  ///
  /// [custom] replaces the base prompt rather than being added to it: two sets
  /// of instructions that disagree is an assistant arguing with itself, and the
  /// person editing this one can see what they are replacing.
  static String systemPromptFor(ChymeTone tone, {String? custom}) {
    final String base = (custom == null || custom.trim().isEmpty)
        ? systemPrompt
        : custom.trim();
    return tone == ChymeTone.neutral ? base : '$base\n\nTone: ${tone.instruction}';
  }

  static final String systemPrompt = '''
You are Chyme, the assistant built into Ace Mail, an email client. You help the
person write and find their own mail.

You may be given their mail: the messages they have — sender, subject and date
— and the message they have open, in full, if any. That is all you can see. You
have no other access to their mail, you cannot see their screen, and you cannot
send anything.

Rules:
- Be brief. Two or three sentences unless asked for more.
- Never invent a message, a sender, a date or an address. If it is not in what
  you were given, say you cannot see it.
- When they are looking for mail, finish with one line of exactly this form:
  SEARCH: words that would appear in the message
  and nothing else on that line. Plain words, not a query language.
- You can act on the mail, not only read it. To do something, finish with one
  line of exactly this form:
  TOOL: name argument
  and nothing else on that line. The app runs it and tells you what came back;
  then answer with what you found. Ask for at most two things before answering
  — a person waiting is not a search engine.

The tools, exactly these names:
${ChymeTools.promptList}

Messages are numbered in the list you were given, as [uid]. Use that number.
- **You never send anything.** `reply` opens a draft in their composer with the
  body you wrote, addressed to the sender and threaded under the message; they
  read it and press send. Deleting, blocking and forgetting a contact are asked
  about first, every time, with the address in the question. Say what you did
  in one line, in the past tense, and do not claim to have done anything you
  did not.
- When drafting or rewriting mail, write only the message body, ready to send,
  with no commentary around it.
- Never repeat a password, a one-time code or a token back to them.
''';

  /// Normalises what somebody typed into a base URL.
  ///
  /// People paste `https://api.openai.com`, or the same with a trailing slash,
  /// or with `/v1/chat/completions` already on the end because that is what the
  /// docs showed them. All three mean the same endpoint, and asking somebody to
  /// know which part of a URL is the part is a way to make a setting nobody
  /// finishes.
  static String normaliseEndpoint(String raw) {
    String value = raw.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    for (final String tail in <String>[
      '/chat/completions',
      '/completions',
      '/models',
    ]) {
      if (value.endsWith(tail)) {
        value = value.substring(0, value.length - tail.length);
      }
    }
    if (value.isEmpty) return '';

    // A bare host means the conventional `/v1`.
    final Uri? uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme && uri.pathSegments.isEmpty) {
      return '$value/v1';
    }
    return value;
  }

  static Uri modelsUri(String endpoint) =>
      Uri.parse('${normaliseEndpoint(endpoint)}/models');

  static Uri chatUri(String endpoint) =>
      Uri.parse('${normaliseEndpoint(endpoint)}/chat/completions');

  /// The models the endpoint offers, sorted.
  static Future<List<String>> models({
    required String endpoint,
    required String apiKey,
  }) async {
    final String body = await _request(
      modelsUri(endpoint),
      apiKey: apiKey,
      method: 'GET',
    );
    final List<String> found = parseModels(body);
    if (found.isEmpty) {
      throw const ChymeException(
        'That endpoint answered, but it did not list any models. Check the URL '
        '— it should be the address the API lives at, not the website.',
      );
    }
    return found;
  }

  /// One completion, given the conversation so far.
  static Future<String> ask({
    required String endpoint,
    required String apiKey,
    required String model,
    required List<ChymeTurn> turns,
  }) async {
    if (model.trim().isEmpty) {
      throw const ChymeNotConfigured(
        'Choose a model first — the endpoint can list what it has.',
      );
    }

    final String body = await _request(
      chatUri(endpoint),
      apiKey: apiKey,
      method: 'POST',
      payload: <String, Object?>{
        'model': model,
        'messages': <Object?>[for (final ChymeTurn turn in turns) turn.toJson()],
        'stream': false,
      },
    );

    final String reply = parseCompletion(body);
    if (reply.trim().isEmpty) {
      throw const ChymeException('The model answered with nothing.');
    }
    return reply.trim();
  }

  /// The model ids out of a `/models` response.
  ///
  /// Tolerant on purpose: providers wrap the list differently, some return
  /// `{data: [{id}]}`, some `{models: [{name}]}`, and one returns a bare array.
  static List<String> parseModels(String body) {
    final Object? decoded = _tryDecode(body);
    final List<dynamic>? list = switch (decoded) {
      final List<dynamic> bare => bare,
      final Map<String, dynamic> map when map['data'] is List<dynamic> =>
        map['data'] as List<dynamic>,
      final Map<String, dynamic> map when map['models'] is List<dynamic> =>
        map['models'] as List<dynamic>,
      _ => null,
    };
    if (list == null) return <String>[];

    final Set<String> ids = <String>{};
    for (final dynamic entry in list) {
      final String? id = switch (entry) {
        final String name => name,
        final Map<String, dynamic> map =>
          (map['id'] ?? map['name'] ?? map['model']) as String?,
        _ => null,
      };
      if (id != null && id.trim().isNotEmpty) ids.add(id.trim());
    }
    return ids.toList()..sort();
  }

  /// The text out of a `/chat/completions` response.
  static String parseCompletion(String body) {
    final Object? decoded = _tryDecode(body);
    if (decoded is! Map<String, dynamic>) return '';
    final Object? choices = decoded['choices'];
    if (choices is! List<dynamic> || choices.isEmpty) return '';
    final Object? first = choices.first;
    if (first is! Map<String, dynamic>) return '';
    final Object? message = first['message'];
    if (message is Map<String, dynamic>) {
      final Object? content = message['content'];
      if (content is String) return content;
      // Some providers return the content as a list of parts.
      if (content is List<dynamic>) {
        return content
            .whereType<Map<String, dynamic>>()
            .map((Map<String, dynamic> part) => part['text'])
            .whereType<String>()
            .join();
      }
    }
    // Older / simpler shape.
    final Object? text = first['text'];
    return text is String ? text : '';
  }

  /// JSON, or null.
  ///
  /// A provider that answers with an HTML error page — a proxy, a captive
  /// portal, a 404 page — must read as "no answer", not as a `FormatException`
  /// thrown out of a parser and blamed on the model.
  static Object? _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  /// The search the reply asked for, or null.
  ///
  /// A reply may end with a line the app understands:
  ///
  /// ```
  /// SEARCH: bank statement
  /// ```
  ///
  /// which the sheet turns into a button rather than running it — the person
  /// asked a question, not for their list to be replaced. Pure, so the rule can
  /// be tested without a model.
  static String? searchFrom(String reply) {
    for (final String line in reply.split('\n').reversed) {
      final String trimmed = line.trim();
      if (!trimmed.toUpperCase().startsWith('SEARCH:')) continue;
      final String query = trimmed.substring('SEARCH:'.length).trim();
      return query.isEmpty ? null : query;
    }
    return null;
  }

  /// A thing the reply asked the app to do.
  ///
  /// The model has no hands. It writes a line, the app reads it, runs something,
  /// and writes the answer back into the conversation — which is all "agentic"
  /// means when you take the word apart.
  static ChymeToolCall? toolFrom(String reply) {
    for (final String line in reply.split('\n')) {
      final String trimmed = line.trim();
      if (!trimmed.toUpperCase().startsWith('TOOL:')) continue;
      final String rest = trimmed.substring('TOOL:'.length).trim();
      if (rest.isEmpty) continue;
      final int space = rest.indexOf(' ');
      if (space < 0) return ChymeToolCall(rest.toLowerCase(), '');
      return ChymeToolCall(
        rest.substring(0, space).toLowerCase(),
        rest.substring(space + 1).trim(),
      );
    }
    return null;
  }

  /// The reply with the `TOOL:` line taken out.
  static String withoutToolLine(String reply) => reply
      .split('\n')
      .where((String line) => !line.trim().toUpperCase().startsWith('TOOL:'))
      .join('\n')
      .trim();

  /// Asks, runs whatever it asked for, and asks again — up to [maxSteps] times.
  ///
  /// A loop rather than a single request, and a *bounded* loop: a model that
  /// keeps asking for things has to be stopped by something, and the something
  /// should be a number here rather than a person pressing stop. Everything the
  /// tools do is read-only or already asks its own question.
  static Future<ChymeRun> run({
    required String endpoint,
    required String apiKey,
    required String model,
    required List<ChymeTurn> turns,
    required Map<String, ChymeTool> tools,
    int maxSteps = 3,
  }) async {
    final List<ChymeTurn> working = <ChymeTurn>[...turns];
    final List<ChymeToolResult> trail = <ChymeToolResult>[];

    for (int step = 0; step < maxSteps; step++) {
      final String reply = await ask(
        endpoint: endpoint,
        apiKey: apiKey,
        model: model,
        turns: working,
      );
      final ChymeToolCall? call = toolFrom(reply);
      if (call == null) {
        return ChymeRun(reply: reply, trail: trail);
      }
      final ChymeTool? tool = tools[call.name];
      String result;
      if (tool == null) {
        result = 'There is no tool called "${call.name}". The tools are: '
            '${tools.keys.join(', ')}.';
      } else {
        try {
          result = await tool(call.argument) ?? 'Nothing found.';
        } on Object catch (error) {
          result = 'That failed: $error';
        }
      }
      trail.add(ChymeToolResult(call: call, result: result));
      working
        ..add(ChymeTurn('assistant', reply))
        ..add(ChymeTurn('user', 'TOOL RESULT (${call.name}): $result'));
    }

    // Out of steps. The last thing it wrote is still an answer, minus the line
    // asking for something nobody is going to run.
    final String last = working.isEmpty ? '' : working.last.content;
    return ChymeRun(reply: withoutToolLine(last), trail: trail);
  }

  /// Whether the reply asked for the open message to be deleted.
  ///
  /// A model may *ask* to delete; it may not delete. The line is a proposal the
  /// sheet turns into a question, and the answer is the person's — an assistant
  /// that can remove mail on its own is one you would be right not to trust.
  /// Pure, so the rule can be tested without a model.
  static bool deleteFrom(String reply) {
    for (final String line in reply.split('\n')) {
      if (line.trim().toUpperCase().startsWith('DELETE:')) return true;
    }
    return false;
  }

  /// The reply with the `DELETE:` line taken out, for showing to a person.
  static String withoutDeleteLine(String reply) => reply
      .split('\n')
      .where((String line) => !line.trim().toUpperCase().startsWith('DELETE:'))
      .join('\n')
      .trim();

  /// The reply with the `SEARCH:` line taken out, for showing to a person.
  static String withoutSearchLine(String reply) => reply
      .split('\n')
      .where((String line) => !line.trim().toUpperCase().startsWith('SEARCH:'))
      .join('\n')
      .trim();

  static Future<String> _request(
    Uri uri, {
    required String apiKey,
    required String method,
    Map<String, Object?>? payload,
  }) async {
    final HttpClient client = HttpClient()..connectionTimeout = _timeout;
    try {
      final HttpClientRequest request =
          await (method == 'GET' ? client.getUrl(uri) : client.postUrl(uri));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (apiKey.trim().isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${apiKey.trim()}',
        );
      }
      if (payload != null) {
        final List<int> bytes = utf8.encode(jsonEncode(payload));
        request.headers.contentType = ContentType.json;
        request.headers.contentLength = bytes.length;
        request.add(bytes);
      }

      final HttpClientResponse response =
          await request.close().timeout(_timeout);
      final String body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_timeout);

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const ChymeException(
          'That endpoint refused the key. Check it, and check whether the key '
          'is allowed to reach this model.',
        );
      }
      if (response.statusCode == 404) {
        throw const ChymeException(
          'That endpoint has no such path. The address should be the API base, '
          'like https://api.openai.com/v1 — not the website, and not the full '
          'chat address.',
        );
      }
      if (response.statusCode >= 400) {
        throw ChymeException(
          'The endpoint answered ${response.statusCode}. ${_firstProblem(body)}',
        );
      }
      return body;
    } on ChymeException {
      rethrow;
    } on TimeoutException {
      throw const ChymeException('The endpoint did not answer in time.');
    } on SocketException catch (error) {
      throw ChymeException(
        'Could not reach the endpoint (${error.osError?.message ?? 'no route'}).',
      );
    } catch (error) {
      throw ChymeException('The request failed: $error');
    } finally {
      client.close(force: true);
    }
  }

  /// The provider's own complaint, when it sent one. Their message is more
  /// useful than ours, and it never contains the key.
  static String _firstProblem(String body) {
    try {
      final Object? decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final Object? error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final Object? message = error['message'];
          if (message is String) return message;
        }
        if (error is String) return error;
      }
    } catch (_) {
      // Not JSON. Say nothing rather than echoing a body that might be HTML.
    }
    return '';
  }
}

/// Something the reply asked the app to run.
class ChymeToolCall {
  const ChymeToolCall(this.name, this.argument);

  final String name;
  final String argument;

  @override
  String toString() => '$name($argument)';
}

/// What a tool returned, kept so the sheet can show what Chyme looked at.
class ChymeToolResult {
  const ChymeToolResult({required this.call, required this.result});

  final ChymeToolCall call;
  final String result;
}

/// A finished run: what Chyme said, and everything it asked for on the way.
class ChymeRun {
  const ChymeRun({required this.reply, required this.trail});

  final String reply;
  final List<ChymeToolResult> trail;
}

/// One tool: takes the argument the model wrote, returns what it should see.
typedef ChymeTool = Future<String?> Function(String argument);

/// Session-scoped conversation memory. It is intentionally in-memory only; no
/// transcript or mail content is written to disk.
///
/// One conversation, and it expires. A chat that lives forever becomes a
/// document nobody tidied: the assistant's context grows, the answers drift
/// toward whatever was said an hour ago, and the sheet opens onto a wall of
/// yesterday. An hour is long enough to come back to a thread you were in the
/// middle of and short enough that the next opening is a fresh one.
abstract final class ChymeMemory {
  /// How long a conversation stays.
  static const Duration lifetime = Duration(hours: 1);

  static final List<ChymeTurn> turns = <ChymeTurn>[];

  static DateTime? _started;

  /// The conversation, emptied first if it has expired.
  static List<ChymeTurn> get current {
    if (_started != null && DateTime.now().difference(_started!) > lifetime) {
      forget();
    }
    return turns;
  }

  static void remember(List<ChymeTurn> conversation) {
    _started ??= DateTime.now();
    turns
      ..clear()
      ..addAll(conversation);
  }

  static void forget() {
    turns.clear();
    _started = null;
  }
}

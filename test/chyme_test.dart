import 'dart:convert';

import 'package:ace_mail/services/chyme.dart';
import 'package:ace_mail/services/chyme_tools.dart';
import 'package:ace_mail/util/text.dart';
import 'package:flutter_test/flutter_test.dart';

/// Chyme talks to an endpoint, so what is tested here is everything about it
/// that does not need one: what somebody may type into the endpoint field, and
/// what a reply may contain.
void main() {
  group('normaliseEndpoint', () {
    test('a bare host means /v1', () {
      expect(
        Chyme.normaliseEndpoint('https://api.openai.com'),
        'https://api.openai.com/v1',
      );
    });

    test('a base with /v1 is left alone', () {
      expect(
        Chyme.normaliseEndpoint('https://api.openai.com/v1'),
        'https://api.openai.com/v1',
      );
    });

    test('a trailing slash is not a different endpoint', () {
      expect(
        Chyme.normaliseEndpoint('http://localhost:11434/v1/'),
        'http://localhost:11434/v1',
      );
    });

    test('the full chat address is understood', () {
      // What the docs show, pasted whole.
      expect(
        Chyme.normaliseEndpoint('https://api.openai.com/v1/chat/completions'),
        'https://api.openai.com/v1',
      );
      expect(
        Chyme.normaliseEndpoint('http://localhost:1234/v1/models'),
        'http://localhost:1234/v1',
      );
    });

    test('the paths are built from whatever it works out to', () {
      expect(
        Chyme.modelsUri('https://api.openai.com').toString(),
        'https://api.openai.com/v1/models',
      );
      expect(
        Chyme.chatUri('https://api.openai.com/v1/').toString(),
        'https://api.openai.com/v1/chat/completions',
      );
    });

    test('an empty string stays empty', () {
      expect(Chyme.normaliseEndpoint('   '), '');
    });
  });

  group('parseModels', () {
    test('the usual shape', () {
      expect(
        Chyme.parseModels('{"data":[{"id":"gpt-4o"},{"id":"gpt-4o-mini"}]}'),
        <String>['gpt-4o', 'gpt-4o-mini'],
      );
    });

    test('a bare array', () {
      expect(
        Chyme.parseModels('[{"id":"llama3"},{"name":"mistral"}]'),
        <String>['llama3', 'mistral'],
      );
    });

    test('a models key', () {
      expect(
        Chyme.parseModels('{"models":[{"name":"phi3"}]}'),
        <String>['phi3'],
      );
    });

    test('duplicates are one model', () {
      expect(
        Chyme.parseModels('{"data":[{"id":"a"},{"id":"a"}]}'),
        <String>['a'],
      );
    });

    test('nonsense lists nothing rather than throwing', () {
      expect(Chyme.parseModels('not json'), isEmpty);
      expect(Chyme.parseModels('{"error":"no"}'), isEmpty);
    });
  });

  group('parseCompletion', () {
    test('the usual shape', () {
      expect(
        Chyme.parseCompletion(
          '{"choices":[{"message":{"role":"assistant","content":"Hello"}}]}',
        ),
        'Hello',
      );
    });

    test('content as parts', () {
      expect(
        Chyme.parseCompletion(
          '{"choices":[{"message":{"content":[{"type":"text","text":"a"},{"type":"text","text":"b"}]}}]}',
        ),
        'ab',
      );
    });

    test('the older text shape', () {
      expect(
        Chyme.parseCompletion('{"choices":[{"text":"old"}]}'),
        'old',
      );
    });

    test('an error response has no text', () {
      expect(Chyme.parseCompletion('{"error":{"message":"nope"}}'), '');
      expect(Chyme.parseCompletion('[]'), '');
      expect(Chyme.parseCompletion('garbage'), '');
    });
  });

  group('the SEARCH line', () {
    test('is found at the end of a reply', () {
      expect(
        Chyme.searchFrom('I can see two from them.\nSEARCH: bank statement'),
        'bank statement',
      );
    });

    test('is found wherever it is', () {
      expect(
        Chyme.searchFrom('SEARCH: invoice\nAnything else.'),
        'invoice',
      );
    });

    test('is case-insensitive and tolerates spacing', () {
      expect(Chyme.searchFrom('search:  tax receipt'), 'tax receipt');
    });

    test('an empty search is not a search', () {
      expect(Chyme.searchFrom('SEARCH:'), isNull);
      expect(Chyme.searchFrom('SEARCH:   '), isNull);
    });

    test('a reply without one is not a failure', () {
      expect(Chyme.searchFrom('There is nothing from them.'), isNull);
    });

    test('the line is taken out of what is shown', () {
      expect(
        Chyme.withoutSearchLine('Two from them.\nSEARCH: bank'),
        'Two from them.',
      );
    });
  });

  group('the turns sent', () {
    test('are the shape the API expects', () {
      expect(
        const ChymeTurn('user', 'hi').toJson(),
        <String, Object?>{'role': 'user', 'content': 'hi'},
      );
    });

    test('the system prompt tells it not to invent anything', () {
      expect(Chyme.systemPrompt, contains('Never invent'));
      expect(Chyme.systemPrompt, contains('SEARCH:'));
      // And not to repeat a credential back.
      expect(Chyme.systemPrompt, contains('one-time code'));
    });

    test('the prompt is plain text, whatever the provider does with it', () {
      expect(() => jsonEncode(Chyme.systemPrompt), returnsNormally);
    });
  });

  group('mentionsAttachment', () {
    test('catches the sentence that loses the form', () {
      expect(mentionsAttachment("I've attached the form."), isTrue);
      expect(mentionsAttachment('Please find the invoice below.'), isTrue);
      expect(mentionsAttachment('See attached.'), isTrue);
      expect(mentionsAttachment('The enclosure covers both.'), isTrue);
      expect(mentionsAttachment('Attaching the signed copy.'), isTrue);
    });

    test('leaves ordinary mail alone', () {
      expect(mentionsAttachment('Thanks, that works for me.'), isFalse);
      expect(mentionsAttachment('Can we meet on Tuesday?'), isFalse);
      expect(mentionsAttachment(''), isFalse);
    });

    test('does not fire on part of a word', () {
      expect(mentionsAttachment('That attachmenty thing'), isFalse);
    });
  });
  group('typed reply and tool arguments', () {
    test('parses protocol markers in one pass and strips them from display text', () {
      final ChymeReply reply = ChymeReply.parse('Answer\nSEARCH: invoice\nDELETE: yes\nTOOL: message_read 42');
      expect(reply.text, 'Answer');
      expect(reply.search, 'invoice');
      expect(reply.deleteRequested, isTrue);
      expect(ChymeReply.parse('DELETE: no').deleteRequested, isFalse);
      expect(reply.tool?.name, 'message_read');
      expect(reply.tool?.argument, '42');
    });

    test('splits a tool argument only at its first pipe', () {
      final ChymeToolArgument parsed = ChymeToolArgument.parse('12 | first | second');
      expect(parsed.head, '12');
      expect(parsed.tail, 'first | second');
    });
  });

}

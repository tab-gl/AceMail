import 'package:ace_mail/util/markdown.dart';
import 'package:flutter_test/flutter_test.dart';

/// The block rules. What Chyme writes is a chat reply, so this is not a
/// Markdown implementation — it is the small part of one that shows up in a
/// reply, and everything else has to survive as a paragraph.
void main() {
  group('blocks', () {
    test('a paragraph', () {
      final List<MdBlock> blocks = parseMarkdown('Two sentences. And a third.');
      expect(blocks, hasLength(1));
      expect((blocks.single as MdParagraph).text,
          'Two sentences. And a third.');
    });

    test('a blank line starts a new one', () {
      final List<MdBlock> blocks = parseMarkdown('One.\n\nTwo.');
      expect(blocks, hasLength(2));
    });

    test('a line break inside a paragraph is a space, not a break', () {
      // Markdown's own rule, and the one that matters here: an assistant that
      // wraps its lines at eighty characters should not arrive with a ragged
      // right edge.
      final List<MdBlock> blocks = parseMarkdown('One line\nand the rest.');
      expect((blocks.single as MdParagraph).text, 'One line and the rest.');
    });

    test('headings, at every level', () {
      final List<MdBlock> blocks = parseMarkdown('# One\n## Two\n### Three');
      expect(blocks.map((MdBlock b) => (b as MdHeading).level), <int>[1, 2, 3]);
    });

    test('bullets', () {
      final List<MdBlock> blocks = parseMarkdown('- one\n- two\n* three');
      final MdList list = blocks.single as MdList;
      expect(list.ordered, isFalse);
      expect(list.items, <String>['one', 'two', 'three']);
    });

    test('numbers', () {
      final List<MdBlock> blocks = parseMarkdown('1. one\n2. two');
      final MdList list = blocks.single as MdList;
      expect(list.ordered, isTrue);
      expect(list.items, <String>['one', 'two']);
    });

    test('a numbered list under a bulleted one is its own list', () {
      final List<MdBlock> blocks = parseMarkdown('- bullet\n1. number');
      expect(blocks, hasLength(2));
      expect((blocks[0] as MdList).ordered, isFalse);
      expect((blocks[1] as MdList).ordered, isTrue);
    });

    test('a fenced block keeps its lines', () {
      final List<MdBlock> blocks =
          parseMarkdown('```dart\nfinal x = 1;\nfinal y = 2;\n```');
      final MdCode code = blocks.single as MdCode;
      expect(code.language, 'dart');
      expect(code.code, 'final x = 1;\nfinal y = 2;');
    });

    test('an unclosed fence does not lose the rest', () {
      final List<MdBlock> blocks = parseMarkdown('```\nstill code');
      expect((blocks.single as MdCode).code, 'still code');
    });

    test('a quote', () {
      final List<MdBlock> blocks = parseMarkdown('> quoted\n> on two lines');
      expect((blocks.single as MdQuote).text, 'quoted on two lines');
    });

    test('a rule', () {
      expect(parseMarkdown('---').single, isA<MdRule>());
    });

    test('nothing is nothing', () {
      expect(parseMarkdown(''), isEmpty);
      expect(parseMarkdown('\n\n  \n'), isEmpty);
    });

    test('plain text with punctuation is left alone', () {
      // The characters Markdown uses are common in mail. A reply that says
      // "2 * 3" must not come back italic.
      final List<MdBlock> blocks = parseMarkdown('The total is 2 * 3, or so.');
      expect((blocks.single as MdParagraph).text, 'The total is 2 * 3, or so.');
    });
  });
}

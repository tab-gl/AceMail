/// A small Markdown reader: the block model and the parser.
///
/// This is the parsing half of what used to be `widgets/markdown_view.dart`.
/// It lives in `util/` because it is pure: no widget tree, no `BuildContext`,
/// no colour, so `test/markdown_test.dart` can exercise it without dragging
/// Flutter, `url_launcher` and the theme into a unit test.
///
/// What it supports is deliberately a short list — a heading, a bullet, a
/// numbered step, a fenced block, a quote, a rule, and everything else is a
/// paragraph. Tables, footnotes, nested lists and raw HTML are not parsed.
///
/// Pure, so the rules are tested without a widget tree.
library;

/// One block of Markdown.
sealed class MdBlock {
  const MdBlock();
}

class MdHeading extends MdBlock {
  const MdHeading(this.level, this.text);
  final int level;
  final String text;
}

class MdParagraph extends MdBlock {
  const MdParagraph(this.text);
  final String text;
}

class MdList extends MdBlock {
  const MdList({required this.items, required this.ordered});
  final List<String> items;
  final bool ordered;
}

class MdQuote extends MdBlock {
  const MdQuote(this.text);
  final String text;
}

class MdCode extends MdBlock {
  const MdCode(this.code, {this.language});
  final String code;
  final String? language;
}

class MdRule extends MdBlock {
  const MdRule();
}

/// Splits Markdown into blocks.
///
/// Written here rather than pulled in, for the same reason the HTML renderer is
/// a package and this is not: the HTML renderer had to survive mail, which is a
/// museum of it, while this only has to survive an assistant that was asked to
/// be brief. What it has to handle is a short list of things — a heading, a
/// bullet, a numbered step, a code span, a bold word, a link — and everything
/// else is a paragraph.
///
/// Pure, so the rules are tested without a widget tree.
List<MdBlock> parseMarkdown(String source) {
  final List<MdBlock> blocks = <MdBlock>[];
  final List<String> lines = source.replaceAll('\r\n', '\n').split('\n');

  final StringBuffer paragraph = StringBuffer();
  final List<String> listItems = <String>[];
  bool listOrdered = false;

  void flushParagraph() {
    final String text = paragraph.toString().trim();
    if (text.isNotEmpty) blocks.add(MdParagraph(text));
    paragraph.clear();
  }

  void flushList() {
    if (listItems.isNotEmpty) {
      blocks.add(MdList(items: List<String>.of(listItems), ordered: listOrdered));
      listItems.clear();
    }
  }

  int i = 0;
  while (i < lines.length) {
    final String line = lines[i];
    final String trimmed = line.trim();

    // A fenced block runs to its closing fence, or to the end if there is none
    // — an assistant that forgets to close one should not lose the rest.
    if (trimmed.startsWith('```')) {
      flushParagraph();
      flushList();
      final String language = trimmed.substring(3).trim();
      final List<String> code = <String>[];
      i++;
      while (i < lines.length && !lines[i].trim().startsWith('```')) {
        code.add(lines[i]);
        i++;
      }
      i++;
      blocks.add(MdCode(code.join('\n'),
          language: language.isEmpty ? null : language));
      continue;
    }

    if (trimmed.isEmpty) {
      flushParagraph();
      flushList();
      i++;
      continue;
    }

    if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(trimmed)) {
      flushParagraph();
      flushList();
      blocks.add(const MdRule());
      i++;
      continue;
    }

    final RegExpMatch? heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
    if (heading != null) {
      flushParagraph();
      flushList();
      blocks.add(MdHeading(heading.group(1)!.length, heading.group(2)!.trim()));
      i++;
      continue;
    }

    final RegExpMatch? quote = RegExp(r'^>\s?(.*)$').firstMatch(trimmed);
    if (quote != null) {
      flushParagraph();
      flushList();
      final List<String> quoted = <String>[quote.group(1)!];
      i++;
      while (i < lines.length &&
          RegExp(r'^>\s?').hasMatch(lines[i].trim())) {
        quoted.add(lines[i].trim().replaceFirst(RegExp(r'^>\s?'), ''));
        i++;
      }
      blocks.add(MdQuote(quoted.join(' ').trim()));
      continue;
    }

    final RegExpMatch? bullet =
        RegExp(r'^([-*+]|\d+[.)])\s+(.*)$').firstMatch(trimmed);
    if (bullet != null) {
      flushParagraph();
      final bool ordered = RegExp(r'^\d').hasMatch(bullet.group(1)!);
      // A list that changes kind starts a new list, so a numbered list under a
      // bulleted one does not silently become part of it.
      if (listItems.isNotEmpty && ordered != listOrdered) flushList();
      listOrdered = ordered;
      listItems.add(bullet.group(2)!.trim());
      i++;
      continue;
    }

    flushList();
    if (paragraph.isNotEmpty) paragraph.write(' ');
    paragraph.write(trimmed);
    i++;
  }

  flushParagraph();
  flushList();
  return blocks;
}

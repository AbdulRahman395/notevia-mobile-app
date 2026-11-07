import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notevia_mobile_app/theme/tokens.dart';
import 'package:notevia_mobile_app/ui/markdown_editor.dart';

MarkdownEditingController ctl(String text, int start, [int? end]) => MarkdownEditingController()
  ..value = TextEditingValue(text: text, selection: TextSelection(baseOffset: start, extentOffset: end ?? start));

final _f = MarkdownListFormatter();

TextEditingValue enter(String text, int at) => _f.formatEditUpdate(
  TextEditingValue(text: text, selection: TextSelection.collapsed(offset: at)),
  TextEditingValue(text: text.replaceRange(at, at, '\n'), selection: TextSelection.collapsed(offset: at + 1)),
);

TextEditingValue backspace(String text, int at) => _f.formatEditUpdate(
  TextEditingValue(text: text, selection: TextSelection.collapsed(offset: at)),
  TextEditingValue(text: text.replaceRange(at - 1, at, ''), selection: TextSelection.collapsed(offset: at - 1)),
);

void main() {
  test('bold wraps and unwraps a selection', () {
    final c = ctl('hello world', 0, 5)..toggleInline('**');
    expect(c.text, '**hello** world');
    expect(c.isInline('**'), isTrue);
    c.toggleInline('**');
    expect(c.text, 'hello world');
    expect(c.selection, const TextSelection(baseOffset: 0, extentOffset: 5));
  });

  test('bold with the cursor inside a bold word removes bold', () {
    final c = ctl('a **bold** b', 5)..toggleInline('**');
    expect(c.text, 'a bold b');
  });

  test('bold with nothing selected starts bold typing, and is dropped if unused', () {
    final c = ctl('a ', 2)..toggleInline('**');
    expect(c.text, 'a ****');
    expect(c.selection.baseOffset, 4);
    expect(c.isInline('**'), isTrue);
    expect(c.markdown, 'a ');
    c.selection = const TextSelection.collapsed(offset: 0);
    expect(c.text, 'a ');
  });

  test('typing into a pending pair keeps it', () {
    final c = ctl('a ', 2)..toggleInline('**');
    c.value = const TextEditingValue(text: 'a **x**', selection: TextSelection.collapsed(offset: 5));
    expect(c.text, 'a **x**');
    expect(c.markdown, 'a **x**');
  });

  test('cursor never sits inside a line prefix', () {
    final c = ctl('## Title', 1);
    expect(c.selection.baseOffset, 3);
    final d = ctl('- [ ] task', 0);
    expect(d.selection.baseOffset, 6);
  });

  test('cursor between hidden closing markers moves before them', () {
    final c = ctl('**bold** x', 7);
    expect(c.selection.baseOffset, 6);
  });

  test('heading toggles and replaces list prefix', () {
    final c = ctl('- item', 3)..toggleBlock(MdBlock.h2);
    expect(c.text, '## item');
    expect(c.currentBlock, MdBlock.h2);
    c.toggleBlock(MdBlock.h2);
    expect(c.text, 'item');
  });

  test('numbered list numbers each selected line', () {
    final c = ctl('a\nb\nc', 0, 5)..toggleBlock(MdBlock.numbered);
    expect(c.text, '1. a\n2. b\n3. c');
  });

  test('checkbox toggles', () {
    final c = ctl('- [ ] task', 10)..toggleTask(2);
    expect(c.text, '- [x] task');
    c.toggleTask(2);
    expect(c.text, '- [ ] task');
  });

  test('enter continues lists', () {
    expect(enter('- one', 5).text, '- one\n- ');
    expect(enter('3. one', 6).text, '3. one\n4. ');
    expect(enter('- [x] done', 10).text, '- [x] done\n- [ ] ');
    expect(enter('plain', 5).text, 'plain\n');
  });

  test('enter on an empty item ends the list', () {
    final v = enter('- one\n- ', 8);
    expect(v.text, '- one\n');
    expect(v.selection.baseOffset, 6);
  });

  test('enter after a bold word goes after its markers', () {
    expect(enter('**bold**', 6).text, '**bold**\n');
  });

  test('backspace skips hidden markers', () {
    final v = backspace('**bold** x', 8);
    expect(v.text, '**bol** x');
    expect(v.selection.baseOffset, 7);
  });

  test('backspace on the last letter drops the empty pair', () {
    final v = backspace('a **b**', 7);
    expect(v.text, 'a ');
  });

  test('backspace at the start of a bullet removes the bullet', () {
    final v = backspace('- item', 2);
    expect(v.text, 'item');
    expect(v.selection.baseOffset, 0);
    expect(backspace('## Title', 3).text, 'Title');
  });

  test('backspace in plain text is unchanged', () {
    expect(backspace('hello', 5).text, 'hell');
  });

  test('a leftover empty pair is dropped', () {
    final c = ctl('a **b**', 7);
    c.value = const TextEditingValue(text: 'a ****', selection: TextSelection.collapsed(offset: 6));
    expect(c.text, 'a ');
    expect(c.selection.baseOffset, 2);
  });

  test('link wraps the selection', () {
    final c = ctl('see docs', 4, 8)..insertLink('https://x.y');
    expect(c.text, 'see [docs](https://x.y)');
  });

  testWidgets('display keeps one character per text character', (tester) async {
    const doc =
        '# Title **bold**\n'
        'Some *italic* and _also_ and ~~gone~~ and `code` and [a link](https://x.y).\n'
        '> quoted **text**\n'
        '- [ ] todo\n- [x] done\n- bullet\n1. one\n2) two\n---\n'
        '```\nlet x = 1;\n```\n'
        '**unclosed and * stars * and __under__\n\n';
    final c = MarkdownEditingController(text: doc)..colors = NvColors.dark;
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: TextField(controller: c, maxLines: null))),
    );
    late TextSpan span;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            span = c.buildTextSpan(context: context, style: const TextStyle(fontSize: 16), withComposing: true);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(span.toPlainText().length, doc.length);
    expect(tester.takeException(), isNull);
  });
}


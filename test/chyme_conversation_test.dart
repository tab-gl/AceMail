import 'package:ace_mail/state/chyme_conversation.dart';
import 'package:ace_mail/services/chyme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('conversation notifies listeners and preserves turn order', () {
    final conversation = ChymeConversation();
    var notifications = 0;
    conversation.addListener(() => notifications++);
    conversation.add(const ChymeTurn('user', 'First'));
    conversation.add(const ChymeTurn('assistant', 'Second'));
    expect(conversation.turns.map((turn) => turn.content), ['First', 'Second']);
    expect(notifications, 2);
    conversation.clear();
    expect(conversation.turns, isEmpty);
    expect(notifications, 3);
  });

  test('conversation expires after one hour', () {
    var now = DateTime(2026, 1, 1, 12);
    final conversation = ChymeConversation(clock: () => now);
    conversation.add(const ChymeTurn('user', 'Private message context'));
    now = now.add(const Duration(minutes: 59));
    expect(conversation.turns, hasLength(1));
    now = now.add(const Duration(minutes: 2));
    expect(conversation.turns, isEmpty);
  });
}

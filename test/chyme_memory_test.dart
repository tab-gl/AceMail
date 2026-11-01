import 'package:ace_mail/services/chyme.dart';
import 'package:ace_mail/state/chyme_conversation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('conversation is shared, ordered and observable', () {
    final ChymeConversation conversation = ChymeConversation();
    int notifications = 0;
    conversation.addListener(() => notifications++);
    conversation.add(const ChymeTurn('user', 'hello'));
    conversation.add(const ChymeTurn('assistant', 'hello back'));
    expect(conversation.turns.map((ChymeTurn turn) => turn.content), ['hello', 'hello back']);
    expect(notifications, 2);
    conversation.clear();
    expect(conversation.turns, isEmpty);
    expect(notifications, 3);
  });

  test('conversation expires after one hour without disk persistence', () {
    DateTime now = DateTime(2026, 1, 1, 12);
    final ChymeConversation conversation = ChymeConversation(clock: () => now);
    conversation.add(const ChymeTurn('user', 'private mail context'));
    now = now.add(const Duration(hours: 1, minutes: 1));
    expect(conversation.turns, isEmpty);
  });
}

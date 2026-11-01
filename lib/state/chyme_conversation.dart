import 'package:flutter/foundation.dart';

import '../services/chyme.dart';

/// In-memory Chyme conversation owned by the application session. It is not
/// persisted: mail content and assistant transcripts never enter local disk.
class ChymeConversation extends ChangeNotifier {
  ChymeConversation({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const Duration lifetime = Duration(hours: 1);
  final DateTime Function() _clock;
  final List<ChymeTurn> _turns = <ChymeTurn>[];
  DateTime? _startedAt;

  List<ChymeTurn> get turns {
    _expireIfNeeded();
    return List<ChymeTurn>.unmodifiable(_turns);
  }

  bool get isEmpty => turns.isEmpty;

  void add(ChymeTurn turn) {
    _expireIfNeeded();
    _startedAt ??= _clock();
    _turns.add(turn);
    notifyListeners();
  }

  void clear() {
    if (_turns.isEmpty && _startedAt == null) return;
    _turns.clear();
    _startedAt = null;
    notifyListeners();
  }

  void _expireIfNeeded() {
    final DateTime? started = _startedAt;
    if (started != null && _clock().difference(started) > lifetime) {
      _turns.clear();
      _startedAt = null;
    }
  }
}

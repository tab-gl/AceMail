import '../data/preferences.dart';
import '../models/full_message.dart';
import '../models/message_summary.dart';
import 'chyme.dart';
import 'chyme_context.dart';

abstract final class ChymePrompt {
  static String forMail({
    required Preferences preferences,
    required List<MessageSummary> visible,
    FullMessage? open,
  }) {
    final ChymeConfig config = ChymeConfig.fromPreferences(preferences);
    return '${Chyme.systemPromptFor(config.tone, custom: config.customPrompt)}\n'
        '${ChymeContext.forMail(visible: visible, open: open, readsMail: config.readsMail)}';
  }
}

import 'package:ace_mail/models/message_summary.dart';
import 'package:ace_mail/services/mail_highlights.dart';
import 'package:flutter_test/flutter_test.dart';

/// The highlights rail sits above the mail, so a wrong card is not a hidden
/// bug: it is the first thing on the screen claiming something about a message.
/// These tests are mostly about what the scanner refuses to classify.
void main() {
  final DateTime now = DateTime.utc(2026, 11, 3, 9);

  int uid = 0;

  MessageSummary mail(
    String subject, {
    String from = 'Sender',
    DateTime? date,
    bool seen = false,
    String? otp,
  }) {
    uid += 1;
    return MessageSummary(
      uid: uid,
      sequenceId: uid,
      subject: subject,
      fromName: from,
      fromEmail: '${from.toLowerCase().replaceAll(' ', '.')}@example.com',
      date: date ?? now.subtract(const Duration(hours: 1)),
      isSeen: seen,
      isFlagged: false,
      otp: otp,
    );
  }

  group('HighlightScanner.scan', () {
    test('classifies the kinds Gmail has cards for', () {
      final List<MailHighlight> found = HighlightScanner.scan(
        <MessageSummary>[
          mail('Your package is out for delivery', from: 'Courier'),
          mail('Your invoice for November', from: 'Power Co'),
          mail('Flight AI 302 confirmed', from: 'Airline'),
          mail('You have been invited: design review', from: 'Calendar'),
          mail('New sign-in to your account', from: 'Bank'),
        ],
        now: now,
      );

      final Set<HighlightKind> kinds = <HighlightKind>{
        for (final MailHighlight h in found) h.kind,
      };
      expect(
        kinds,
        containsAll(<HighlightKind>[
          HighlightKind.delivery,
          HighlightKind.bill,
          HighlightKind.travel,
          HighlightKind.event,
          HighlightKind.security,
        ]),
      );
    });

    test('a code wins over every keyword', () {
      final List<MailHighlight> found = HighlightScanner.scan(
        <MessageSummary>[
          mail(
            'Your delivery verification code',
            otp: '483920',
            from: 'Courier',
          ),
        ],
        now: now,
      );

      expect(found.single.kind, HighlightKind.code);
      expect(found.single.title, '483920');
    });

    test('orders codes and security above the rest', () {
      final List<MailHighlight> found = HighlightScanner.scan(
        <MessageSummary>[
          mail('Your invoice is ready', from: 'Power Co'),
          mail('New sign-in to your account', from: 'Bank'),
          mail('Your code is 7712', otp: '7712', from: 'Bank'),
        ],
        now: now,
      );

      expect(
        found.map((MailHighlight h) => h.kind).toList(),
        <HighlightKind>[
          HighlightKind.code,
          HighlightKind.security,
          HighlightKind.bill,
        ],
      );
    });

    test('leaves read mail alone', () {
      final List<MailHighlight> found = HighlightScanner.scan(
        <MessageSummary>[
          mail('Your package has shipped', seen: true),
        ],
        now: now,
      );

      expect(found, isEmpty);
    });

    test('ignores anything older than the window', () {
      final List<MailHighlight> found = HighlightScanner.scan(
        <MessageSummary>[
          mail(
            'Your package has shipped',
            date: now.subtract(const Duration(days: 30)),
          ),
        ],
        now: now,
      );

      expect(found, isEmpty);
    });

    test('does not classify ordinary mail', () {
      final List<MailHighlight> found = HighlightScanner.scan(
        <MessageSummary>[
          mail('Re: lunch on Friday', from: 'Ananya'),
          mail('The notes from yesterday', from: 'Rohit'),
          mail('', from: 'Nobody'),
        ],
        now: now,
      );

      expect(found, isEmpty);
    });

    test('caps how many cards one kind can take', () {
      final List<MailHighlight> found = HighlightScanner.scan(
        <MessageSummary>[
          for (int i = 0; i < 5; i++)
            mail('Your order $i has shipped', from: 'Shop $i'),
        ],
        now: now,
      );

      expect(found.length, HighlightScanner.perKind);
      expect(found.every((MailHighlight h) => h.kind == HighlightKind.delivery),
          isTrue);
    });

    test('respects the overall limit', () {
      final List<MailHighlight> found = HighlightScanner.scan(
        <MessageSummary>[
          mail('Your package has shipped'),
          mail('Your invoice is ready'),
          mail('Flight confirmed'),
          mail('You are invited'),
          mail('New sign-in to your account'),
        ],
        now: now,
        limit: 2,
      );

      expect(found.length, 2);
    });

    test('takes the newest of each kind first', () {
      final List<MailHighlight> found = HighlightScanner.scan(
        <MessageSummary>[
          mail(
            'Your order has shipped',
            from: 'Older',
            date: now.subtract(const Duration(days: 2)),
          ),
          mail(
            'Your order has shipped',
            from: 'Newer',
            date: now.subtract(const Duration(minutes: 5)),
          ),
        ],
        now: now,
      );

      expect(found.first.detail, 'Newer');
    });

    test('a card carries the message it came from', () {
      final MessageSummary message = mail('Your invoice is ready');
      final List<MailHighlight> found =
          HighlightScanner.scan(<MessageSummary>[message], now: now);

      expect(found.single.message.uid, message.uid);
      expect(found.single.title, 'Your invoice is ready');
      expect(found.single.detail, 'Sender');
    });

    test('an empty list makes no cards', () {
      expect(HighlightScanner.scan(<MessageSummary>[], now: now), isEmpty);
      expect(
        HighlightScanner.scan(<MessageSummary>[mail('x')], now: now, limit: 0),
        isEmpty,
      );
    });
  });
}

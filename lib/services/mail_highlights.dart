import 'package:flutter/foundation.dart';

import '../models/message_summary.dart';

/// What kind of thing a highlight is about.
///
/// Deliberately short. Gmail's highlights are packages, bills, flights and
/// reservations, and the list is short for a reason: a card that says something
/// the row below it does not is worth the height, and a card that restates the
/// row is not. Six kinds is already generous.
enum HighlightKind {
  /// A one-time code, which is the one highlight that saves a tap rather than
  /// a glance.
  code,

  /// A sign-in, a password change, a new device — the mail you read because it
  /// was not you.
  security,

  /// Something is on its way, or has arrived.
  delivery,

  /// A bill, an invoice, a payment.
  bill,

  /// A flight, a train, a booking.
  travel,

  /// An invitation or an appointment.
  event;

  /// The heading over the card. Not a sentence — it is a label, and the card
  /// beside it is the sentence.
  String get label => switch (this) {
        HighlightKind.code => 'Code',
        HighlightKind.security => 'Security',
        HighlightKind.delivery => 'Delivery',
        HighlightKind.bill => 'Bill',
        HighlightKind.travel => 'Travel',
        HighlightKind.event => 'Event',
      };

  /// Where the kind sits in the rail. Codes and security first, because they
  /// are the two a person acts on within the minute.
  int get priority => switch (this) {
        HighlightKind.code => 0,
        HighlightKind.security => 1,
        HighlightKind.delivery => 2,
        HighlightKind.bill => 3,
        HighlightKind.travel => 4,
        HighlightKind.event => 5,
      };
}

/// One card in the rail.
@immutable
class MailHighlight {
  const MailHighlight({
    required this.kind,
    required this.message,
    required this.title,
    required this.detail,
  });

  final HighlightKind kind;

  /// The message this card is about. Tapping the card opens it — the card is a
  /// shortcut to a row that is already in the list, never a thing of its own.
  final MessageSummary message;

  /// The line in the card. A code for [HighlightKind.code], the subject
  /// otherwise.
  final String title;

  /// Who it is from.
  final String detail;
}

/// Finds the handful of messages at the top of an inbox worth a card.
///
/// The rules are keyword rules over the subject and sender, and they are
/// deliberately narrow: this runs on every rebuild of the list, and a classifier
/// that guesses produces cards that are wrong often enough to be noise. Every
/// card here is a message that is *also* in the list below it — the rail is a
/// shortcut, not a summary, and nothing in it is invented. The card says the
/// subject and who sent it; it never claims a package is arriving today, because
/// the headers do not know that.
abstract final class HighlightScanner {
  /// How far back a message can be and still be a highlight. A week is the
  /// window in which "your code" or "your delivery" is still the thing you are
  /// doing; a month-old bill is a row, not a highlight.
  static const Duration window = Duration(days: 7);

  /// At most this many cards per kind, so one chatty sender cannot fill the
  /// rail with six of the same thing.
  static const int perKind = 2;

  /// The patterns, in the order they are tried. First match wins, so the
  /// specific kinds are asked before the general ones: "your verification code
  /// for the delivery" is a code.
  static const Map<HighlightKind, String> _patterns = <HighlightKind, String>{
    HighlightKind.security:
        r'\b(password|passcode|sign[- ]?in|log[- ]?in|2fa|two[- ]?factor|'
            r'two[- ]?step|security alert|unusual (activity|sign[- ]?in)|'
            r'new (device|sign[- ]?in)|account (alert|notice|locked)|'
            r'authenticat|suspicious|verify your (account|identity|email))\b',
    HighlightKind.delivery:
        r'\b(order|package|parcel|shipment|delivery|deliveries|delivered|'
            r'shipped|shipping|tracking|dispatched|out for delivery|'
            r'arriving|waybill|consignment)\b',
    HighlightKind.bill:
        r'\b(invoice|bill|billing|payment|paid|receipt|statement|'
            r'amount due|due date|subscription|renewal|renewed|refund)\b',
    HighlightKind.travel:
        r'\b(flight|boarding|itinerary|booking|booked|reservation|hotel|'
            r'train|pnr|ticket|check[- ]?in|airline|departure|gate change)\b',
    HighlightKind.event:
        r'\b(invitation|invite|invited|meeting|webinar|rsvp|calendar|'
            r'appointment|scheduled|reminder)\b',
  };

  static final Map<HighlightKind, RegExp> _compiled = <HighlightKind, RegExp>{
    for (final MapEntry<HighlightKind, String> entry in _patterns.entries)
      entry.key: RegExp(entry.value, caseSensitive: false),
  };

  /// The cards for [rows], newest first within each kind, capped at [limit].
  ///
  /// Read messages are skipped: a highlight is a thing still to be dealt with,
  /// and a rail that keeps showing yesterday's read mail is a rail people learn
  /// to scroll past. [now] is injectable so the window can be tested without
  /// waiting a week.
  static List<MailHighlight> scan(
    Iterable<MessageSummary> rows, {
    DateTime? now,
    int limit = 6,
  }) {
    if (limit <= 0) return const <MailHighlight>[];
    final DateTime reference = now ?? DateTime.now();
    final DateTime oldest = reference.subtract(window);

    final List<MailHighlight> found = <MailHighlight>[];
    final Map<HighlightKind, int> taken = <HighlightKind, int>{};

    // Sorted rather than assumed: the list is already newest-first, but the
    // scanner is also called on a search result and on a unified inbox, and a
    // highlight rail that orders itself by whatever it was handed is a rail
    // that changes order when the folder does.
    final List<MessageSummary> sorted = rows.toList()
      ..sort((MessageSummary a, MessageSummary b) {
        final DateTime ad = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        final DateTime bd = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });

    for (final MessageSummary message in sorted) {
      if (found.length >= limit) break;
      if (message.isSeen) continue;
      final DateTime? date = message.date;
      if (date == null || date.isBefore(oldest)) continue;

      final HighlightKind? kind = _classify(message);
      if (kind == null) continue;
      if ((taken[kind] ?? 0) >= perKind) continue;

      taken[kind] = (taken[kind] ?? 0) + 1;
      found.add(
        MailHighlight(
          kind: kind,
          message: message,
          title: kind == HighlightKind.code
              ? message.otp!
              : message.subject.trim(),
          detail: message.fromName.trim(),
        ),
      );
    }

    // Priority first, then newest within a kind. A stable sort keeps the
    // newest-first order the loop above already produced.
    found.sort((MailHighlight a, MailHighlight b) {
      final int byKind = a.kind.priority.compareTo(b.kind.priority);
      if (byKind != 0) return byKind;
      return (b.message.date ?? oldest).compareTo(a.message.date ?? oldest);
    });
    return found;
  }

  /// The kind of [message], or null when it is not one of them.
  ///
  /// A code beats every keyword: a code in the subject is unambiguous, and the
  /// message is worth a card whatever else it says.
  static HighlightKind? _classify(MessageSummary message) {
    if (message.otp != null) return HighlightKind.code;
    final String subject = message.subject;
    if (subject.trim().isEmpty) return null;
    for (final MapEntry<HighlightKind, RegExp> entry in _compiled.entries) {
      if (entry.value.hasMatch(subject)) return entry.key;
    }
    return null;
  }
}

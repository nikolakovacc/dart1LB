import 'package:support/support.dart';
import 'package:test/test.dart';

void main() {
  group('1. Синтаксичний розбір (parseLine) та валідація', () {
    test('Успішний розбір коректного CSV рядка', () {
      const line =
          'TICK-2026-0001;test@corp.ua;Оплата;Critical;Closed;8;2026-10-01T09:00:00;2026-10-01T17:00:00';
      final result = parseLine(line);
      expect(result.ticket, isNotNull);
      expect(result.error, isNull);
      expect(result.ticket!.id, equals('TICK-2026-0001'));
      expect(result.ticket!.client, equals('test@corp.ua'));
      expect(result.ticket!.estimatedHours, equals(8));
      expect(result.ticket!.closedAt, isNotNull);
    });
    test('Розбір рядка з відсутньою датою закриття (NONE)', () {
      const line =
          'TICK-2026-0002;client@ua.biz;Запит;Low;Open;2;2026-10-02T10:00:00;NONE';
      final result = parseLine(line);
      expect(result.ticket, isNotNull);
      expect(result.ticket!.closedAt, isNull);
    });
    test('Відхилення рядка з недостатньою кількістю полів', () {
      const line = 'TICK-2026-0003;user@test.ua;Помилка;Low';
      final result = parseLine(line);
      expect(result.ticket, isNull);
      expect(result.error, contains('Невідповідна кількість полів'));
    });
    test('Відхилення рядка з нечисловим значенням у оцінці часу', () {
      const line =
          'TICK-2026-0004;user@test.ua;Помилка;Low;Open;NotANumber;2026-10-01T09:00:00;NONE';
      final result = parseLine(line);
      expect(result.ticket, isNull);
      expect(result.error, contains('не є цілим числом'));
    });
    test('Відхилення рядка з некоректною датою', () {
      const line =
          'TICK-2026-0005;user@test.ua;Помилка дати;Low;Open;5;invalid-date-string;NONE';
      final result = parseLine(line);
      expect(result.ticket, isNull);
      expect(result.error, contains('Некоректний формат дати створення'));
    });
    test('Валідатор виявляє неприпустимі значення пріоритету та зв'
        'язку дат', () {
      final invalidTicket = (
        id: 'BAD-ID',
        client: 'bad-email',
        topic: 'Тест',
        priority: 'SuperUrgent', // Невідомий пріоритет
        status: 'Closed',
        estimatedHours: 250, // Поза діапазоном (1..100)
        createdAt: DateTime(2026, 10, 10, 12, 0),
        closedAt: DateTime(2026, 10, 10, 10, 0), // Закрито раніше створення!
      );
      final violations = validateTicket(invalidTicket);
      expect(violations, hasLength(3));
      expect(violations[0], contains('Невідомий пріоритет'));
      expect(violations[1], contains('Оцінка годин поза діапазоном'));
      expect(violations[2], contains('Дата закриття не може передувати'));
    });
  });
  group('2. Конвеєри обробки та агрегація', () {
    test('Конвеєр averageResolutionTimeHours коректно рахує середній час', () {
      final sample = [
        (
          id: 'T-1',
          client: 'c1@t.ua',
          topic: 'Top 1',
          priority: 'Low',
          status: 'Closed',
          estimatedHours: 2,
          createdAt: DateTime(2026, 10, 1, 10, 0),
          closedAt: DateTime(2026, 10, 1, 14, 0), // 4 години
        ),
        (
          id: 'T-2',
          client: 'c2@t.ua',
          topic: 'Top 2',
          priority: 'High',
          status: 'Closed',
          estimatedHours: 5,
          createdAt: DateTime(2026, 10, 2, 9, 0),
          closedAt: DateTime(2026, 10, 2, 17, 0), // 8 годин
        ),
      ];
      final avg = averageResolutionTimeHours(sample);
      expect(avg, closeTo(6.0, 0.01)); // (4 + 8) / 2 = 6.0
    });
    test(
      'Конвеєр totalEstimatedHoursByPriority рахує години активних тікетів',
      () {
        final sample = [
          (
            id: 'T-1',
            client: 'c1@t.ua',
            topic: 'Top 1',
            priority: 'Critical',
            status: 'Open',
            estimatedHours: 10,
            createdAt: DateTime.now(),
            closedAt: null,
          ),
          (
            id: 'T-2',
            client: 'c2@t.ua',
            topic: 'Top 2',
            priority: 'High',
            status: 'In Progress',
            estimatedHours: 15,
            createdAt: DateTime.now(),
            closedAt: null,
          ),
          (
            id: 'T-3',
            client: 'c3@t.ua',
            topic: 'Top 3',
            priority: 'Critical',
            status: 'Closed', // Закритий не повинен враховуватись
            estimatedHours: 20,
            createdAt: DateTime.now(),
            closedAt: DateTime.now(),
          ),
        ];
        final total = totalEstimatedHoursByPriority(sample, {
          'Critical',
          'High',
        });
        expect(total, equals(25)); // 10 + 15 = 25
      },
    );
    test('Групування та агрегація за пріоритетом', () {
      final tickets = rawTicketLines
          .map(parseLine)
          .where((r) => r.ticket != null)
          .map((r) => r.ticket!)
          .toList();
      final grouped = groupTicketsByPriority(tickets);
      final stats = aggregateByPriority(grouped);
      expect(grouped.containsKey('Critical'), isTrue);
      expect(stats['Critical']!.total, equals(4));
    });
  });
  group('3. Сортування та замикання', () {
    test('Сортування за пріоритетом (Critical > Low)', () {
      final tickets = rawTicketLines
          .map(parseLine)
          .where((r) => r.ticket != null)
          .map((r) => r.ticket!)
          .toList();
      final sorted = sortTickets(tickets, sortBy: 'priority', ascending: false);
      expect(sorted.first.priority, equals('Critical'));
      expect(sorted.last.priority, equals('Low'));
    });
    test('Замикання makeCounter ізолює стан для кожного екземпляра', () {
      final c1 = makeCounter();
      final c2 = makeCounter(10);
      expect(c1(), equals(1));
      expect(c1(), equals(2));
      expect(c2(), equals(11));
      expect(c1(), equals(3));
    });
  });
  group('4. Регулярні вирази, маскування та дати', () {
    test('Регулярний вираз перевіряє формат ідентифікатора', () {
      final match = ticketIdRegex.firstMatch('TICK-2026-0042');
      expect(match, isNotNull);
      expect(match!.namedGroup('dept'), equals('TICK'));
      expect(match.namedGroup('year'), equals('2026'));
      expect(match.namedGroup('seq'), equals('0042'));
    });
    test('Маскування email через replaceAllMapped', () {
      const email = 'alexander.ivanov@domain.com';
      final masked = maskClientEmail(email);
      expect(masked, equals('al***@domain.com'));
    });
    test('Арифметика дат', () {
      final ticket = (
        id: 'T-1',
        client: 'u@u.ua',
        topic: 'T',
        priority: 'Low',
        status: 'Closed',
        estimatedHours: 1,
        createdAt: DateTime(2026, 10, 1, 10, 0),
        closedAt: DateTime(2026, 10, 1, 15, 30),
      );
      final dur = ticketResolutionDuration(ticket);
      expect(dur, isNotNull);
      expect(dur!.inHours, equals(5));
      expect(dur.inMinutes, equals(330));
    });
  });
}

/// Тип сутності звернення до служби підтримки (Варіант 6), поданий як кортеж (record).
/// Класи згідно з вимогами ЛР1 суворо заборонені.
typedef Ticket = ({
  String id,
  String client,
  String topic,
  String priority,
  String status,
  int estimatedHours,
  DateTime createdAt,
  DateTime? closedAt,
});

/// Результат синтаксичного розбору рядка CSV без використання винятків.
typedef ParseResult = ({Ticket? ticket, String? error, String rawLine});

/// Константний набір вхідних рядків CSV (18 записів, 4 з яких навмисно пошкоджені).
const List<String> rawTicketLines = [
  'TICK-2026-0001;ivan.petrenko@enterprise.ua;Не проходить оплата карткою;Critical;Closed;8;2026-10-01T09:30:00;2026-10-01T17:30:00',
  'TICK-2026-0002;olena.koval@smb.com;Зміна контактного email у профілі;Low;Open;2;2026-10-03T11:00:00;NONE',
  'TICK-2026-0003;dmytro.k@tech.ua;Помилка інтеграції з REST API;High;In Progress;12;2026-10-05T16:20:00;NONE',
  'TICK-2026-0004;anna.bila@startup.io;Консультація щодо тарифних планів;Low;Closed;1;2026-10-06T10:15:00;2026-10-06T11:15:00',
  'TICK-2026-0005;admin@finance.corp.ua;Збій синхронізації бази даних;Critical;Closed;6;2026-10-07T08:00:00;2026-10-07T14:00:00',
  'TICK-2026-0006;corrupted.user@test.ua;Відсутні необхідні поля;Low',
  'TICK-2026-0007;taras.h@service.ua;Запит на вивантаження резервної копії;Medium;Open;4;2026-10-09T13:40:00;NONE',
  'TICK-2026-0008;security.officer@bank.ua;Падіння веб-сервера після деплою;Critical;Closed;9;2026-10-10T22:10:00;2026-10-11T07:10:00',
  'TICK-2026-0009;bad.number@corp.ua;Нечислова оцінка часу;Medium;Open;три;2026-10-11T09:00:00;NONE',
  'TICK-2026-0010;support@client.ua;Уточнення вимог до нового функціоналу;Low;Resolved;2;2026-10-12T15:00:00;NONE',
  'TICK-2026-0011;serhii.m@company.org;Помилка валідації форми реєстрації;Medium;Closed;5;2026-10-13T10:00:00;2026-10-13T18:00:00',
  'TICK-2026-0012;bad.date@fail.ua;Некоректний місяць дати;High;Open;6;2026-13-45T10:00:00;NONE',
  'TICK-2026-0013;yulia.v@retail.ua;Неможливо завантажити скан договору;Medium;Closed;6;2026-10-14T11:20:00;2026-10-14T20:20:00',
  'TICK-2026-0014;nadiia.s@mail.ua;Забув пароль до облікового запису;Low;Resolved;1;2026-10-15T09:30:00;NONE',
  'TICK-2026-0015;roman.d@biz.ua;Повільна генерація PDF-звітів;High;In Progress;10;2026-10-16T15:00:00;NONE',
  'TICK-2026-0016;bad.closed@biz.ua;Невалідна дата закриття;Medium;Closed;4;2026-10-16T12:00:00;invalid-closed-date',
  'TICK-2026-0017;svitlana.p@corp.ua;Витік пам’яті у фоновому процесі;Critical;Open;14;2026-10-17T08:45:00;NONE',
  'TICK-2026-0018;maksym.o@start.ua;Запит на підключення webhook-сповіщень;Medium;In Progress;5;2026-10-18T14:10:00;NONE',
];

/// Безпечно розбирає рядок CSV на складові без використання блоку try/catch.
ParseResult parseLine(String line) {
  final parts = line.split(';');
  if (parts.length != 8) {
    return (
      ticket: null,
      error:
          'Невідповідна кількість полів: очікувалося 8, отримано ${parts.length}',
      rawLine: line,
    );
  }

  final id = parts[0].trim();
  final client = parts[1].trim();
  final topic = parts[2].trim();
  final priority = parts[3].trim();
  final status = parts[4].trim();

  final estimatedHours = int.tryParse(parts[5].trim());
  if (estimatedHours == null) {
    return (
      ticket: null,
      error:
          'Некоректне значення оцінки часу: "${parts[5].trim()}" не є цілим числом',
      rawLine: line,
    );
  }

  final createdAt = DateTime.tryParse(parts[6].trim());
  if (createdAt == null) {
    return (
      ticket: null,
      error: 'Некоректний формат дати створення: "${parts[6].trim()}"',
      rawLine: line,
    );
  }

  final closedRaw = parts[7].trim();
  DateTime? closedAt;
  if (closedRaw != 'NONE' && closedRaw.isNotEmpty) {
    closedAt = DateTime.tryParse(closedRaw);
    if (closedAt == null) {
      return (
        ticket: null,
        error: 'Некоректний формат дати закриття: "$closedRaw"',
        rawLine: line,
      );
    }
  }

  return (
    ticket: (
      id: id,
      client: client,
      topic: topic,
      priority: priority,
      status: status,
      estimatedHours: estimatedHours,
      createdAt: createdAt,
      closedAt: closedAt,
    ),
    error: null,
    rawLine: line,
  );
}

/// Валідує бізнес-правила звернення до підтримки.
/// Повертає список помилок (якщо порожній — запис валідний).
List<String> validateTicket(Ticket ticket) {
  final errors = <String>[];
  const validPriorities = {'Low', 'Medium', 'High', 'Critical'};
  const validStatuses = {'Open', 'In Progress', 'Resolved', 'Closed'};

  if (!validPriorities.contains(ticket.priority)) {
    errors.add('Невідомий пріоритет: ${ticket.priority}');
  }
  if (!validStatuses.contains(ticket.status)) {
    errors.add('Невідомий статус: ${ticket.status}');
  }
  if (ticket.estimatedHours <= 0 || ticket.estimatedHours > 100) {
    errors.add(
      'Оцінка годин поза діапазоном (1..100): ${ticket.estimatedHours}',
    );
  }
  if (ticket.closedAt != null && ticket.closedAt!.isBefore(ticket.createdAt)) {
    errors.add('Дата закриття не може передувати даті створення');
  }
  if (ticket.status == 'Closed' && ticket.closedAt == null) {
    errors.add(
      'Для статусу Closed обов'
      'язково має бути вказана дата закриття',
    );
  }
  if (ticket.status == 'Open' && ticket.closedAt != null) {
    errors.add('Для статусу Open дата закриття має бути відсутня (NONE)');
  }

  return errors;
}

/// Конвеєр 1: Обчислює середній час вирішення закритих звернень у годинах (where -> map -> fold).
double averageResolutionTimeHours(Iterable<Ticket> tickets) {
  final closedDurations = tickets
      .where((t) => t.status == 'Closed' && t.closedAt != null)
      .map((t) => t.closedAt!.difference(t.createdAt).inMinutes / 60.0);

  final count = closedDurations.length;
  if (count == 0) return 0.0;

  final totalHours = closedDurations.fold<double>(
    0.0,
    (acc, hours) => acc + hours,
  );
  return totalHours / count;
}

/// Конвеєр 2: Обчислює загальну оцінку трудомісткості активних звернень заданих пріоритетів.
int totalEstimatedHoursByPriority(
  Iterable<Ticket> tickets,
  Set<String> priorities,
) {
  return tickets
      .where((t) => priorities.contains(t.priority) && t.status != 'Closed')
      .map((t) => t.estimatedHours)
      .fold<int>(0, (total, hours) => total + hours);
}

/// Конвеєр 3: Знаходить найстаріше незакрите звернення за допомогою fold.
Ticket? findOldestActiveTicket(Iterable<Ticket> tickets) {
  final activeTickets = tickets.where((t) => t.status != 'Closed');
  if (activeTickets.isEmpty) return null;

  return activeTickets.fold<Ticket>(
    activeTickets.first,
    (oldest, current) =>
        current.createdAt.isBefore(oldest.createdAt) ? current : oldest,
  );
}

/// Крок 6: Групує звернення за їхнім пріоритетом у `Map<String, List<Ticket>>`.
Map<String, List<Ticket>> groupTicketsByPriority(Iterable<Ticket> tickets) {
  final grouped = <String, List<Ticket>>{};
  for (final ticket in tickets) {
    grouped.putIfAbsent(ticket.priority, () => <Ticket>[]).add(ticket);
  }
  return grouped;
}

/// Крок 6: Обчислює агреговані показники для кожної групи пріоритету.
Map<String, ({int total, int closed, double avgHours})> aggregateByPriority(
  Map<String, List<Ticket>> grouped,
) {
  final result = <String, ({int total, int closed, double avgHours})>{};

  for (final entry in grouped.entries) {
    final list = entry.value;
    final total = list.length;
    final closed = list.where((t) => t.status == 'Closed').length;
    final totalHours = list.fold<int>(0, (sum, t) => sum + t.estimatedHours);
    final avgHours = total == 0 ? 0.0 : totalHours / total;

    result[entry.key] = (total: total, closed: closed, avgHours: avgHours);
  }

  return result;
}

/// Крок 7: Сортує звернення за вказаним критерієм ('date', 'priority', 'hours')
/// з можливістю зміни напряму через іменований параметр [ascending].
List<Ticket> sortTickets(
  Iterable<Ticket> tickets, {
  String sortBy = 'date',
  bool ascending = true,
}) {
  final list = List<Ticket>.from(tickets);

  list.sort((a, b) {
    int cmp;
    switch (sortBy) {
      case 'priority':
        const priorityWeight = {
          'Low': 1,
          'Medium': 2,
          'High': 3,
          'Critical': 4,
        };
        final weightA = priorityWeight[a.priority] ?? 0;
        final weightB = priorityWeight[b.priority] ?? 0;
        cmp = weightA.compareTo(weightB);
        break;
      case 'hours':
        cmp = a.estimatedHours.compareTo(b.estimatedHours);
        break;
      case 'date':
      default:
        cmp = a.createdAt.compareTo(b.createdAt);
    }
    return ascending ? cmp : -cmp;
  });

  return list;
}

/// Крок 8: Фабрика замикання-лічильника.
/// Захоплює локальну змінну [count] у купі (heap).
int Function() makeCounter([int initial = 0]) {
  var count = initial;
  return () {
    count++;
    return count;
  };
}

/// Крок 8: Фабрика предикатів, що замикає цільовий пріоритет.
bool Function(Ticket) makePriorityFilter(String targetPriority) {
  return (Ticket ticket) => ticket.priority == targetPriority;
}

/// Крок 9: Регулярний вираз для номера тікета з іменованими групами.
final ticketIdRegex = RegExp(r'^(?<dept>[A-Z]+)-(?<year>\d{4})-(?<seq>\d{4})$');

/// Крок 9: Регулярний вираз для аналізу email клієнта.
final clientEmailRegex = RegExp(r'^(?<username>[^@]+)@(?<domain>.+)$');

/// Крок 9: Маскує email клієнта для захисту персональних даних (GDPR) через replaceAllMapped.
String maskClientEmail(String email) {
  return email.replaceAllMapped(clientEmailRegex, (match) {
    if (match is RegExpMatch) {
      final user = match.namedGroup('username') ?? '';
      final domain = match.namedGroup('domain') ?? '';
      final visiblePrefix = user.length <= 2 ? user : user.substring(0, 2);
      return '$visiblePrefix***@$domain';
    }
    return email;
  });
}

/// Крок 10: Обчислює вік звернення у днях через difference та Duration.
int ticketAgeInDays(Ticket ticket, [DateTime? relativeTo]) {
  final now = relativeTo ?? DateTime.now();
  return now.difference(ticket.createdAt).inDays;
}

/// Крок 10: Обчислює точну тривалість вирішення закритого тікета як Duration.
Duration? ticketResolutionDuration(Ticket ticket) {
  if (ticket.closedAt == null) return null;
  return ticket.closedAt!.difference(ticket.createdAt);
}

/// Крок 11: Форматує підсумковий звіт за допомогою StringBuffer.
/// Використовує іменовані параметри зі значеннями за замовчуванням.
String buildReport(
  Iterable<Ticket> tickets, {
  String title = 'РЕЄСТР ЗВЕРНЕНЬ ДО СЛУЖБИ ПІДТРИМКИ (ЗВІТ)',
  bool maskEmails = true,
  int maxEntries = 5,
}) {
  final buffer = StringBuffer();
  final lineSep = '=' * 80;
  final subSep = '-' * 80;
  buffer.writeln(lineSep);
  buffer.writeln(title.padLeft((80 + title.length) ~/ 2));
  buffer.writeln(lineSep);
  buffer.writeln(
    'НОМЕР | КЛІЄНТ | ПРІОРИТЕТ | СТАТУС | ГОДИН | ДАТА СТВОРЕННЯ',
  );
  buffer.writeln(subSep);
  for (final t in tickets.take(maxEntries)) {
    final clientStr = maskEmails ? maskClientEmail(t.client) : t.client;
    final dateStr = t.createdAt.toString().substring(0, 16);
    buffer.writeln(
      '${t.id} | ${clientStr.padRight(22)} | ${t.priority.padRight(9)} | ${t.status.padRight(11)} | ${t.estimatedHours.toString().padLeft(2)} год | $dateStr',
    );
  }
  buffer.writeln(lineSep);
  buffer.writeln('Підсумкова статистика за вибіркою:');
  buffer.writeln('  Всього валідних звернень: ${tickets.length}');
  buffer.writeln(
    '  Середній час вирішення закритих: ${averageResolutionTimeHours(tickets).toStringAsFixed(1)} год',
  );
  buffer.writeln(lineSep);
  return buffer.toString();
}

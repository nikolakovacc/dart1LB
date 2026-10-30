import 'package:support/support.dart';

void main() {
  print('--------------------------------------------------------');
  print('  ЛАБОРАТОРНА РОБОТА 1. ФУНКЦІЇ ТА ОБРОБКА КОЛЕКЦІЙ');
  print('  Варіант 6: Реєстр звернень до підтримки');
  print('---------------------------------------------------------\n');

  // Крок 8: Демонстрація замикання-лічильника при парсингу
  final lineCounter = makeCounter();

  // Крок 2 та 3: Розбір рядків без try/catch
  final parsed = rawTicketLines.map((line) {
    lineCounter();
    return parseLine(line);
  }).toList();

  final validTickets = parsed
      .where((r) => r.ticket != null)
      .map((r) => r.ticket!)
      .toList();
  final corrupted = parsed.where((r) => r.error != null).toList();

  print('1. Розбір вхідних даних');
  print('Оброблено рядків через замикання: ${lineCounter()}');
  print('Успішно розібрано валідних тікетів: ${validTickets.length}');
  print('Виявлено пошкоджених записів: ${corrupted.length}\n');

  print('Перелік відхилених пошкоджених рядків (без винятків):');
  for (var i = 0; i < corrupted.length; i++) {
    print('  [${i + 1}] ${corrupted[i].error}');
  }

  // Крок 4: Валідація бізнес-правил
  print('\n2. Валідація розібраних записів');
  var hasViolations = false;
  for (final t in validTickets) {
    final v = validateTicket(t);
    if (v.isNotEmpty) {
      hasViolations = true;
      print('  Порушення у тікеті ${t.id}: $v');
    }
  }
  if (!hasViolations) {
    print('  Усі 15 звернень пройшли бізнес-валідацію успішно (0 порушень)!');
  }

  // Крок 5: Конвеєри
  print('\n3. Конвеєри обробки даних (where -> map -> fold)');
  print(
    'Конвеєр 1: Середній час вирішення закритих звернень: ${averageResolutionTimeHours(validTickets).toStringAsFixed(2)} год.',
  );
  print(
    'Конвеєр 2: Оцінка активних Critical+High: ${totalEstimatedHoursByPriority(validTickets, {'Critical', 'High'})} год.',
  );
  final oldest = findOldestActiveTicket(validTickets);
  if (oldest != null) {
    print(
      'Конвеєр 3: Найстаріше активне: ${oldest.id} (створено: ${oldest.createdAt})',
    );
  }

  // Крок 6: Групування та агрегація
  print('\n4. Групування записів та агреговані показники');
  final grouped = groupTicketsByPriority(validTickets);
  final stats = aggregateByPriority(grouped);
  stats.forEach((priority, data) {
    print(
      '  [$priority]: Всього: ${data.total} | Закрито: ${data.closed} | Сер. оцінка: ${data.avgHours.toStringAsFixed(1)} год',
    );
  });

  // Крок 7: Сортування
  print('\n5. Сортування результату');
  final sortedByDate = sortTickets(
    validTickets,
    sortBy: 'date',
    ascending: false,
  );
  print('Топ-3 найновіших:');
  for (final t in sortedByDate.take(3)) {
    print(
      '  ${t.id} [${t.createdAt.toString().substring(0, 10)}] ${t.priority.padRight(8)} - ${t.topic}',
    );
  }

  // Крок 8: Замикання-предикат
  print('\n6. Замикання (Closures)');
  final isCritical = makePriorityFilter('Critical');
  final criticalCount = validTickets.where(isCritical).length;
  print('Кількість критичних звернень через фільтр-замикання: $criticalCount');

  // Крок 9: Регулярні вирази та маскування
  print('\n7. Регулярні вирази з іменованими групами та GDPR');
  const sampleEmail = 'volodymyr.shevchuk@enterprises.com';
  print('Оригінальний email: "$sampleEmail"');
  print('Маскований email:   "${maskClientEmail(sampleEmail)}"');

  final idMatch = ticketIdRegex.firstMatch('TICK-2026-0042');
  if (idMatch != null) {
    print('Розбір номера тікета через іменовані групи:');
    print(
      '  dept: ${idMatch.namedGroup('dept')}, year: ${idMatch.namedGroup('year')}, seq: ${idMatch.namedGroup('seq')}',
    );
  }

  // Крок 10: Арифметика дат
  print('\n8. Арифметика дат (DateTime та Duration)');
  final first = validTickets.first;
  print('Вік першого тікета в днях: ${ticketAgeInDays(first)} дн.');
  final resDur = ticketResolutionDuration(first);
  if (resDur != null) {
    print(
      'Тривалість вирішення першого тікета: ${resDur.inHours} год ${resDur.inMinutes % 60} хв',
    );
  }

  // Крок 11: Звіт через StringBuffer
  print('\n9. Підсумковий текстовий звіт (StringBuffer)');
  print(buildReport(sortedByDate, maxEntries: 5));
}

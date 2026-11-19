import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../data/weight_repository.dart';
import '../models/weight_record.dart';
import '../utils/weight_formatters.dart';

enum StatisticsPeriod { weekly, monthly, yearly, custom }

class WeightStatRow {
  const WeightStatRow({
    required this.period,
    required this.averageKg,
    required this.movingAverageKg,
    this.variationKg,
  });

  final String period;
  final double averageKg;
  final double movingAverageKg;
  final double? variationKg;
}

List<WeightStatRow> calculateWeightStatistics({
  required List<WeightRecord> records,
  required StatisticsPeriod period,
  required DateTime customStart,
  required DateTime customEnd,
}) {
  if (period == StatisticsPeriod.custom) {
    final selected = records
        .where((record) =>
            !record.day.isBefore(dateOnly(customStart)) &&
            !record.day.isAfter(dateOnly(customEnd)))
        .toList()
      ..sort((a, b) => a.day.compareTo(b.day));

    return List<WeightStatRow>.generate(selected.length, (index) {
      final record = selected[index];
      final windowStart = index > 4 ? index - 4 : 0;
      final window = selected.sublist(windowStart, index + 1);
      final movingAverage =
          window.map((item) => item.weightKg).reduce((a, b) => a + b) /
              window.length;
      final previous = index == 0 ? null : selected[index - 1].weightKg;
      return WeightStatRow(
        period: formatDate(record.day),
        averageKg: record.weightKg,
        variationKg: previous == null ? null : record.weightKg - previous,
        movingAverageKg: movingAverage,
      );
    }).reversed.toList(growable: false);
  }

  final grouped = <DateTime, List<double>>{};
  for (final record in records) {
    final key = _periodStart(record.day, period);
    grouped.putIfAbsent(key, () => []).add(record.weightKg);
  }

  final averages = <DateTime, double>{};
  for (final entry in grouped.entries) {
    averages[entry.key] =
        entry.value.reduce((a, b) => a + b) / entry.value.length;
  }
  final chronologicalKeys = averages.keys.toList()..sort();

  final rows = <WeightStatRow>[];
  for (var index = 0; index < chronologicalKeys.length; index++) {
    final key = chronologicalKeys[index];
    final value = averages[key]!;
    final previousKey = _previousPeriodStart(key, period);
    final previousAverage = averages[previousKey];
    final startOfWindow = index > 4 ? index - 4 : 0;
    final recentKeys = chronologicalKeys.sublist(startOfWindow, index + 1);
    final movingAverage =
        recentKeys.map((item) => averages[item]!).reduce((a, b) => a + b) /
            recentKeys.length;

    rows.add(
      WeightStatRow(
        period: _periodLabel(key, period),
        averageKg: value,
        variationKg: previousAverage == null ? null : value - previousAverage,
        movingAverageKg: movingAverage,
      ),
    );
  }
  return rows.reversed.toList(growable: false);
}

DateTime _periodStart(DateTime date, StatisticsPeriod period) {
  switch (period) {
    case StatisticsPeriod.weekly:
      final daysSinceMonday = date.weekday - DateTime.monday;
      return DateTime(date.year, date.month, date.day - daysSinceMonday);
    case StatisticsPeriod.monthly:
      return DateTime(date.year, date.month);
    case StatisticsPeriod.yearly:
      return DateTime(date.year);
    case StatisticsPeriod.custom:
      return dateOnly(date);
  }
}

DateTime _previousPeriodStart(DateTime start, StatisticsPeriod period) {
  switch (period) {
    case StatisticsPeriod.weekly:
      return DateTime(start.year, start.month, start.day - 7);
    case StatisticsPeriod.monthly:
      return DateTime(start.year, start.month - 1);
    case StatisticsPeriod.yearly:
      return DateTime(start.year - 1);
    case StatisticsPeriod.custom:
      return start.subtract(const Duration(days: 1));
  }
}

String _periodLabel(DateTime start, StatisticsPeriod period) {
  switch (period) {
    case StatisticsPeriod.weekly:
      final end = DateTime(start.year, start.month, start.day + 6);
      return '${DateFormat('dd/MM', 'pt_BR').format(start)} – '
          '${DateFormat('dd/MM/yyyy', 'pt_BR').format(end)}';
    case StatisticsPeriod.monthly:
      return DateFormat('MMM/yyyy', 'pt_BR').format(start);
    case StatisticsPeriod.yearly:
      return DateFormat('yyyy', 'pt_BR').format(start);
    case StatisticsPeriod.custom:
      return formatDate(start);
  }
}

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late Future<List<WeightRecord>> _recordsFuture;
  StatisticsPeriod _period = StatisticsPeriod.weekly;
  late DateTime _customStart;
  late DateTime _customEnd;

  @override
  void initState() {
    super.initState();
    _recordsFuture = WeightRepository.instance.getAll();
    _customEnd = dateOnly(DateTime.now());
    _customStart = _customEnd.subtract(const Duration(days: 29));
  }

  Future<void> _selectPeriod(StatisticsPeriod period) async {
    setState(() => _period = period);
    if (period == StatisticsPeriod.custom) await _selectCustomRange();
  }

  Future<void> _selectCustomRange() async {
    final today = dateOnly(DateTime.now());
    final range = await showDateRangePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      firstDate: DateTime(1900),
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: _customStart.isAfter(today) ? today : _customStart,
        end: _customEnd.isAfter(today) ? today : _customEnd,
      ),
      helpText: 'Escolha o período',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
      saveText: 'Aplicar',
    );
    if (range != null) {
      setState(() {
        _customStart = dateOnly(range.start);
        _customEnd = dateOnly(range.end);
      });
    }
  }

  Future<void> _reload() async {
    final next = WeightRepository.instance.getAll();
    setState(() => _recordsFuture = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Estatísticas')),
      body: FutureBuilder<List<WeightRecord>>(
        future: _recordsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _StatisticsError(onRetry: _reload);
          }
          final records = snapshot.data ?? const <WeightRecord>[];
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _PeriodSelector(
                  selected: _period,
                  onSelected: _selectPeriod,
                ),
                if (_period == StatisticsPeriod.custom) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _selectCustomRange,
                      icon: const Icon(Icons.date_range_outlined),
                      label: Text(
                        '${formatDate(_customStart)} – ${formatDate(_customEnd)}',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  'Médias calculadas apenas com pesagens existentes. '
                  'Períodos sem registros são omitidos.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  _period == StatisticsPeriod.custom
                      ? 'Variação em relação à pesagem anterior; MA5 usa até as cinco datas mais recentes.'
                      : 'Variação em relação ao período anterior comparável; MA5 usa até os cinco períodos mais recentes.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                const SizedBox(height: 16),
                _StatisticsTable(
                  rows: calculateWeightStatistics(
                    records: records,
                    period: _period,
                    customStart: _customStart,
                    customEnd: _customEnd,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onSelected});

  final StatisticsPeriod selected;
  final ValueChanged<StatisticsPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    const choices = [
      (StatisticsPeriod.weekly, 'Semanal'),
      (StatisticsPeriod.monthly, 'Mensal'),
      (StatisticsPeriod.yearly, 'Anual'),
      (StatisticsPeriod.custom, 'Personalizado'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: choices.map((choice) {
        final (value, label) = choice;
        return ChoiceChip(
          label: Text(label),
          selected: selected == value,
          onSelected: (_) => onSelected(value),
        );
      }).toList(),
    );
  }
}

class _StatisticsTable extends StatelessWidget {
  const _StatisticsTable({required this.rows});

  final List<WeightStatRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1F),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text('Ainda não há pesagens neste período.'),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          horizontalMargin: 16,
          columnSpacing: 22,
          dataRowMinHeight: 56,
          dataRowMaxHeight: 68,
          headingTextStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
          columns: const [
            DataColumn(label: Text('Período/data')),
            DataColumn(label: Text('Média (kg)'), numeric: true),
            DataColumn(label: Text('Variação (kg)'), numeric: true),
            DataColumn(label: Text('MA5 (kg)'), numeric: true),
          ],
          rows: rows.map((row) {
            return DataRow(
              cells: [
                DataCell(Text(row.period)),
                DataCell(Text(formatWeight(row.averageKg))),
                DataCell(_VariationValue(value: row.variationKg)),
                DataCell(Text(formatWeight(row.movingAverageKg))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _VariationValue extends StatelessWidget {
  const _VariationValue({required this.value});

  final double? value;

  @override
  Widget build(BuildContext context) {
    if (value == null) return const Text('—');
    if (value == 0) return Text(formatWeight(0));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          value! > 0 ? Icons.arrow_upward : Icons.arrow_downward,
          size: 16,
          color: Theme.of(context).colorScheme.primary,
          semanticLabel: value! > 0 ? 'Aumento' : 'Queda',
        ),
        const SizedBox(width: 4),
        Text(formatSignedWeight(value!)),
      ],
    );
  }
}

class _StatisticsError extends StatelessWidget {
  const _StatisticsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Não foi possível carregar as estatísticas.'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

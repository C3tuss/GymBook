import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:gymbook/models/weight_record.dart';
import 'package:gymbook/screens/statistics_screen.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('calculateWeightStatistics', () {
    test('calcula a média semanal com registros existentes e variação', () {
      final rows = calculateWeightStatistics(
        records: [
          WeightRecord(date: DateTime(2026, 11, 2), weightKg: 80),
          WeightRecord(date: DateTime(2026, 11, 6), weightKg: 82),
          WeightRecord(date: DateTime(2026, 11, 9), weightKg: 78),
        ],
        period: StatisticsPeriod.weekly,
        customStart: DateTime(2026, 11, 1),
        customEnd: DateTime(2026, 11, 30),
      );

      expect(rows, hasLength(2));
      expect(rows.first.averageKg, 78);
      expect(rows.first.variationKg, -3);
      expect(rows.last.averageKg, 81);
      expect(rows.last.variationKg, isNull);
      expect(rows.first.movingAverageKg, 79.5);
    });

    test('omite datas sem pesagem no intervalo personalizado e na MA5', () {
      final rows = calculateWeightStatistics(
        records: [
          WeightRecord(date: DateTime(2026, 11, 1), weightKg: 70),
          WeightRecord(date: DateTime(2026, 11, 5), weightKg: 72),
          WeightRecord(date: DateTime(2026, 11, 9), weightKg: 74),
        ],
        period: StatisticsPeriod.custom,
        customStart: DateTime(2026, 11, 4),
        customEnd: DateTime(2026, 11, 10),
      );

      expect(rows, hasLength(2));
      expect(rows.first.averageKg, 74);
      expect(rows.first.variationKg, 2);
      expect(rows.first.movingAverageKg, 73);
      expect(rows.last.averageKg, 72);
      expect(rows.last.variationKg, isNull);
    });

    test('não trata uma semana vazia como zero nem como período exibido', () {
      final rows = calculateWeightStatistics(
        records: [
          WeightRecord(date: DateTime(2026, 11, 2), weightKg: 80),
          WeightRecord(date: DateTime(2026, 11, 23), weightKg: 90),
        ],
        period: StatisticsPeriod.weekly,
        customStart: DateTime(2026, 11, 1),
        customEnd: DateTime(2026, 11, 30),
      );

      expect(rows, hasLength(2));
      expect(rows.first.averageKg, 90);
      expect(rows.first.variationKg, isNull);
      expect(rows.first.movingAverageKg, 85);
    });
  });
}

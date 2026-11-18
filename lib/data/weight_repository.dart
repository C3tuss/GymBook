import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/weight_record.dart';

class SaveWeightResult {
  const SaveWeightResult.saved() : conflictingRecord = null;

  const SaveWeightResult.duplicate(this.conflictingRecord);

  final WeightRecord? conflictingRecord;

  bool get hasConflict => conflictingRecord != null;
}

class WeightRepository {
  WeightRepository._();

  static final WeightRepository instance = WeightRepository._();

  Future<Database>? _databaseFuture;

  Future<Database> get _database async {
    return _databaseFuture ??= _openDatabase();
  }

  Future<Database> _openDatabase() async {
    final databaseDirectory = await getDatabasesPath();
    return openDatabase(
      path.join(databaseDirectory, 'gymbook_weight.db'),
      version: 1,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE weigh_ins (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL UNIQUE,
            weight_kg REAL NOT NULL CHECK (weight_kg > 0)
          )
        ''');
      },
    );
  }

  Future<List<WeightRecord>> getAll() async {
    final database = await _database;
    final rows = await database.query(
      'weigh_ins',
      orderBy: 'date DESC',
    );
    return rows.map(WeightRecord.fromDatabaseMap).toList(growable: false);
  }

  Future<SaveWeightResult> save(WeightRecord record) async {
    final database = await _database;
    return database.transaction((transaction) async {
      final duplicates = await transaction.query(
        'weigh_ins',
        where: 'date = ?',
        whereArgs: [record.dateKey],
        limit: 1,
      );

      if (duplicates.isNotEmpty) {
        final existing = WeightRecord.fromDatabaseMap(duplicates.first);
        if (existing.id != record.id) {
          return SaveWeightResult.duplicate(existing);
        }
      }

      if (record.id == null) {
        await transaction.insert('weigh_ins', record.toDatabaseMap());
      } else {
        await transaction.update(
          'weigh_ins',
          record.toDatabaseMap(),
          where: 'id = ?',
          whereArgs: [record.id],
        );
      }
      return const SaveWeightResult.saved();
    });
  }

  Future<void> delete(int id) async {
    final database = await _database;
    await database.delete('weigh_ins', where: 'id = ?', whereArgs: [id]);
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class OfflineService {
  static Database? _db;
  static Future<Database> get db async {
    _db ??= await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'market_bridge.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
        CREATE TABLE pending_products(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          server_id INTEGER,
          name TEXT NOT NULL,
          price REAL,
          quantity INTEGER,
          description TEXT,
          barcode TEXT,
          image_path TEXT,
          action TEXT DEFAULT 'create',
          created_at TEXT
        )
      ''');
      },
    );
  }

  static Future<int> addPending(Map<String, dynamic> product) async {
    final database = await db;
    return database.insert('pending_products', {
      'name': product['name'],
      'price': product['price'],
      'quantity': product['quantity'],
      'description': product['description'],
      'barcode': product['barcode'],
      'image_path': product['image_path'],
      'action': product['action'] ?? 'create',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getPending() async {
    final database = await db;
    return database.query('pending_products', orderBy: 'id ASC');
  }

  static Future<void> removePending(int id) async {
    final database = await db;
    await database.delete('pending_products', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> clearPending() async {
    final database = await db;
    await database.delete('pending_products');
  }

  static Future<int> pendingCount() async {
    final database = await db;
    final result = await database.rawQuery(
      'SELECT COUNT(*) as c FROM pending_products',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}

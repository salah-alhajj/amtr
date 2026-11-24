import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';
import '../../../models/product_ingredient.dart';

/// مستودع حفظ وجلب مكوّنات وصفات المنتجات في SQLite
class ProductIngredientRepository {
  final AppDatabase dbHelper;

  ProductIngredientRepository({AppDatabase? db})
      : dbHelper = db ?? AppDatabase.instance;

  Future<List<ProductIngredient>> getByProductId(String productId) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'product_ingredients',
      where: 'productId = ?',
      whereArgs: [productId],
    );
    return maps.map(ProductIngredient.fromMap).toList();
  }

  Future<void> saveIngredient(ProductIngredient ingredient) async {
    final db = await dbHelper.database;
    await db.insert(
      'product_ingredients',
      ingredient.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> replaceForProduct(
    String productId,
    List<ProductIngredient> ingredients,
  ) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete(
        'product_ingredients',
        where: 'productId = ?',
        whereArgs: [productId],
      );
      for (final item in ingredients) {
        await txn.insert(
          'product_ingredients',
          item.copyWith(productId: productId).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> deleteIngredient(String id) async {
    final db = await dbHelper.database;
    await db.delete(
      'product_ingredients',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteByProductId(String productId) async {
    final db = await dbHelper.database;
    await db.delete(
      'product_ingredients',
      where: 'productId = ?',
      whereArgs: [productId],
    );
  }
}

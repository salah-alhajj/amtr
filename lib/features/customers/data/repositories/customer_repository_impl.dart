import '../../../../core/database/app_database.dart';
import '../../../../models/customer.dart';
import '../../domain/repositories/customer_repository.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  final AppDatabase dbHelper;

  CustomerRepositoryImpl({AppDatabase? db}) : dbHelper = db ?? AppDatabase.instance;

  @override
  Future<List<Customer>> getAllCustomers() async {
    final db = await dbHelper.database;
    final maps = await db.query('customers', orderBy: 'name ASC');
    return maps.map((e) => Customer.fromMap(e)).toList();
  }

  @override
  Future<Customer?> getCustomerById(String id) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Customer.fromMap(maps.first);
    }
    return null;
  }

  @override
  Future<void> saveCustomer(Customer customer) async {
    final db = await dbHelper.database;
    await db.insert('customers', customer.toMap());
  }

  @override
  Future<void> updateCustomer(Customer customer) async {
    final db = await dbHelper.database;
    await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  @override
  Future<void> deleteCustomer(String id) async {
    final db = await dbHelper.database;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<Customer>> searchCustomers(String query) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'customers',
      where: 'name LIKE ? OR phone LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return maps.map((e) => Customer.fromMap(e)).toList();
  }
}

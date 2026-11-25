import '../../../../core/audit/audit.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../models/customer.dart';
import '../../../../core/utils/yemen_phone_helper.dart';
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
    final map = customer.toMap();
    await db.insert('customers', map);
    await CentralAuditService.instance.log(
      entityType: AuditEntityType.customer,
      entityId: customer.id,
      entityLabel: customer.name,
      action: AuditAction.create,
      summary: customer.name,
      after: map,
      sourceModule: 'customers',
    );
    DataSyncBus.instance.notify(DataDomain.customers);
  }

  @override
  Future<void> updateCustomer(Customer customer) async {
    final db = await dbHelper.database;
    final beforeCustomer = await getCustomerById(customer.id);
    final afterMap = customer.toMap();
    await db.update(
      'customers',
      afterMap,
      where: 'id = ?',
      whereArgs: [customer.id],
    );
    await CentralAuditService.instance.log(
      entityType: AuditEntityType.customer,
      entityId: customer.id,
      entityLabel: customer.name,
      action: AuditAction.update,
      summary: customer.name,
      before: beforeCustomer?.toMap(),
      after: afterMap,
      sourceModule: 'customers',
    );
    DataSyncBus.instance.notify(DataDomain.customers);
  }

  @override
  Future<void> deleteCustomer(String id) async {
    final db = await dbHelper.database;
    final beforeCustomer = await getCustomerById(id);
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
    if (beforeCustomer != null) {
      await CentralAuditService.instance.log(
        entityType: AuditEntityType.customer,
        entityId: id,
        entityLabel: beforeCustomer.name,
        action: AuditAction.delete,
        summary: beforeCustomer.name,
        before: beforeCustomer.toMap(),
        sourceModule: 'customers',
      );
    }
    DataSyncBus.instance.notify(DataDomain.customers);
  }

  @override
  Future<List<Customer>> searchCustomers(String query) async {
    final db = await dbHelper.database;
    final clean = query.trim();
    final latinDigits = YemenPhoneHelper.convertArabicIndicDigits(clean);
    final arabicDigits = YemenPhoneHelper.convertToIndicDigits(clean);

    final maps = await db.query(
      'customers',
      where: 'name LIKE ? OR phone LIKE ? OR phone LIKE ? OR whatsapp LIKE ? OR whatsapp LIKE ?',
      whereArgs: [
        '%$clean%',
        '%$latinDigits%',
        '%$arabicDigits%',
        '%$latinDigits%',
        '%$arabicDigits%',
      ],
      orderBy: 'name ASC',
    );
    return maps.map((e) => Customer.fromMap(e)).toList();
  }
}

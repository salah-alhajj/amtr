import 'package:flutter/foundation.dart';
import '../../../../models/customer.dart';
import '../../domain/repositories/customer_repository.dart';

class CustomerController extends ChangeNotifier {
  final CustomerRepository repository;

  bool _isLoading = false;
  List<Customer> _customers = [];
  String _searchQuery = '';

  CustomerController({required this.repository});

  bool get isLoading => _isLoading;
  List<Customer> get customers => _customers;
  String get searchQuery => _searchQuery;

  Future<void> loadCustomers() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_searchQuery.trim().isEmpty) {
        _customers = await repository.getAllCustomers();
      } else {
        _customers = await repository.searchCustomers(_searchQuery.trim());
      }
    } catch (e) {
      debugPrint('Error loading customers: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void search(String query) {
    _searchQuery = query;
    loadCustomers();
  }

  Future<void> addCustomer(Customer customer) async {
    await repository.saveCustomer(customer);
    await loadCustomers();
  }

  Future<void> updateCustomer(Customer customer) async {
    await repository.updateCustomer(customer);
    await loadCustomers();
  }

  Future<void> deleteCustomer(String id) async {
    await repository.deleteCustomer(id);
    await loadCustomers();
  }
}

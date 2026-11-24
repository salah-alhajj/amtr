import 'dart:async';

/// مجالات البيانات التي تطلق تحديثات تفاعلية عند تعديلها
enum DataDomain {
  orders,
  payments,
  expenses,
  products,
  customers,
  suppliers,
  materials,
  couriers,
  businessMode,
}

/// حافلة إشعارات خفيفة لتحديث لوحة التحكم والصندوق اليومي تلقائياً عند أي تغيير
class DataSyncBus {
  DataSyncBus._();
  static final DataSyncBus instance = DataSyncBus._();

  final StreamController<DataDomain> _controller =
      StreamController<DataDomain>.broadcast();

  Stream<DataDomain> get stream => _controller.stream;

  void notify(DataDomain domain) {
    if (!_controller.isClosed) {
      _controller.add(domain);
    }
  }
}

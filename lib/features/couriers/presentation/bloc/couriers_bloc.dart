import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../models/courier.dart';
import '../../data/repositories/courier_repository_impl.dart';

// --- Events ---
abstract class CouriersEvent {
  const CouriersEvent();
}

class LoadCouriers extends CouriersEvent {
  final bool silent;
  const LoadCouriers({this.silent = false});
}

class SearchCouriers extends CouriersEvent {
  final String query;
  const SearchCouriers(this.query);
}

class SaveCourierEvent extends CouriersEvent {
  final Courier courier;
  const SaveCourierEvent(this.courier);
}

class DeleteCourierEvent extends CouriersEvent {
  final String id;
  const DeleteCourierEvent(this.id);
}

// --- States ---
abstract class CouriersState {
  const CouriersState();
}

class CouriersInitial extends CouriersState {
  const CouriersInitial();
}

class CouriersLoading extends CouriersState {
  const CouriersLoading();
}

class CouriersLoaded extends CouriersState {
  final List<CourierCustodySummary> allSummaries;
  final List<CourierCustodySummary> displayedSummaries;
  final String searchQuery;

  const CouriersLoaded({
    required this.allSummaries,
    required this.displayedSummaries,
    this.searchQuery = '',
  });
}

class CouriersError extends CouriersState {
  final String message;
  const CouriersError(this.message);
}

// --- BLoC ---
class CouriersBloc extends Bloc<CouriersEvent, CouriersState> {
  final CourierRepositoryImpl repository;
  late final StreamSubscription<DataDomain> _syncSub;
  bool _isSelfMutating = false;

  CouriersBloc({required this.repository}) : super(const CouriersInitial()) {
    on<LoadCouriers>(_onLoad);
    on<SearchCouriers>(_onSearch);
    on<SaveCourierEvent>(_onSave);
    on<DeleteCourierEvent>(_onDelete);

    _syncSub = DataSyncBus.instance.stream.listen((domain) {
      if (!isClosed &&
          !_isSelfMutating &&
          state is CouriersLoaded &&
          (domain == DataDomain.couriers || domain == DataDomain.orders)) {
        add(const LoadCouriers(silent: true));
      }
    });
  }

  Future<void> _runSelfMutation(Future<void> Function() mutation) async {
    _isSelfMutating = true;
    try {
      await mutation();
      await Future<void>.microtask(() {});
    } finally {
      _isSelfMutating = false;
    }
  }

  @override
  Future<void> close() async {
    await _syncSub.cancel();
    return super.close();
  }

  Future<void> _onLoad(
    LoadCouriers event,
    Emitter<CouriersState> emit,
  ) async {
    final prevQuery =
        state is CouriersLoaded ? (state as CouriersLoaded).searchQuery : '';

    if (!event.silent && state is! CouriersLoaded) {
      emit(const CouriersLoading());
    }
    try {
      final summaries = await repository.getAllCustodySummaries();
      final filtered = _applySearch(summaries, prevQuery);
      emit(CouriersLoaded(
        allSummaries: summaries,
        displayedSummaries: filtered,
        searchQuery: prevQuery,
      ));
    } catch (e) {
      emit(CouriersError(e.toString()));
    }
  }

  void _onSearch(SearchCouriers event, Emitter<CouriersState> emit) {
    if (state is! CouriersLoaded) return;
    final current = state as CouriersLoaded;
    final filtered = _applySearch(current.allSummaries, event.query);
    emit(CouriersLoaded(
      allSummaries: current.allSummaries,
      displayedSummaries: filtered,
      searchQuery: event.query,
    ));
  }

  List<CourierCustodySummary> _applySearch(
    List<CourierCustodySummary> list,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((summary) {
      final c = summary.courier;
      return c.name.toLowerCase().contains(q) ||
          (c.phone ?? '').toLowerCase().contains(q) ||
          (c.whatsapp ?? '').toLowerCase().contains(q) ||
          (c.notes ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _onSave(
    SaveCourierEvent event,
    Emitter<CouriersState> emit,
  ) async {
    await _runSelfMutation(() => repository.saveCourier(event.courier));
    add(const LoadCouriers(silent: true));
  }

  Future<void> _onDelete(
    DeleteCourierEvent event,
    Emitter<CouriersState> emit,
  ) async {
    await _runSelfMutation(() => repository.deleteCourier(event.id));
    add(const LoadCouriers(silent: true));
  }
}

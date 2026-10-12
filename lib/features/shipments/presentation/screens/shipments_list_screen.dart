import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../bloc/shipments_bloc.dart';
import '../widgets/shipment_card.dart';
import 'add_edit_shipment_screen.dart';
import 'shipment_details_screen.dart';

class ShipmentsListScreen extends StatefulWidget {
  const ShipmentsListScreen({super.key});

  @override
  State<ShipmentsListScreen> createState() => _ShipmentsListScreenState();
}

class _ShipmentsListScreenState extends State<ShipmentsListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleBloc>();
    return Scaffold(
      appBar: AppBar(
        title: Text('shipments_title'.i18n()),
      ),
      body: BlocBuilder<ShipmentsBloc, ShipmentsState>(
        builder: (context, state) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: AppSearchBar(
                  controller: _searchController,
                  hintText: 'search_shipments_hint'.i18n(),
                  onChanged: (val) {
                    context.read<ShipmentsBloc>().add(SearchShipments(val));
                  },
                  onClear: () {
                    context.read<ShipmentsBloc>().add(const SearchShipments(''));
                  },
                ),
              ),
              Expanded(
                child: _buildShipmentsBody(context, state),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'shipments_fab',
        onPressed: () async {
          final shipmentsBloc = context.read<ShipmentsBloc>();
          final res = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditShipmentScreen()),
          );
          if (res == true) {
            shipmentsBloc.add(const LoadShipments());
          }
        },
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('new_shipment'.i18n(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildShipmentsBody(BuildContext context, ShipmentsState state) {
    if (state is ShipmentsLoading || state is ShipmentsInitial) {
      return AppShimmer.list(itemCount: 5, isCards: true);
    }

    if (state is ShipmentsError) {
      return AppErrorStateView(
        message: state.message,
        onRetry: () => context.read<ShipmentsBloc>().add(const LoadShipments()),
      );
    }

    if (state is ShipmentsLoaded) {
      if (state.shipments.isEmpty) {
        return EmptyStateView(
          icon: Icons.local_shipping_outlined,
          title: 'shipments_empty_title'.i18n(),
          subtitle: 'shipments_empty_subtitle'.i18n(),
          actionLabel: 'new_shipment'.i18n(),
          actionIcon: Icons.add,
          onActionPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddEditShipmentScreen()),
            );
          },
        );
      }

      return RefreshIndicator(
        onRefresh: () async {
          if (!mounted) return;
          context.read<ShipmentsBloc>().add(const LoadShipments());
        },
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: state.shipments.length,
          itemBuilder: (context, index) {
            final shipment = state.shipments[index];
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 200 + (index.clamp(0, 8) * 35)),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 16 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: ShipmentCard(
                shipment: shipment,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ShipmentDetailsScreen(shipmentId: shipment.id)),
                  );
                  if (context.mounted) {
                    context.read<ShipmentsBloc>().add(const LoadShipments());
                  }
                },
              ),
            );
          },
        ),
      );
    }

    return const SizedBox.shrink();
  }
}



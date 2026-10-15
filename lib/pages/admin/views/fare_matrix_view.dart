import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants.dart';
import '../../../state/app_state.dart';
import '../../../models/fare_matrix.dart';
import '../../../services/fare_calculator.dart';
import '../admin_theme.dart';
import '../widgets/admin_widgets.dart';

class AdminFareMatrixView extends StatefulWidget {
  const AdminFareMatrixView({super.key});
  @override
  State<AdminFareMatrixView> createState() => _AdminFareMatrixViewState();
}

class _AdminFareMatrixViewState extends State<AdminFareMatrixView> {
  double _simulatorDistanceKm = 5.0;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminSectionHeader(
          title: 'Fare Matrix Configuration',
          subtitle:
              'Manage and update pricing rules. Changes apply instantly to all new passenger bookings.',
        ),
        const SizedBox(height: 10),
        _buildVehicleCard(
            context, app, VehicleType.tricycle, Icons.electric_rickshaw),
        const SizedBox(height: 16),
        _buildVehicleCard(context, app, VehicleType.habal, Icons.two_wheeler),
        const SizedBox(height: 24),
        _buildSimulator(context, app),
        const SizedBox(height: 32),
        const Text('Fare Matrix Audit History',
            style: TextStyle(
                color: AdminTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildHistoryPanel(),
      ],
    );
  }

  Widget _buildVehicleCard(
      BuildContext context, AppState app, VehicleType type, IconData icon) {
    final matrix = app.getFareMatrixFor(type);
    final name = type == VehicleType.tricycle ? 'Tricycle' : 'Habal-Habal';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AdminTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AdminTheme.slate, size: 28),
              const SizedBox(width: 12),
              Text(name,
                  style: const TextStyle(
                      color: AdminTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                  'Last updated: ${DateFormat("MMM d, yyyy h:mm a").format(matrix.updatedAt)}',
                  style:
                      const TextStyle(color: AdminTheme.slate, fontSize: 12)),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _showEditDialog(context, app, matrix, name),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Edit Rates'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.terracotta,
                    foregroundColor: Colors.white),
              )
            ],
          ),
          const Divider(height: 32, color: AdminTheme.borderLight),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              _buildMetric('Base Fare', 'P ${matrix.baseFare}'),
              _buildMetric(
                  'Included Distance', '${matrix.includedBaseDistance} km'),
              _buildMetric('Per Km Rate', 'P ${matrix.perKmRate}/km'),
              _buildMetric('Minimum Fare', 'P ${matrix.minimumFare}'),
              _buildMetric('Rounding Rule', 'Nearest P5'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value,
      {Color color = AdminTheme.textPrimary}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: AdminTheme.slate, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildHistoryPanel() {
    return Container(
      decoration: AdminTheme.cardDecoration(),
      height: 300,
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client
            .from('fare_matrix_history')
            .stream(primaryKey: ['id'])
            .order('changed_at', ascending: false)
            .limit(50),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final history = snapshot.data!;
          if (history.isEmpty)
            return const Center(
                child: Text('No history found.',
                    style: TextStyle(color: AdminTheme.slate)));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: history.length,
            separatorBuilder: (_, __) =>
                const Divider(color: AdminTheme.borderLight),
            itemBuilder: (context, index) {
              final h = history[index];
              final date = DateTime.parse(h['changed_at'].toString());
              return ListTile(
                dense: true,
                title: Text('${h['vehicle_type']} updated',
                    style: const TextStyle(
                        color: AdminTheme.textPrimary,
                        fontWeight: FontWeight.bold)),
                subtitle: Text(
                    'Changed at ${DateFormat("MMM d, yyyy h:mm a").format(date)}',
                    style: const TextStyle(color: AdminTheme.slate)),
                trailing: const Icon(Icons.history_rounded,
                    color: AdminTheme.slate, size: 16),
              );
            },
          );
        },
      ),
    );
  }

  void _showEditDialog(
      BuildContext context, AppState app, FareMatrix matrix, String name) {
    final baseCtrl = TextEditingController(text: matrix.baseFare.toString());
    final includedDistanceCtrl =
        TextEditingController(text: matrix.includedBaseDistance.toString());
    final perKmCtrl = TextEditingController(text: matrix.perKmRate.toString());
    final minFareCtrl =
        TextEditingController(text: matrix.minimumFare.toString());
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              backgroundColor: AdminTheme.bgCard,
              title: Text('Edit $name Fare Matrix',
                  style: const TextStyle(color: AdminTheme.textPrimary)),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                            'WARNING: This will affect all new bookings immediately.',
                            style: TextStyle(
                                color: AdminTheme.terracotta,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _buildField('Base Fare', baseCtrl),
                        _buildField('Included Base Distance (km)',
                            includedDistanceCtrl),
                        _buildField('Per Km Rate', perKmCtrl),
                        _buildField('Minimum Fare', minFareCtrl),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.terracotta,
                      foregroundColor: Colors.white),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setState(() => isSaving = true);
                            final updated = matrix.copyWith(
                              baseFare: double.parse(baseCtrl.text),
                              includedBaseDistance:
                                  double.parse(includedDistanceCtrl.text),
                              perKmRate: double.parse(perKmCtrl.text),
                              minimumFare: double.parse(minFareCtrl.text),
                              updatedAt: DateTime.now(),
                            );
                            try {
                              await app.fareMatrixRepo.updateMatrix(updated);
                              app.forceUpdateFareMatrix(updated);
                              if (ctx.mounted) {
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Fare matrix saved successfully.')));
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                setState(() => isSaving = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor:
                                            AdminTheme.terracotta));
                              }
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Save Matrix'),
                )
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildField(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        style: const TextStyle(color: AdminTheme.textPrimary),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: AdminTheme.inputDecoration(labelText: label, hintText: ''),
        validator: (val) {
          if (val == null || val.isEmpty) return 'Required';
          final num = double.tryParse(val);
          if (num == null) return 'Must be a number';
          if (num < 0) return 'Cannot be negative';
          return null;
        },
      ),
    );
  }

  Widget _buildSimulator(BuildContext context, AppState app) {
    final tricyMatrix = app.getFareMatrixFor(VehicleType.tricycle);
    final habalMatrix = app.getFareMatrixFor(VehicleType.habal);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AdminTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Interactive Trip Fare Simulator',
              style: TextStyle(
                  color: AdminTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
              'Simulate the passenger total fare across any distance in real time.',
              style: TextStyle(color: AdminTheme.slate, fontSize: 12)),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                  'Trip Distance: ${_simulatorDistanceKm.toStringAsFixed(1)} km',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              const Spacer(),
              _buildPresetButton(1.0),
              const SizedBox(width: 8),
              _buildPresetButton(3.0),
              const SizedBox(width: 8),
              _buildPresetButton(5.0),
              const SizedBox(width: 8),
              _buildPresetButton(10.0),
              const SizedBox(width: 8),
              _buildPresetButton(15.0),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AdminTheme.terracotta,
              inactiveTrackColor: AdminTheme.slate.withOpacity(0.3),
              thumbColor: AdminTheme.terracotta,
              overlayColor: AdminTheme.terracotta.withOpacity(0.2),
            ),
            child: Slider(
              value: _simulatorDistanceKm,
              min: 1.0,
              max: 50.0,
              divisions: 490,
              onChanged: (val) {
                setState(() {
                  _simulatorDistanceKm = val;
                });
              },
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                  child: _buildSimulatorResultCard(
                      'Tricycle', tricyMatrix, Icons.electric_rickshaw)),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildSimulatorResultCard(
                      'Habal-Habal', habalMatrix, Icons.two_wheeler)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton(double km) {
    final isSelected = _simulatorDistanceKm == km;
    return InkWell(
      onTap: () {
        setState(() {
          _simulatorDistanceKm = km;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AdminTheme.terracotta : AdminTheme.bgCard,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color:
                  isSelected ? AdminTheme.terracotta : AdminTheme.borderLight),
        ),
        child: Text('${km.toInt()} km',
            style: TextStyle(
                color: isSelected ? Colors.white : AdminTheme.slate,
                fontSize: 12)),
      ),
    );
  }

  Widget _buildSimulatorResultCard(
      String name, FareMatrix matrix, IconData icon) {
    final fare = _calculateSimulatedFare(matrix, _simulatorDistanceKm);
    final validKm = FareCalculator.chargeableDistanceKm(
      matrix,
      _simulatorDistanceKm,
    );
    final distanceCharge = validKm * matrix.perKmRate;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ],
              ),
              Text('P${fare.toInt()}',
                  style: const TextStyle(
                      color: AdminTheme.terracotta,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AdminTheme.borderLight),
          const SizedBox(height: 12),
          _buildFareRow('Base Fare', 'P${matrix.baseFare.toInt()}'),
          _buildFareRow(
            'Distance Charge (${validKm.toStringAsFixed(1)} km x P${matrix.perKmRate.toInt()})',
            'P${distanceCharge.toStringAsFixed(1)}',
          ),
          _buildFareRow('Total Fare', 'P${fare.toInt()}', isGreen: true),
        ],
      ),
    );
  }

  Widget _buildFareRow(String label, String value, {bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: AdminTheme.slate, fontSize: 12)),
          Text(value,
              style: TextStyle(
                  color: isGreen ? AdminTheme.successText : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ],
      ),
    );
  }

  double _calculateSimulatedFare(FareMatrix config, double distanceKm) {
    return FareCalculator.calculateFare(
      matrix: config,
      distanceKm: distanceKm,
      durationMinutes: 0,
    );
  }
}

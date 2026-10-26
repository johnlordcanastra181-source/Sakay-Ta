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
  List<Map<String, dynamic>>? _cachedHistory;
  bool _isLoadingHistory = false;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory({bool refresh = false}) async {
    if (_isLoadingHistory) return;
    if (mounted) {
      setState(() {
        _isLoadingHistory = true;
        _historyError = null;
      });
    }
    try {
      final res = await Supabase.instance.client
          .from('fare_matrix_history')
          .select()
          .order('changed_at', ascending: false)
          .limit(50)
          .timeout(const Duration(seconds: 4));
      if (mounted) {
        setState(() {
          _cachedHistory = List<Map<String, dynamic>>.from(res as List);
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _historyError = e.toString();
          _isLoadingHistory = false;
        });
      }
    }
  }

  String _formatCurrency(double val) {
    if (val % 1 == 0) return 'P${val.toInt()}';
    return 'P${val.toStringAsFixed(2)}';
  }

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
              _buildMetric('Minimum Fare', _formatCurrency(matrix.baseFare)),
              _buildMetric(
                  'Included Distance', '${matrix.includedBaseDistance} km'),
              _buildMetric('Per Km Rate', '${_formatCurrency(matrix.perKmRate)}/km'),
              _buildMetric('Formula', 'Minimum Fare + Distance Charge'),
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
      height: 320,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _cachedHistory != null
                      ? '${_cachedHistory!.length} updates recorded'
                      : 'Audit Log',
                  style: const TextStyle(color: AdminTheme.slate, fontSize: 13),
                ),
                IconButton(
                  tooltip: 'Refresh History',
                  icon: _isLoadingHistory
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AdminTheme.terracotta))
                      : const Icon(Icons.refresh_rounded,
                          color: AdminTheme.slate, size: 20),
                  onPressed: _isLoadingHistory
                      ? null
                      : () => _fetchHistory(refresh: true),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AdminTheme.borderLight),
          Expanded(child: _buildHistoryContent()),
        ],
      ),
    );
  }

  Widget _buildHistoryContent() {
    if (_isLoadingHistory && _cachedHistory == null) {
      return const Center(
        child: CircularProgressIndicator(color: AdminTheme.terracotta),
      );
    }
    if (_historyError != null && (_cachedHistory == null || _cachedHistory!.isEmpty)) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, color: AdminTheme.slate, size: 28),
            const SizedBox(height: 8),
            const Text('Unable to load history or offline',
                style: TextStyle(color: AdminTheme.slate)),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.bgCard,
                foregroundColor: AdminTheme.textPrimary,
              ),
              onPressed: () => _fetchHistory(refresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final history = _cachedHistory ?? const [];
    if (history.isEmpty) {
      return const Center(
        child: Text('No fare matrix history recorded yet.',
            style: TextStyle(color: AdminTheme.slate)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      separatorBuilder: (_, __) =>
          const Divider(color: AdminTheme.borderLight),
      itemBuilder: (context, index) {
        final h = history[index];
        DateTime? date;
        try {
          if (h['changed_at'] != null) {
            date = DateTime.parse(h['changed_at'].toString());
          }
        } catch (_) {}
        final vType = h['vehicle_type']?.toString().toUpperCase() ?? 'MATRIX';
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text('$vType Fare Updated',
              style: const TextStyle(
                  color: AdminTheme.textPrimary,
                  fontWeight: FontWeight.bold)),
          subtitle: Text(
              date != null
                  ? 'Changed at ${DateFormat("MMM d, yyyy h:mm a").format(date)}'
                  : 'Recent change',
              style: const TextStyle(color: AdminTheme.slate)),
          trailing: const Icon(Icons.history_rounded,
              color: AdminTheme.slate, size: 16),
        );
      },
    );
  }

  void _showEditDialog(
      BuildContext context, AppState app, FareMatrix matrix, String name) {
    final minFareCtrl = TextEditingController(text: matrix.baseFare.toString());
    final includedDistanceCtrl =
        TextEditingController(text: matrix.includedBaseDistance.toString());
    final perKmCtrl = TextEditingController(text: matrix.perKmRate.toString());
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
                        _buildField('Minimum Fare (₱)', minFareCtrl),
                        _buildField('Included Distance (km)',
                            includedDistanceCtrl),
                        _buildField('Per Km Rate (₱/km)', perKmCtrl),
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
                            final minFare = double.parse(minFareCtrl.text);
                            final updated = matrix.copyWith(
                              baseFare: minFare,
                              includedBaseDistance:
                                  double.parse(includedDistanceCtrl.text),
                              perKmRate: double.parse(perKmCtrl.text),
                              minimumFare: minFare,
                              updatedAt: DateTime.now(),
                            );
                            try {
                              await app.fareMatrixRepo.updateMatrix(updated);
                              app.forceUpdateFareMatrix(updated);
                              _fetchHistory(refresh: true);
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
              inactiveTrackColor: AdminTheme.slate.withValues(alpha: 0.3),
              thumbColor: AdminTheme.terracotta,
              overlayColor: AdminTheme.terracotta.withValues(alpha: 0.2),
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
    final distanceCharge =
        double.parse((validKm * matrix.perKmRate).toStringAsFixed(2));

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
              Text(_formatCurrency(fare),
                  style: const TextStyle(
                      color: AdminTheme.terracotta,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AdminTheme.borderLight),
          const SizedBox(height: 12),
          _buildFareRow('Minimum Fare', _formatCurrency(matrix.baseFare)),
          _buildFareRow(
            'Distance Charge (${validKm.toStringAsFixed(1)} km x ${_formatCurrency(matrix.perKmRate)})',
            _formatCurrency(distanceCharge),
          ),
          _buildFareRow('Total Fare', _formatCurrency(fare), isGreen: true),
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

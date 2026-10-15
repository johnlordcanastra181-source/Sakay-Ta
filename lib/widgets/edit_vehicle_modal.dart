import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/driver_profile.dart';
import '../state/app_state.dart';

class EditVehicleModal extends StatefulWidget {
  const EditVehicleModal({super.key, required this.profile});
  final DriverProfile profile;

  static Future<void> show(BuildContext context,
      {required DriverProfile profile}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditVehicleModal(profile: profile),
    );
  }

  @override
  State<EditVehicleModal> createState() => _EditVehicleModalState();
}

class _EditVehicleModalState extends State<EditVehicleModal> {
  late final TextEditingController _plateCtrl =
      TextEditingController(text: widget.profile.plateNumber);
  late final TextEditingController _makeCtrl =
      TextEditingController(text: widget.profile.make);
  late final TextEditingController _modelCtrl =
      TextEditingController(text: widget.profile.model);
  late final TextEditingController _colorCtrl =
      TextEditingController(text: widget.profile.color);
  late final TextEditingController _todaCtrl =
      TextEditingController(text: widget.profile.todaName ?? '');

  late VehicleType _vehicleType = widget.profile.vehicleType;
  bool _isSaving = false;

  @override
  void dispose() {
    _plateCtrl.dispose();
    _makeCtrl.dispose();
    _modelCtrl.dispose();
    _colorCtrl.dispose();
    _todaCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveVehicle() async {
    final plate = _plateCtrl.text.trim().toUpperCase();
    final make = _makeCtrl.text.trim();
    final model = _modelCtrl.text.trim();
    final color = _colorCtrl.text.trim();
    final toda = _todaCtrl.text.trim();

    if (plate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid plate number.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final app = context.read<AppState>();

    try {
      await app.updateDriverVehicleInfo(
        plateNumber: plate,
        make: make.isNotEmpty ? make : widget.profile.make,
        model: model.isNotEmpty ? model : widget.profile.model,
        color: color.isNotEmpty ? color : widget.profile.color,
        todaName: toda.isNotEmpty ? toda : widget.profile.todaName,
        vehicleType: _vehicleType,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF059669),
            content: Text('Vehicle details updated successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update vehicle details: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Vehicle & TODA Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Vehicle Type Selector
              const Text(
                'VEHICLE TYPE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _vehicleTypeCard(
                      type: VehicleType.tricycle,
                      title: 'Tricycle',
                      icon: Icons.electric_rickshaw_rounded,
                      selected: _vehicleType == VehicleType.tricycle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _vehicleTypeCard(
                      type: VehicleType.habal,
                      title: 'Habal-Habal',
                      icon: Icons.two_wheeler_rounded,
                      selected: _vehicleType == VehicleType.habal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Plate Number
              TextField(
                controller: _plateCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Plate Number',
                  hintText: 'e.g. 123-ABC or 4567-XX',
                  prefixIcon: const Icon(Icons.badge_rounded,
                      color: AppColors.terracotta),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),

              // Make & Model
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _makeCtrl,
                      decoration: InputDecoration(
                        labelText: 'Make',
                        hintText: 'e.g. Honda / Kawasaki',
                        prefixIcon: const Icon(
                            Icons.precision_manufacturing_rounded,
                            size: 20),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _modelCtrl,
                      decoration: InputDecoration(
                        labelText: 'Model',
                        hintText: 'e.g. TMX 125 / Barako',
                        prefixIcon: const Icon(
                            Icons.directions_car_filled_rounded,
                            size: 20),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Color & TODA
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _colorCtrl,
                      decoration: InputDecoration(
                        labelText: 'Color',
                        hintText: 'e.g. Blue / Red / Silver',
                        prefixIcon: const Icon(Icons.palette_rounded, size: 20),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _todaCtrl,
                      decoration: InputDecoration(
                        labelText: 'TODA Association',
                        hintText: 'e.g. Tagbilaran TODA',
                        prefixIcon: const Icon(Icons.groups_rounded, size: 20),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                onPressed: _isSaving ? null : _saveVehicle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.terracotta,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Save Vehicle Details',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vehicleTypeCard({
    required VehicleType type,
    required String title,
    required IconData icon,
    required bool selected,
  }) {
    return InkWell(
      onTap: () => setState(() => _vehicleType = type),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.terracotta.withValues(alpha: 0.08)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.terracotta : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? AppColors.terracotta : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                color:
                    selected ? AppColors.terracotta : const Color(0xFF1E1E1E),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

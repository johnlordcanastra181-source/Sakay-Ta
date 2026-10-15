import 'package:flutter/material.dart';
import '../core/psgc_data.dart';
import '../core/theme.dart';
import '../models/philippine_address.dart';

/// 3-Level Cascading Philippine Standard Geographic Code (PSGC) Picker Widget.
///
/// Ensures 100% accurate, standardized Philippine addresses without requiring
/// the user to manually type province, city/municipality, or barangay names.
/// Each level opens a scrollable, searchable bottom sheet so all 1,634+
/// municipalities and 42,000+ barangays are reachable.
class PhilippineAddressSelector extends StatefulWidget {
  final PhilippineAddress? initialAddress;
  final ValueChanged<PhilippineAddress> onAddressChanged;
  final bool showStreetField;
  final String streetLabel;
  final String streetHint;

  const PhilippineAddressSelector({
    super.key,
    this.initialAddress,
    required this.onAddressChanged,
    this.showStreetField = true,
    this.streetLabel = 'House / Building / Street Details (Optional)',
    this.streetHint = 'e.g. Block 4 Lot 12, Acacia Street',
  });

  @override
  State<PhilippineAddressSelector> createState() =>
      _PhilippineAddressSelectorState();
}

class _PhilippineAddressSelectorState extends State<PhilippineAddressSelector> {
  PSGCItem? _selectedProvince;
  PSGCItem? _selectedCity;
  PSGCItem? _selectedBarangay;
  final TextEditingController _streetCtrl = TextEditingController();

  List<PSGCItem> _provinces = [];
  List<PSGCItem> _cities = [];
  List<PSGCItem> _barangays = [];

  @override
  void initState() {
    super.initState();
    _provinces = PSGCData.getProvinces();
    _initFromInitialAddress();
  }

  void _initFromInitialAddress() {
    if (widget.initialAddress != null) {
      final initial = widget.initialAddress!;
      if (initial.streetDetails != null) {
        _streetCtrl.text = initial.streetDetails!;
      }
      if (initial.provinceCode.isNotEmpty) {
        final matchProv =
            _provinces.where((p) => p.code == initial.provinceCode);
        if (matchProv.isNotEmpty) {
          _selectedProvince = matchProv.first;
          _cities = PSGCData.getCitiesForProvince(_selectedProvince!.code);

          if (initial.cityCode.isNotEmpty) {
            final matchCity = _cities.where((c) => c.code == initial.cityCode);
            if (matchCity.isNotEmpty) {
              _selectedCity = matchCity.first;
              _barangays = PSGCData.getBarangaysForCity(_selectedCity!.code);

              if (initial.barangayCode.isNotEmpty) {
                final matchBrgy =
                    _barangays.where((b) => b.code == initial.barangayCode);
                if (matchBrgy.isNotEmpty) {
                  _selectedBarangay = matchBrgy.first;
                }
              }
            }
          }
        }
      }
    }
  }

  void _notifyChange() {
    final address = PhilippineAddress(
      provinceName: _selectedProvince?.name ?? '',
      provinceCode: _selectedProvince?.code ?? '',
      cityName: _selectedCity?.name ?? '',
      cityCode: _selectedCity?.code ?? '',
      barangayName: _selectedBarangay?.name ?? '',
      barangayCode: _selectedBarangay?.code ?? '',
      streetDetails:
          _streetCtrl.text.trim().isNotEmpty ? _streetCtrl.text.trim() : null,
    );
    widget.onAddressChanged(address);
  }

  void _onProvinceSelected(PSGCItem? province) {
    setState(() {
      _selectedProvince = province;
      _selectedCity = null;
      _selectedBarangay = null;
      _cities =
          province != null ? PSGCData.getCitiesForProvince(province.code) : [];
      _barangays = [];
    });
    _notifyChange();
  }

  void _onCitySelected(PSGCItem? city) {
    setState(() {
      _selectedCity = city;
      _selectedBarangay = null;
      _barangays = city != null ? PSGCData.getBarangaysForCity(city.code) : [];
    });
    _notifyChange();
  }

  void _onBarangaySelected(PSGCItem? barangay) {
    setState(() {
      _selectedBarangay = barangay;
    });
    _notifyChange();
  }

  @override
  void dispose() {
    _streetCtrl.dispose();
    super.dispose();
  }

  Future<void> _openPicker({
    required String title,
    required List<PSGCItem> items,
    required PSGCItem? current,
    required ValueChanged<PSGCItem> onSelected,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = await showModalBottomSheet<PSGCItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardColor(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _PickerSheet(
        title: title,
        items: items,
        current: current,
      ),
    );
    if (selected != null) {
      onSelected(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Province Picker
        _buildDropdownHeader('Province (Lalawigan)',
            isRequired: true, isDark: isDark),
        const SizedBox(height: 6),
        _buildDropdownCard(
          isDark: isDark,
          child: _buildPickerField(
            hint: 'Select Province',
            value: _selectedProvince,
            isDark: isDark,
            onTap: () => _openPicker(
              title: 'Select Province',
              items: _provinces,
              current: _selectedProvince,
              onSelected: _onProvinceSelected,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 2. City / Municipality Picker
        _buildDropdownHeader(
          'City / Municipality (Lungsod / Bayan)',
          isRequired: true,
          isEnabled: _selectedProvince != null,
          isDark: isDark,
        ),
        const SizedBox(height: 6),
        _buildDropdownCard(
          enabled: _selectedProvince != null,
          isDark: isDark,
          child: _buildPickerField(
            hint: _selectedProvince == null
                ? 'Select Province First'
                : 'Select City / Municipality',
            value: _selectedCity,
            enabled: _selectedProvince != null,
            isDark: isDark,
            onTap: () => _openPicker(
              title: 'Select City / Municipality',
              items: _cities,
              current: _selectedCity,
              onSelected: _onCitySelected,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 3. Barangay Picker
        _buildDropdownHeader(
          'Barangay',
          isRequired: true,
          isEnabled: _selectedCity != null,
          isDark: isDark,
        ),
        const SizedBox(height: 6),
        _buildDropdownCard(
          enabled: _selectedCity != null,
          isDark: isDark,
          child: _buildPickerField(
            hint: _selectedCity == null
                ? 'Select City/Municipality First'
                : 'Select Barangay',
            value: _selectedBarangay,
            enabled: _selectedCity != null,
            isDark: isDark,
            onTap: () => _openPicker(
              title: 'Select Barangay',
              items: _barangays,
              current: _selectedBarangay,
              onSelected: _onBarangaySelected,
            ),
          ),
        ),

        if (widget.showStreetField) ...[
          const SizedBox(height: 14),
          _buildDropdownHeader(widget.streetLabel,
              isRequired: false, isDark: isDark),
          const SizedBox(height: 6),
          TextFormField(
            controller: _streetCtrl,
            onChanged: (_) => _notifyChange(),
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textColor(isDark),
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: widget.streetHint,
              hintStyle: TextStyle(
                  color: AppColors.subtextColor(isDark), fontSize: 13),
              filled: true,
              fillColor: AppColors.inputBgColor(isDark),
              prefixIcon: Icon(
                Icons.home_outlined,
                size: 20,
                color: AppColors.subtextColor(isDark),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: isDark
                    ? BorderSide(color: AppColors.darkBorder)
                    : BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: isDark
                    ? BorderSide(color: AppColors.darkBorder)
                    : BorderSide.none,
              ),
            ),
          ),
        ],

        // Live Selected Address Summary Box
        if (_selectedProvince != null && _selectedCity != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF064E3B).withValues(alpha: 0.5)
                  : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF059669) : const Color(0xFFBBF7D0),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: isDark
                      ? const Color(0xFF34D399)
                      : const Color(0xFF16A34A),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Standard Address: ${_selectedBarangay != null ? "Brgy. ${_selectedBarangay!.name}, " : ""}${_selectedCity!.name}, ${_selectedProvince!.name}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF6EE7B7)
                          : const Color(0xFF15803D),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPickerField({
    required String hint,
    required PSGCItem? value,
    required VoidCallback? onTap,
    bool enabled = true,
    required bool isDark,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value?.name ?? hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: value != null
                      ? AppColors.textColor(isDark)
                      : enabled
                          ? AppColors.subtextColor(isDark)
                          : (isDark
                              ? const Color(0xFF475569)
                              : const Color(0xFFB0B0B0)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_drop_down,
              color: enabled
                  ? AppColors.subtextColor(isDark)
                  : (isDark
                      ? const Color(0xFF475569)
                      : const Color(0xFFC0C0C0)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownHeader(
    String title, {
    required bool isRequired,
    bool isEnabled = true,
    required bool isDark,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isEnabled
                ? AppColors.textColor(isDark)
                : AppColors.subtextColor(isDark),
          ),
        ),
        if (isRequired)
          const Text(
            ' *',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFFDC2626),
            ),
          ),
      ],
    );
  }

  Widget _buildDropdownCard({
    required Widget child,
    bool enabled = true,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: enabled
            ? (isDark ? AppColors.darkCardElevated : const Color(0xFFF4F4F6))
            : (isDark ? AppColors.darkCard : const Color(0xFFEBEBEB)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: enabled
              ? (isDark ? AppColors.darkBorder : Colors.transparent)
              : (isDark ? AppColors.darkBorder : const Color(0xFFDCDCDC)),
        ),
      ),
      child: child,
    );
  }
}

/// Scrollable + searchable selection sheet.
class _PickerSheet extends StatefulWidget {
  final String title;
  final List<PSGCItem> items;
  final PSGCItem? current;

  const _PickerSheet({
    required this.title,
    required this.items,
    required this.current,
  });

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<PSGCItem> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.items;
    return widget.items
        .where((item) => item.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.72;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF475569)
                      : const Color(0xFFD8D8D8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor(isDark),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (value) => setState(() => _query = value),
                style:
                    TextStyle(color: AppColors.textColor(isDark), fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search ${widget.title.toLowerCase()}',
                  hintStyle: TextStyle(
                      color: AppColors.subtextColor(isDark), fontSize: 13),
                  prefixIcon:
                      Icon(Icons.search, color: AppColors.subtextColor(isDark)),
                  filled: true,
                  fillColor: AppColors.inputBgColor(isDark),
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: isDark
                        ? BorderSide(color: AppColors.darkBorder)
                        : BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: isDark
                        ? BorderSide(color: AppColors.darkBorder)
                        : BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No results found',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.subtextColor(isDark), fontSize: 14),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: _filtered.length,
                  itemBuilder: (context, index) {
                    final item = _filtered[index];
                    final isSelected = item.code == widget.current?.code;
                    return ListTile(
                      dense: true,
                      title: Text(
                        item.name,
                        style: TextStyle(
                            fontSize: 14, color: AppColors.textColor(isDark)),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check,
                              color: isDark
                                  ? AppColors.goldVibrant
                                  : const Color(0xFF6E5600),
                              size: 20)
                          : null,
                      selected: isSelected,
                      selectedTileColor: isDark
                          ? AppColors.goldVibrant.withValues(alpha: 0.15)
                          : const Color(0xFFF7F3E3),
                      onTap: () => Navigator.of(context).pop(item),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

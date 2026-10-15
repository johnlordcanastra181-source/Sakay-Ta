import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../models/saved_place.dart';
import '../services/saved_places_service.dart';
import '../services/osm_map_service.dart';
import 'philippine_address_selector.dart';

class SavedPlacesModal extends StatefulWidget {
  const SavedPlacesModal({
    super.key,
    required this.userId,
    this.onSelectPlace,
  });

  final String userId;
  final ValueChanged<SavedPlace>? onSelectPlace;

  static Future<void> show(
    BuildContext context, {
    required String userId,
    ValueChanged<SavedPlace>? onSelectPlace,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SavedPlacesModal(
        userId: userId,
        onSelectPlace: onSelectPlace,
      ),
    );
  }

  @override
  State<SavedPlacesModal> createState() => _SavedPlacesModalState();
}

class _SavedPlacesModalState extends State<SavedPlacesModal> {
  final SavedPlacesService _savedPlacesService = SavedPlacesService.instance;

  @override
  void initState() {
    super.initState();
    _savedPlacesService.init(widget.userId);
  }

  void _showAddOrEditPlaceDialog({SavedPlace? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? 'Home');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    var category = existing?.category ?? 'home';
    var usePsgcSelector = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEdit ? 'Edit Saved Place' : 'Add Saved Place',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E1E1E),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Category Selector
                  const Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _categoryChip(
                        label: 'Home',
                        icon: Icons.home_rounded,
                        color: const Color(0xFF059669),
                        selected: category == 'home',
                        onTap: () => setSheetState(() {
                          category = 'home';
                          if (!isEdit && nameCtrl.text.isEmpty) {
                            nameCtrl.text = 'Home';
                          }
                        }),
                      ),
                      _categoryChip(
                        label: 'Work',
                        icon: Icons.work_rounded,
                        color: const Color(0xFF3B82F6),
                        selected: category == 'work',
                        onTap: () => setSheetState(() {
                          category = 'work';
                          if (!isEdit && nameCtrl.text.isEmpty) {
                            nameCtrl.text = 'Work';
                          }
                        }),
                      ),
                      _categoryChip(
                        label: 'School',
                        icon: Icons.school_rounded,
                        color: const Color(0xFFD97706),
                        selected: category == 'school',
                        onTap: () => setSheetState(() {
                          category = 'school';
                          if (!isEdit && nameCtrl.text.isEmpty) {
                            nameCtrl.text = 'School';
                          }
                        }),
                      ),
                      _categoryChip(
                        label: 'Market',
                        icon: Icons.shopping_basket_rounded,
                        color: const Color(0xFF8B5CF6),
                        selected: category == 'market',
                        onTap: () => setSheetState(() {
                          category = 'market';
                          if (!isEdit && nameCtrl.text.isEmpty) {
                            nameCtrl.text = 'Market';
                          }
                        }),
                      ),
                      _categoryChip(
                        label: 'Custom',
                        icon: Icons.location_on_rounded,
                        color: const Color(0xFF6E5600),
                        selected: category == 'custom',
                        onTap: () => setSheetState(() => category = 'custom'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Place Name
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Place Name (e.g. Home, Office, Gym)',
                      prefixIcon: const Icon(Icons.bookmark_outline_rounded),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Address Input Switcher (Text field or PSGC Selector)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Location & Address',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF374151),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => setSheetState(
                            () => usePsgcSelector = !usePsgcSelector),
                        icon: Icon(
                          usePsgcSelector
                              ? Icons.edit_note_rounded
                              : Icons.account_tree_rounded,
                          size: 16,
                        ),
                        label: Text(
                          usePsgcSelector ? 'Manual Input' : 'PSGC Picker',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  if (usePsgcSelector) ...[
                    PhilippineAddressSelector(
                      onAddressChanged: (addr) {
                        if (addr.isComplete) {
                          addressCtrl.text = addr.formattedAddress;
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                  ],

                  TextField(
                    controller: addressCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Address Details / Street / Landmark',
                      hintText:
                          'e.g. Banilad Town Center, Gov. Cuenco Ave, Cebu City',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Save Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final address = addressCtrl.text.trim();

                      if (name.isEmpty || address.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Please enter place name and address.'),
                          ),
                        );
                        return;
                      }

                      final matches =
                          await OsmMapService.instance.autocomplete(address);
                      if (!sheetCtx.mounted) return;
                      if (matches.isEmpty) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text(
                              'Unable to locate this address. Check the address and your connection.'),
                        ));
                        return;
                      }
                      final selected = await showDialog<Place>(
                        context: sheetCtx,
                        builder: (dialogContext) => SimpleDialog(
                          title: const Text('Select the matching location'),
                          children: matches
                              .map((place) => SimpleDialogOption(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, place),
                                    child:
                                        Text('${place.name}\n${place.address}'),
                                  ))
                              .toList(),
                        ),
                      );
                      if (selected == null || !sheetCtx.mounted) return;
                      final newPlace = SavedPlace(
                        id: existing?.id ??
                            'place_${DateTime.now().millisecondsSinceEpoch}',
                        userId: widget.userId,
                        name: name,
                        address: address,
                        geo: selected.geo,
                        category: category,
                        createdAt: existing?.createdAt ?? DateTime.now(),
                      );

                      if (isEdit) {
                        await _savedPlacesService.updatePlace(
                            widget.userId, newPlace);
                      } else {
                        await _savedPlacesService.addPlace(
                            widget.userId, newPlace);
                      }

                      if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                      setState(() {});
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                isEdit ? 'Place updated!' : 'Place saved!'),
                            backgroundColor: const Color(0xFF059669),
                          ),
                        );
                      }
                    },
                    child: Text(
                      isEdit ? 'Update Saved Place' : 'Save Place',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoryChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _savedPlacesService,
      builder: (context, _) {
        final places = _savedPlacesService.places;

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Saved Places',
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
              const SizedBox(height: 4),
              const Text(
                'Quickly book rides to your frequent home, work, and favorite destinations.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 18),

              // Places List
              if (places.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: Column(
                    children: const [
                      Icon(Icons.location_off_outlined,
                          size: 44, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'No saved places yet.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: places.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final place = places[i];

                    return InkWell(
                      onTap: () {
                        if (widget.onSelectPlace != null) {
                          widget.onSelectPlace!(place);
                          Navigator.pop(context);
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: place.iconColor.withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(place.icon,
                                  color: place.iconColor, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    place.name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E1E1E),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    place.address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  size: 18, color: Color(0xFF6B7280)),
                              onPressed: () =>
                                  _showAddOrEditPlaceDialog(existing: place),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 18, color: Color(0xFFDC2626)),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text('Delete ${place.name}?'),
                                    content: const Text(
                                        'Are you sure you want to remove this saved place?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFFDC2626),
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _savedPlacesService.deletePlace(
                                      widget.userId, place.id);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 18),

              // Add Place Button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFF059669), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => _showAddOrEditPlaceDialog(),
                icon: const Icon(Icons.add_location_alt_rounded,
                    color: Color(0xFF059669)),
                label: const Text(
                  'Add New Saved Place',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

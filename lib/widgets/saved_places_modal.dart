import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/neumorphic_theme.dart';
import '../models/saved_place.dart';
import '../services/saved_places_service.dart';
import '../services/osm_map_service.dart';
import 'neumorphic_widgets.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController(text: existing?.name ?? 'Home');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    var category = existing?.category ?? 'home';
    var usePsgcSelector = false;
    var isSaving = false;

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
            decoration: BoxDecoration(
              color: NeumorphicColors.surface(isDark),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.5)
                      : const Color(0xFFA6B4C9).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, -6),
                ),
              ],
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
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: NeumorphicColors.text(isDark),
                          letterSpacing: -0.3,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: NeumorphicColors.subtext(isDark),
                        ),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Category Selector
                  Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: NeumorphicColors.subtext(isDark),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _categoryChip(
                        label: 'Home',
                        icon: Icons.home_rounded,
                        color: const Color(0xFF059669),
                        selected: category == 'home',
                        isDark: isDark,
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
                        isDark: isDark,
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
                        isDark: isDark,
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
                        isDark: isDark,
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
                        isDark: isDark,
                        onTap: () => setSheetState(() => category = 'custom'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Place Name
                  Container(
                    decoration: NeumorphicDecorations.inset(
                      isDark: isDark,
                      radius: 14,
                    ),
                    child: TextField(
                      controller: nameCtrl,
                      style: TextStyle(color: NeumorphicColors.text(isDark)),
                      decoration: InputDecoration(
                        labelText: 'Place Name (e.g. Home, Office, Gym)',
                        labelStyle: TextStyle(
                          color: NeumorphicColors.subtext(isDark),
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.bookmark_outline_rounded,
                          color: NeumorphicColors.subtext(isDark),
                        ),
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Address Input Switcher (Text field or PSGC Selector)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Location & Address',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: NeumorphicColors.subtext(isDark),
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
                          color: NeumorphicColors.brandPrimary,
                        ),
                        label: Text(
                          usePsgcSelector ? 'Manual Input' : 'PSGC Picker',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: NeumorphicColors.brandPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

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

                  Container(
                    decoration: NeumorphicDecorations.inset(
                      isDark: isDark,
                      radius: 14,
                    ),
                    child: TextField(
                      controller: addressCtrl,
                      maxLines: 2,
                      style: TextStyle(color: NeumorphicColors.text(isDark)),
                      decoration: InputDecoration(
                        labelText: 'Address Details / Street / Landmark',
                        labelStyle: TextStyle(
                          color: NeumorphicColors.subtext(isDark),
                          fontSize: 13,
                        ),
                        hintText:
                            'e.g. Banilad Town Center, Gov. Cuenco Ave, Cebu City',
                        hintStyle: TextStyle(
                          color: NeumorphicColors.subtext(isDark).withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                        prefixIcon: Icon(
                          Icons.location_on_outlined,
                          color: NeumorphicColors.subtext(isDark),
                        ),
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Save Button
                  NeumorphicButton(
                    text: isSaving
                        ? 'Saving...'
                        : (isEdit ? 'Update Saved Place' : 'Save Place'),
                    isLoading: isSaving,
                    accentColor: const Color(0xFF059669),
                    height: 50,
                    onPressed: isSaving
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            final address = addressCtrl.text.trim();

                            if (name.isEmpty || address.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Please enter place name and address.'),
                                ),
                              );
                              return;
                            }

                            setSheetState(() => isSaving = true);
                            Geo? resolvedGeo = existing?.geo;

                            try {
                              var matches = await OsmMapService.instance
                                  .autocomplete(address);
                              if (matches.isEmpty && address.contains(',')) {
                                final firstPart =
                                    address.split(',').first.trim();
                                if (firstPart.isNotEmpty) {
                                  matches = await OsmMapService.instance
                                      .autocomplete(firstPart);
                                }
                              }
                              if (!sheetCtx.mounted) return;

                              if (matches.isNotEmpty) {
                                resolvedGeo = matches.first.geo;
                              }
                            } catch (e) {
                              debugPrint('SavedPlacesModal: geocode lookup fallback $e');
                            }

                            // Graceful fallback coordinate if unlocated
                            resolvedGeo ??= const Geo(10.3157, 123.8854);

                            final newPlace = SavedPlace(
                              id: existing?.id ??
                                  'place_${DateTime.now().millisecondsSinceEpoch}',
                              userId: widget.userId,
                              name: name,
                              address: address,
                              geo: resolvedGeo,
                              category: category,
                              createdAt: existing?.createdAt ?? DateTime.now(),
                            );

                            try {
                              if (isEdit) {
                                await _savedPlacesService.updatePlace(
                                    widget.userId, newPlace);
                              } else {
                                await _savedPlacesService.addPlace(
                                    widget.userId, newPlace);
                              }

                              if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isEdit
                                        ? 'Place updated!'
                                        : 'Place saved!'),
                                    backgroundColor: const Color(0xFF059669),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (sheetCtx.mounted) {
                                setSheetState(() => isSaving = false);
                                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to save place: $e'),
                                    backgroundColor: const Color(0xFFDC2626),
                                  ),
                                );
                              }
                            }
                          },
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
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: selected
            ? NeumorphicDecorations.pill(
                isDark: isDark,
                isSelected: true,
                activeColor: color,
              )
            : NeumorphicDecorations.raised(
                isDark: isDark,
                radius: 14,
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
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? Colors.white : NeumorphicColors.text(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: _savedPlacesService,
      builder: (context, _) {
        final places = _savedPlacesService.places;

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          decoration: BoxDecoration(
            color: NeumorphicColors.surface(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.5)
                    : const Color(0xFFA6B4C9).withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Saved Places',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: NeumorphicColors.text(isDark),
                      letterSpacing: -0.3,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: NeumorphicColors.subtext(isDark),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Quickly book rides to your frequent home, work, and favorite destinations.',
                style: TextStyle(
                  fontSize: 13,
                  color: NeumorphicColors.subtext(isDark),
                ),
              ),
              const SizedBox(height: 18),

              // Places List
              if (places.isEmpty)
                NeumorphicCard(
                  padding: const EdgeInsets.all(32),
                  radius: 20,
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: NeumorphicDecorations.inset(
                          isDark: isDark,
                          radius: 26,
                        ),
                        child: Icon(
                          Icons.location_off_outlined,
                          size: 26,
                          color: NeumorphicColors.subtext(isDark),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No saved places yet.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: NeumorphicColors.text(isDark),
                        ),
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

                    return NeumorphicCard(
                      padding: const EdgeInsets.all(14),
                      radius: 16,
                      onTap: () {
                        if (widget.onSelectPlace != null) {
                          widget.onSelectPlace!(place);
                          Navigator.pop(context);
                        }
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: NeumorphicDecorations.inset(
                              isDark: isDark,
                              radius: 22,
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
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: NeumorphicColors.text(isDark),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  place.address,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: NeumorphicColors.subtext(isDark),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.edit_outlined,
                                size: 18, color: NeumorphicColors.subtext(isDark)),
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
                                  backgroundColor: NeumorphicColors.surface(isDark),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                  title: Text(
                                    'Delete ${place.name}?',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: NeumorphicColors.text(isDark),
                                    ),
                                  ),
                                  content: Text(
                                    'Are you sure you want to remove this saved place?',
                                    style: TextStyle(
                                      color: NeumorphicColors.subtext(isDark),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: Text(
                                        'Cancel',
                                        style: TextStyle(
                                          color: NeumorphicColors.subtext(isDark),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 90,
                                      child: NeumorphicButton(
                                        text: 'Delete',
                                        height: 40,
                                        accentColor: const Color(0xFFDC2626),
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                      ),
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
                    );
                  },
                ),

              const SizedBox(height: 18),

              // Add Place Button
              NeumorphicButton(
                text: 'Add New Saved Place',
                icon: Icons.add_location_alt_rounded,
                isSecondary: true,
                height: 50,
                onPressed: () => _showAddOrEditPlaceDialog(),
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../state/app_state.dart';
import '../admin_theme.dart';
import '../widgets/admin_widgets.dart';

/// Module: Manage TODA Associations — Registry of tricycle & habal-habal operator associations.
class AdminTodasView extends StatefulWidget {
  const AdminTodasView({super.key});

  @override
  State<AdminTodasView> createState() => _AdminTodasViewState();
}

class _AdminTodasViewState extends State<AdminTodasView> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _showAddTodaDialog([Map<String, dynamic>? existingToda]) async {
    final app = context.read<AppState>();
    final nameCtrl = TextEditingController(text: existingToda?['name'] ?? '');
    final muniCtrl = TextEditingController(
        text: (existingToda?['area'] ??
                existingToda?['municipality'] ??
                existingToda?['city'] ??
                'Cebu City')
            .toString());
    final provCtrl = TextEditingController(
        text: existingToda?['province']?.toString() ?? '');
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.94).clamp(280.0, 440.0);
    var saving = false;
    String? errorText;

    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: AdminTheme.bgCard,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AdminTheme.border)),
            title: Text(
              existingToda == null
                  ? 'Register New TODA Association'
                  : 'Edit TODA Association',
              style: const TextStyle(
                  color: AdminTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: dialogWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(
                        color: AdminTheme.textPrimary, fontSize: 13),
                    decoration: AdminTheme.inputDecoration(
                        labelText: 'TODA Name / Title',
                        hintText:
                            'e.g. Lahug-Banilad Tricycle Operators Assn.'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: muniCtrl,
                    style: const TextStyle(
                        color: AdminTheme.textPrimary, fontSize: 13),
                    decoration: AdminTheme.inputDecoration(
                        labelText: 'Municipality / City',
                        hintText: 'e.g. Cebu City'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: provCtrl,
                    style: const TextStyle(
                        color: AdminTheme.textPrimary, fontSize: 13),
                    decoration: AdminTheme.inputDecoration(
                        labelText: 'Province', hintText: 'e.g. Cebu'),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        errorText!,
                        style: const TextStyle(
                            color: AdminTheme.terracotta, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel',
                      style: TextStyle(color: AdminTheme.slate))),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        final name = nameCtrl.text.trim();
                        final city = muniCtrl.text.trim();
                        final requiredFieldsValid =
                            name.isNotEmpty && city.isNotEmpty;
                        debugPrint('[AdminTODA][VALIDATION] '
                            'name_present=${name.isNotEmpty} '
                            'city_present=${city.isNotEmpty} '
                            'valid=$requiredFieldsValid');
                        if (name.isEmpty || city.isEmpty) {
                          setDialogState(() {
                            errorText = name.isEmpty
                                ? 'Enter a TODA name.'
                                : 'Enter a municipality or city.';
                          });
                          return;
                        }

                        final id = (existingToda?['id']?.toString().trim() ??
                                    '')
                                .isNotEmpty
                            ? existingToda!['id'].toString().trim()
                            : 'toda-${DateTime.now().millisecondsSinceEpoch}';
                        final existingCode =
                            existingToda?['code']?.toString().trim() ?? '';
                        final todaData = {
                          'id': id,
                          'code': existingCode.isEmpty ? id : existingCode,
                          'name': name,
                          'municipality': city,
                          'province': provCtrl.text.trim(),
                        };

                        setDialogState(() {
                          saving = true;
                          errorText = null;
                        });
                        try {
                          final saved = await app.saveToda(todaData);
                          debugPrint(
                              '[AdminTODA][UI_SUCCESS] id=${saved['id']} '
                              'name=${saved['name']}');
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'TODA Association saved successfully.')),
                              );
                            }
                          }
                        } catch (error, stackTrace) {
                          debugPrint('[AdminTODA][UI_ERROR] '
                              'type=${error.runtimeType} message=$error');
                          debugPrintStack(stackTrace: stackTrace);
                          if (ctx.mounted) {
                            setDialogState(() {
                              saving = false;
                              errorText = _formatTodaError(error);
                            });
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.terracotta,
                    foregroundColor: Colors.white),
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Association'),
              ),
            ],
          ),
        ),
      );
    } finally {
      nameCtrl.dispose();
      muniCtrl.dispose();
      provCtrl.dispose();
    }
  }

  String _formatTodaError(Object error) {
    if (error is PostgrestException) {
      return 'Supabase ${error.code}: ${error.message}';
    }
    if (error is StateError) {
      return error.message.toString();
    }
    return 'Error saving TODA: $error';
  }

  void _confirmDeleteToda(Map<String, dynamic> toda, AppState app) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AdminTheme.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded,
                color: AdminTheme.terracotta, size: 22),
            SizedBox(width: 8),
            Text('Delete TODA Association',
                style: TextStyle(color: AdminTheme.textPrimary, fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${toda['name']}" from the registry? Drivers currently under this association will remain registered.',
          style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:
                const Text('Cancel', style: TextStyle(color: AdminTheme.slate)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.terracotta,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await app.deleteToda(toda['id']);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('TODA "${toda['name']}" removed successfully.'),
                    backgroundColor: AdminTheme.navyLight,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminSectionHeader(
          title: 'TODA Associations Registry',
          subtitle:
              'Manage recognized Tricycle & Habal-Habal Operator and Driver Associations across LGUs.',
          actions: [
            ElevatedButton.icon(
              onPressed: () => _showAddTodaDialog(),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add TODA'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.terracotta,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),

        // ── Search & Grid ────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: AdminTheme.cardDecoration(),
          child: SizedBox(
            width: isMobile ? double.infinity : 320,
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              style:
                  const TextStyle(color: AdminTheme.textPrimary, fontSize: 13),
              decoration: AdminTheme.inputDecoration(
                hintText: 'Search TODA by name or municipality...',
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AdminTheme.slate, size: 18),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            size: 16, color: AdminTheme.slate),
                        onPressed: () => setState(() => _searchCtrl.clear()))
                    : null,
              ),
            ),
          ),
        ),

        AdminDataStreamBuilder<List<Map<String, dynamic>>>(
          section: 'todas',
          stream: app.streamTodas(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                  child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator()));
            }

            var todas = snapshot.data ?? [];
            if (_searchCtrl.text.trim().isNotEmpty) {
              final q = _searchCtrl.text.toLowerCase().trim();
              todas = todas.where((t) {
                final name = (t['name'] ?? '').toString().toLowerCase();
                final muni = (t['area'] ?? '').toString().toLowerCase();
                return name.contains(q) || muni.contains(q);
              }).toList();
            }

            if (todas.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: AdminEmptyState(
                  icon: Icons.groups_outlined,
                  title: 'No TODA Associations Found',
                  subtitle:
                      'Register TODA associations to allow drivers to select their official organization during signup.',
                ),
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final count = constraints.maxWidth < 600
                    ? 1
                    : (constraints.maxWidth < 1000 ? 2 : 3);

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: count,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: constraints.maxWidth < 600
                        ? 2.2
                        : (constraints.maxWidth < 1000 ? 2.0 : 1.8),
                  ),
                  itemCount: todas.length,
                  itemBuilder: (context, i) {
                    final toda = todas[i];
                    final name = toda['name'] ?? 'Unnamed TODA';
                    final muni = toda['area'] ?? '-';

                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: AdminTheme.cardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color:
                                      AdminTheme.gold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.groups_rounded,
                                    color: AdminTheme.gold, size: 20),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 16, color: AdminTheme.slate),
                                onPressed: () => _showAddTodaDialog(toda),
                                tooltip: 'Edit TODA',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 16, color: AdminTheme.terracotta),
                                onPressed: () => _confirmDeleteToda(toda, app),
                                tooltip: 'Delete TODA',
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            name,
                            style: const TextStyle(
                                color: AdminTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            muni,
                            style: const TextStyle(
                                color: AdminTheme.textMuted, fontSize: 12),
                          ),
                          const Spacer(),
                          const Row(
                            children: [
                              Icon(Icons.verified_rounded,
                                  size: 14, color: AdminTheme.successText),
                              SizedBox(width: 4),
                              Text('LGU Accredited Association',
                                  style: TextStyle(
                                      color: AdminTheme.textSecondary,
                                      fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}

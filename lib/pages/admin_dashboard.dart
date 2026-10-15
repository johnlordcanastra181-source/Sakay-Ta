import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../state/app_state.dart';
import 'admin/admin_shell.dart';

/// Entry point for the Admin Dashboard inside the Flutter application.
/// Hosts the full-featured, responsive Flutter Web Admin Shell.
class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key, required this.onNavigate});
  final Function(AppScreen) onNavigate;

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      onLogout: () async {
        await context.read<AppState>().logout();
        onNavigate(AppScreen.login);
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:kologsoft/providers/dashboard_provider.dart';
import 'package:provider/provider.dart';

class LogoutDialog {
  static Future<void> show(BuildContext parentcontext) {
    final datafeed = Provider.of<Datafeed>(parentcontext, listen: false);
    final dashboardProvider = Provider.of<DashboardProvider>(
      parentcontext,
      listen: false,
    );
    final colorScheme = Theme.of(parentcontext).colorScheme;

    return showDialog(
      context: parentcontext,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          title: Text('Logout', style: TextStyle(color: colorScheme.onSurface)),
          content: Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurface,
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              onPressed: () async {
                Navigator.pop(context);
                await dashboardProvider.clearBranchStock();
                await datafeed.logout(parentcontext);
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }
}

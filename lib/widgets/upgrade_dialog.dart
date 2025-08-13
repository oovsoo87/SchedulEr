import 'package:flutter/material.dart';

// A reusable function to show the upgrade prompt.
void showUpgradeDialog(BuildContext context, {required String title, required String message}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Maybe Later'),
        ),
        ElevatedButton(
          onPressed: () {
            // TODO: Handle the In-App Purchase flow.
            // This is where you would trigger the purchase process.
            Navigator.pop(context);
            // For now, we can show a placeholder message.
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('The upgrade process would begin here.')),
            );
          },
          child: const Text('Upgrade Now'),
        ),
      ],
    ),
  );
}
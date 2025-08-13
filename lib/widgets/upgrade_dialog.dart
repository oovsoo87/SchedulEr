import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scheduler/services/iap_service.dart';

// A reusable function to show the upgrade prompt.
void showUpgradeDialog(BuildContext context, {required String title, required String message}) {
  showDialog(
    context: context,
    builder: (context) => Consumer(
        builder: (context, ref, child) {
          return AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Maybe Later'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Trigger the purchase flow using our IAP service
                  ref.read(iapServiceProvider).buyProUpgrade();
                  Navigator.pop(context);
                },
                child: const Text('Upgrade Now'),
              ),
            ],
          );
        }
    ),
  );
}
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Layer 1: Framework errors (build/layout/paint)
  FlutterError.onError = (details) {
    debugPrint('FlutterError: ${details.exception}');
    FlutterError.presentError(details);
  };

  // Layer 2: Uncaught async errors (platform channel callbacks, Future chains)
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught async error: $error\n$stack');
    return true; // Prevent default termination
  };

  // Layer 3: Error widget fallback for build errors
  ErrorWidget.builder = (details) {
    return Material(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            const Text('An error occurred'),
            TextButton(
              onPressed: () {
                // Restart app
                runApp(const SmsApp());
              },
              child: const Text('Restart'),
            ),
          ],
        ),
      ),
    );
  };

  runApp(const SmsApp());
}

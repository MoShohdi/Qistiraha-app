import 'package:flutter/material.dart';

const _kBrand = Color(0xFF99AFD7);

/// Shown in place of an endless spinner when a live stream or future errors.
/// Gives the user a clear message and a Retry affordance instead of leaving
/// them stuck on a frozen `CircularProgressIndicator`.
class StreamErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  final String message;

  const StreamErrorView({
    super.key,
    required this.onRetry,
    this.message =
        "We couldn't load your data. Check your connection and try again.",
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBrand,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

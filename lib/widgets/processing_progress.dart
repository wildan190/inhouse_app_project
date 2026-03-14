import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../providers/product_provider.dart';

class ProcessingProgress extends StatelessWidget {
  final ProductProvider provider;

  const ProcessingProgress({super.key, required this.provider});

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF6D28D9).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const SpinKitRing(color: Color(0xFF6D28D9), size: 20, lineWidth: 2),
                  const SizedBox(width: 12),
                  const Text(
                    'Processing Merge...',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Text(
                _formatDuration(provider.processingDuration),
                style: const TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'monospace'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: provider.progress,
              backgroundColor: const Color(0xFF111827),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6D28D9)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(provider.progress * 100).toStringAsFixed(1)}%',
                style: const TextStyle(color: Color(0xFFA78BFA), fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Text(
                'Merging ${provider.selectedItemsCount} items',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../providers/product_provider.dart';

class HomeSidebar extends StatelessWidget {
  final ProductProvider provider;
  final TextEditingController controller;

  const HomeSidebar({
    super.key,
    required this.provider,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 250,
      margin: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF374151) : Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PROCESSED ORDERS',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87, 
                    fontSize: 13, 
                    fontWeight: FontWeight.bold
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.blue, size: 18),
                      onPressed: () => provider.refreshProcessedList(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Refresh list',
                    ),
                    if (provider.processedOrderNumbers.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_sweep, color: Colors.red, size: 18),
                        onPressed: () => provider.clearProcessedOrders(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Clear list',
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Divider(color: theme.dividerColor, height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: controller,
                readOnly: true,
                maxLines: null,
                expands: true,
                style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: 'No orders processed yet',
                  hintStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey[400], fontSize: 12),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF111827) : Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF374151) : Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF374151) : Colors.grey[300]!),
                  ),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

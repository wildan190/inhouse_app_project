import 'package:flutter/material.dart';
import '../providers/product_provider.dart';

class TableHeader extends StatelessWidget {
  final ProductProvider provider;

  const TableHeader({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final allSelected = provider.orderNumbers.isNotEmpty && 
                       provider.selectedOrderNumbers.length == provider.orderNumbers.length;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? const Color(0xFF374151) : Colors.grey[300]!),
      ),
      child: Row(
        children: [
          SizedBox(
            height: 24, width: 24,
            child: Checkbox(
              value: allSelected,
              onChanged: (v) => provider.toggleAllSelection(v ?? false),
              checkColor: Colors.white,
              activeColor: const Color(0xFF6D28D9),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Row(
              children: [
                _buildSortableHeader('PRODUCT INFO', 'sku', provider),
                const SizedBox(width: 8),
                _buildSortableHeader('ID SKU', 'id_sku', provider),
              ],
            ),
          ),
          const Expanded(
            flex: 2,
            child: Center(
              child: Text('UPLOAD', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Center(
              child: Text('MERGED', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
          const Expanded(
            flex: 3,
            child: Text('RESI', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          const Expanded(
            flex: 1,
            child: Center(
              child: Text('QTY', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Center(
              child: Text('STATUS', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: _buildSortableHeader('TIME', 'time', provider),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Center(
              child: Text('OPERATE', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortableHeader(String label, String column, ProductProvider provider) {
    final isSelected = provider.sortColumn == column;
    return InkWell(
      onTap: () => provider.setSort(column),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            Icon(
              isSelected 
                ? (provider.isAscending ? Icons.arrow_upward : Icons.arrow_downward) 
                : Icons.arrow_downward,
              size: 12,
              color: isSelected ? const Color(0xFF6D28D9) : Colors.grey.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

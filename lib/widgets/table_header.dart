import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../providers/theme_provider.dart';

class TableHeader extends StatefulWidget {
  final ProductProvider provider;

  const TableHeader({super.key, required this.provider});

  @override
  State<TableHeader> createState() => _TableHeaderState();
}

class _TableHeaderState extends State<TableHeader> {
  String? _hoveredColumn;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final allSelected = widget.provider.paginatedOrderNumbers.isNotEmpty && 
                       widget.provider.paginatedOrderNumbers.every((orderNo) => widget.provider.selectedOrderNumbers.contains(orderNo));
    final theme = Theme.of(context);
    
    bool isDark;
    if (themeProvider.themeMode == ThemeMode.system) {
      isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    } else {
      isDark = themeProvider.themeMode == ThemeMode.dark;
    }

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
              onChanged: (v) => widget.provider.toggleAllSelection(v ?? false),
              checkColor: Colors.white,
              activeColor: const Color(0xFF6D28D9),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Row(
              children: [
                const Text('PRODUCT INFORMATION', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                _buildSortableHeader('SKU PLATFORM', 'sku', widget.provider),
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
              child: _buildSortableHeader('TIME', 'time', widget.provider),
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
    final isHovered = _hoveredColumn == column;
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredColumn = column),
      onExit: (_) => setState(() => _hoveredColumn = null),
      child: GestureDetector(
        onTap: () => provider.setSort(column),
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: isHovered ? (Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label, 
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF6D28D9) : Colors.grey, 
                    fontSize: 11, 
                    fontWeight: FontWeight.bold
                  )
                ),
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
        ),
      ),
    );
  }
}

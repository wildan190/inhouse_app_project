import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../providers/theme_provider.dart';

class PaginationBar extends StatelessWidget {
  final ProductProvider provider;

  const PaginationBar({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    
    bool isDark;
    if (themeProvider.themeMode == ThemeMode.system) {
      isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    } else {
      isDark = themeProvider.themeMode == ThemeMode.dark;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: isDark ? const Color(0xFF1F2937) : Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text('Orders per page:', style: TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(width: 6),
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1F2937) : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isDark ? const Color(0xFF374151) : Colors.grey[300]!),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: provider.pageSize,
                    dropdownColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 16),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 11),
                    items: [10, 20, 50, 100, 300].map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text(value.toString()),
                      );
                    }).toList(),
                    onChanged: (int? newValue) {
                      if (newValue != null) {
                        provider.setPageSize(newValue);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.chevron_left, color: isDark ? Colors.white : Colors.black87),
                onPressed: provider.currentPage > 1 ? () => provider.setPage(provider.currentPage - 1) : null,
              ),
              const SizedBox(width: 12),
              Text(
                'Page ${provider.currentPage} of ${provider.totalPages}', 
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87, 
                  fontSize: 11, 
                  fontWeight: FontWeight.w500
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.chevron_right, color: isDark ? Colors.white : Colors.black87),
                onPressed: provider.currentPage < provider.totalPages ? () => provider.setPage(provider.currentPage + 1) : null,
              ),
            ],
          ),
          const SizedBox(width: 60), // Adjusted spacer
        ],
      ),
    );
  }
}

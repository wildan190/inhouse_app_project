import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../providers/theme_provider.dart';

class FloatingSearchBar extends StatelessWidget {
  final bool isVisible;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ProductProvider provider;
  final VoidCallback onClose;
  final VoidCallback onSubmitted;

  const FloatingSearchBar({
    super.key,
    required this.isVisible,
    required this.controller,
    required this.focusNode,
    required this.provider,
    required this.onClose,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    
    bool isDark;
    if (themeProvider.themeMode == ThemeMode.system) {
      isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    } else {
      isDark = themeProvider.themeMode == ThemeMode.dark;
    }

    return Positioned(
      top: 60, // Lowered from 10 to not cover toolbar buttons
      right: 20,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        color: theme.cardColor,
        child: Container(
          width: 350,
          constraints: const BoxConstraints(maxHeight: 300), // Limits total height to 300px
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: isDark ? const Color(0xFF374151) : Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start, // Align close button to top
            children: [
              Expanded(
                child: Scrollbar( // Add scrollbar for better visibility
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: (value) => provider.setSearchQuery(value),
                    onSubmitted: (_) => onSubmitted(),
                    autofocus: true,
                    maxLines: null, // Still dynamic but constrained by parent
                    keyboardType: TextInputType.multiline,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Cari Masal... (Pisahkan dengan Enter)',
                      hintStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey[400], fontSize: 12),
                      prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey : Colors.grey[400], size: 18),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      suffix: controller.text.isNotEmpty 
                        ? Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(
                              '${provider.orderNumbers.length} hasil',
                              style: TextStyle(color: isDark ? Colors.grey : Colors.grey[400], fontSize: 11),
                            ),
                          )
                        : null,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: IconButton(
                  icon: Icon(Icons.close, color: isDark ? Colors.grey : Colors.grey[400], size: 18),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

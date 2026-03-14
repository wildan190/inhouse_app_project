import 'dart:io';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import 'product_row.dart';

class OrderGroup extends StatelessWidget {
  final String orderNumber;
  final List<Product> products;
  final ProductProvider provider;
  final Function(Product, File) onImageUpload;

  const OrderGroup({
    super.key,
    required this.orderNumber,
    required this.products,
    required this.provider,
    required this.onImageUpload,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = provider.selectedOrderNumbers.contains(orderNumber);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected 
            ? (isDark ? const Color(0xFF1F2937).withValues(alpha: 0.5) : Colors.deepPurple.withValues(alpha: 0.05))
            : theme.cardColor,
        border: Border.all(color: isDark ? const Color(0xFF1F2937) : Colors.grey[200]!),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2937).withValues(alpha: 0.3) : Colors.grey[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
            child: Row(
              children: [
                SizedBox(
                  height: 24, width: 24,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (v) => provider.toggleOrderSelection(orderNumber),
                    checkColor: Colors.white,
                    activeColor: const Color(0xFF6D28D9),
                  ),
                ),
                const SizedBox(width: 8),
                SelectableText(
                  'Order: $orderNumber', 
                  style: TextStyle(
                    color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9), 
                    fontWeight: FontWeight.bold, 
                    fontSize: 13
                  ),
                ),
                const SizedBox(width: 8),
                SelectableText(
                  '(${products.length} Items)', 
                  style: TextStyle(color: isDark ? Colors.grey : Colors.grey[600], fontSize: 11),
                ),
              ],
            ),
          ),
          ...products.map((product) => ProductRow(
            product: product,
            provider: provider,
            onImageUpload: onImageUpload,
          )),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';

class ProductRow extends StatefulWidget {
  final Product product;
  final ProductProvider provider;
  final Function(Product, File) onImageUpload;

  const ProductRow({
    super.key,
    required this.product,
    required this.provider,
    required this.onImageUpload,
  });

  @override
  State<ProductRow> createState() => _ProductRowState();
}

class _ProductRowState extends State<ProductRow> {
  bool _isDragging = false;

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending': return Colors.grey;
      case 'image_uploaded': return Colors.blue;
      case 'completed': return Colors.green;
      case 'error': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final provider = widget.provider;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: isDark ? const Color(0xFF1F2937).withValues(alpha: 0.5) : Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 32),
          // 1. PRODUCT INFORMATION
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F2937) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isDark ? const Color(0xFF374151) : Colors.grey[300]!),
                  ),
                  child: product.tautanGambarProduk.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: CachedNetworkImage(
                            imageUrl: product.tautanGambarProduk,
                            fit: BoxFit.cover,
                            memCacheWidth: 120,
                            placeholder: (context, url) => const SpinKitPulse(color: Colors.grey, size: 16),
                            errorWidget: (context, url, error) => const Icon(Icons.image, color: Colors.grey, size: 20),
                          ),
                        )
                      : const Icon(Icons.image, color: Colors.grey, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SelectableText(
                        product.skuPlatform, 
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 12, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: SelectableText(
                          'ID SKU: ${product.idSku}', 
                          style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 2),
                      SelectableText(
                        product.spesifikasiProduk, 
                        style: const TextStyle(color: Colors.grey, fontSize: 10), 
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 2. UPLOAD (Source Image)
          Expanded(
            flex: 2,
            child: Center(
              child: DropTarget(
                onDragDone: (detail) async {
                  if (detail.files.isNotEmpty) {
                    final file = File(detail.files.first.path);
                    widget.onImageUpload(product, file);
                  }
                },
                onDragEntered: (detail) => setState(() => _isDragging = true),
                onDragExited: (detail) => setState(() => _isDragging = false),
                child: InkWell(
                  onTap: () async {
                    try {
                      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
                      if (result != null && result.files.single.path != null) {
                        File imageFile = File(result.files.single.path!);
                        widget.onImageUpload(product, imageFile);
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _isDragging ? const Color(0xFF374151) : const Color(0xFF111827),
                      border: Border.all(
                        color: _isDragging ? const Color(0xFFA78BFA) : const Color(0xFF374151),
                        width: _isDragging ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: product.localImagePath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Image.file(File(product.localImagePath!), fit: BoxFit.cover, cacheWidth: 120),
                          )
                        : Icon(
                            _isDragging ? Icons.file_upload : Icons.add,
                            color: _isDragging ? const Color(0xFFA78BFA) : Colors.grey,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ),
          ),
          // 3. MERGED (Result Image)
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF374151)),
                ),
                child: product.mergedImagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: Image.file(File(product.mergedImagePath!), fit: BoxFit.cover, cacheWidth: 120),
                      )
                    : const Icon(Icons.image_not_supported, color: Colors.grey, size: 20),
              ),
            ),
          ),
          // 4. RESI
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SelectableText(product.nomorResi, style: const TextStyle(color: Colors.white, fontSize: 11)),
                SelectableText(product.noPesanan, style: const TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ),
          ),
          // 5. QTY
          Expanded(
            flex: 1,
            child: Center(
              child: SelectableText(product.jumlahBarang.toString(), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
          // 6. STATUS
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(product.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _getStatusColor(product.status).withValues(alpha: 0.3)),
                ),
                child: Text(
                  (product.status ?? 'pending').toUpperCase().replaceAll('_', ' '),
                  style: TextStyle(color: _getStatusColor(product.status), fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          // 7. TIME
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                product.createdAt != null ? DateFormat('HH:mm:ss').format(product.createdAt!) : '-',
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ),
          ),
          // 8. OPERATE
          Expanded(
            flex: 2,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (product.localImagePath != null)
                    IconButton(
                      icon: const Icon(Icons.merge_type, color: Color(0xFF6D28D9), size: 18),
                      onPressed: () => provider.mergeProduct(product),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Merge individual',
                    ),
                  if (product.localImagePath != null) const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                    onPressed: () => provider.deleteProduct(product.id!),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Delete item',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

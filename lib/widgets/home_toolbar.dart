import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../providers/theme_provider.dart';
import 'import_preview_dialog.dart';

class HomeToolbar extends StatelessWidget {
  final ProductProvider provider;
  final TextEditingController searchController;
  final String globalUploadMode;
  final Function(String) onUploadModeChanged;

  const HomeToolbar({
    super.key,
    required this.provider,
    required this.searchController,
    required this.globalUploadMode,
    required this.onUploadModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    // Determine dark mode based on themeMode or system brightness
    bool isDark;
    if (themeProvider.themeMode == ThemeMode.system) {
      isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    } else {
      isDark = themeProvider.themeMode == ThemeMode.dark;
    }

    return Row(
      children: [
        Text(
          'Product List',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87, 
            fontSize: 18, 
            fontWeight: FontWeight.w600
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2937) : Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${provider.orderNumbers.length} Order, ${provider.products.length} Total, ${provider.totalQuantity} Qty',
            style: TextStyle(color: isDark ? Colors.grey : Colors.grey[600], fontSize: 11),
          ),
        ),
        if (provider.selectedOrderNumbers.isNotEmpty) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF6D28D9).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF6D28D9)),
            ),
            child: Text(
              '${provider.selectedOrderNumbers.length} Orders (${provider.selectedItemsCount} Items) Selected',
              style: const TextStyle(color: Color(0xFFA78BFA), fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
        const SizedBox(width: 16),
        // Theme Toggle Button
        IconButton(
          icon: Icon(
            isDark ? Icons.light_mode : Icons.dark_mode,
            color: isDark ? Colors.yellow[700] : Colors.blueGrey[800],
            size: 20,
          ),
          tooltip: isDark ? 'Ganti ke Mode Terang' : 'Ganti ke Mode Gelap',
          onPressed: () => themeProvider.toggleTheme(),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2937).withValues(alpha: 0.5) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF374151) : Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Text(
                'Upload Rule:', 
                style: TextStyle(
                  color: isDark ? Colors.grey : Colors.grey[700], 
                  fontSize: 12, 
                  fontWeight: FontWeight.bold
                )
              ),
              const SizedBox(width: 12),
              _buildUploadModeRadio('Single', 'single', Colors.blue, isDark),
              _buildUploadModeRadio('SKU Platform', 'sku', Colors.purple, isDark),
              _buildUploadModeRadio('ID SKU', 'id_sku', Colors.orange, isDark),
            ],
          ),
        ),
        const Spacer(),
        _buildActionButton('Import Data', Icons.upload_file, () async {
          try {
            final file = await provider.pickImportFile();
            if (file != null) {
              final products = await provider.parseImportFile(file);
              if (products != null && products.isNotEmpty) {
                if (context.mounted) {
                  await ImportPreviewDialog.show(context, products, provider);
                }
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('File kosong atau format tidak didukung.'), backgroundColor: Colors.orange),
                );
              }
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          }
        }, const Color(0xFF374151)),
        const SizedBox(width: 6),
        _buildActionButton('Save Selected Merged', Icons.save_alt, () async {
          final success = await provider.saveSelectedMerged();
          if (!success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Gagal menyimpan: Pastikan SEMUA baris pada pesanan yang dipilih telah diunggah gambarnya dan diproses merge.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          } else if (success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Berhasil menyimpan hasil merge ke folder tujuan.'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }, const Color(0xFF059669)),
        const SizedBox(width: 6),
        _buildActionButton('Merge Selected', Icons.merge_type, provider.mergeSelected, const Color(0xFF6D28D9)),
        const SizedBox(width: 6),
        _buildActionButton('Delete Selected', Icons.delete_sweep, provider.deleteSelected, const Color(0xFFDC2626)),
      ],
    );
  }

  Widget _buildUploadModeRadio(String label, String value, Color activeColor, bool isDark) {
    return InkWell(
      onTap: () => onUploadModeChanged(value),
      child: Padding(
        padding: const EdgeInsets.only(right: 12.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Radio<String>(
                value: value,
                groupValue: globalUploadMode,
                activeColor: activeColor,
                onChanged: (val) => onUploadModeChanged(val!),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label, 
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 11)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed, Color color) => ElevatedButton.icon(
        onPressed: onPressed, 
        icon: Icon(icon, size: 14, color: Colors.white),
        label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color, 
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
}

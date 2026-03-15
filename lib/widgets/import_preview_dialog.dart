import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import '../providers/theme_provider.dart';

class ImportPreviewDialog extends StatelessWidget {
  final List<Product> products;
  final ProductProvider provider;

  const ImportPreviewDialog({
    super.key,
    required this.products,
    required this.provider,
  });

  static Future<void> show(BuildContext context, List<Product> products, ProductProvider provider) async {
    return showDialog(
      context: context,
      builder: (context) => ImportPreviewDialog(products: products, provider: provider),
    );
  }

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

    return AlertDialog(
      backgroundColor: theme.cardColor,
      title: Text(
        'Preview Import (${products.length} Items)', 
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
      ),
      content: SizedBox(
        width: 800,
        height: 500,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF111827) : Colors.grey[100]),
                    columns: const [
                      DataColumn(label: Text('SKU Platform', style: TextStyle(color: Colors.grey, fontSize: 12))),
                      DataColumn(label: Text('ID SKU', style: TextStyle(color: Colors.grey, fontSize: 12))),
                      DataColumn(label: Text('No Pesanan', style: TextStyle(color: Colors.grey, fontSize: 12))),
                      DataColumn(label: Text('Nomor Resi', style: TextStyle(color: Colors.grey, fontSize: 12))),
                      DataColumn(label: Text('Qty', style: TextStyle(color: Colors.grey, fontSize: 12))),
                    ],
                    rows: products.take(100).map((p) => DataRow(
                      cells: [
                        DataCell(Text(p.skuPlatform, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 11))),
                        DataCell(Text(p.idSku, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 11))),
                        DataCell(Text(p.noPesanan, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 11))),
                        DataCell(Text(p.nomorResi, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 11))),
                        DataCell(Text(p.jumlahBarang.toString(), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 11))),
                      ],
                    )).toList(),
                  ),
                ),
              ),
            ),
            if (products.length > 100)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  '* Showing first 100 items only', 
                  style: TextStyle(color: Colors.grey, fontSize: 10, fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
          onPressed: () {
            provider.importProducts(products);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Berhasil mengimpor ${products.length} produk.'), 
                backgroundColor: Colors.green,
              ),
            );
          },
          child: const Text('Import Sekarang', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

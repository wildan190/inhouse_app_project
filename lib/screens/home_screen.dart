import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../models/product.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductProvider>(context, listen: false).fetchProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);

    return Scaffold(
      backgroundColor: Color(0xFF101827),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Product Export Management',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Text('Home > ', style: TextStyle(color: Colors.grey)),
                    Text('Product Export Management', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ],
            ),
            SizedBox(height: 32),
            
            // Toolbar
            Row(
              children: [
                Text(
                  'Product List',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                ),
                SizedBox(width: 12),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${productProvider.products.length} Total',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
                if (productProvider.selectedOrderNumbers.isNotEmpty) ...[
                  SizedBox(width: 12),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(0xFF6D28D9).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Color(0xFF6D28D9)),
                    ),
                    child: Text(
                      '${productProvider.selectedOrderNumbers.length} Orders (${productProvider.selectedItemsCount} Items) Selected',
                      style: TextStyle(color: Color(0xFFA78BFA), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                Spacer(),
                _buildActionButton('Import Excel', Icons.upload_file, () async {
                  try {
                    await productProvider.importExcel();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error importing Excel: $e')),
                      );
                    }
                  }
                }, Color(0xFF374151)),
                SizedBox(width: 8),
                _buildActionButton('Save All Merged', Icons.save_alt, productProvider.saveAllMerged, Color(0xFF059669)),
                SizedBox(width: 8),
                _buildActionButton('Merge Selected', Icons.merge_type, productProvider.mergeSelected, Color(0xFF6D28D9)),
                SizedBox(width: 8),
                _buildActionButton('Delete Selected', Icons.delete_sweep, productProvider.deleteSelected, Color(0xFFDC2626)),
              ],
            ),
            SizedBox(height: 16),

            // Progress Bar
            if (productProvider.isLoading)
              Container(
                margin: EdgeInsets.only(bottom: 16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          productProvider.progress > 0 ? 'Processing Images...' : 'Working...',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${(productProvider.progress * 100).toInt()}%',
                          style: TextStyle(color: Color(0xFF6D28D9), fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: productProvider.progress.clamp(0.0, 1.0),
                        backgroundColor: Color(0xFF111827),
                        color: Color(0xFF6D28D9),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),

            // Table Header & Content with Horizontal Scroll
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    width: 1600, // Fixed width for horizontal scroll
                    child: Column(
                      children: [
                        // Table Header
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Color(0xFF1F2937),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: productProvider.orderNumbers.isNotEmpty && 
                                       productProvider.selectedOrderNumbers.length == productProvider.orderNumbers.length,
                                onChanged: (v) => productProvider.toggleAllSelection(v ?? false),
                                checkColor: Colors.white,
                                activeColor: Color(0xFF6D28D9),
                              ),
                              SizedBox(width: 12),
                              _buildTableHeader('PRODUCT INFORMATION', 4),
                              SizedBox(width: 20),
                              _buildTableHeader('UNGGAH GAMBAR', 2),
                              SizedBox(width: 20),
                              _buildTableHeader('ORDER NUMBER', 3),
                              SizedBox(width: 20),
                              _buildTableHeader('NOMOR RESI', 3), // New Column
                              SizedBox(width: 20),
                              _buildTableHeader('QTY', 1), // New Column
                              SizedBox(width: 20),
                              _buildTableHeader('TIME', 2),
                              SizedBox(width: 20),
                              _buildTableHeader('MERGED IMAGE', 2),
                              SizedBox(width: 20),
                              _buildTableHeader('STATE', 2),
                              SizedBox(width: 20),
                              _buildTableHeader('OPERATE', 2),
                            ],
                          ),
                        ),

                        // Table Content
                        Expanded(
                          child: ListView.builder(
                            itemCount: productProvider.paginatedOrderNumbers.length,
                            itemBuilder: (context, index) {
                              final orderNumber = productProvider.paginatedOrderNumbers[index];
                              final products = productProvider.groupedProducts[orderNumber] ?? [];
                              return _buildOrderGroup(orderNumber, products, productProvider);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Pagination Controls
            _buildPaginationControls(productProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderGroup(String orderNumber, List<Product> products, ProductProvider provider) {
    final isSelected = provider.selectedOrderNumbers.contains(orderNumber);

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? Color(0xFF1F2937).withOpacity(0.5) : Color(0xFF111827),
        border: Border.all(color: Color(0xFF1F2937)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Color(0xFF1F2937).withOpacity(0.3),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (v) => provider.toggleOrderSelection(orderNumber),
                  checkColor: Colors.white,
                  activeColor: Color(0xFF6D28D9),
                ),
                SizedBox(width: 12),
                Text('Order: $orderNumber', style: TextStyle(color: Color(0xFFA78BFA), fontWeight: FontWeight.bold)),
                SizedBox(width: 12),
                Text('(${products.length} Items)', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          ...products.map((product) => _buildProductRow(product, provider)),
        ],
      ),
    );
  }

  Widget _buildProductRow(Product product, ProductProvider provider) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF1F2937).withOpacity(0.5)))),
      child: Row(
        children: [
          SizedBox(width: 48),
          // Product Info
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  width: 80, // Increased size
                  height: 80,
                  decoration: BoxDecoration(
                    color: Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Color(0xFF374151)),
                  ),
                  child: product.tautanGambarProduk.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: CachedNetworkImage(
                            imageUrl: product.tautanGambarProduk,
                            fit: BoxFit.cover,
                            memCacheWidth: 160,
                            placeholder: (context, url) => SpinKitPulse(color: Colors.grey, size: 20),
                            errorWidget: (context, url, error) => Icon(Icons.image, color: Colors.grey),
                          ),
                        )
                      : Icon(Icons.image, color: Colors.grey),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(product.skuPlatform, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      SizedBox(height: 4),
                      Text('Option: ${product.spesifikasiProduk}', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 20),

          // Upload Image
          Expanded(
            flex: 2,
            child: Center( // Center to keep it square
              child: InkWell(
                onTap: () async {
                  try {
                    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
                    if (result != null && result.files.single.path != null) {
                      await provider.updateProductImage(product, File(result.files.single.path!));
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Color(0xFF111827),
                    border: Border.all(color: Color(0xFF374151)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: product.localImagePath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.file(File(product.localImagePath!), fit: BoxFit.cover, cacheWidth: 160),
                        )
                      : Icon(Icons.add, color: Colors.grey),
                ),
              ),
            ),
          ),
          SizedBox(width: 20),

          // Order Number
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(product.noPesanan, style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Color(0xFF6D28D9), borderRadius: BorderRadius.circular(4)),
                  child: Text('BOOK', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          SizedBox(width: 20),

          // Nomor Resi
          Expanded(
            flex: 3,
            child: Text(
              product.nomorResi,
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          SizedBox(width: 20),

          // Qty
          Expanded(
            flex: 1,
            child: Text(
              product.jumlahBarang.toString(),
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(width: 20),

          // Time
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                product.createdAt != null ? product.createdAt.toString().split('.')[0].replaceAll(' ', '\n') : '-', 
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ),
          SizedBox(width: 20),

          // Merged Image
          Expanded(
            flex: 2,
            child: Center( // Center to keep it square
              child: product.mergedImagePath != null
                  ? InkWell(
                      onTap: () async {
                        final file = File(product.mergedImagePath!);
                        if (await file.exists()) {
                          final uri = Uri.file(product.mergedImagePath!);
                          if (await canLaunchUrl(uri)) await launchUrl(uri);
                        }
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Color(0xFF111827),
                          border: Border.all(color: Colors.white.withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.file(File(product.mergedImagePath!), fit: BoxFit.cover, cacheWidth: 160),
                        ),
                      ),
                    )
                  : Text('PENDING', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          ),
          SizedBox(width: 20),
          Expanded(flex: 2, child: Text((product.status ?? 'PENDING').toUpperCase(), style: TextStyle(color: Colors.white, fontSize: 12))),
          SizedBox(width: 20),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton(onPressed: () => provider.mergeProduct(product), child: Text('MERGE', style: TextStyle(color: Colors.blue, fontSize: 12)), style: TextButton.styleFrom(padding: EdgeInsets.zero)),
                TextButton(onPressed: () => provider.deleteProduct(product.id!), child: Text('DELETE', style: TextStyle(color: Colors.red, fontSize: 12)), style: TextButton.styleFrom(padding: EdgeInsets.zero)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls(ProductProvider provider) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(color: Color(0xFF1F2937), borderRadius: BorderRadius.vertical(bottom: Radius.circular(8))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text('Orders per page:', style: TextStyle(color: Colors.grey, fontSize: 13)),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(color: Color(0xFF111827), borderRadius: BorderRadius.circular(4)),
                child: DropdownButton<int>(
                  value: provider.pageSize,
                  dropdownColor: Color(0xFF1F2937),
                  underline: SizedBox(),
                  items: [10, 25, 50, 100].map((int value) => DropdownMenuItem<int>(value: value, child: Text(value.toString(), style: TextStyle(color: Colors.white, fontSize: 13)))).toList(),
                  onChanged: (v) => provider.setPageSize(v ?? 10),
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(icon: Icon(Icons.chevron_left, color: provider.currentPage > 1 ? Colors.white : Colors.grey), onPressed: provider.currentPage > 1 ? () => provider.setPage(provider.currentPage - 1) : null),
              Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Color(0xFF6D28D9), borderRadius: BorderRadius.circular(4)), child: Text('${provider.currentPage} / ${provider.totalPages == 0 ? 1 : provider.totalPages}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              IconButton(icon: Icon(Icons.chevron_right, color: provider.currentPage < provider.totalPages ? Colors.white : Colors.grey), onPressed: provider.currentPage < provider.totalPages ? () => provider.setPage(provider.currentPage + 1) : null),
            ],
          ),
          Text('Showing ${(provider.currentPage - 1) * provider.pageSize + 1} to ${((provider.currentPage - 1) * provider.pageSize + provider.paginatedOrderNumbers.length)} of ${provider.orderNumbers.length} orders', style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String title, int flex) => Expanded(flex: flex, child: Text(title, style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)));

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed, Color color) => ElevatedButton.icon(onPressed: onPressed, icon: Icon(icon, size: 16, color: Colors.white), label: Text(label, style: TextStyle(color: Colors.white, fontSize: 13)), style: ElevatedButton.styleFrom(backgroundColor: color, padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))));
}

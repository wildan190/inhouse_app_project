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
  final ScrollController _horizontalController = ScrollController();

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductProvider>(context, listen: false).fetchProducts();
    });
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);

    return Scaffold(
      backgroundColor: Color(0xFF101827),
      body: Padding(
        padding: const EdgeInsets.all(16.0), // Reduced from 24
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toolbar
            Row(
              children: [
                Text(
                  'Product List',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600), // Reduced from 20
                ),
                SizedBox(width: 8), // Reduced from 12
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2), // Reduced
                  decoration: BoxDecoration(
                    color: Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${productProvider.products.length} Total',
                    style: TextStyle(color: Colors.grey, fontSize: 11), // Reduced from 12
                  ),
                ),
                if (productProvider.selectedOrderNumbers.isNotEmpty) ...[
                  SizedBox(width: 8), // Reduced from 12
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2), // Reduced
                    decoration: BoxDecoration(
                      color: Color(0xFF6D28D9).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Color(0xFF6D28D9)),
                    ),
                    child: Text(
                      '${productProvider.selectedOrderNumbers.length} Orders (${productProvider.selectedItemsCount} Items) Selected',
                      style: TextStyle(color: Color(0xFFA78BFA), fontSize: 11, fontWeight: FontWeight.bold), // Reduced from 12
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
                SizedBox(width: 6),
                _buildActionButton('Upload by SKU', Icons.collections, () async {
                  if (productProvider.products.isEmpty) return;
                  
                  // Show a simple dialog to pick SKU
                  final skus = productProvider.products.map((p) => p.skuPlatform).toSet().toList();
                  String? selectedSku = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Color(0xFF1F2937),
                      title: Text('Select SKU Platform', style: TextStyle(color: Colors.white, fontSize: 16)),
                      content: Container(
                        width: 300,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: skus.length,
                          itemBuilder: (context, index) => ListTile(
                            title: Text(skus[index], style: TextStyle(color: Colors.white, fontSize: 13)),
                            onTap: () => Navigator.pop(context, skus[index]),
                          ),
                        ),
                      ),
                    ),
                  );

                  if (selectedSku != null) {
                    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
                    if (result != null && result.files.single.path != null) {
                      await productProvider.updateImageBySku(selectedSku, File(result.files.single.path!));
                    }
                  }
                }, Color(0xFF4B5563)),
                SizedBox(width: 6),
                _buildActionButton('Upload by ID SKU', Icons.perm_identity, () async {
                  if (productProvider.products.isEmpty) return;
                  
                  final idSkus = productProvider.products.map((p) => p.idSku).toSet().toList();
                  String? selectedIdSku = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Color(0xFF1F2937),
                      title: Text('Select ID SKU', style: TextStyle(color: Colors.white, fontSize: 16)),
                      content: Container(
                        width: 300,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: idSkus.length,
                          itemBuilder: (context, index) => ListTile(
                            title: Text(idSkus[index], style: TextStyle(color: Colors.white, fontSize: 13)),
                            onTap: () => Navigator.pop(context, idSkus[index]),
                          ),
                        ),
                      ),
                    ),
                  );

                  if (selectedIdSku != null) {
                    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
                    if (result != null && result.files.single.path != null) {
                      await productProvider.updateImageBySku(selectedIdSku, File(result.files.single.path!), isIdSku: true);
                    }
                  }
                }, Color(0xFF4B5563)),
                SizedBox(width: 6),
                _buildActionButton('List Processed', Icons.playlist_add_check, productProvider.refreshProcessedList, Color(0xFF4B5563)),
                SizedBox(width: 6), // Reduced from 8
                _buildActionButton('Save All Merged', Icons.save_alt, () async {
                   final success = await productProvider.saveAllMerged();
                   if (!success && mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(
                         content: Text('Gagal menyimpan: Pastikan SEMUA baris data telah diunggah gambarnya dan diproses merge.'),
                         backgroundColor: Colors.redAccent,
                       ),
                     );
                   } else if (success && mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(
                         content: Text('Semua gambar (${productProvider.products.length} file) berhasil disimpan.'),
                         backgroundColor: Colors.green,
                       ),
                     );
                   }
                 }, Color(0xFF059669)),
                SizedBox(width: 6), // Reduced from 8
                _buildActionButton('Merge Selected', Icons.merge_type, productProvider.mergeSelected, Color(0xFF6D28D9)),
                SizedBox(width: 6), // Reduced from 8
                _buildActionButton('Delete Selected', Icons.delete_sweep, productProvider.deleteSelected, Color(0xFFDC2626)),
              ],
            ),
            SizedBox(height: 12), // Reduced from 16

            // Progress Bar
            if (productProvider.isLoading)
              Container(
                margin: EdgeInsets.only(bottom: 12), // Reduced from 16
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Reduced
                decoration: BoxDecoration(
                  color: Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              productProvider.progress > 0 ? 'Processing Images...' : 'Working...',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), // Reduced
                            ),
                            if (productProvider.isProcessing)
                              Text(
                                'Time elapsed: ${_formatDuration(productProvider.processingDuration)}',
                                style: TextStyle(color: Colors.grey, fontSize: 11), // Reduced from 12
                              ),
                          ],
                        ),
                        Text(
                          '${(productProvider.progress * 100).toInt()}%',
                          style: TextStyle(color: Color(0xFF6D28D9), fontWeight: FontWeight.w900, fontSize: 13), // Reduced
                        ),
                      ],
                    ),
                    SizedBox(height: 8), // Reduced from 12
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4), // Reduced from 6
                      child: LinearProgressIndicator(
                        value: productProvider.progress.clamp(0.0, 1.0),
                        backgroundColor: Color(0xFF111827),
                        color: Color(0xFF6D28D9),
                        minHeight: 6, // Reduced from 8
                      ),
                    ),
                  ],
                ),
              ),
            
            // Last processing time summary (if not loading)
            if (!productProvider.isLoading && productProvider.processingDuration > Duration.zero)
              Container(
                margin: EdgeInsets.only(bottom: 12), // Reduced from 16
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Reduced
                decoration: BoxDecoration(
                  color: Color(0xFF059669).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFF059669).withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer, color: Color(0xFF10B981), size: 14), // Reduced from 16
                    SizedBox(width: 6), // Reduced from 8
                    Text(
                      'Last processing completed in: ${_formatDuration(productProvider.processingDuration)}',
                      style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold), // Reduced from 13
                    ),
                  ],
                ),
              ),

            // Table Content Area with Sidebar
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Table
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        Expanded(
                          child: Scrollbar(
                            controller: _horizontalController,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: _horizontalController,
                              scrollDirection: Axis.horizontal,
                              child: Container(
                                width: 1400,
                                child: Column(
                                  children: [
                                    // Table Header
                                    Container(
                                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: Color(0xFF1F2937),
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                                      ),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            height: 24, width: 24,
                                            child: Checkbox(
                                              value: productProvider.orderNumbers.isNotEmpty && 
                                                     productProvider.selectedOrderNumbers.length == productProvider.orderNumbers.length,
                                              onChanged: (v) => productProvider.toggleAllSelection(v ?? false),
                                              checkColor: Colors.white,
                                              activeColor: Color(0xFF6D28D9),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          _buildTableHeader('PRODUCT INFORMATION', 4),
                                          SizedBox(width: 16),
                                          _buildTableHeader('UNGGAH GAMBAR', 2),
                                          SizedBox(width: 16),
                                          _buildTableHeader('MERGED IMAGE', 2),
                                          SizedBox(width: 16),
                                          _buildTableHeader('ORDER NUMBER', 3),
                                          SizedBox(width: 16),
                                          _buildTableHeader('NOMOR RESI', 3),
                                          SizedBox(width: 16),
                                          _buildTableHeader('QTY', 1),
                                          SizedBox(width: 16),
                                          _buildTableHeader('TIME', 2),
                                          SizedBox(width: 16),
                                          _buildTableHeader('STATE', 2),
                                          SizedBox(width: 16),
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
                        // Pagination Controls below table
                        _buildPaginationControls(productProvider),
                      ],
                    ),
                  ),

                  // Sidebar for Processed Orders (only visible when there's space)
                  if (MediaQuery.of(context).size.width > 1200)
                    Container(
                      width: 250,
                      margin: EdgeInsets.only(left: 16),
                      decoration: BoxDecoration(
                        color: Color(0xFF1F2937),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Color(0xFF374151)),
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
                                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.refresh, color: Colors.blue, size: 18),
                                        onPressed: () => productProvider.refreshProcessedList(),
                                        padding: EdgeInsets.zero,
                                        constraints: BoxConstraints(),
                                        tooltip: 'Refresh list',
                                      ),
                                      if (productProvider.processedOrderNumbers.isNotEmpty) ...[
                                        SizedBox(width: 8),
                                        IconButton(
                                          icon: Icon(Icons.delete_sweep, color: Colors.red, size: 18),
                                          onPressed: () => productProvider.clearProcessedOrders(),
                                          padding: EdgeInsets.zero,
                                          constraints: BoxConstraints(),
                                          tooltip: 'Clear list',
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                            ),
                          ),
                          Divider(color: Color(0xFF374151), height: 1),
                          Expanded(
                            child: productProvider.processedOrderNumbers.isEmpty
                                ? Center(
                                    child: Text(
                                      'No orders processed yet',
                                      style: TextStyle(color: Colors.grey, fontSize: 12),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: EdgeInsets.all(8),
                                    itemCount: productProvider.processedOrderNumbers.length,
                                    separatorBuilder: (context, index) => SizedBox(height: 4),
                                    itemBuilder: (context, index) {
                                      final orderNo = productProvider.processedOrderNumbers[index];
                                      return Container(
                                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Color(0xFF059669).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Color(0xFF059669).withOpacity(0.3)),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.check_circle, color: Color(0xFF10B981), size: 14),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                orderNo,
                                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                              ),
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.download, color: Colors.blue, size: 16),
                                              onPressed: () async {
                                                final success = await productProvider.exportOrderByNumber(orderNo);
                                                if (success && mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Order $orderNo berhasil di-export.'),
                                                      backgroundColor: Colors.green,
                                                      duration: Duration(seconds: 2),
                                                    ),
                                                  );
                                                } else if (!success && mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Gagal export: File tidak ditemukan atau belum di-merge.'),
                                                      backgroundColor: Colors.redAccent,
                                                    ),
                                                  );
                                                }
                                              },
                                              padding: EdgeInsets.zero,
                                              constraints: BoxConstraints(),
                                              tooltip: 'Export this order',
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderGroup(String orderNumber, List<Product> products, ProductProvider provider) {
    final isSelected = provider.selectedOrderNumbers.contains(orderNumber);

    return Container(
      margin: EdgeInsets.only(bottom: 6), // Reduced from 8
      decoration: BoxDecoration(
        color: isSelected ? Color(0xFF1F2937).withOpacity(0.5) : Color(0xFF111827),
        border: Border.all(color: Color(0xFF1F2937)),
        borderRadius: BorderRadius.circular(6), // Reduced from 8
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 6, horizontal: 12), // Reduced
            decoration: BoxDecoration(
              color: Color(0xFF1F2937).withOpacity(0.3),
              borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
            ),
            child: Row(
              children: [
                SizedBox(
                  height: 24, width: 24,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (v) => provider.toggleOrderSelection(orderNumber),
                    checkColor: Colors.white,
                    activeColor: Color(0xFF6D28D9),
                  ),
                ),
                SizedBox(width: 8),
                Text('Order: $orderNumber', style: TextStyle(color: Color(0xFFA78BFA), fontWeight: FontWeight.bold, fontSize: 13)), // Reduced
                SizedBox(width: 8),
                Text('(${products.length} Items)', style: TextStyle(color: Colors.grey, fontSize: 11)), // Reduced
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
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12), // Reduced from 12v, 16h
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF1F2937).withOpacity(0.5)))),
      child: Row(
        children: [
          SizedBox(width: 32), // Reduced from 48
          // Product Info
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  width: 60, // Reduced from 80
                  height: 60,
                  decoration: BoxDecoration(
                    color: Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(6), // Reduced
                    border: Border.all(color: Color(0xFF374151)),
                  ),
                  child: product.tautanGambarProduk.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: CachedNetworkImage(
                            imageUrl: product.tautanGambarProduk,
                            fit: BoxFit.cover,
                            memCacheWidth: 120, // Reduced cache size
                            placeholder: (context, url) => SpinKitPulse(color: Colors.grey, size: 16),
                            errorWidget: (context, url, error) => Icon(Icons.image, color: Colors.grey, size: 20),
                          ),
                        )
                      : Icon(Icons.image, color: Colors.grey, size: 20),
                ),
                SizedBox(width: 12), // Reduced from 16
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(product.skuPlatform, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)), // Reduced from 14
                      SizedBox(height: 2),
                      Text('SKU: ${product.idSku}', style: TextStyle(color: Color(0xFFA78BFA), fontSize: 11, fontWeight: FontWeight.w500)), // Reduced from 12
                      SizedBox(height: 1),
                      Text('Option: ${product.spesifikasiProduk}', style: TextStyle(color: Colors.grey, fontSize: 11)), // Reduced from 12
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16), // Reduced from 20

          // Upload Image
          Expanded(
            flex: 2,
            child: Center(
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
                  width: 60, // Reduced from 80
                  height: 60,
                  decoration: BoxDecoration(
                    color: Color(0xFF111827),
                    border: Border.all(color: Color(0xFF374151)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: product.localImagePath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Image.file(File(product.localImagePath!), fit: BoxFit.cover, cacheWidth: 120),
                        )
                      : Icon(Icons.add, color: Colors.grey, size: 20),
                ),
              ),
            ),
          ),
          SizedBox(width: 16),

          // Merged Image
          Expanded(
            flex: 2,
            child: Center(
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
                        width: 60, // Reduced from 80
                        height: 60,
                        decoration: BoxDecoration(
                          color: Color(0xFF111827),
                          border: Border.all(color: Colors.white.withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Image.file(File(product.mergedImagePath!), fit: BoxFit.cover, cacheWidth: 120),
                        ),
                      ),
                    )
                  : Text('PENDING', style: TextStyle(color: Colors.grey, fontSize: 11)),
            ),
          ),
          SizedBox(width: 16),

          // Order Number
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(product.noPesanan, style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)), // Reduced from 14
                SizedBox(height: 2),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Color(0xFF6D28D9), borderRadius: BorderRadius.circular(4)),
                  child: Text('BOOK', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)), // Reduced from 11
                ),
              ],
            ),
          ),
          SizedBox(width: 16),

          // Nomor Resi
          Expanded(
            flex: 3,
            child: Text(
              product.nomorResi,
              style: TextStyle(color: Colors.white, fontSize: 12), // Reduced from 13
            ),
          ),
          SizedBox(width: 16),

          // Qty
          Expanded(
            flex: 1,
            child: Text(
              product.jumlahBarang.toString(),
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), // Reduced from 13
            ),
          ),
          SizedBox(width: 16),

          // Time
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                product.createdAt != null ? product.createdAt.toString().split('.')[0].replaceAll(' ', '\n') : '-', 
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 11), // Reduced from 12
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(flex: 2, child: Text((product.status ?? 'PENDING').toUpperCase(), style: TextStyle(color: Colors.white, fontSize: 11))), // Reduced
          SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => provider.mergeProduct(product), 
                  child: Text('MERGE', style: TextStyle(color: Colors.blue, fontSize: 11)), // Reduced from 12
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size(0, 24), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                ),
                TextButton(
                  onPressed: () => provider.deleteProduct(product.id!), 
                  child: Text('DELETE', style: TextStyle(color: Colors.red, fontSize: 11)), // Reduced from 12
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size(0, 24), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls(ProductProvider provider) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12), // Reduced from 16
      decoration: BoxDecoration(color: Color(0xFF1F2937), borderRadius: BorderRadius.vertical(bottom: Radius.circular(6))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text('Orders per page:', style: TextStyle(color: Colors.grey, fontSize: 11)), // Reduced from 13
              SizedBox(width: 6),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(color: Color(0xFF111827), borderRadius: BorderRadius.circular(4)),
                child: DropdownButton<int>(
                  value: provider.pageSize,
                  dropdownColor: Color(0xFF1F2937),
                  underline: SizedBox(),
                  isDense: true, // More compact
                  items: [10, 25, 50, 100, 300, 500].map((int value) => DropdownMenuItem<int>(value: value, child: Text(value.toString(), style: TextStyle(color: Colors.white, fontSize: 11)))).toList(),
                  onChanged: (v) => provider.setPageSize(v ?? 10),
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                iconSize: 20, // Reduced from default
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
                icon: Icon(Icons.chevron_left, color: provider.currentPage > 1 ? Colors.white : Colors.grey), 
                onPressed: provider.currentPage > 1 ? () => provider.setPage(provider.currentPage - 1) : null
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                decoration: BoxDecoration(color: Color(0xFF6D28D9), borderRadius: BorderRadius.circular(4)), 
                child: Text('${provider.currentPage} / ${provider.totalPages == 0 ? 1 : provider.totalPages}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))
              ),
              SizedBox(width: 8),
              IconButton(
                iconSize: 20, // Reduced
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
                icon: Icon(Icons.chevron_right, color: provider.currentPage < provider.totalPages ? Colors.white : Colors.grey), 
                onPressed: provider.currentPage < provider.totalPages ? () => provider.setPage(provider.currentPage + 1) : null
              ),
            ],
          ),
          Text(
            'Showing ${(provider.currentPage - 1) * provider.pageSize + 1} to ${((provider.currentPage - 1) * provider.pageSize + provider.paginatedOrderNumbers.length)} of ${provider.orderNumbers.length} orders', 
            style: TextStyle(color: Colors.grey, fontSize: 11) // Reduced from 13
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String title, int flex) => Expanded(flex: flex, child: Text(title, style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)));

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed, Color color) => ElevatedButton.icon(
        onPressed: onPressed, 
        icon: Icon(icon, size: 14, color: Colors.white), // Reduced from 16
        label: Text(label, style: TextStyle(color: Colors.white, fontSize: 11)), // Reduced from 13
        style: ElevatedButton.styleFrom(
          backgroundColor: color, 
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Reduced from 16, 12
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          minimumSize: Size(0, 32), // More compact height
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
}

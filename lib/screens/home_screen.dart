import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';
import '../providers/product_provider.dart';
import '../models/product.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _horizontalController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _processedOrdersController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _mainFocusNode = FocusNode(); // Focus node for the whole screen
  int? _draggingProductId;
  String _globalUploadMode = 'single';
  bool _isSearchVisible = false;

  Future<void> _handleImageUpload(Product product, File imageFile, ProductProvider provider) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploading in mode: ${_globalUploadMode.toUpperCase()}'),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.blueGrey,
          ),
        );
      }
      await provider.updateProductImage(product, imageFile, syncMode: _globalUploadMode);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showImportPreview(List<Product> products, ProductProvider provider) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: Text('Preview Import (${products.length} Items)', style: const TextStyle(color: Colors.white, fontSize: 16)),
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
                      headingRowColor: WidgetStateProperty.all(const Color(0xFF111827)),
                      columns: const [
                        DataColumn(label: Text('SKU Platform', style: TextStyle(color: Colors.grey, fontSize: 12))),
                        DataColumn(label: Text('ID SKU', style: TextStyle(color: Colors.grey, fontSize: 12))),
                        DataColumn(label: Text('No Pesanan', style: TextStyle(color: Colors.grey, fontSize: 12))),
                        DataColumn(label: Text('Nomor Resi', style: TextStyle(color: Colors.grey, fontSize: 12))),
                        DataColumn(label: Text('Qty', style: TextStyle(color: Colors.grey, fontSize: 12))),
                      ],
                      rows: products.take(100).map((p) => DataRow(
                        cells: [
                          DataCell(Text(p.skuPlatform, style: const TextStyle(color: Colors.white, fontSize: 11))),
                          DataCell(Text(p.idSku, style: const TextStyle(color: Colors.white, fontSize: 11))),
                          DataCell(Text(p.noPesanan, style: const TextStyle(color: Colors.white, fontSize: 11))),
                          DataCell(Text(p.nomorResi, style: const TextStyle(color: Colors.white, fontSize: 11))),
                          DataCell(Text(p.jumlahBarang.toString(), style: const TextStyle(color: Colors.white, fontSize: 11))),
                        ],
                      )).toList(),
                    ),
                  ),
                ),
              ),
              if (products.length > 100)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text('* Showing first 100 items only', style: TextStyle(color: Colors.grey, fontSize: 10, fontStyle: FontStyle.italic)),
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
                SnackBar(content: Text('Berhasil mengimpor ${products.length} produk.'), backgroundColor: Colors.green),
              );
            },
            child: const Text('Import Sekarang', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _searchController.dispose();
    _processedOrdersController.dispose();
    _searchFocusNode.dispose();
    _mainFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);

    final newProcessedText = productProvider.processedOrderNumbers.join('\n');
    if (_processedOrdersController.text != newProcessedText) {
      _processedOrdersController.text = newProcessedText;
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          setState(() => _isSearchVisible = true);
          Future.delayed(const Duration(milliseconds: 50), () {
            _searchFocusNode.requestFocus();
            _searchController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _searchController.text.length,
            );
          });
        },
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () {
          setState(() => _isSearchVisible = true);
          Future.delayed(const Duration(milliseconds: 50), () {
            _searchFocusNode.requestFocus();
            _searchController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _searchController.text.length,
            );
          });
        },
      },
      child: Focus(
        focusNode: _mainFocusNode,
        autofocus: true,
        child: Scaffold(
          backgroundColor: const Color(0xFF101827),
          body: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Product List',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2937),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${productProvider.products.length} Total',
                            style: const TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ),
                        if (productProvider.selectedOrderNumbers.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6D28D9).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF6D28D9)),
                            ),
                            child: Text(
                              '${productProvider.selectedOrderNumbers.length} Orders (${productProvider.selectedItemsCount} Items) Selected',
                              style: const TextStyle(color: Color(0xFFA78BFA), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                        const SizedBox(width: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2937).withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF374151)),
                          ),
                          child: Row(
                            children: [
                              const Text('Upload Rule:', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 12),
                              _buildUploadModeRadio('Single', 'single', Colors.blue),
                              _buildUploadModeRadio('SKU Platform', 'sku', Colors.purple),
                              _buildUploadModeRadio('ID SKU', 'id_sku', Colors.orange),
                            ],
                          ),
                        ),
                        const Spacer(),
                        _buildActionButton('Import Data', Icons.upload_file, () async {
                          try {
                            final file = await productProvider.pickImportFile();
                            if (file != null) {
                              final products = await productProvider.parseImportFile(file);
                              if (products != null && products.isNotEmpty) {
                                await _showImportPreview(products, productProvider);
                              } else if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('File kosong atau format tidak didukung.'), backgroundColor: Colors.orange),
                                );
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        }, const Color(0xFF374151)),
                        const SizedBox(width: 6),
                        _buildActionButton('List Processed', Icons.playlist_add_check, productProvider.refreshProcessedList, const Color(0xFF4B5563)),
                        const SizedBox(width: 6),
                        _buildActionButton('Save Selected Merged', Icons.save_alt, () async {
                          final success = await productProvider.saveSelectedMerged();
                          if (!success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Gagal menyimpan: Pastikan SEMUA baris pada pesanan yang dipilih telah diunggah gambarnya dan diproses merge.'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          } else if (success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Berhasil menyimpan hasil merge ke folder tujuan.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }, const Color(0xFF059669)),
                        const SizedBox(width: 6),
                        _buildActionButton('Merge Selected', Icons.merge_type, productProvider.mergeSelected, const Color(0xFF6D28D9)),
                        const SizedBox(width: 6),
                        _buildActionButton('Delete Selected', Icons.delete_sweep, productProvider.deleteSelected, const Color(0xFFDC2626)),
                      ],
                    ),
                    if (productProvider.isProcessing) _buildProcessingProgress(productProvider),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: productProvider.isLoading && productProvider.products.isEmpty
                                ? const Center(child: SpinKitFadingCube(color: Color(0xFF6D28D9), size: 40))
                                : _buildProductList(productProvider),
                          ),
                          if (MediaQuery.of(context).size.width > 1200)
                            Container(
                              width: 250,
                              margin: const EdgeInsets.only(left: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1F2937),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF374151)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'PROCESSED ORDERS',
                                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.refresh, color: Colors.blue, size: 18),
                                              onPressed: () => productProvider.refreshProcessedList(),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              tooltip: 'Refresh list',
                                            ),
                                            if (productProvider.processedOrderNumbers.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: const Icon(Icons.delete_sweep, color: Colors.red, size: 18),
                                                onPressed: () => productProvider.clearProcessedOrders(),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                tooltip: 'Clear list',
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(color: Color(0xFF374151), height: 1),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: TextField(
                                        controller: _processedOrdersController,
                                        readOnly: true,
                                        maxLines: null,
                                        expands: true,
                                        style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontFamily: 'monospace'),
                                        decoration: InputDecoration(
                                          hintText: 'No orders processed yet',
                                          hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                                          filled: true,
                                          fillColor: const Color(0xFF111827),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(4),
                                            borderSide: const BorderSide(color: Color(0xFF374151)),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(4),
                                            borderSide: const BorderSide(color: Color(0xFF374151)),
                                          ),
                                          contentPadding: const EdgeInsets.all(10),
                                        ),
                                      ),
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
              if (_isSearchVisible)
                Positioned(
                  top: 10,
                  right: 20,
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFF1F2937),
                    child: Container(
                      width: 350,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF374151)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              onChanged: (value) => productProvider.setSearchQuery(value),
                              onSubmitted: (_) {
                                setState(() {
                                  _isSearchVisible = false;
                                });
                                _mainFocusNode.requestFocus();
                              },
                              autofocus: true,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: const InputDecoration(
                                hintText: 'Search... (Split by comma)',
                                hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                                prefixIcon: Icon(Icons.search, color: Colors.grey, size: 18),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                            onPressed: () {
                              setState(() {
                                _isSearchVisible = false;
                                _searchController.clear();
                                productProvider.setSearchQuery('');
                              });
                              _mainFocusNode.requestFocus();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingProgress(ProductProvider provider) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF6D28D9).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const SpinKitRing(color: Color(0xFF6D28D9), size: 20, lineWidth: 2),
                  const SizedBox(width: 12),
                  const Text(
                    'Processing Merge...',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Text(
                _formatDuration(provider.processingDuration),
                style: const TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'monospace'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: provider.progress,
              backgroundColor: const Color(0xFF111827),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6D28D9)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(provider.progress * 100).toStringAsFixed(1)}%',
                style: const TextStyle(color: Color(0xFFA78BFA), fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Text(
                'Merging ${provider.selectedItemsCount} items',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  Widget _buildProductList(ProductProvider provider) {
    if (provider.orderNumbers.isEmpty) {
      return const Center(child: Text('No data available', style: TextStyle(color: Colors.grey)));
    }

    return Column(
      children: [
        _buildTableHeader(provider),
        Expanded(
          child: ListView.builder(
            itemCount: provider.paginatedOrderNumbers.length,
            itemBuilder: (context, index) {
              final orderNo = provider.paginatedOrderNumbers[index];
              final products = provider.getProductsByOrder(orderNo);
              return _buildOrderGroup(orderNo, products, provider);
            },
          ),
        ),
        _buildPagination(provider),
      ],
    );
  }

  Widget _buildTableHeader(ProductProvider provider) {
    final allSelected = provider.orderNumbers.isNotEmpty && 
                       provider.selectedOrderNumbers.length == provider.orderNumbers.length;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF374151)),
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
          const Expanded(
            flex: 5,
            child: Text('PRODUCT INFORMATION', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
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
          const Expanded(
            flex: 2,
            child: Center(
              child: Text('TIME', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
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

  Widget _buildPagination(ProductProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF1F2937)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text('Orders per page:', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF374151)),
                ),
                child: DropdownButton<int>(
                  value: provider.pageSize,
                  dropdownColor: const Color(0xFF1F2937),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 18),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  items: [10, 20, 50, 100].map((int value) {
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
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
                onPressed: provider.currentPage > 1 ? () => provider.setPage(provider.currentPage - 1) : null,
              ),
              const SizedBox(width: 8),
              Text('Page ${provider.currentPage} of ${provider.totalPages}', 
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white, size: 20),
                onPressed: provider.currentPage < provider.totalPages ? () => provider.setPage(provider.currentPage + 1) : null,
              ),
            ],
          ),
          const SizedBox(width: 100), // Spacer to balance the layout
        ],
      ),
    );
  }

  Widget _buildOrderGroup(String orderNumber, List<Product> products, ProductProvider provider) {
    final isSelected = provider.selectedOrderNumbers.contains(orderNumber);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF1F2937).withValues(alpha: 0.5) : const Color(0xFF111827),
        border: Border.all(color: const Color(0xFF1F2937)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937).withValues(alpha: 0.3),
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
                SelectableText('Order: $orderNumber', style: const TextStyle(color: Color(0xFFA78BFA), fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 8),
                SelectableText('(${products.length} Items)', style: const TextStyle(color: Colors.grey, fontSize: 11)),
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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: const Color(0xFF1F2937).withValues(alpha: 0.5)))),
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
                    color: const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF374151)),
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
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
                    await _handleImageUpload(product, file, provider);
                  }
                },
                onDragEntered: (detail) {
                  setState(() {
                    _draggingProductId = product.id;
                  });
                },
                onDragExited: (detail) {
                  setState(() {
                    _draggingProductId = null;
                  });
                },
                child: InkWell(
                  onTap: () async {
                    try {
                      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
                      if (result != null && result.files.single.path != null) {
                        File imageFile = File(result.files.single.path!);
                        await _handleImageUpload(product, imageFile, provider);
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
                      color: _draggingProductId == product.id ? const Color(0xFF374151) : const Color(0xFF111827),
                      border: Border.all(
                        color: _draggingProductId == product.id ? const Color(0xFFA78BFA) : const Color(0xFF374151),
                        width: _draggingProductId == product.id ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: product.localImagePath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Image.file(File(product.localImagePath!), fit: BoxFit.cover, cacheWidth: 120),
                          )
                        : Icon(
                            _draggingProductId == product.id ? Icons.file_upload : Icons.add,
                            color: _draggingProductId == product.id ? const Color(0xFFA78BFA) : Colors.grey,
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

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending': return Colors.grey;
      case 'image_uploaded': return Colors.blue;
      case 'completed': return Colors.green;
      case 'error': return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _buildUploadModeRadio(String label, String value, Color activeColor) {
    return InkWell(
      onTap: () => setState(() => _globalUploadMode = value),
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
                groupValue: _globalUploadMode,
                activeColor: activeColor,
                onChanged: (val) => setState(() => _globalUploadMode = val!),
              ),
            ),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
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

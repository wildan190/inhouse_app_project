import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../providers/product_provider.dart';
import '../models/product.dart';
import '../widgets/product_row.dart';
import '../widgets/order_group.dart';
import '../widgets/table_header.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/processing_progress.dart';
import '../widgets/floating_search_bar.dart';
import '../widgets/import_preview_dialog.dart';
import '../widgets/home_sidebar.dart';
import '../widgets/home_toolbar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _processedOrdersController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _mainFocusNode = FocusNode(); 
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

  @override
  void dispose() {
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
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_isSearchVisible) {
            setState(() => _isSearchVisible = false);
            _searchController.clear();
            productProvider.setSearchQuery('');
            _mainFocusNode.requestFocus();
          }
        },
      },
      child: Focus(
        focusNode: _mainFocusNode,
        autofocus: true,
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HomeToolbar(
                      provider: productProvider,
                      searchController: _searchController,
                      globalUploadMode: _globalUploadMode,
                      onUploadModeChanged: (mode) => setState(() => _globalUploadMode = mode),
                    ),
                    if (productProvider.isProcessing) ProcessingProgress(provider: productProvider),
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
                            HomeSidebar(
                              provider: productProvider,
                              controller: _processedOrdersController,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              FloatingSearchBar(
                isVisible: _isSearchVisible,
                controller: _searchController,
                focusNode: _searchFocusNode,
                provider: productProvider,
                onClose: () {
                  setState(() => _isSearchVisible = false);
                  _searchController.clear();
                  productProvider.setSearchQuery('');
                  _mainFocusNode.requestFocus();
                },
                onSubmitted: () {
                  setState(() => _isSearchVisible = false);
                  _mainFocusNode.requestFocus();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductList(ProductProvider provider) {
    if (provider.orderNumbers.isEmpty) {
      return const Center(child: Text('No data available', style: TextStyle(color: Colors.grey)));
    }

    return Column(
      children: [
        TableHeader(provider: provider),
        Expanded(
          child: ListView.builder(
            itemCount: provider.paginatedOrderNumbers.length,
            itemBuilder: (context, index) {
              final orderNo = provider.paginatedOrderNumbers[index];
              final products = provider.getProductsByOrder(orderNo);
              return OrderGroup(
                orderNumber: orderNo,
                products: products,
                provider: provider,
                onImageUpload: (product, file) => _handleImageUpload(product, file, provider),
              );
            },
          ),
        ),
        PaginationBar(provider: provider),
      ],
    );
  }
}

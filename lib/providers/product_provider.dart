import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../models/product.dart';
import '../services/database_service.dart';
import '../services/image_service.dart';
import '../services/excel_service.dart';

class ProductProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final ImageService _imageService = ImageService();
  final ExcelService _excelService = ExcelService();

  List<Product> _products = [];
  bool _isLoading = false;
  double _progress = 0;
  Set<String> _selectedOrderNumbers = {};
  String _searchQuery = ''; // Search query state
  List<String> _searchTerms = []; // List of search terms for bulk search
  
  // Processing time tracking
  Duration _processingDuration = Duration.zero;
  bool _isProcessing = false;
  List<String> _processedOrderNumbers = [];

  // Pagination states
  int _currentPage = 1;
  int _pageSize = 10;
  Map<String, List<Product>> _groupedProducts = {};
  List<String> _orderNumbers = [];
  List<String> _paginatedOrderNumbers = [];

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  double get progress => _progress;
  Set<String> get selectedOrderNumbers => _selectedOrderNumbers;
  String get searchQuery => _searchQuery; 
  List<String> get searchTerms => _searchTerms; // Search terms getter
  Duration get processingDuration => _processingDuration;
  bool get isProcessing => _isProcessing;
  List<String> get processedOrderNumbers => _processedOrderNumbers;

  void setSearchQuery(String query) {
    _searchQuery = query;
    // Split query ONLY by comma for bulk search as requested
    _searchTerms = query
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
        
    _currentPage = 1; // Reset to first page when searching
    _updatePaginatedData();
    notifyListeners();
  }

  void clearProcessedOrders() {
    _processedOrderNumbers.clear();
    notifyListeners();
  }

  int get currentPage => _currentPage;
  int get pageSize => _pageSize;
  int get totalPages => (_orderNumbers.length / _pageSize).ceil();
  List<String> get orderNumbers => _orderNumbers;
  List<String> get paginatedOrderNumbers => _paginatedOrderNumbers;

  Map<String, List<Product>> get groupedProducts => _groupedProducts;

  List<Product> getProductsByOrder(String orderNumber) {
    return _groupedProducts[orderNumber] ?? [];
  }

  int get selectedItemsCount {
    int count = 0;
    for (var orderNo in _selectedOrderNumbers) {
      if (_groupedProducts.containsKey(orderNo)) {
        count += _groupedProducts[orderNo]!.length;
      }
    }
    return count;
  }

  ProductProvider() {
    fetchProducts();
  }

  Future<void> fetchProducts({bool updateLoading = true}) async {
    if (updateLoading) {
      _isLoading = true;
      notifyListeners();
    }
    _products = await _dbService.getProducts();
    _updatePaginatedData();
    refreshProcessedList(); // Auto-update processed list after fetching
    if (updateLoading) {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _updatePaginatedData() {
    // Group products by order number with filtering
    _groupedProducts = {};
    for (var p in _products) {
      // Bulk filter logic: match search terms against SKU, Order No, or Nomor Resi
      if (_searchTerms.isNotEmpty) {
        bool matchesTerm = false;
        for (final term in _searchTerms) {
          if (p.skuPlatform.toLowerCase().contains(term) ||
              p.idSku.toLowerCase().contains(term) ||
              p.noPesanan.toLowerCase().contains(term) ||
              p.nomorResi.toLowerCase().contains(term) ||
              p.spesifikasiProduk.toLowerCase().contains(term)) {
            matchesTerm = true;
            break; // Match found for at least one term
          }
        }
        if (!matchesTerm) continue;
      }

      if (!_groupedProducts.containsKey(p.noPesanan)) {
        _groupedProducts[p.noPesanan] = [];
      }
      _groupedProducts[p.noPesanan]!.add(p);
    }

    _orderNumbers = _groupedProducts.keys.toList();
    
    // Sort order numbers (could be by date if available)
    _orderNumbers.sort((a, b) => b.compareTo(a));

    _updateCurrentPageData();
  }

  void _updateCurrentPageData() {
    final start = (_currentPage - 1) * _pageSize;
    final end = start + _pageSize;
    
    if (start >= _orderNumbers.length) {
      _paginatedOrderNumbers = [];
    } else {
      _paginatedOrderNumbers = _orderNumbers.sublist(
        start, 
        end > _orderNumbers.length ? _orderNumbers.length : end
      );
    }
  }

  void setPage(int page) {
    _currentPage = page;
    _updateCurrentPageData();
    notifyListeners();
  }

  void setPageSize(int size) {
    _pageSize = size;
    _currentPage = 1;
    _updateCurrentPageData();
    notifyListeners();
  }

  void toggleOrderSelection(String orderNumber) {
    if (_selectedOrderNumbers.contains(orderNumber)) {
      _selectedOrderNumbers.remove(orderNumber);
    } else {
      _selectedOrderNumbers.add(orderNumber);
    }
    notifyListeners();
  }

  void toggleAllSelection(bool selected) {
    if (selected) {
      _selectedOrderNumbers = Set.from(_orderNumbers);
    } else {
      _selectedOrderNumbers.clear();
    }
    notifyListeners();
  }

  Future<File?> pickImportFile() async {
    return await _excelService.pickFile();
  }

  Future<List<Product>?> parseImportFile(File file) async {
    _isLoading = true;
    notifyListeners();
    try {
      final products = await _excelService.parseFile(file);
      return products;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> importProducts(List<Product> products) async {
    if (products.isEmpty) return;
    
    _isLoading = true;
    _progress = 0;
    notifyListeners();
    
    await _dbService.insertProductsBulk(products);
    await fetchProducts(updateLoading: false);
    
    _isLoading = false;
    notifyListeners();
  }

  Future<int> updateProductImage(Product product, File imageFile, {String syncMode = 'single'}) async {
    // Copy image to local app directory for persistence
    final db = await _dbService.database;
    final directory = Directory(p.dirname(db.path));
    final imagesDir = Directory(p.join(directory.path, 'images'));
    
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    
    final fileName = p.basename(imageFile.path);
    final localPath = p.join(imagesDir.path, fileName);
    
    File localImageFile;
    if (await File(localPath).exists()) {
      localImageFile = File(localPath);
    } else {
      localImageFile = await imageFile.copy(localPath);
    }

    _isLoading = true;
    _progress = 0.5;
    notifyListeners();

    int updatedCount = 0;

    if (syncMode == 'single') {
      final updatedProduct = Product(
        id: product.id,
        skuPlatform: product.skuPlatform,
        jumlahBarang: product.jumlahBarang,
        noPesanan: product.noPesanan,
        nomorResi: product.nomorResi,
        idProduk: product.idProduk,
        idSku: product.idSku,
        spesifikasiProduk: product.spesifikasiProduk,
        tautanGambarProduk: product.tautanGambarProduk,
        localImagePath: localImageFile.path,
        mergedImagePath: null, // Reset merged image on NEW upload
        status: 'image_uploaded',
      );
      await _dbService.updateProduct(updatedProduct);
      updatedCount = 1;
    } else if (syncMode == 'sku') {
      updatedCount = await _dbService.updateProductsImageBulk(
        localImageFile.path,
        skuPlatform: product.skuPlatform,
      );
    } else if (syncMode == 'id_sku') {
      updatedCount = await _dbService.updateProductsImageBulk(
        localImageFile.path,
        idSku: product.idSku,
      );
    }

    _progress = 0.9;
    notifyListeners();
    
    await fetchProducts(updateLoading: false);
    
    _isLoading = false;
    _progress = 0;
    notifyListeners();
    return updatedCount;
  }

  Future<void> mergeProduct(Product product, {bool silent = false}) async {
    final mergedPath = await _imageService.mergeProductImage(
      product,
      product.localImagePath != null ? File(product.localImagePath!) : null,
    );

    if (mergedPath != null) {
      final updatedProduct = Product(
        id: product.id,
        skuPlatform: product.skuPlatform,
        jumlahBarang: product.jumlahBarang,
        noPesanan: product.noPesanan,
        nomorResi: product.nomorResi,
        idProduk: product.idProduk,
        idSku: product.idSku,
        spesifikasiProduk: product.spesifikasiProduk,
        tautanGambarProduk: product.tautanGambarProduk,
        localImagePath: product.localImagePath,
        mergedImagePath: mergedPath,
        status: 'completed',
      );

      await _dbService.updateProduct(updatedProduct);
      if (!silent) {
        await fetchProducts();
      }
    }
  }

  Future<void> mergeSelected() async {
    if (_selectedOrderNumbers.isEmpty) return;
    
    _isLoading = true;
    _isProcessing = true;
    _progress = 0.01;
    _processingDuration = Duration.zero;
    notifyListeners();
    
    final stopwatch = Stopwatch()..start();
    
    List<Product> toProcess = _products.where((p) => _selectedOrderNumbers.contains(p.noPesanan)).toList();
    int total = toProcess.length;
    int completed = 0;

    const int maxConcurrent = 8;
    
    final List<Future<void>> workers = [];
    int index = 0;

    Future<void> runWorker() async {
      while (index < total) {
        final currentIdx = index++;
        if (currentIdx >= total) break;
        
        await mergeProduct(toProcess[currentIdx], silent: true);
        
        completed++;
        _progress = completed / total;
        _processingDuration = stopwatch.elapsed;
        notifyListeners();
      }
    }

    for (int i = 0; i < maxConcurrent && i < total; i++) {
      workers.add(runWorker());
    }

    await Future.wait(workers);
    stopwatch.stop();
    
    await fetchProducts(updateLoading: false);
    
    _isProcessing = false;
    _isLoading = false;
    _progress = 0;
    notifyListeners();
  }

  Future<bool> saveSelectedMerged() async {
    List<Product> toSave = _products.where((p) => 
      _selectedOrderNumbers.contains(p.noPesanan) && 
      p.status == 'completed' && 
      p.mergedImagePath != null
    ).toList();

    if (toSave.isEmpty) return false;

    final success = await _imageService.saveMergedImages(toSave);
    if (success) {
      refreshProcessedList();
    }
    return success;
  }

  void refreshProcessedList() {
    final successfulOrders = _products
        .where((p) => p.status == 'completed')
        .map((p) => p.noPesanan)
        .toSet()
        .toList();
    
    _processedOrderNumbers = successfulOrders;
    notifyListeners();
  }

  Future<void> deleteProduct(int id) async {
    await _dbService.deleteProduct(id);
    await fetchProducts();
  }

  Future<void> deleteSelected() async {
    if (_selectedOrderNumbers.isEmpty) return;
    
    _isLoading = true;
    notifyListeners();
    
    for (var orderNo in _selectedOrderNumbers) {
      final products = _groupedProducts[orderNo] ?? [];
      for (var p in products) {
        await _dbService.deleteProduct(p.id!);
      }
    }
    
    _selectedOrderNumbers.clear();
    await fetchProducts();
    
    _isLoading = false;
    notifyListeners();
  }
}

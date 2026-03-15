import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../models/product.dart';
import '../services/database_service.dart';
import '../services/image_service.dart';
import '../services/excel_service.dart';
import 'product_list_manager.dart';

class ProductProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final ImageService _imageService = ImageService();
  final ExcelService _excelService = ExcelService();
  final ProductListManager _listManager = ProductListManager();

  bool _isLoading = false;
  double _progress = 0;
  Set<String> _selectedOrderNumbers = {};
  
  // Processing time tracking
  Duration _processingDuration = Duration.zero;
  bool _isProcessing = false;
  List<String> _processedOrderNumbers = [];

  // Getters delegating to _listManager
  List<Product> get products => _listManager.products;
  String get searchQuery => _listManager.searchQuery;
  List<String> get searchTerms => _listManager.searchTerms;
  int get currentPage => _listManager.currentPage;
  int get pageSize => _listManager.pageSize;
  int get totalPages => _listManager.totalPages;
  int get totalQuantity => _listManager.totalQuantity;
  List<String> get orderNumbers => _listManager.orderNumbers;
  List<String> get paginatedOrderNumbers => _listManager.paginatedOrderNumbers;
  Map<String, List<Product>> get groupedProducts => _listManager.groupedProducts;
  String get sortColumn => _listManager.sortColumn;
  bool get isAscending => _listManager.isAscending;

  // Other Getters
  bool get isLoading => _isLoading;
  double get progress => _progress;
  Set<String> get selectedOrderNumbers => _selectedOrderNumbers;
  Duration get processingDuration => _processingDuration;
  bool get isProcessing => _isProcessing;
  List<String> get processedOrderNumbers => _processedOrderNumbers;

  int get selectedItemsCount => _listManager.calculateSelectedItemsCount(_selectedOrderNumbers);

  ProductProvider() {
    fetchProducts();
  }

  void setSort(String column) {
    if (_listManager.sortColumn == column) {
      _listManager.isAscending = !_listManager.isAscending;
    } else {
      _listManager.sortColumn = column;
      _listManager.isAscending = true;
    }
    _listManager.updatePaginatedData();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _listManager.updateSearch(query);
    _listManager.updatePaginatedData();
    notifyListeners();
  }

  void setPage(int page) {
    _listManager.currentPage = page;
    _listManager.updateCurrentPageData();
    notifyListeners();
  }

  void setPageSize(int size) {
    _listManager.pageSize = size;
    _listManager.currentPage = 1;
    _listManager.updateCurrentPageData();
    notifyListeners();
  }

  Future<void> fetchProducts({bool updateLoading = true}) async {
    if (updateLoading) {
      _isLoading = true;
      notifyListeners();
    }
    _listManager.products = await _dbService.getProducts();
    _listManager.updatePaginatedData();
    refreshProcessedList();
    if (updateLoading) {
      _isLoading = false;
      notifyListeners();
    }
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
      _selectedOrderNumbers.addAll(_listManager.paginatedOrderNumbers);
    } else {
      for (var orderNo in _listManager.paginatedOrderNumbers) {
        _selectedOrderNumbers.remove(orderNo);
      }
    }
    notifyListeners();
  }

  List<Product> getProductsByOrder(String orderNumber) {
    return _listManager.groupedProducts[orderNumber] ?? [];
  }

  // --- External Actions ---

  Future<File?> pickImportFile() => _excelService.pickFile();

  Future<List<Product>?> parseImportFile(File file) async {
    _isLoading = true;
    notifyListeners();
    try {
      return await _excelService.parseFile(file);
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
    final db = await _dbService.database;
    final directory = Directory(p.dirname(db.path));
    final imagesDir = Directory(p.join(directory.path, 'images'));
    if (!await imagesDir.exists()) await imagesDir.create(recursive: true);
    
    final fileName = p.basename(imageFile.path);
    final localPath = p.join(imagesDir.path, fileName);
    
    File localImageFile = await File(localPath).exists() ? File(localPath) : await imageFile.copy(localPath);

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
        mergedImagePath: null,
        status: 'image_uploaded',
        createdAt: product.createdAt,
      );
      await _dbService.updateProduct(updatedProduct);
      updatedCount = 1;
    } else if (syncMode == 'sku') {
      updatedCount = await _dbService.updateProductsImageBulk(localImageFile.path, skuPlatform: product.skuPlatform);
    } else if (syncMode == 'id_sku') {
      updatedCount = await _dbService.updateProductsImageBulk(localImageFile.path, idSku: product.idSku);
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
        createdAt: product.createdAt,
      );
      await _dbService.updateProduct(updatedProduct);
      if (!silent) await fetchProducts(updateLoading: false);
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
    List<Product> toProcess = _listManager.products.where((p) => _selectedOrderNumbers.contains(p.noPesanan)).toList();
    int total = toProcess.length;
    int completed = 0;

    Future<void> runWorker() async {
      while (completed < total) {
        final currentIdx = completed++;
        if (currentIdx >= total) break;
        await mergeProduct(toProcess[currentIdx], silent: true);
        _progress = completed / total;
        _processingDuration = stopwatch.elapsed;
        notifyListeners();
      }
    }

    await Future.wait(List.generate(8, (_) => runWorker()));
    stopwatch.stop();
    await fetchProducts(updateLoading: false);
    _isProcessing = false;
    _isLoading = false;
    _progress = 0;
    notifyListeners();
  }

  Future<bool> saveSelectedMerged() async {
    // 1. Get all selected order numbers
    if (_selectedOrderNumbers.isEmpty) return false;

    // 2. Check if EVERY item in the selected orders is completed
    for (var orderNo in _selectedOrderNumbers) {
      final itemsInOrder = _listManager.groupedProducts[orderNo] ?? [];
      
      // If any item in the order is not completed or missing merged image, fail the whole save
      bool allCompleted = itemsInOrder.every((p) => p.status == 'completed' && p.mergedImagePath != null);
      if (!allCompleted) return false;
    }

    // 3. Collect all products from the selected orders (now we know they are all completed)
    List<Product> toSave = _listManager.products.where((p) => 
      _selectedOrderNumbers.contains(p.noPesanan)
    ).toList();

    if (toSave.isEmpty) return false;
    final success = await _imageService.saveMergedImages(toSave);
    if (success) refreshProcessedList();
    return success;
  }

  void refreshProcessedList() {
    final Map<String, List<Product>> allGroups = _listManager.groupedProducts;
    List<String> completedOrders = [];

    allGroups.forEach((orderNo, items) {
      // An order is only "processed" if ALL items in it are completed
      bool isFullyProcessed = items.isNotEmpty && 
                             items.every((p) => p.status == 'completed' && p.mergedImagePath != null);
      if (isFullyProcessed) {
        completedOrders.add(orderNo);
      }
    });

    _processedOrderNumbers = completedOrders;
    notifyListeners();
  }

  void clearProcessedOrders() {
    _processedOrderNumbers.clear();
    notifyListeners();
  }

  Future<void> deleteProduct(int id) async {
    await _dbService.deleteProduct(id);
    await fetchProducts(updateLoading: false);
  }

  Future<void> deleteSelected() async {
    if (_selectedOrderNumbers.isEmpty) return;
    _isLoading = true;
    notifyListeners();
    for (var orderNo in _selectedOrderNumbers) {
      final products = _listManager.groupedProducts[orderNo] ?? [];
      for (var p in products) await _dbService.deleteProduct(p.id!);
    }
    _selectedOrderNumbers.clear();
    await fetchProducts(updateLoading: false);
    _isLoading = false;
    notifyListeners();
  }
}

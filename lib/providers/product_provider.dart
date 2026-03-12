import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import '../models/product.dart';
import '../services/database_service.dart';
import '../services/excel_service.dart';
import '../services/image_service.dart';
import 'dart:io';

class ProductProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final ExcelService _excelService = ExcelService();
  final ImageService _imageService = ImageService();

  List<Product> _products = [];
  bool _isLoading = false;
  double _progress = 0;
  Set<String> _selectedOrderNumbers = {};

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

  // Pagination getters
  int get currentPage => _currentPage;
  int get pageSize => _pageSize;
  int get totalPages => (_orderNumbers.length / _pageSize).ceil();
  List<String> get paginatedOrderNumbers => _paginatedOrderNumbers;
  Map<String, List<Product>> get groupedProducts => _groupedProducts;
  List<String> get orderNumbers => _orderNumbers;

  int get selectedItemsCount {
    if (_selectedOrderNumbers.isEmpty) return 0;
    return _products.where((p) => _selectedOrderNumbers.contains(p.noPesanan)).length;
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
      _selectedOrderNumbers = _orderNumbers.toSet();
    } else {
      _selectedOrderNumbers.clear();
    }
    notifyListeners();
  }

  void setPage(int page) {
    if (page >= 1 && page <= totalPages) {
      _currentPage = page;
      _updatePaginatedData();
      notifyListeners();
    }
  }

  void setPageSize(int size) {
    _pageSize = size;
    _currentPage = 1;
    _updatePaginatedData();
    notifyListeners();
  }

  void _updatePaginatedData() {
    // Group products by order number
    _groupedProducts = {};
    for (var p in _products) {
      if (!_groupedProducts.containsKey(p.noPesanan)) {
        _groupedProducts[p.noPesanan] = [];
      }
      _groupedProducts[p.noPesanan]!.add(p);
    }
    
    _orderNumbers = _groupedProducts.keys.toList();
    
    int start = (_currentPage - 1) * _pageSize;
    int end = start + _pageSize;
    
    if (start >= _orderNumbers.length) {
      _paginatedOrderNumbers = [];
    } else {
      _paginatedOrderNumbers = _orderNumbers.sublist(
        start,
        end > _orderNumbers.length ? _orderNumbers.length : end,
      );
    }
  }

  Future<void> fetchProducts({bool updateLoading = true}) async {
    if (updateLoading) {
      _isLoading = true;
      _progress = 0;
      notifyListeners();
    }
    _products = await _dbService.getProducts();
    _updatePaginatedData();
    if (updateLoading) {
      _isLoading = false;
      notifyListeners();
    } else {
      notifyListeners();
    }
  }

  Future<void> importExcel() async {
    final importedProducts = await _excelService.pickAndParseExcel();
    if (importedProducts != null && importedProducts.isNotEmpty) {
      _isLoading = true;
      _progress = 0;
      notifyListeners();
      await _dbService.insertProductsBulk(importedProducts);
      await fetchProducts(updateLoading: false);
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProductImage(Product product, File imageFile) async {
    // Copy image to local app directory for persistence
    final db = await _dbService.database;
    final directory = Directory(p.dirname(db.path));
    final imagesDir = Directory(p.join(directory.path, 'images'));
    
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    
    final fileName = p.basename(imageFile.path);
    final localPath = p.join(imagesDir.path, fileName);
    
    final localImageFile = await imageFile.copy(localPath);
    
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
      status: 'image_uploaded',
    );

    await _dbService.updateProduct(updatedProduct);
    await fetchProducts();
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
    _progress = 0.01; // Start with a tiny bit to avoid indeterminate state
    notifyListeners();
    
    List<Product> toProcess = _products.where((p) => _selectedOrderNumbers.contains(p.noPesanan)).toList();
    int total = toProcess.length;

    for (int i = 0; i < total; i++) {
      await mergeProduct(toProcess[i], silent: true);
      _progress = (i + 1) / total;
      notifyListeners();
    }
    
    _selectedOrderNumbers.clear(); // Clear selection after merge
    await fetchProducts(updateLoading: false);
    _isLoading = false;
    _progress = 0;
    notifyListeners();
  }

  Future<void> deleteSelected() async {
    if (_selectedOrderNumbers.isEmpty) return;
    
    _isLoading = true;
    _progress = 0.01;
    notifyListeners();

    List<Product> toDelete = _products.where((p) => _selectedOrderNumbers.contains(p.noPesanan)).toList();
    int total = toDelete.length;

    for (int i = 0; i < total; i++) {
      if (toDelete[i].id != null) {
        await _dbService.deleteProduct(toDelete[i].id!);
      }
      _progress = (i + 1) / total;
      notifyListeners();
    }

    _selectedOrderNumbers.clear();
    await fetchProducts(updateLoading: false);
    _isLoading = false;
    _progress = 0;
    notifyListeners();
  }

  Future<void> saveAllMerged() async {
    final mergedProducts = _products.where((p) => p.mergedImagePath != null).toList();
    if (mergedProducts.isEmpty) return;

    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) return;

    _isLoading = true;
    _progress = 0.01;
    notifyListeners();

    int total = mergedProducts.length;

    for (int i = 0; i < total; i++) {
      final product = mergedProducts[i];
      final sourceFile = File(product.mergedImagePath!);
      if (await sourceFile.exists()) {
        final fileName = p.basename(product.mergedImagePath!);
        final destinationPath = p.join(selectedDirectory, fileName);
        await sourceFile.copy(destinationPath);
      }
      _progress = (i + 1) / total;
      notifyListeners();
    }

    _selectedOrderNumbers.clear(); // Clear selection after saving
    _isLoading = false;
    _progress = 0;
    notifyListeners();
  }

  Future<void> deleteProduct(int id) async {
    final product = _products.firstWhere((p) => p.id == id);
    await _dbService.deleteProduct(id);
    _selectedOrderNumbers.remove(product.noPesanan);
    await fetchProducts();
  }

  Future<void> deleteAll() async {
    await _dbService.deleteAllProducts();
    _selectedOrderNumbers.clear();
    await fetchProducts();
  }
}

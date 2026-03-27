import '../models/product.dart';

class ProductListManager {
  List<Product> products = [];
  String searchQuery = '';
  List<String> searchTerms = [];
  int currentPage = 1;
  int pageSize = 10;
  String sortColumn = 'sku';
  bool isAscending = true;

  Map<String, List<Product>> groupedProducts = {};
  List<String> orderNumbers = [];
  List<String> paginatedOrderNumbers = [];

  void updateSearch(String query) {
    searchQuery = query;
    // Split query by newlines for mass search
    searchTerms = query
        .split('\n')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
    currentPage = 1;
  }

  void updatePaginatedData() {
    // 1. Filter products based on search terms
    List<Product> filteredProducts = [];
    for (var p in products) {
      if (searchTerms.isNotEmpty) {
        bool matchesTerm = false;
        for (final term in searchTerms) {
          if (p.skuPlatform.toLowerCase().contains(term) ||
              p.idSku.toLowerCase().contains(term) ||
              p.idProduk.toLowerCase().contains(term) ||
              p.noPesanan.toLowerCase().contains(term) ||
              p.nomorResi.toLowerCase().contains(term) ||
              p.spesifikasiProduk.toLowerCase().contains(term)) {
            matchesTerm = true;
            break; 
          }
        }
        if (!matchesTerm) continue;
      }
      filteredProducts.add(p);
    }

    // 2. Sort the filtered flat list
    filteredProducts.sort((a, b) {
      int cmp;
      switch (sortColumn) {
        case 'sku':
          cmp = a.skuPlatform.toLowerCase().compareTo(b.skuPlatform.toLowerCase());
          if (cmp == 0) {
            cmp = a.idSku.toLowerCase().compareTo(b.idSku.toLowerCase());
          }
          break;
        case 'id_sku':
          cmp = a.idSku.toLowerCase().compareTo(b.idSku.toLowerCase());
          break;
        case 'time':
        default:
          final aTime = a.createdAt ?? DateTime(0);
          final bTime = b.createdAt ?? DateTime(0);
          cmp = aTime.compareTo(bTime);
          break;
      }
      return isAscending ? cmp : -cmp;
    });

    // 3. Group products by order number while maintaining sort order
    groupedProducts = {};
    orderNumbers = [];
    for (var p in filteredProducts) {
      if (!groupedProducts.containsKey(p.noPesanan)) {
        groupedProducts[p.noPesanan] = [];
        orderNumbers.add(p.noPesanan);
      }
      groupedProducts[p.noPesanan]!.add(p);
    }

    updateCurrentPageData();
  }

  void updateCurrentPageData() {
    final start = (currentPage - 1) * pageSize;
    final end = start + pageSize;
    
    if (start >= orderNumbers.length) {
      paginatedOrderNumbers = [];
    } else {
      paginatedOrderNumbers = orderNumbers.sublist(
        start, 
        end > orderNumbers.length ? orderNumbers.length : end
      );
    }
  }

  int get totalPages => (orderNumbers.length / pageSize).ceil();

  int get totalQuantity {
    int sum = 0;
    for (var p in products) {
      sum += p.jumlahBarang;
    }
    return sum;
  }

  int calculateSelectedItemsCount(Set<String> selectedOrderNumbers) {
    int count = 0;
    for (var orderNo in selectedOrderNumbers) {
      if (groupedProducts.containsKey(orderNo)) {
        count += groupedProducts[orderNo]!.length;
      }
    }
    return count;
  }
}

import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/product.dart';

class AutoUploadService {
  /// Matches a list of files with a list of products based on SKU Platform or ID SKU.
  /// This matching is CASE-SENSITIVE as requested.
  /// Returns a Map where the key is the Product ID and the value is the matched File.
  Map<int, File> matchProductsWithFiles(List<Product> products, List<File> files) {
    if (products.isEmpty || files.isEmpty) return {};

    // 1. Create a lookup map for files: NameWithoutExtension -> File object
    // This is case-sensitive because Dart Map keys are case-sensitive.
    final Map<String, File> fileNameMap = {};
    for (var file in files) {
      final nameWithoutExt = p.basenameWithoutExtension(file.path);
      fileNameMap[nameWithoutExt] = file;
    }

    final Map<int, File> matches = {};

    for (var product in products) {
      if (product.id == null) continue;

      // Priority 1: Match with SKU Platform (Case-Sensitive)
      if (fileNameMap.containsKey(product.skuPlatform)) {
        matches[product.id!] = fileNameMap[product.skuPlatform]!;
      } 
      // Priority 2: Match with ID SKU (Case-Sensitive)
      else if (fileNameMap.containsKey(product.idSku)) {
        matches[product.id!] = fileNameMap[product.idSku]!;
      }
    }

    return matches;
  }
}

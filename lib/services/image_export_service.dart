import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../models/product.dart';

class ImageExportService {
  // Background isolate function for file writing
  static Future<void> saveToFile(Map<String, dynamic> args) async {
    final String path = args['path'];
    final Uint8List bytes = args['bytes'];
    await File(path).writeAsBytes(bytes);
  }

  /// Saves multiple merged images to a user-selected directory.
  /// Ensures unique filenames for every single item, even with identical order numbers.
  /// Wraps results in a folder if there's more than one item.
  Future<bool> saveMergedImages(List<Product> products) async {
    try {
      print('DEBUG: Starting saveMergedImages for ${products.length} items');
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) {
        print('DEBUG: No directory selected');
        return false;
      }

      // Calculate total files to be saved
      int totalFilesExpected = 0;
      for (var p in products) {
        if (p.mergedImagePath != null) {
          totalFilesExpected += (p.jumlahBarang > 0 ? p.jumlahBarang : 1);
        }
      }

      if (totalFilesExpected == 0) return false;

      Directory targetDir = Directory(selectedDirectory);
      
      // If more than one file, create a subfolder
      if (totalFilesExpected > 1) {
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final folderName = 'Merged_Results_$timestamp';
        targetDir = Directory(p.join(selectedDirectory, folderName));
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
      }

      int savedCount = 0;
      
      for (var i = 0; i < products.length; i++) {
        final product = products[i];
        if (product.mergedImagePath == null) continue;

        final sourceFile = File(product.mergedImagePath!);
        if (!await sourceFile.exists()) continue;

        final int qty = product.jumlahBarang > 0 ? product.jumlahBarang : 1;
        
        for (int copyNum = 1; qty >= copyNum; copyNum++) {
          final cleanOrderNo = product.noPesanan.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
          
          // Format: NoPesanan_Qty_CopyNum (Using product ID to ensure uniqueness if multiple items in same order)
          final fileName = '${cleanOrderNo}_Qty${product.jumlahBarang}_Dup${product.id}_$copyNum.png';
          final targetPath = p.join(targetDir.path, fileName);

          await sourceFile.copy(targetPath);
          savedCount++;
        }
      }
      
      print('DEBUG: Successfully saved $savedCount files to ${targetDir.path}');
      return savedCount > 0;
    } catch (e) {
      print('Error saving merged images: $e');
      return false;
    }
  }
}

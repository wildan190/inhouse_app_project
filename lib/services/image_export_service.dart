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
  Future<bool> saveMergedImages(List<Product> products, {Function(double)? onProgress}) async {
    try {
      print('DEBUG: Starting saveMergedImages for ${products.length} items');
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) {
        print('DEBUG: No directory selected');
        return false;
      }

      // 1. Pre-calculate total files to be saved for progress tracking
      int totalFilesExpected = 0;
      for (var p in products) {
        if (p.mergedImagePath != null) {
          totalFilesExpected += p.mergedImagePath!.split('|').length;
        }
      }

      if (totalFilesExpected == 0) return false;

      Directory targetDir = Directory(selectedDirectory);
      
      // 2. Create a timestamped folder to avoid clutter and permissions issues with root folders
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final folderName = 'Merged_Results_$timestamp';
      targetDir = Directory(p.join(selectedDirectory, folderName));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      int savedCount = 0;
      
      // 3. Process sequentially with yield points to keep UI responsive
      for (var i = 0; i < products.length; i++) {
        final product = products[i];
        if (product.mergedImagePath == null) continue;

        final List<String> sourcePaths = product.mergedImagePath!.split('|');
        
        for (int copyNum = 0; copyNum < sourcePaths.length; copyNum++) {
          try {
            final sourceFile = File(sourcePaths[copyNum]);
            if (!await sourceFile.exists()) {
              print('DEBUG: Source file not found: ${sourcePaths[copyNum]}');
              continue;
            }

            final cleanOrderNo = product.noPesanan.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
            final fileName = '${cleanOrderNo}_Qty${product.jumlahBarang}_Dup${product.id}_${copyNum + 1}.png';
            final targetPath = p.join(targetDir.path, fileName);

            // Use copySync for better performance inside try-catch if we want, 
            // but copy is already async. Let's stick with copy but add a yield.
            await sourceFile.copy(targetPath);
            savedCount++;

            if (onProgress != null) {
              onProgress(savedCount / totalFilesExpected);
            }

            // Allow event loop to process other things (UI updates)
            if (savedCount % 5 == 0) {
              await Future.delayed(const Duration(milliseconds: 10));
            }
          } catch (e) {
            print('DEBUG: Error copying file ${sourcePaths[copyNum]}: $e');
            // Continue with other files even if one fails
          }
        }
      }
      
      print('DEBUG: Successfully saved $savedCount/$totalFilesExpected files to ${targetDir.path}');
      return savedCount > 0;
    } catch (e) {
      print('CRITICAL: Error in saveMergedImages: $e');
      return false;
    }
  }
}

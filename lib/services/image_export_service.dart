import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
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

  // Background isolate function for file copying
  static Future<void> copyFileTask(Map<String, String> args) async {
    final String source = args['source']!;
    final String target = args['target']!;
    final sourceFile = File(source);
    if (await sourceFile.exists()) {
      await sourceFile.copy(target);
    }
  }

  /// Saves multiple merged images to a user-selected directory using a sequential queue.
  /// Ensures the UI thread is not blocked by moving file I/O to background isolates.
  Future<bool> saveMergedImages(List<Product> products, {Function(double)? onProgress}) async {
    try {
      print('DEBUG: Starting saveMergedImages with queue for ${products.length} products');
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) return false;

      // 1. GATHER ALL TASKS (Preparing the Queue)
      final List<Map<String, String>> copyQueue = [];
      
      // Create a timestamped folder
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final folderName = 'Merged_Results_$timestamp';
      final targetDir = Directory(p.join(selectedDirectory, folderName));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      for (var product in products) {
        if (product.mergedImagePath == null) continue;
        final List<String> sourcePaths = product.mergedImagePath!.split('|');
        
        for (int copyNum = 0; copyNum < sourcePaths.length; copyNum++) {
          final cleanOrderNo = product.noPesanan.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
          final fileName = '${cleanOrderNo}_Qty${product.jumlahBarang}_Dup${product.id}_${copyNum + 1}.png';
          final targetPath = p.join(targetDir.path, fileName);
          
          copyQueue.add({
            'source': sourcePaths[copyNum],
            'target': targetPath,
          });
        }
      }

      final int totalTasks = copyQueue.length;
      if (totalTasks == 0) return false;

      // 2. PROCESS QUEUE SEQUENTIALLY (Worker Pattern)
      int completedTasks = 0;
      
      for (var task in copyQueue) {
        try {
          // Use compute to move the actual file copy (I/O) to a background Isolate
          await compute(ImageExportService.copyFileTask, task);
          
          completedTasks++;
          if (onProgress != null) {
            onProgress(completedTasks / totalTasks);
          }

          // Force a small yield to keep the main isolate's event loop breathing
          // This ensures the progress bar updates smoothly even on slow disks
          await Future.delayed(const Duration(milliseconds: 5));
        } catch (e) {
          print('DEBUG: Error in copy task for ${task['source']}: $e');
        }
      }
      
      print('DEBUG: Successfully processed queue: $completedTasks/$totalTasks files saved');
      return completedTasks > 0;
    } catch (e) {
      print('CRITICAL: Error in saveMergedImages queue: $e');
      return false;
    }
  }
}

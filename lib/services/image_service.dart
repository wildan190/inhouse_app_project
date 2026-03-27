import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/product.dart';
import 'image_resource_service.dart';
import 'image_processor_service.dart';
import 'image_export_service.dart';

class ImageService {
  final ImageResourceService _resourceService = ImageResourceService();
  final ImageProcessorService _processorService = ImageProcessorService();
  final ImageExportService _exportService = ImageExportService();

  /// Merges a product's details and image into a new composite image.
  /// Returns a string containing one or more paths separated by '|' if qty > 1.
  Future<String?> mergeProductImage(Product product, File? uploadedImage) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final outputDir = Directory(p.join(directory.path, 'merged_images'));
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      // 1. Load Resources in Parallel
      final results = await Future.wait([
        _resourceService.loadOriginalImage(uploadedImage),
        _resourceService.loadLinkedImage(product.tautanGambarProduk),
      ]);

      final ui.Image? uiImage = results[0];
      final ui.Image? linkedImage = results[1];

      if (uiImage == null) return null;

      final int qty = product.jumlahBarang > 0 ? product.jumlahBarang : 1;
      List<String> outputPaths = [];

      for (int i = 1; i <= qty; i++) {
        final String groupInfo = '$qty-$i';
        final cleanOrderNo = product.noPesanan.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final cleanIdSku = product.idSku.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final outputPath = p.join(outputDir.path, 'merged_${cleanOrderNo}_${cleanIdSku}_${product.id}_${i}_${DateTime.now().millisecondsSinceEpoch}.png');

        // 2. Calculate FIXED Dimensions for 300 DPI (9cm x 2.5cm)
        const double dpi = 300.0;
        const double cmToInch = 0.393701;
        final double containerWidthPx = 9 * cmToInch * dpi;   // ~1063 px
        final double containerHeightPx = 2.5 * cmToInch * dpi; // ~295 px
        final double verticalPadding = 40.0; 
        final double headerAreaHeight = containerHeightPx + verticalPadding;
        const double gapBetweenHeaderAndImage = 60.0;

        final int canvasWidth = uiImage.width;
        final int finalCanvasWidth = canvasWidth < containerWidthPx.toInt() ? containerWidthPx.toInt() + 80 : canvasWidth;
        final int canvasHeight = uiImage.height + headerAreaHeight.toInt() + gapBetweenHeaderAndImage.toInt();

        // 3. Drawing Process
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);

        final double margin = 40.0;
        final double containerLeft = finalCanvasWidth - containerWidthPx - margin;
        final double containerTop = verticalPadding / 2;

        // Draw Header Background
        canvas.drawRect(
          Rect.fromLTWH(containerLeft, containerTop, containerWidthPx, containerHeightPx), 
          Paint()..color = Colors.white
        );

        // Draw QR and Details (with groupInfo e.g. "5-1", "5-2")
        await _processorService.drawDetailsInContainer(
          canvas, product, containerLeft, containerTop, containerWidthPx.toInt(), containerHeightPx.toInt(), linkedImage,
          groupInfo: qty > 1 ? groupInfo : null,
        );

        // Draw the Original Image
        double imageX = (finalCanvasWidth - uiImage.width) / 2;
        canvas.drawImage(uiImage, Offset(imageX, headerAreaHeight + gapBetweenHeaderAndImage), Paint());
        
        // 4. Finalize and Save
        final picture = recorder.endRecording();
        final finalImg = await picture.toImage(finalCanvasWidth, canvasHeight);
        final byteData = await finalImg.toByteData(format: ui.ImageByteFormat.png);
        
        if (byteData != null) {
          Uint8List buffer = byteData.buffer.asUint8List();
          buffer = _processorService.injectDpi(buffer, 300);
          
          await compute(ImageExportService.saveToFile, {'path': outputPath, 'bytes': buffer});
          outputPaths.add(outputPath);
          
          finalImg.dispose();
          picture.dispose();
        }
      }

      uiImage.dispose();
      linkedImage?.dispose();

      return outputPaths.isNotEmpty ? outputPaths.join('|') : null;
    } catch (e) {
      print('Error in mergeProductImage: $e');
    }
    return null;
  }

  Future<bool> saveMergedImages(List<Product> products, {Function(double)? onProgress}) => 
      _exportService.saveMergedImages(products, onProgress: onProgress);
}

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
  Future<String?> mergeProductImage(Product product, File? uploadedImage) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final outputDir = Directory(p.join(directory.path, 'merged_images'));
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      final cleanOrderNo = product.noPesanan.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final cleanIdSku = product.idSku.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final outputPath = p.join(outputDir.path, 'merged_${cleanOrderNo}_${cleanIdSku}_${product.id}_${DateTime.now().millisecondsSinceEpoch}.png');

      // 1. Load Resources in Parallel
      final results = await Future.wait([
        _resourceService.loadOriginalImage(uploadedImage),
        _resourceService.loadLinkedImage(product.tautanGambarProduk),
      ]);

      final ui.Image? uiImage = results[0];
      final ui.Image? linkedImage = results[1];

      if (uiImage == null) return null;

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

      // Draw QR and Details
      await _processorService.drawDetailsInContainer(
        canvas, product, containerLeft, containerTop, containerWidthPx.toInt(), containerHeightPx.toInt(), linkedImage
      );

      // Draw the Original Image
      double imageX = (finalCanvasWidth - uiImage.width) / 2;
      canvas.drawImage(uiImage, Offset(imageX, headerAreaHeight + gapBetweenHeaderAndImage), Paint());
      
      uiImage.dispose();
      linkedImage?.dispose();

      // 4. Finalize and Save
      final picture = recorder.endRecording();
      final finalImg = await picture.toImage(finalCanvasWidth, canvasHeight);
      final byteData = await finalImg.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        Uint8List buffer = byteData.buffer.asUint8List();
        buffer = _processorService.injectDpi(buffer, 300);
        
        await compute(ImageExportService.saveToFile, {'path': outputPath, 'bytes': buffer});
        
        finalImg.dispose();
        picture.dispose();
        return outputPath;
      }
    } catch (e) {
      print('Error in mergeProductImage: $e');
    }
    return null;
  }

  Future<bool> saveMergedImages(List<Product> products) => _exportService.saveMergedImages(products);
}

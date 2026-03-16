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

        // 2. Calculate Landscape Dimensions
        // User requested 160cm width with 300 DPI (Pixels/Inch)
        // 160 cm / 2.54 cm/inch * 300 DPI = ~18,897 pixels
        const double targetWidthCm = 160.0;
        const double cmToInch = 0.393701;
        const double renderDpi = 300.0; // Forced to 300 DPI as requested
        
        // PRIORITY: "jangan ada pengecilan apapun" & "size asli"
        // We set the canvas width to at least 160cm, but if the original image is wider,
        // we use the original image's width to avoid any downscaling or cropping.
        final double minCanvasWidthPx = targetWidthCm * cmToInch * renderDpi; 
        final double finalCanvasWidth = uiImage.width.toDouble() > minCanvasWidthPx 
            ? uiImage.width.toDouble() 
            : minCanvasWidthPx;
        
        // QR Area: 9cm x 2.5cm but oriented VERTICALLY (2.5 wide, 9 high)
        final double qrAreaBoxWidth = 2.5 * cmToInch * renderDpi;
        final double qrAreaBoxHeight = 9.0 * cmToInch * renderDpi;
        
        // Position: 55cm from the bottom edge
        final double distFromBottom = 55.0 * cmToInch * renderDpi;
        
        // Calculate dynamic height based on original image and QR position requirement
        // Ensure we don't scale down or crop the original image height
        final double minHeightRequired = distFromBottom + qrAreaBoxHeight + (2.0 * cmToInch * renderDpi); 
        final double canvasHeight = uiImage.height.toDouble() > minHeightRequired 
            ? uiImage.height.toDouble() 
            : minHeightRequired;

        // 3. Drawing Process
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);

        // --- REMOVED WHITE BACKGROUND TO MAINTAIN PNG TRANSPARENCY ---
        // This ensures that the original transparency of the image is preserved.

        // --- QR AREA POSITIONING (Left Side) ---
        final double margin = 1.0 * cmToInch * renderDpi; // 1cm margin
        final double containerLeft = margin;
        final double containerTop = canvasHeight - distFromBottom - qrAreaBoxHeight;

        // Draw QR Area Border and Background (Keep white background for readability of text/QR)
        final Rect qrRect = Rect.fromLTWH(containerLeft, containerTop, qrAreaBoxWidth, qrAreaBoxHeight);
        canvas.drawRect(qrRect, Paint()..color = Colors.white);
        canvas.drawRect(
          qrRect, 
          Paint()
            ..color = Colors.black
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 3.0 // Bold border
        );

        // Rotate and Draw Details inside QR Area
        canvas.save();
        canvas.translate(containerLeft, containerTop + qrAreaBoxHeight);
        canvas.rotate(-3.14159 / 2);
        
        await _processorService.drawDetailsInContainer(
          canvas, 
          product, 
          0, 0, 
          qrAreaBoxHeight.toInt(), 
          qrAreaBoxWidth.toInt(),
          linkedImage,
          groupInfo: qty > 1 ? groupInfo : null,
        );
        canvas.restore();

        // --- HORIZONTAL LINES ---
        final double lineGap = 1.0 * cmToInch * renderDpi; // 1cm gap
        final double centerY = containerTop + (qrAreaBoxHeight / 2);
        final double lineY1 = centerY - (lineGap / 2);
        final double lineY2 = centerY + (lineGap / 2);
        
        // Lines start from the right border of the QR area (sticking to it)
        final double lineStartX = containerLeft + qrAreaBoxWidth; 
        final double lineWidth = 15.0 * cmToInch * renderDpi; // 15cm long lines
        
        final linePaint = Paint()
          ..color = Colors.black
          ..strokeWidth = 5.0 // Bold lines
          ..style = ui.PaintingStyle.stroke;

        canvas.drawLine(Offset(lineStartX, lineY1), Offset(lineStartX + lineWidth, lineY1), linePaint);
        canvas.drawLine(Offset(lineStartX, lineY2), Offset(lineStartX + lineWidth, lineY2), linePaint);

        // --- MAIN IMAGE POSITIONING ---
        // Draw at 1:1 pixel ratio to ensure "jangan ada pengecilan apapun"
        // Centered on the (potentially expanded) canvas
        double imageX = (finalCanvasWidth - uiImage.width) / 2;
        double imageY = (canvasHeight - uiImage.height) / 2;
        
        canvas.drawImage(uiImage, Offset(imageX, imageY), Paint());
        
        // 4. Finalize and Save
        final picture = recorder.endRecording();
        final finalImg = await picture.toImage(finalCanvasWidth.round(), canvasHeight.round());
        final byteData = await finalImg.toByteData(format: ui.ImageByteFormat.png);
        
        if (byteData != null) {
          Uint8List buffer = byteData.buffer.asUint8List();
          // Inject 300 DPI so Photoshop sees 300 Pixels/Inch
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

  Future<bool> saveMergedImages(List<Product> products) => _exportService.saveMergedImages(products);
}

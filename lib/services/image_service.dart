import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart'; // Added for compute
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path/path.dart' as p;
import '../models/product.dart';
import 'package:http/http.dart' as http;

class ImageService {
  /// Merges a product's details and image into a new composite image.
  /// Optimized for performance and large file sizes (>500MB).
  /// Maximizes GPU and RAM usage as requested.
  Future<String?> mergeProductImage(Product product, File? uploadedImage) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final outputDir = Directory(p.join(directory.path, 'merged_images'));
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      final outputPath = p.join(outputDir.path, 'merged_${product.noPesanan}_${DateTime.now().millisecondsSinceEpoch}.png');

      // 1. Load Resources in Parallel (MAX PERFORMANCE)
      final List<Future<ui.Image?>> loadingTasks = [];
      
      // Task for original image
      loadingTasks.add(_loadOriginalImage(uploadedImage));
      
      // Task for linked image
      loadingTasks.add(_loadLinkedImage(product.tautanGambarProduk));

      final results = await Future.wait(loadingTasks);
      final ui.Image? uiImage = results[0];
      final ui.Image? linkedImage = results[1];

      if (uiImage == null) return null;

      // 2. Calculate Dimensions for 300 DPI
      const double dpi = 300.0;
      const double cmToInch = 0.393701;
      
      double minWidthPx = 9 * cmToInch * dpi; // ~1063 px
      double containerWidthPx = minWidthPx;
      
      if (uiImage.width > containerWidthPx * 2) {
        containerWidthPx = uiImage.width * 0.4;
      }
      
      double containerHeightPx = containerWidthPx * (2.5 / 9.0);
      double verticalPadding = containerHeightPx * 0.2;
      double headerHeightPx = containerHeightPx + verticalPadding;
      const double gapBetweenHeaderAndImage = 60.0;

      final int canvasWidth = uiImage.width;
      final int canvasHeight = uiImage.height + headerHeightPx.toInt() + gapBetweenHeaderAndImage.toInt();

      // 3. Drawing Process (GPU ACCELERATED)
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final double margin = 40.0;
      final double containerLeft = canvasWidth - containerWidthPx - margin;
      final double containerTop = verticalPadding / 2;

      // Draw Header Background
      final paint = Paint()..color = Colors.white;
      canvas.drawRect(
        Rect.fromLTWH(containerLeft, containerTop, containerWidthPx, containerHeightPx), 
        paint
      );

      // Draw QR and Details (Awaited to ensure sequential drawing on canvas)
      await _drawDetailsInContainer(
        canvas, 
        product, 
        containerLeft, 
        containerTop, 
        containerWidthPx.toInt(), 
        containerHeightPx.toInt(),
        linkedImage
      );

      // Draw the Original Image (Hardware accelerated)
      canvas.drawImage(uiImage, Offset(0, headerHeightPx + gapBetweenHeaderAndImage), Paint());
      
      // Dispose original immediately after drawing
      uiImage.dispose();
      linkedImage?.dispose();

      // 4. Finalize and Save
      final picture = recorder.endRecording();
      // toImage is asynchronous and utilizes GPU memory
      final finalImg = await picture.toImage(canvasWidth, canvasHeight);
      
      // toByteData performs the encoding. PNG is lossless as requested.
      final byteData = await finalImg.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        final buffer = byteData.buffer.asUint8List();
        
        // Use compute to offload file writing to a background isolate
        // This prevents the main thread from blocking while writing huge files
        await compute(_saveToFile, {'path': outputPath, 'bytes': buffer});
        
        finalImg.dispose();
        picture.dispose();
        return outputPath;
      }
    } catch (e) {
      print('Error in mergeProductImage: $e');
    }
    return null;
  }

  // Helper to load original image efficiently
  Future<ui.Image?> _loadOriginalImage(File? uploadedImage) async {
    if (uploadedImage == null || !await uploadedImage.exists()) return null;
    try {
      final Uint8List imageBytes = await uploadedImage.readAsBytes();
      final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(imageBytes);
      final ui.ImageDescriptor descriptor = await ui.ImageDescriptor.encoded(buffer);
      final ui.Codec codec = await descriptor.instantiateCodec();
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      buffer.dispose();
      return frameInfo.image;
    } catch (e) {
      print('Error loading original image: $e');
      return null;
    }
  }

  // Helper to load linked image in parallel
  Future<ui.Image?> _loadLinkedImage(String url) async {
    if (url.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(response.bodyBytes);
        final ui.ImageDescriptor descriptor = await ui.ImageDescriptor.encoded(buffer);
        final ui.Codec codec = await descriptor.instantiateCodec();
        final ui.FrameInfo frameInfo = await codec.getNextFrame();
        buffer.dispose();
        return frameInfo.image;
      }
    } catch (e) {
      print('Error fetching linked image: $e');
    }
    return null;
  }

  // Background isolate function for file writing
  static Future<void> _saveToFile(Map<String, dynamic> args) async {
    final String path = args['path'];
    final Uint8List bytes = args['bytes'];
    await File(path).writeAsBytes(bytes);
  }

  Future<void> _drawDetailsInContainer(
    Canvas canvas, 
    Product product, 
    double left, 
    double top, 
    int width, 
    int height,
    ui.Image? linkedImage
  ) async {
    final double padding = height * 0.1;
    final double contentHeight = height.toDouble() - (padding * 2);
    
    // 1. QR Code (Far Right)
    final double qrSize = contentHeight;
    final double qrLeft = left + width - qrSize - padding;
    
    final qrValidationResult = QrValidator.validate(
      data: product.noPesanan,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    );

    if (qrValidationResult.status == QrValidationStatus.valid) {
      final qrCode = qrValidationResult.qrCode!;
      final painter = QrPainter.withQr(
        qr: qrCode,
        color: const Color(0xFF000000),
        gapless: true,
      );

      final qrImage = await painter.toImage(qrSize);
      canvas.drawImage(qrImage, Offset(qrLeft, top + padding), Paint());
      qrImage.dispose();
    }

    // 2. Linked Image Thumbnail (To the left of QR)
    final double thumbSize = contentHeight;
    final double thumbLeft = qrLeft - thumbSize - padding;
    if (linkedImage != null) {
      canvas.drawImageRect(
        linkedImage,
        Rect.fromLTWH(0, 0, linkedImage.width.toDouble(), linkedImage.height.toDouble()),
        Rect.fromLTWH(thumbLeft, top + padding, thumbSize, thumbSize),
        Paint()..filterQuality = ui.FilterQuality.high,
      );
    }

    // 3. Text Details (Far Left)
    // IMPORTANT: textMaxWidth must account for BOTH QR and Thumbnail to avoid overlap
    final double textLeft = left + padding;
    final double textMaxWidth = thumbLeft - textLeft - padding;

    final double fontSizeSmall = height * 0.10; // Reduced from 0.12
    final double fontSizeLarge = height * 0.22; // Reduced from 0.28

    final textStyleSmall = TextStyle(
      color: Colors.black, 
      fontSize: fontSizeSmall, 
      fontWeight: FontWeight.normal, // Removed bold
    );
    final textStyleLarge = TextStyle(
      color: Colors.black, 
      fontSize: fontSizeLarge, 
      fontWeight: FontWeight.normal, // Removed w900
    );

    double yOffset = top + padding;

    // Order No, SKU, Spec
    final lines = [
      'NO. PESANAN: ${product.noPesanan}',
      'SKU: ${product.idSku}',
      'SPEC: ${product.spesifikasiProduk}',
    ];

    for (var line in lines) {
      final tp = TextPainter(
        text: TextSpan(text: line, style: textStyleSmall),
        textDirection: TextDirection.ltr,
      );
      tp.layout(maxWidth: textMaxWidth);
      tp.paint(canvas, Offset(textLeft, yOffset));
      yOffset += tp.height + (padding * 0.1);
    }

    // Qty (Large)
    final qtyTp = TextPainter(
      text: TextSpan(text: 'Qty: ${product.jumlahBarang}', style: textStyleLarge),
      textDirection: TextDirection.ltr,
    );
    qtyTp.layout(maxWidth: textMaxWidth);
    // Draw Qty at the bottom of the container
    qtyTp.paint(canvas, Offset(textLeft, top + height - qtyTp.height - padding));
  }
}

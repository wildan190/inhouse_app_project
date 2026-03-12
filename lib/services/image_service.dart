import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path/path.dart' as p;
import '../models/product.dart';

import 'package:http/http.dart' as http;

class ImageService {
  /// Merges a product's details and image into a new composite image.
  /// Optimized for performance and large file sizes (>500MB).
  /// Maintains original image resolution (300 DPI) and adds a header area.
  Future<String?> mergeProductImage(Product product, File? uploadedImage) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final outputDir = Directory(p.join(directory.path, 'merged_images'));
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      final outputPath = p.join(outputDir.path, 'merged_${product.noPesanan}_${DateTime.now().millisecondsSinceEpoch}.png');

      // 1. Load Original Image (NO COMPRESSION)
      ui.Image? uiImage;
      if (uploadedImage != null && await uploadedImage.exists()) {
        final Uint8List imageBytes = await uploadedImage.readAsBytes();
        final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(imageBytes);
        final ui.ImageDescriptor descriptor = await ui.ImageDescriptor.encoded(buffer);
        final ui.Codec codec = await descriptor.instantiateCodec(); // Full resolution
        final ui.FrameInfo frameInfo = await codec.getNextFrame();
        uiImage = frameInfo.image;
        buffer.dispose();
      }

      if (uiImage == null) return null;

      // 2. Fetch Linked Image (Tautan Gambar Produk)
      ui.Image? linkedImage;
      try {
        if (product.tautanGambarProduk.isNotEmpty) {
          final response = await http.get(Uri.parse(product.tautanGambarProduk));
          if (response.statusCode == 200) {
            final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(response.bodyBytes);
            final ui.ImageDescriptor descriptor = await ui.ImageDescriptor.encoded(buffer);
            final ui.Codec codec = await descriptor.instantiateCodec();
            final ui.FrameInfo frameInfo = await codec.getNextFrame();
            linkedImage = frameInfo.image;
            buffer.dispose();
          }
        }
      } catch (e) {
        print('Error fetching linked image: $e');
      }

      // 3. Calculate Dimensions for 300 DPI
      // 300 DPI = 300 pixels per inch
      // 1 cm = 0.393701 inches
      // QR + Data Area: Total Lebar 9cm x Tinggi 2.5cm (Physical)
      // BUT if the main image is huge, 9cm at 300DPI will be too small to see.
      // We will use a larger scale if the image is high resolution.
      const double dpi = 300.0;
      const double cmToInch = 0.393701;
      
      // We'll use a dynamic scaling factor based on image width to keep it readable
      // but ensure the minimum is 9cm @ 300 DPI
      double minWidthPx = 9 * cmToInch * dpi; // ~1063 px
      double containerWidthPx = minWidthPx;
      
      // if image is very wide, let the header grow but maintain aspect ratio
      if (uiImage.width > containerWidthPx * 2) {
        containerWidthPx = uiImage.width * 0.4; // Take 40% of image width
      }
      
      // Maintain the 9:2.5 aspect ratio
      double containerHeightPx = containerWidthPx * (2.5 / 9.0);

      // Padding for the header area on the canvas
      double verticalPadding = containerHeightPx * 0.2;
      double headerHeightPx = containerHeightPx + verticalPadding;
      
      // Gap between header area and main image
      const double gapBetweenHeaderAndImage = 60.0; // 60px gap

      final int canvasWidth = uiImage.width;
      final int canvasHeight = uiImage.height + headerHeightPx.toInt() + gapBetweenHeaderAndImage.toInt();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // 4. Draw Header Container (White Background, Right Aligned)
      final double margin = 40.0;
      final double containerLeft = canvasWidth - containerWidthPx - margin;
      final double containerTop = verticalPadding / 2;

      final paint = Paint()..color = Colors.white;
      canvas.drawRect(
        Rect.fromLTWH(
          containerLeft, 
          containerTop, 
          containerWidthPx, 
          containerHeightPx
        ), 
        paint
      );

      // 5. Draw QR and Details INSIDE the container
      await _drawDetailsInContainer(
        canvas, 
        product, 
        containerLeft, 
        containerTop, 
        containerWidthPx.toInt(), 
        containerHeightPx.toInt(),
        linkedImage // Use the image from URL
      );

      // 6. Draw the Original Image (Starting below the header area + gap)
      canvas.drawImage(uiImage, Offset(0, headerHeightPx + gapBetweenHeaderAndImage), Paint());
      
      // Clean up
      uiImage.dispose();
      linkedImage?.dispose();

      // 7. Finalize and Save
      final picture = recorder.endRecording();
      final finalImg = await picture.toImage(canvasWidth, canvasHeight);
      final byteData = await finalImg.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        final buffer = byteData.buffer.asUint8List();
        await File(outputPath).writeAsBytes(buffer);
        finalImg.dispose();
        picture.dispose();
        return outputPath;
      }
    } catch (e) {
      print('Error in mergeProductImage: $e');
    }
    return null;
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

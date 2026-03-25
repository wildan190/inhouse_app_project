import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:archive/archive.dart';
import '../models/product.dart';

class ImageProcessorService {
  /// Injects a pHYs chunk into the PNG byte stream to specify DPI.
  /// Standard PNGs from dart:ui don't include DPI metadata, causing them to default to 72 DPI.
  /// 300 DPI = 11811 pixels per meter.
  Uint8List injectDpi(Uint8List pngBytes, int dpi) {
    try {
      // 1. Calculate Pixels Per Meter
      // 300 DPI = 300 pixels / 0.0254 meters = 11811.02...
      final int ppm = (dpi / 0.0254).round();
      
      // 2. Prepare pHYs Chunk Data
      final physData = ByteData(9);
      physData.setUint32(0, ppm, Endian.big); // X axis
      physData.setUint32(4, ppm, Endian.big); // Y axis
      physData.setUint8(8, 1); // Unit: meter (1)

      // 3. Prepare pHYs Chunk Type ('pHYs')
      final physType = Uint8List.fromList([112, 72, 89, 115]); // p H Y s
      
      // 4. Calculate CRC32 (Type + Data)
      final crcInput = Uint8List(4 + 9);
      crcInput.setRange(0, 4, physType);
      crcInput.setRange(4, 13, physData.buffer.asUint8List());
      
      // package:archive provides getCrc32
      final int crc = getCrc32(crcInput);

      // 5. Construct Full pHYs Chunk
      // [Length (4)] [Type (4)] [Data (9)] [CRC (4)]
      final physChunk = ByteData(4 + 4 + 9 + 4);
      physChunk.setUint32(0, 9, Endian.big); // Length of data
      physChunk.setUint8(4, 112); // p
      physChunk.setUint8(5, 72);  // H
      physChunk.setUint8(6, 89);  // Y
      physChunk.setUint8(7, 115); // s
      for (int i = 0; i < 9; i++) {
        physChunk.setUint8(8 + i, physData.getUint8(i));
      }
      physChunk.setUint32(17, crc, Endian.big); // CRC

      // 6. Insert after IHDR chunk
      // PNG Signature (8 bytes) + IHDR Chunk (Length 4 + Type 4 + Data 13 + CRC 4 = 25 bytes)
      // Total offset to insert pHYs: 8 + 25 = 33
      if (pngBytes.length > 33) {
        final result = Uint8List(pngBytes.length + physChunk.lengthInBytes);
        result.setRange(0, 33, pngBytes.sublist(0, 33));
        result.setRange(33, 33 + physChunk.lengthInBytes, physChunk.buffer.asUint8List());
        result.setRange(33 + physChunk.lengthInBytes, result.length, pngBytes.sublist(33));
        return result;
      }
    } catch (e) {
      print('Failed to inject DPI: $e');
    }
    return pngBytes;
  }

  Future<void> drawDetailsInContainer(
    Canvas canvas, 
    Product product, 
    double left, 
    double top, 
    int width, 
    int height,
    ui.Image? linkedImage,
    {String? groupInfo}
  ) async {
    final double padding = height * 0.1;
    final double contentHeight = height.toDouble() - (padding * 2);
    
    // 1. QR Code (Far Right) - Contains Tracking Number (Nomor Resi)
    final double qrSize = contentHeight;
    final double qrLeft = left + width - qrSize - padding;
    
    final qrValidationResult = QrValidator.validate(
      data: product.nomorResi,
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

    final double fontSizeSmall = height * 0.08; 
    final double fontSizeLarge = height * 0.18; 

    final textStyleSmall = TextStyle(
      color: Colors.black, 
      fontSize: fontSizeSmall, 
      fontWeight: FontWeight.bold,
    );
    final textStyleLarge = TextStyle(
      color: Colors.black, 
      fontSize: fontSizeLarge, 
      fontWeight: FontWeight.bold,
    );

    double yOffset = top + padding;

    // Helper to truncate text
    String truncate(String text, int max) => text.length > max ? text.substring(0, max) : text;
    final orderNo = truncate(product.noPesanan, 20);
    final resi = truncate(product.nomorResi.toUpperCase(), 20);

    // Order No, SKU, Spec, Resi
    final lines = [
      'NO. PESANAN: $orderNo',
      'NO. RESI: $resi',
      'SKU PLATFORM: ${product.skuPlatform}',
      'SPEC: ${product.spesifikasiProduk}',
      'FILE: ${groupInfo ?? '1-1'}',
    ];

    for (var line in lines) {
      final tp = TextPainter(
        text: TextSpan(text: line, style: textStyleSmall),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      );
      tp.layout(maxWidth: textMaxWidth);
      tp.paint(canvas, Offset(textLeft, yOffset));
      yOffset += tp.height + (padding * 0.1);
    }

    // Qty (Large)
    final qtyText = 'Qty: ${product.jumlahBarang}';
    final qtyTp = TextPainter(
      text: TextSpan(text: qtyText, style: textStyleLarge),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );
    qtyTp.layout(maxWidth: textMaxWidth);
    // Draw Qty at the bottom of the container
    qtyTp.paint(canvas, Offset(textLeft, top + height - qtyTp.height - padding));
  }
}

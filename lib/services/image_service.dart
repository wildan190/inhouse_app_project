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
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart'; // Added for directory picking

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

      // Use a more unique filename including product ID to prevent overwriting in concurrent processing
      final cleanOrderNo = product.noPesanan.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final cleanIdSku = product.idSku.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final outputPath = p.join(outputDir.path, 'merged_${cleanOrderNo}_${cleanIdSku}_${product.id}_${DateTime.now().millisecondsSinceEpoch}.png');

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

      // 2. Calculate FIXED Dimensions for 300 DPI (9cm x 2.5cm)
      const double dpi = 300.0;
      const double cmToInch = 0.393701;
      
      // FIX: Exactly 9cm x 2.5cm at 300 DPI
      final double containerWidthPx = 9 * cmToInch * dpi;   // ~1063 px
      final double containerHeightPx = 2.5 * cmToInch * dpi; // ~295 px
      
      // Vertical padding to give some space around the fixed container on the canvas
      final double verticalPadding = 40.0; 
      final double headerAreaHeight = containerHeightPx + verticalPadding;
      const double gapBetweenHeaderAndImage = 60.0;

      final int canvasWidth = uiImage.width;
      // Ensure canvas is at least as wide as the 9cm container
      final int finalCanvasWidth = canvasWidth < containerWidthPx.toInt() ? containerWidthPx.toInt() + 80 : canvasWidth;
      final int canvasHeight = uiImage.height + headerAreaHeight.toInt() + gapBetweenHeaderAndImage.toInt();

      // 3. Drawing Process (GPU ACCELERATED)
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Position container: Right aligned with a small margin
      final double margin = 40.0;
      final double containerLeft = finalCanvasWidth - containerWidthPx - margin;
      final double containerTop = verticalPadding / 2;

      // Draw Header Background (Exactly 9cm x 2.5cm)
      final paint = Paint()..color = Colors.white;
      canvas.drawRect(
        Rect.fromLTWH(containerLeft, containerTop, containerWidthPx, containerHeightPx), 
        paint
      );

      // Draw QR and Details INSIDE the fixed container
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
      // Center it if the canvas was widened for the header
      double imageX = (finalCanvasWidth - uiImage.width) / 2;
      canvas.drawImage(uiImage, Offset(imageX, headerAreaHeight + gapBetweenHeaderAndImage), Paint());
      
      // Dispose original immediately after drawing
      uiImage.dispose();
      linkedImage?.dispose();

      // 4. Finalize and Save
      final picture = recorder.endRecording();
      final finalImg = await picture.toImage(finalCanvasWidth, canvasHeight);
      
      // toByteData performs the encoding. PNG is lossless as requested.
      final byteData = await finalImg.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        Uint8List buffer = byteData.buffer.asUint8List();
        
        // 5. Inject DPI Metadata (300 DPI) for Photoshop/Print
        // This ensures the file is recognized as 300 DPI instead of 72 DPI
        buffer = _injectDpi(buffer, 300);
        
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

  /// Injects a pHYs chunk into the PNG byte stream to specify DPI.
  /// Standard PNGs from dart:ui don't include DPI metadata, causing them to default to 72 DPI.
  /// 300 DPI = 11811 pixels per meter.
  static Uint8List _injectDpi(Uint8List pngBytes, int dpi) {
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

  /// Saves multiple merged images to a user-selected directory.
  /// Ensures unique filenames for every single item, even with identical order numbers.
  Future<bool> saveMergedImages(List<Product> products) async {
    try {
      print('DEBUG: Starting saveMergedImages for ${products.length} items');
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) {
        print('DEBUG: No directory selected');
        return false;
      }

      final directory = Directory(selectedDirectory);
      int savedCount = 0;
      
      for (var i = 0; i < products.length; i++) {
        final product = products[i];
        if (product.mergedImagePath == null) {
          print('DEBUG: Product ${product.id} has no merged image path, skipping');
          continue;
        }

        final sourceFile = File(product.mergedImagePath!);
        if (!await sourceFile.exists()) {
          print('DEBUG: Source file does not exist: ${product.mergedImagePath}, skipping');
          continue;
        }

        // Construct an EXTREMELY unique filename to prevent any collision
        // Format: [OrderNo]_[IDSKU]_Qty[Qty]_[DatabaseID].png
        final cleanOrderNo = product.noPesanan.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
        final cleanIdSku = product.idSku.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
        
        final fileName = '${cleanOrderNo}_${cleanIdSku}_Qty${product.jumlahBarang}_ID${product.id}.png';
        final targetPath = p.join(directory.path, fileName);

        print('DEBUG: Saving item ${i+1}/${products.length} to $targetPath');
        await sourceFile.copy(targetPath);
        savedCount++;
      }
      
      print('DEBUG: Successfully saved $savedCount files to $selectedDirectory');
      return savedCount > 0;
    } catch (e) {
      print('Error saving merged images: $e');
      return false;
    }
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

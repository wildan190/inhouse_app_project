import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import '../models/product.dart';

class ExcelService {
  Future<List<Product>?> pickAndParseExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      var bytes = file.readAsBytesSync();
      
      Excel? excel;
      try {
        // First, try to normalize the byte stream to handle WPS/MS Excel differences
        final normalizedBytes = _normalizeExcel(bytes);
        excel = Excel.decodeBytes(normalizedBytes);
      } catch (e) {
        print('Excel decode failed after normalization: $e. Attempting aggressive repair...');
        try {
          final repairedBytes = _repairExcel(bytes, aggressive: true);
          if (repairedBytes != null) {
            excel = Excel.decodeBytes(repairedBytes);
            print('Excel aggressively repaired successfully!');
          }
        } catch (repairError) {
          print('Aggressive repair failed: $repairError');
          // Last resort: try to decode original bytes
          try {
            excel = Excel.decodeBytes(bytes);
          } catch (lastError) {
            print('Final attempt failed: $lastError');
            rethrow;
          }
        }
      }

      if (excel == null) return null;

      List<Product> products = [];

      for (var table in excel.tables.keys) {
        var rows = excel.tables[table]!.rows;
        if (rows.isEmpty) continue;

        // Find header row indices
        Map<String, int> headerMap = {};
        var headerRow = rows[0];
        for (int i = 0; i < headerRow.length; i++) {
          var cellValue = headerRow[i]?.value?.toString().trim().toLowerCase();
          if (cellValue != null) {
            headerMap[cellValue] = i;
          }
        }

        // Validate headers (Case-insensitive)
        final requiredHeaders = {
          'sku platform': 'SKU Platform',
          'jumlah barang': 'Jumlah Barang',
          'no. pesanan': 'No. Pesanan',
          'nomor resi': 'Nomor Resi',
          'id produk': 'ID Produk',
          'id sku': 'ID SKU',
          'spesifikasi produk': 'Spesifikasi Produk',
          'tautan gambar produk': 'Tautan Gambar Produk'
        };

        // Parse data rows
        for (int i = 1; i < rows.length; i++) {
          var row = rows[i];
          if (row.isEmpty) continue;

          // Skip if the row is effectively empty
          bool isRowEmpty = true;
          for (var cell in row) {
            if (cell?.value != null && cell!.value.toString().trim().isNotEmpty) {
              isRowEmpty = false;
              break;
            }
          }
          if (isRowEmpty) continue;

          try {
            products.add(Product(
              skuPlatform: _getCellValueByHeader(row, headerMap, 'sku platform'),
              jumlahBarang: int.tryParse(_getCellValueByHeader(row, headerMap, 'jumlah barang')) ?? 0,
              noPesanan: _getCellValueByHeader(row, headerMap, 'no. pesanan'),
              nomorResi: _getCellValueByHeader(row, headerMap, 'nomor resi'),
              idProduk: _getCellValueByHeader(row, headerMap, 'id produk'),
              idSku: _getCellValueByHeader(row, headerMap, 'id sku'),
              spesifikasiProduk: _getCellValueByHeader(row, headerMap, 'spesifikasi produk'),
              tautanGambarProduk: _getCellValueByHeader(row, headerMap, 'tautan gambar produk'),
            ));
          } catch (e) {
            print('Error parsing row $i: $e');
          }
        }
      }
      return products;
    }
    return null;
  }

  /// Normalizes Excel structure to handle differences between WPS, MS Excel, and other exporters.
  List<int> _normalizeExcel(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final newArchive = Archive();

      for (final file in archive) {
        if (!file.isFile) continue;

        // Skip non-essential metadata and visual objects (drawings, media) 
        // that often cause parsing failures when images are embedded in the sheet.
        // We only need the TEXT/URL data, not the physical images inside Excel.
        if (file.name.contains('calcChain.xml') || 
            file.name.contains('printerSettings') || 
            file.name.contains('customProperty') ||
            file.name.contains('drawings/') || 
            file.name.contains('media/') || 
            file.name.endsWith('.vml') ||
            file.name.contains('_rels/drawing')) {
          continue;
        }

        dynamic content = file.content;
        
        // If it's a worksheet, strip drawing tags to prevent crash when physical images are gone
        if (file.name.startsWith('xl/worksheets/sheet') && file.name.endsWith('.xml')) {
          String xml = String.fromCharCodes(content as List<int>);
          // Aggressively remove <drawing ... /> and <legacyDrawing ... /> tags
          xml = xml.replaceAll(RegExp(r'<drawing[^>]*/>'), '');
          xml = xml.replaceAll(RegExp(r'<drawing[^>]*>.*?</drawing>', dotAll: true), '');
          xml = xml.replaceAll(RegExp(r'<legacyDrawing[^>]*/>'), '');
          xml = xml.replaceAll(RegExp(r'<legacyDrawing[^>]*>.*?</legacyDrawing>', dotAll: true), '');
          content = Uint8List.fromList(xml.codeUnits);
        }

        newArchive.addFile(ArchiveFile(file.name, file.size, content));
      }

      return ZipEncoder().encode(newArchive) ?? bytes;
    } catch (e) {
      print('Normalization failed, using original bytes: $e');
      return bytes;
    }
  }

  /// Repairs corrupted Excel files by removing problematic metadata.
  /// If aggressive is true, it removes styles.xml and drawings to ensure raw data can be read.
  List<int>? _repairExcel(List<int> bytes, {bool aggressive = false}) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final newArchive = Archive();
      bool modified = false;

      for (final file in archive) {
        if (!file.isFile) continue;

        // Aggressively remove styles and drawings to fix formatting/object errors
        if (aggressive && (file.name == 'xl/styles.xml' || file.name.contains('drawings/'))) {
          modified = true;
          continue;
        }

        dynamic content = file.content;
        
        // Also strip from sheets in aggressive mode
        if (aggressive && file.name.startsWith('xl/worksheets/sheet') && file.name.endsWith('.xml')) {
          String xml = String.fromCharCodes(content as List<int>);
          xml = xml.replaceAll(RegExp(r'<drawing[^>]*/>'), '');
          xml = xml.replaceAll(RegExp(r'<drawing[^>]*>.*?</drawing>', dotAll: true), '');
          xml = xml.replaceAll(RegExp(r'<legacyDrawing[^>]*/>'), '');
          xml = xml.replaceAll(RegExp(r'<legacyDrawing[^>]*>.*?</legacyDrawing>', dotAll: true), '');
          content = Uint8List.fromList(xml.codeUnits);
          modified = true;
        }

        newArchive.addFile(ArchiveFile(file.name, file.size, content));
      }

      return modified ? ZipEncoder().encode(newArchive) : null;
    } catch (e) {
      print('Repair failed: $e');
      return null;
    }
  }

  String _getCellValueByHeader(List<Data?> row, Map<String, int> headerMap, String headerName) {
    final index = headerMap[headerName];
    if (index == null || index >= row.length) return '';
    return row[index]?.value?.toString().trim() ?? '';
  }
}

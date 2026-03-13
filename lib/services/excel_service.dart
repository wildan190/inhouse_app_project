import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import '../models/product.dart';

class ExcelService {
  Future<File?> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );
    if (result != null) {
      return File(result.files.single.path!);
    }
    return null;
  }

  Future<List<Product>?> parseFile(File file) async {
    final extension = file.path.split('.').last.toLowerCase();
    if (extension == 'csv') {
      return parseCsv(file);
    } else {
      // Try SpreadsheetDecoder first as it's very robust for reading
      try {
        print('Attempting to parse Excel with SpreadsheetDecoder...');
        final products = await _parseExcelWithSpreadsheetDecoder(file);
        if (products != null && products.isNotEmpty) {
          return products;
        }
      } catch (e) {
        print('SpreadsheetDecoder parsing failed: $e. Falling back to standard excel package...');
      }
      
      // Fallback to standard excel package with normalization
      return parseExcel(file);
    }
  }

  Future<List<Product>?> _parseExcelWithSpreadsheetDecoder(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final decoder = SpreadsheetDecoder.decodeBytes(bytes, update: false);
      
      List<Product> products = [];
      
      for (var table in decoder.tables.keys) {
        final rows = decoder.tables[table]!.rows;
        if (rows.isEmpty) continue;

        Map<String, int> headerMap = {};
        final headerRow = rows[0];
        for (int i = 0; i < headerRow.length; i++) {
          final cellValue = headerRow[i]?.toString().trim().toLowerCase();
          if (cellValue != null) {
            headerMap[cellValue] = i;
          }
        }

        for (int i = 1; i < rows.length; i++) {
          final row = rows[i];
          if (row.isEmpty) continue;

          bool isRowEmpty = true;
          for (var cell in row) {
            if (cell != null && cell.toString().trim().isNotEmpty) {
              isRowEmpty = false;
              break;
            }
          }
          if (isRowEmpty) continue;

          products.add(Product(
            skuPlatform: _getSpreadsheetValue(row, headerMap, 'sku platform'),
            jumlahBarang: int.tryParse(_getSpreadsheetValue(row, headerMap, 'jumlah barang')) ?? 0,
            noPesanan: _getSpreadsheetValue(row, headerMap, 'no. pesanan'),
            nomorResi: _getSpreadsheetValue(row, headerMap, 'nomor resi'),
            idProduk: _getSpreadsheetValue(row, headerMap, 'id produk'),
            idSku: _getSpreadsheetValue(row, headerMap, 'id sku'),
            spesifikasiProduk: _getSpreadsheetValue(row, headerMap, 'spesifikasi produk'),
            tautanGambarProduk: _getSpreadsheetValue(row, headerMap, 'tautan gambar produk'),
          ));
        }
      }
      return products;
    } catch (e) {
      print('SpreadsheetDecoder error: $e');
      return null;
    }
  }

  String _getSpreadsheetValue(List<dynamic> row, Map<String, int> headerMap, String headerName) {
    final index = headerMap[headerName];
    if (index == null || index >= row.length) return '';
    return row[index]?.toString().trim() ?? '';
  }

  Future<List<Product>?> parseCsv(File file) async {
    try {
      final input = file.openRead();
      final fields = await input
          .transform(utf8.decoder)
          .transform(CsvToListConverter())
          .toList();

      if (fields.isEmpty) return null;

      List<Product> products = [];
      Map<String, int> headerMap = {};
      var headerRow = fields[0];
      
      for (int i = 0; i < headerRow.length; i++) {
        var cellValue = headerRow[i]?.toString().trim().toLowerCase();
        if (cellValue != null) {
          headerMap[cellValue] = i;
        }
      }

      for (int i = 1; i < fields.length; i++) {
        var row = fields[i];
        if (row.isEmpty) continue;

        try {
          products.add(Product(
            skuPlatform: _getCsvValueByHeader(row, headerMap, 'sku platform'),
            jumlahBarang: int.tryParse(_getCsvValueByHeader(row, headerMap, 'jumlah barang')) ?? 0,
            noPesanan: _getCsvValueByHeader(row, headerMap, 'no. pesanan'),
            nomorResi: _getCsvValueByHeader(row, headerMap, 'nomor resi'),
            idProduk: _getCsvValueByHeader(row, headerMap, 'id produk'),
            idSku: _getCsvValueByHeader(row, headerMap, 'id sku'),
            spesifikasiProduk: _getCsvValueByHeader(row, headerMap, 'spesifikasi produk'),
            tautanGambarProduk: _getCsvValueByHeader(row, headerMap, 'tautan gambar produk'),
          ));
        } catch (e) {
          print('Error parsing CSV row $i: $e');
        }
      }
      return products;
    } catch (e) {
      print('CSV parse failed: $e');
      return null;
    }
  }

  String _getCsvValueByHeader(List<dynamic> row, Map<String, int> headerMap, String headerName) {
    final index = headerMap[headerName];
    if (index == null || index >= row.length) return '';
    return row[index]?.toString().trim() ?? '';
  }

  Future<List<Product>?> parseExcel(File file) async {
    var bytes = file.readAsBytesSync();
    
    excel_pkg.Excel? excel;
    try {
      final normalizedBytes = _normalizeExcel(bytes);
      excel = excel_pkg.Excel.decodeBytes(normalizedBytes);
    } catch (e) {
      print('Excel decode failed after normalization: $e. Attempting aggressive repair...');
      try {
        final repairedBytes = _repairExcel(bytes, aggressive: true);
        if (repairedBytes != null) {
          excel = excel_pkg.Excel.decodeBytes(repairedBytes);
          print('Excel aggressively repaired successfully!');
        }
      } catch (repairError) {
        print('Aggressive repair failed: $repairError');
        try {
          excel = excel_pkg.Excel.decodeBytes(bytes);
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

      Map<String, int> headerMap = {};
      var headerRow = rows[0];
      for (int i = 0; i < headerRow.length; i++) {
        var cellValue = headerRow[i]?.value?.toString().trim().toLowerCase();
        if (cellValue != null) {
          headerMap[cellValue] = i;
        }
      }

      for (int i = 1; i < rows.length; i++) {
        var row = rows[i];
        if (row.isEmpty) continue;

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
          print('Error parsing Excel row $i: $e');
        }
      }
    }
    return products;
  }

  Future<List<Product>?> pickAndParseExcel() async {
    File? file = await pickFile();
    if (file != null) {
      return parseFile(file);
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

        // SKIP NON-ESSENTIAL METADATA for better compatibility (WPS, LibreOffice, MS Excel)
        if (file.name.contains('calcChain.xml') || 
            file.name.contains('printerSettings') || 
            file.name.contains('customProperty') ||
            file.name.contains('drawings/') || 
            file.name.contains('media/') || 
            file.name.contains('theme/') || // Skip themes
            file.name.contains('metadata/') || // Skip metadata
            file.name.contains('customData/') || // Skip WPS custom data
            file.name.endsWith('.vml') ||
            file.name.contains('xl/styles.xml') || // ALWAYS remove styles to avoid corruption
            file.name.contains('_rels/drawing')) {
          continue;
        }

        dynamic content = file.content;
        
        // Strip references to removed objects in rels and sheet files using UTF-8 safe decoding
        if (file.name.endsWith('.rels') || (file.name.startsWith('xl/worksheets/sheet') && file.name.endsWith('.xml'))) {
          try {
            // Use UTF-8 for safe decoding of all characters (including non-ASCII from WPS)
            String xml = utf8.decode(content as List<int>, allowMalformed: true);
            
            // Aggressively remove <drawing ... />, <legacyDrawing ... />, and <s ... /> (style) tags
            xml = xml.replaceAll(RegExp(r'<drawing[^>]*/>'), '');
            xml = xml.replaceAll(RegExp(r'<drawing[^>]*>.*?</drawing>', dotAll: true), '');
            xml = xml.replaceAll(RegExp(r'<legacyDrawing[^>]*/>'), '');
            xml = xml.replaceAll(RegExp(r'<legacyDrawing[^>]*>.*?</legacyDrawing>', dotAll: true), '');
            
            // Remove style references from cells: s="123" -> nothing
            xml = xml.replaceAll(RegExp(r' s="[0-9]*"'), '');
            
            // Remove Relationship references to drawings/styles/themes/metadata
            xml = xml.replaceAll(RegExp(r'<Relationship[^>]*Target="[^"]*(drawing|styles|theme|metadata|calcChain|printerSettings)[^"]*"[^>]*/>'), '');
            
            // WPS specific: strip custom namespaces if causing issues
            xml = xml.replaceAll(RegExp(r' xmlns:wps="[^"]*"'), '');
            xml = xml.replaceAll(RegExp(r'<wps:[^>]*>.*?</wps:[^>]*>', dotAll: true), '');

            content = utf8.encode(xml);
          } catch (e) {
            print('UTF-8 decode failed for ${file.name}, using fallback char codes: $e');
            // Fallback for non-UTF8 XML (rare in .xlsx but possible in some exporters)
            String xml = String.fromCharCodes(content as List<int>);
            xml = xml.replaceAll(RegExp(r' s="[0-9]*"'), '');
            content = Uint8List.fromList(xml.codeUnits);
          }
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

  String _getCellValueByHeader(List<excel_pkg.Data?> row, Map<String, int> headerMap, String headerName) {
    final index = headerMap[headerName];
    if (index == null || index >= row.length) return '';
    return row[index]?.value?.toString().trim() ?? '';
  }
}

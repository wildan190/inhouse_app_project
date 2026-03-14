import 'dart:io';
import 'dart:convert';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import '../models/product.dart';
import 'excel_repair_service.dart';

class ExcelService {
  final ExcelRepairService _repairService = ExcelRepairService();

  Future<File?> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );
    return result != null ? File(result.files.single.path!) : null;
  }

  Future<List<Product>?> parseFile(File file) async {
    final extension = file.path.split('.').last.toLowerCase();
    if (extension == 'csv') return parseCsv(file);
    
    try {
      final products = await _parseExcelWithSpreadsheetDecoder(file);
      if (products != null && products.isNotEmpty) return products;
    } catch (e) {
      print('SpreadsheetDecoder failed: $e. Falling back to standard excel package...');
    }
    return parseExcel(file);
  }

  Future<List<Product>?> _parseExcelWithSpreadsheetDecoder(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final decoder = SpreadsheetDecoder.decodeBytes(bytes, update: false);
      List<Product> products = [];
      
      for (var table in decoder.tables.keys) {
        final rows = decoder.tables[table]!.rows;
        if (rows.isEmpty) continue;
        final headerMap = _buildHeaderMap(rows[0].map((e) => e?.toString()).toList());

        for (int i = 1; i < rows.length; i++) {
          final row = rows[i];
          if (row.isEmpty || _isRowEmpty(row)) continue;
          products.add(_mapToProduct(row, headerMap, (r, h, name) => _getSpreadsheetValue(r, h, name)));
        }
      }
      return products;
    } catch (e) {
      return null;
    }
  }

  Future<List<Product>?> parseCsv(File file) async {
    try {
      final fields = await file.openRead().transform(utf8.decoder).transform(CsvToListConverter()).toList();
      if (fields.isEmpty) return null;
      final headerMap = _buildHeaderMap(fields[0].map((e) => e?.toString()).toList());
      
      List<Product> products = [];
      for (int i = 1; i < fields.length; i++) {
        if (fields[i].isEmpty) continue;
        products.add(_mapToProduct(fields[i], headerMap, (r, h, name) => _getCellValue(r, h, name)));
      }
      return products;
    } catch (e) {
      return null;
    }
  }

  Future<List<Product>?> parseExcel(File file) async {
    var bytes = file.readAsBytesSync();
    excel_pkg.Excel? excel;
    try {
      excel = excel_pkg.Excel.decodeBytes(_repairService.normalizeExcel(bytes));
    } catch (e) {
      try {
        final repaired = _repairService.repairExcel(bytes, aggressive: true);
        if (repaired != null) excel = excel_pkg.Excel.decodeBytes(repaired);
      } catch (_) {
        excel = excel_pkg.Excel.decodeBytes(bytes);
      }
    }
    if (excel == null) return null;

    List<Product> products = [];
    for (var table in excel.tables.keys) {
      var rows = excel.tables[table]!.rows;
      if (rows.isEmpty) continue;
      final headerMap = _buildHeaderMap(rows[0].map((e) => e?.value?.toString()).toList());

      for (int i = 1; i < rows.length; i++) {
        var row = rows[i];
        if (row.isEmpty || _isExcelRowEmpty(row)) continue;
        products.add(_mapToProduct(row, headerMap, (r, h, name) => _getExcelCellValue(r, h, name)));
      }
    }
    return products;
  }

  Map<String, int> _buildHeaderMap(List<String?> headerRow) {
    Map<String, int> headerMap = {};
    for (int i = 0; i < headerRow.length; i++) {
      final val = headerRow[i]?.trim().toLowerCase();
      if (val != null) headerMap[val] = i;
    }
    return headerMap;
  }

  bool _isRowEmpty(List<dynamic> row) => row.every((c) => c == null || c.toString().trim().isEmpty);
  bool _isExcelRowEmpty(List<excel_pkg.Data?> row) => row.every((c) => c?.value == null || c!.value.toString().trim().isEmpty);

  Product _mapToProduct(dynamic row, Map<String, int> headerMap, String Function(dynamic, Map<String, int>, String) getter) {
    return Product(
      skuPlatform: getter(row, headerMap, 'sku platform'),
      jumlahBarang: int.tryParse(getter(row, headerMap, 'jumlah barang')) ?? 0,
      noPesanan: getter(row, headerMap, 'no. pesanan'),
      nomorResi: getter(row, headerMap, 'nomor resi'),
      idProduk: getter(row, headerMap, 'id produk'),
      idSku: getter(row, headerMap, 'id sku'),
      spesifikasiProduk: getter(row, headerMap, 'spesifikasi produk'),
      tautanGambarProduk: getter(row, headerMap, 'tautan gambar produk'),
    );
  }

  String _getSpreadsheetValue(List<dynamic> row, Map<String, int> headerMap, String name) {
    final idx = headerMap[name];
    return (idx != null && idx < row.length) ? row[idx]?.toString().trim() ?? '' : '';
  }

  String _getCellValue(List<dynamic> row, Map<String, int> headerMap, String name) {
    final idx = headerMap[name];
    return (idx != null && idx < row.length) ? row[idx]?.toString().trim() ?? '' : '';
  }

  String _getExcelCellValue(List<excel_pkg.Data?> row, Map<String, int> headerMap, String name) {
    final idx = headerMap[name];
    return (idx != null && idx < row.length) ? row[idx]?.value?.toString().trim() ?? '' : '';
  }
}

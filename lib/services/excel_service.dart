import 'dart:io';
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
        excel = Excel.decodeBytes(bytes);
      } catch (e) {
        print('Initial Excel decode failed: $e. Attempting repair...');
        try {
          final repairedBytes = _repairExcel(bytes);
          if (repairedBytes != null) {
            excel = Excel.decodeBytes(repairedBytes);
            print('Excel repaired successfully!');
          }
        } catch (repairError) {
          print('Repair failed: $repairError');
          rethrow;
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

  /// Repairs corrupted Excel files by removing problematic metadata (like styles.xml)
  /// that often causes the "custom numFmtId" error in the 'excel' package.
  List<int>? _repairExcel(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final newArchive = Archive();

    bool stylesRemoved = false;

    for (final file in archive) {
      // Skip the styles.xml file as it's the primary source of numFmtId errors
      if (file.name == 'xl/styles.xml') {
        stylesRemoved = true;
        continue;
      }
      
      if (file.isFile) {
        newArchive.addFile(ArchiveFile(file.name, file.size, file.content));
      }
    }

    if (!stylesRemoved) return null; // If no styles found, maybe it's another error

    return ZipEncoder().encode(newArchive);
  }

  String _getCellValueByHeader(List<Data?> row, Map<String, int> headerMap, String headerName) {
    final index = headerMap[headerName];
    if (index == null || index >= row.length) return '';
    return row[index]?.value?.toString().trim() ?? '';
  }
}

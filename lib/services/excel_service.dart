import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
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
      var excel = Excel.decodeBytes(bytes);

      List<Product> products = [];

      for (var table in excel.tables.keys) {
        var rows = excel.tables[table]!.rows;
        if (rows.isEmpty) continue;

        // Find header row indices
        Map<String, int> headerMap = {};
        var headerRow = rows[0];
        for (int i = 0; i < headerRow.length; i++) {
          var cellValue = headerRow[i]?.value?.toString().trim();
          if (cellValue != null) {
            headerMap[cellValue] = i;
          }
        }

        // Validate headers
        List<String> requiredHeaders = [
          'SKU Platform',
          'Jumlah Barang',
          'No. Pesanan',
          'Nomor Resi',
          'ID Produk',
          'ID SKU',
          'Spesifikasi Produk',
          'Tautan Gambar Produk'
        ];

        for (var header in requiredHeaders) {
          if (!headerMap.containsKey(header)) {
            // Optional: handle missing headers more gracefully or throw error
            print('Missing header: $header');
          }
        }

        // Parse data rows
        for (int i = 1; i < rows.length; i++) {
          var row = rows[i];
          if (row.isEmpty) continue;

          try {
            products.add(Product(
              skuPlatform: _getCellValue(row, headerMap['SKU Platform']),
              jumlahBarang: int.tryParse(_getCellValue(row, headerMap['Jumlah Barang'])) ?? 0,
              noPesanan: _getCellValue(row, headerMap['No. Pesanan']),
              nomorResi: _getCellValue(row, headerMap['Nomor Resi']),
              idProduk: _getCellValue(row, headerMap['ID Produk']),
              idSku: _getCellValue(row, headerMap['ID SKU']),
              spesifikasiProduk: _getCellValue(row, headerMap['Spesifikasi Produk']),
              tautanGambarProduk: _getCellValue(row, headerMap['Tautan Gambar Produk']),
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

  String _getCellValue(List<Data?> row, int? index) {
    if (index == null || index >= row.length) return '';
    return row[index]?.value?.toString() ?? '';
  }
}

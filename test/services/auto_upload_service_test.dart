import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:inhouse_export/models/product.dart';
import 'package:inhouse_export/services/auto_upload_service.dart';

void main() {
  late AutoUploadService autoUploadService;

  setUp(() {
    autoUploadService = AutoUploadService();
  });

  group('AutoUploadService - Matching Logic', () {
    test('should match products with files case-sensitively', () {
      final products = [
        Product(
          id: 1,
          skuPlatform: 'SKU123',
          idSku: 'ID456',
          jumlahBarang: 1,
          noPesanan: 'ORD1',
          nomorResi: 'RESI1',
          idProduk: 'PROD1',
          spesifikasiProduk: 'Spec1',
          tautanGambarProduk: '',
        ),
        Product(
          id: 2,
          skuPlatform: 'sku123', // lowercase version
          idSku: 'id456',
          jumlahBarang: 1,
          noPesanan: 'ORD2',
          nomorResi: 'RESI2',
          idProduk: 'PROD2',
          spesifikasiProduk: 'Spec2',
          tautanGambarProduk: '',
        ),
      ];

      final files = [
        File('path/to/SKU123.png'),
      ];

      final matches = autoUploadService.matchProductsWithFiles(products, files);

      // Should only match the uppercase SKU
      expect(matches.length, 1);
      expect(matches.containsKey(1), true);
      expect(matches.containsKey(2), false);
      expect(matches[1]!.path, contains('SKU123.png'));
    });

    test('should prioritize SKU Platform over ID SKU', () {
      final products = [
        Product(
          id: 1,
          skuPlatform: 'PRIMARY_SKU',
          idSku: 'SECONDARY_ID',
          jumlahBarang: 1,
          noPesanan: 'ORD1',
          nomorResi: 'RESI1',
          idProduk: 'PROD1',
          spesifikasiProduk: 'Spec1',
          tautanGambarProduk: '',
        ),
      ];

      final files = [
        File('path/to/PRIMARY_SKU.png'),
        File('path/to/SECONDARY_ID.png'),
      ];

      final matches = autoUploadService.matchProductsWithFiles(products, files);

      expect(matches.length, 1);
      expect(matches[1]!.path, contains('PRIMARY_SKU.png'));
    });

    test('should match with ID SKU if SKU Platform is not found', () {
      final products = [
        Product(
          id: 1,
          skuPlatform: 'NON_EXISTENT',
          idSku: 'EXISTENT_ID',
          jumlahBarang: 1,
          noPesanan: 'ORD1',
          nomorResi: 'RESI1',
          idProduk: 'PROD1',
          spesifikasiProduk: 'Spec1',
          tautanGambarProduk: '',
        ),
      ];

      final files = [
        File('path/to/EXISTENT_ID.jpg'),
      ];

      final matches = autoUploadService.matchProductsWithFiles(products, files);

      expect(matches.length, 1);
      expect(matches[1]!.path, contains('EXISTENT_ID.jpg'));
    });

    test('should return empty map if no matches found', () {
      final products = [
        Product(
          id: 1,
          skuPlatform: 'SKU_A',
          idSku: 'ID_A',
          jumlahBarang: 1,
          noPesanan: 'ORD1',
          nomorResi: 'RESI1',
          idProduk: 'PROD1',
          spesifikasiProduk: 'Spec1',
          tautanGambarProduk: '',
        ),
      ];

      final files = [
        File('path/to/DIFFERENT_NAME.png'),
      ];

      final matches = autoUploadService.matchProductsWithFiles(products, files);

      expect(matches.isEmpty, true);
    });
  });
}

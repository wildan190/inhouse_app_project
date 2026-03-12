class Product {
  final int? id;
  final String skuPlatform;
  final int jumlahBarang;
  final String noPesanan;
  final String nomorResi;
  final String idProduk;
  final String idSku;
  final String spesifikasiProduk;
  final String tautanGambarProduk;
  final String? localImagePath;
  final String? mergedImagePath;
  final String? status; // e.g., 'pending', 'processing', 'completed'
  final DateTime? createdAt;

  Product({
    this.id,
    required this.skuPlatform,
    required this.jumlahBarang,
    required this.noPesanan,
    required this.nomorResi,
    required this.idProduk,
    required this.idSku,
    required this.spesifikasiProduk,
    required this.tautanGambarProduk,
    this.localImagePath,
    this.mergedImagePath,
    this.status = 'pending',
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sku_platform': skuPlatform,
      'jumlah_barang': jumlahBarang,
      'no_pesanan': noPesanan,
      'nomor_resi': nomorResi,
      'id_produk': idProduk,
      'id_sku': idSku,
      'spesifikasi_produk': spesifikasiProduk,
      'tautan_gambar_produk': tautanGambarProduk,
      'local_image_path': localImagePath,
      'merged_image_path': mergedImagePath,
      'status': status,
      'created_at': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      skuPlatform: map['sku_platform'],
      jumlahBarang: map['jumlah_barang'],
      noPesanan: map['no_pesanan'],
      nomorResi: map['nomor_resi'],
      idProduk: map['id_produk'],
      idSku: map['id_sku'],
      spesifikasiProduk: map['spesifikasi_produk'],
      tautanGambarProduk: map['tautan_gambar_produk'],
      localImagePath: map['local_image_path'],
      mergedImagePath: map['merged_image_path'],
      status: map['status'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }
}

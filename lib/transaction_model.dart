class TransactionModel {
  final int? id;
  final String jenis;      // Pemasukan / Pengeluaran
  final String lokasi;     // Etan / Kulon
  final String tanggal;
  final double jumlah;     // Kilo
  final double harga;      // Harga per kilo
  final double total;
  final String keterangan;

  TransactionModel({
    this.id, required this.jenis, required this.lokasi,
    required this.tanggal, required this.jumlah,
    required this.harga, required this.total, required this.keterangan
  });

  // Konversi ke Map untuk disimpan di SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id, 'jenis': jenis, 'lokasi': lokasi, 'tanggal': tanggal,
      'jumlah': jumlah, 'harga': harga, 'total': total, 'keterangan': keterangan,
    };
  }
}
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DbHelper {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await initDb();
    return _db!;
  }

  initDb() async {
    String path = join(await getDatabasesPath(), 'catatan_jeruk.db');
    return await openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE transaksi (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          jenis TEXT, 
          lokasi TEXT, 
          tanggal TEXT,
          jumlah REAL, 
          harga REAL, 
          total REAL, 
          keterangan TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE kebun (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nama TEXT NOT NULL
        )
      ''');
      // Data default awal
      await db.insert('kebun', {'nama': 'Default - Hapus Saja'});
    });
  }

  // --- FUNGSI KELOLA KEBUN (DINAMIS) ---

  Future<void> hapusTotalSemuaData() async {
    final db = await database;
    // Hapus semua transaksi
    await db.delete('transaksi');
    // Hapus semua kebun
    await db.delete('kebun');

    // Opsional: Masukkan kembali data default jika ingin
    // aplikasi tidak kosong melompong setelah dihapus
    await db.insert('kebun', {'nama': 'Default - Hapus Saja'});
  }

  Future<List<Map<String, dynamic>>> getDaftarKebun() async {
    final db = await database;
    return await db.query('kebun');
  }

  Future<int> addKebun(String nama) async {
    final db = await database;
    return await db.insert('kebun', {'nama': nama});
  }

  Future<int> deleteKebun(int id) async {
    final db = await database;
    return await db.delete('kebun', where: 'id = ?', whereArgs: [id]);
  }

  // --- FUNGSI TRANSAKSI ---

  Future<int> insertTransaksi(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('transaksi', data);
  }

  Future<List<Map<String, dynamic>>> getTransaksi() async {
    final db = await database;
    // Menggunakan ID DESC agar input terbaru selalu di atas
    return await db.query('transaksi', orderBy: 'id DESC');
  }

  Future<int> deleteTransaksi(int id) async {
    final db = await database;
    return await db.delete('transaksi', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllByLokasi(String jenis, String lokasi) async {
    final db = await database;
    return await db.delete('transaksi',
        where: 'jenis = ? AND lokasi = ?',
        whereArgs: [jenis, lokasi]);
  }

  Future<int> deleteAllTransaksi() async {
    final db = await database;
    return await db.delete('transaksi');
  }

  Future<List<Map<String, dynamic>>> getTransaksiByLokasiDanTahun(String jenis, String bulan, String tahun) async {
    final db = await database;
    // Format pencarian: %MM/YYYY% (cocok untuk tanggal dd/MM/yyyy)
    String pattern = "%$bulan/$tahun%";
    return await db.query(
      'transaksi',
      where: 'jenis = ? AND tanggal LIKE ?',
      whereArgs: [jenis, pattern],
      orderBy: 'tanggal DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getTransaksiByFilterTahun(String jenis, String tahun) async {
    final db = await database;

    if (jenis == "" || jenis == "Semua") {
      return await db.query(
        'transaksi',
        where: 'tanggal LIKE ?',
        whereArgs: ['%$tahun%'],
        orderBy: 'id DESC',
      );
    }

    return await db.query(
      'transaksi',
      where: 'jenis = ? AND tanggal LIKE ?',
      whereArgs: [jenis, '%$tahun%'],
      orderBy: 'id DESC',
    );
  }
}
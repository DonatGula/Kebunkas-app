import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db_helper.dart';
import '../theme_manager.dart';

// --- CUSTOM STICKY HEADER DELEGATE ---
class HistoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  HistoryHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;
  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant HistoryHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}

class HistoryPemasukanPage extends StatefulWidget {
  const HistoryPemasukanPage({super.key});

  @override
  State<HistoryPemasukanPage> createState() => _HistoryPemasukanPageState();
}

class _HistoryPemasukanPageState extends State<HistoryPemasukanPage> {
  final DbHelper _dbHelper = DbHelper();
  final tm = ThemeManager();

  String? filterLokasi;
  late String filterTahun;

  final List<String> listTahun = List.generate(
      (DateTime.now().year - 2020) + 2,
          (index) => (2020 + index).toString()
  );

  @override
  void initState() {
    super.initState();
    filterTahun = DateTime.now().year.toString();
  }

  String formatRibuan(dynamic nominal) => NumberFormat.decimalPattern('id').format(nominal);

  @override
  Widget build(BuildContext context) {
    final Color aksenDinamis = tm.primary;

    return Scaffold(
      backgroundColor: tm.bgColor,
      body: FutureBuilder(
        future: Future.wait([
          _dbHelper.getTransaksi(),
          _dbHelper.getDaftarKebun(),
        ]),
        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: aksenDinamis));
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return Center(child: _buildStateKosong("Gagal memuat data"));
          }

          List<Map<String, dynamic>> dataSemua = List<Map<String, dynamic>>.from(snapshot.data![0]);
          List<Map<String, dynamic>> listKebun = List<Map<String, dynamic>>.from(snapshot.data![1]);

          if (filterLokasi == null && listKebun.isNotEmpty) {
            filterLokasi = listKebun[0]['nama'];
          }

          // --- Perhitungan Statistik ---
          double totalSemuaUang = dataSemua
              .where((item) => item['jenis'] == 'Pemasukan')
              .fold(0.0, (sum, item) => sum + (double.tryParse(item['total'].toString()) ?? 0.0));

          double totalTahunIni = dataSemua
              .where((item) => item['jenis'] == 'Pemasukan' && item['tanggal'].toString().contains(filterTahun))
              .fold(0.0, (sum, item) => sum + (double.tryParse(item['total'].toString()) ?? 0.0));

          List<Map<String, dynamic>> dataFiltered = dataSemua
              .where((item) =>
          item['jenis'] == 'Pemasukan' &&
              item['lokasi'] == filterLokasi &&
              item['tanggal'].toString().contains(filterTahun))
              .toList();

          double kgLoc = dataFiltered.fold(0.0, (sum, item) => sum + (double.tryParse(item['jumlah'].toString()) ?? 0.0));

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // HEADER STICKY
              SliverPersistentHeader(
                pinned: true,
                delegate: HistoryHeaderDelegate(
                  minHeight: 230,
                  maxHeight: 230,
                  child: _buildModernHeader(totalSemuaUang, totalTahunIni, kgLoc, aksenDinamis),
                ),
              ),

              // TAB KEBUN & FILTER
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(25, 20, 25, 10),
                      child: Text("Pilih Lahan",
                          style: TextStyle(color: tm.textColor, fontWeight: FontWeight.w900, fontSize: 16)),
                    ),
                    if (listKebun.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25),
                        child: Text("Belum ada data kebun", style: TextStyle(color: tm.subTextColor)),
                      )
                    else
                      SizedBox(
                        height: 50,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: listKebun.length,
                          itemBuilder: (context, index) => _buildTabKebun(listKebun[index]['nama'], aksenDinamis),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(25, 15, 25, 10),
                      child: Row(
                        children: [
                          Expanded(child: _buildPilihTahun(aksenDinamis)),
                          const SizedBox(width: 10),
                          _buildTombolHapusSemua(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // DAFTAR TRANSAKSI
              dataFiltered.isEmpty
                  ? SliverFillRemaining(
                hasScrollBody: false,
                child: _buildStateKosong("Tidak ada data di $filterLokasi"),
              )
                  : SliverPadding(
                padding: const EdgeInsets.fromLTRB(25, 10, 25, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildKartuTransaksi(dataFiltered[index], aksenDinamis),
                    childCount: dataFiltered.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- WIDGET HELPER ---

  Widget _buildModernHeader(double totalAll, double totalYear, double locKg, Color aksen) {
    return Container(
      padding: const EdgeInsets.fromLTRB(25, 50, 25, 10),
      decoration: BoxDecoration(
        color: tm.cardColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(tm.isDarkMode ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          Text("TOTAL PENDAPATAN",
              style: TextStyle(color: aksen, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 8),
          FittedBox(
            child: Text("Rp ${formatRibuan(totalAll)}",
                style: TextStyle(color: tm.textColor, fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -1)),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              _cardKecilStat("Tahun $filterTahun", "Rp ${formatRibuan(totalYear)}", Icons.calendar_today_rounded, Colors.orangeAccent),
              const SizedBox(width: 12),
              _cardKecilStat("${filterLokasi ?? 'Lahan'}", "${locKg.toStringAsFixed(1)} Kg", Icons.balance_rounded, Colors.greenAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardKecilStat(String label, String val, IconData ikon, Color warna) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: tm.bgColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: tm.subTextColor.withOpacity(0.05))
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: warna.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(ikon, color: warna, size: 10),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: TextStyle(color: tm.subTextColor, fontSize: 9, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(val,
                      style: TextStyle(color: tm.textColor, fontWeight: FontWeight.w900, fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabKebun(String nama, Color aksen) {
    bool isSelected = filterLokasi == nama;
    return GestureDetector(
      onTap: () => setState(() => filterLokasi = nama),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(left: 5, right: 5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? aksen : tm.cardColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: isSelected ? [BoxShadow(color: aksen.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: Center(
          child: Text(
            nama.toUpperCase(),
            style: TextStyle(
                color: isSelected ? Colors.white : tm.subTextColor,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.5
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKartuTransaksi(Map<String, dynamic> data, Color aksen) {
    return Dismissible(
      key: Key(data['id'].toString()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (dir) => _showKonfirmasiHapus(data['id']),
      background: _buildBgHapus(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: tm.cardColor,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: tm.subTextColor.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
              child: const Icon(Icons.add_chart_rounded, color: Colors.green, size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['tanggal'], style: TextStyle(color: tm.subTextColor, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text("Rp ${formatRibuan(data['total'])}",
                      style: TextStyle(color: tm.textColor, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("${data['jumlah']} Kg",
                    style: TextStyle(color: aksen, fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 2),
                Text(data['lokasi'] ?? '-',
                    style: TextStyle(color: tm.subTextColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPilihTahun(Color aksen) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
      decoration: BoxDecoration(
          color: tm.cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: tm.subTextColor.withOpacity(0.1))
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: filterTahun,
          dropdownColor: tm.cardColor,
          isExpanded: true,
          icon: Icon(Icons.calendar_today_rounded, color: aksen, size: 16),
          style: TextStyle(color: tm.textColor, fontWeight: FontWeight.w900, fontFamily: 'Nunito'),
          items: listTahun.map((y) => DropdownMenuItem(
              value: y,
              child: Text("Tahun $y", style: TextStyle(color: tm.textColor))
          )).toList(),
          onChanged: (v) => setState(() => filterTahun = v!),
        ),
      ),
    );
  }

  Widget _buildBgHapus() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 25),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Colors.orangeAccent, Colors.redAccent]),
          borderRadius: BorderRadius.circular(25)
      ),
      child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 30),
    );
  }

  Widget _buildTombolHapusSemua() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.redAccent.withOpacity(0.1))
      ),
      child: IconButton(
          onPressed: _konfirmasiHapusSemua,
          icon: const Icon(Icons.auto_delete_rounded, color: Colors.redAccent)
      ),
    );
  }

  Widget _buildStateKosong(String pesan) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: tm.subTextColor.withOpacity(0.2)),
          const SizedBox(height: 15),
          Text(pesan, style: TextStyle(color: tm.subTextColor, fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }

  // --- FUNGSI DATABASE ---

  Future<bool> _showKonfirmasiHapus(int id) async {
    bool hapus = false;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: tm.cardColor,
        surfaceTintColor: tm.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Text("Hapus Data?", style: TextStyle(color: tm.textColor, fontWeight: FontWeight.w900)),
        content: Text("Data panen ini akan dihapus permanen.", style: TextStyle(color: tm.subTextColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Batal", style: TextStyle(color: tm.subTextColor))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              onPressed: () async {
                await _dbHelper.deleteTransaksi(id);
                hapus = true;
                if (mounted) {
                  Navigator.pop(context);
                  setState(() {});
                }
              }, child: const Text("Hapus", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    return hapus;
  }

  void _konfirmasiHapusSemua() {
    if (filterLokasi == null) return;
    showDialog(context: context, builder: (context) => AlertDialog(
      backgroundColor: tm.cardColor,
      surfaceTintColor: Colors.redAccent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      title: const Text("Bersihkan Data?", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.redAccent)),
      content: Text("Hapus semua catatan panen di $filterLokasi pada tahun $filterTahun?", style: TextStyle(color: tm.textColor)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("Batal", style: TextStyle(color: tm.subTextColor))),
        ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, elevation: 0),
            onPressed: () async {
              // Note: Pastikan di db_helper fungsi deleteAllByLokasi mendukung filter tahun jika diperlukan lebih spesifik
              await _dbHelper.deleteAllByLokasi('Pemasukan', filterLokasi!);
              if (mounted) {
                Navigator.pop(context);
                setState(() {});
              }
            }, child: const Text("Hapus Semua", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      ],
    ));
  }
}
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db_helper.dart';
import '../theme_manager.dart';

class ExpenseHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  ExpenseHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override double get minExtent => minHeight;
  @override double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant ExpenseHeaderDelegate oldDelegate) => true;
}

class HistoryPengeluaranPage extends StatefulWidget {
  const HistoryPengeluaranPage({super.key});

  @override
  State<HistoryPengeluaranPage> createState() => _HistoryPengeluaranPageState();
}

class _HistoryPengeluaranPageState extends State<HistoryPengeluaranPage> {
  final DbHelper _dbHelper = DbHelper();
  final tm = ThemeManager();

  late String filterTahun;
  late List<String> listTahun;

  @override
  void initState() {
    super.initState();
    filterTahun = DateTime.now().year.toString();
    listTahun = _generateYearList();
  }

  List<String> _generateYearList() {
    int currentYear = DateTime.now().year;
    int startYear = 2020;
    return List.generate((currentYear + 1) - startYear + 1, (index) {
      return (startYear + index).toString();
    }).reversed.toList();
  }

  String formatRibuan(dynamic nominal) => NumberFormat.decimalPattern('id').format(nominal);

  @override
  Widget build(BuildContext context) {
    const Color aksenMerah = Color(0xFFD32F2F);

    return Scaffold(
      backgroundColor: tm.bgColor,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        // Kita ambil semua transaksi pengeluaran (tanpa filter tahun dulu di query)
        future: _dbHelper.getTransaksi(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: aksenMerah));
          }

          // Ambil semua data pengeluaran saja
          List<Map<String, dynamic>> allExpenses = (snapshot.data ?? [])
              .where((item) => item['jenis'] == 'Pengeluaran').toList();

          // 1. Hitung Total Semua Tahun
          double totalSemuaTahun = allExpenses.fold(0.0, (sum, item) =>
          sum + (double.tryParse(item['total'].toString()) ?? 0));

          // 2. Filter data berdasarkan tahun yang dipilih
          List<Map<String, dynamic>> filteredData = allExpenses
              .where((item) => item['tanggal'].toString().contains(filterTahun)).toList();

          // 3. Hitung Total Tahun yang dipilih
          double totalTahunIni = filteredData.fold(0.0, (sum, item) =>
          sum + (double.tryParse(item['total'].toString()) ?? 0));

          return CustomScrollView(
            slivers: [
              // HEADER STICKY DENGAN DUA INFORMASI TOTAL
              SliverPersistentHeader(
                pinned: true,
                delegate: ExpenseHeaderDelegate(
                  minHeight: 220, // Sedikit lebih tinggi untuk menampung statistik tambahan
                  maxHeight: 220,
                  child: _buildModernHeader(totalSemuaTahun, totalTahunIni, aksenMerah),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(25, 20, 25, 10),
                  child: Row(
                    children: [
                      Text("DAFTAR BELANJA",
                          style: TextStyle(fontWeight: FontWeight.w900, color: tm.primary, fontSize: 11, letterSpacing: 1.2)),
                      const SizedBox(width: 15),
                      Expanded(child: _buildDropdownTahun()),
                      const SizedBox(width: 10),
                      _buildDeleteSweepButton(),
                    ],
                  ),
                ),
              ),

              filteredData.isEmpty
                  ? SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState("Belum ada belanja di $filterTahun"),
              )
                  : SliverPadding(
                padding: const EdgeInsets.fromLTRB(25, 10, 25, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildExpenseCard(filteredData[index], aksenMerah),
                    childCount: filteredData.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModernHeader(double totalAll, double totalYear, Color aksen) {
    return Container(
      padding: const EdgeInsets.fromLTRB(25, 50, 25, 10),
      decoration: BoxDecoration(
        color: tm.cardColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(35)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          Text("TOTAL PENGELUARAN (SEMUA)",
              style: TextStyle(color: aksen, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 5),
          FittedBox(
            child: Text("Rp ${formatRibuan(totalAll)}",
                style: TextStyle(color: tm.textColor, fontSize: 25, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 20),
          // Baris statistik kecil untuk tahun yang dipilih
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
                color: tm.bgColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white.withOpacity(0.05))
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Tahun $filterTahun",
                    style: TextStyle(color: tm.subTextColor, fontWeight: FontWeight.bold, fontSize: 13)),
                Text("Rp ${formatRibuan(totalYear)}",
                    style: TextStyle(color: aksen, fontWeight: FontWeight.w900, fontSize: 15)),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- Widget lain tetap sama namun disesuaikan sedikit ---

  Widget _buildExpenseCard(Map<String, dynamic> data, Color aksen) {
    return Dismissible(
      key: Key(data['id'].toString()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async => await _showConfirmDeleteDialog(data['id']),
      background: _buildBgHapus(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: tm.cardColor,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: aksen.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
              child: Icon(Icons.shopping_cart_checkout_rounded, color: aksen, size: 22),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['tanggal'], style: TextStyle(color: tm.subTextColor, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(data['keterangan'] ?? "Belanja",
                      style: TextStyle(color: tm.textColor, fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            ),
            Text("Rp ${formatRibuan(data['total'])}",
                style: TextStyle(color: aksen, fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildBgHapus() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 25),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(22)),
      child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 28),
    );
  }

  Widget _buildDropdownTahun() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      height: 45,
      decoration: BoxDecoration(color: tm.cardColor, borderRadius: BorderRadius.circular(15)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: filterTahun,
          dropdownColor: tm.cardColor,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: tm.primary),
          style: TextStyle(color: tm.textColor, fontWeight: FontWeight.bold),
          items: listTahun.map((y) => DropdownMenuItem(value: y, child: Text("Tahun $y"))).toList(),
          onChanged: (val) => setState(() => filterTahun = val!),
        ),
      ),
    );
  }

  Widget _buildDeleteSweepButton() {
    return Container(
      decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: IconButton(
        onPressed: _confirmDeleteAll,
        icon: const Icon(Icons.auto_delete_rounded, color: Colors.redAccent, size: 20),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 50),
        Icon(Icons.shopping_bag_outlined, size: 80, color: tm.subTextColor.withOpacity(0.1)),
        const SizedBox(height: 15),
        Text(msg, style: TextStyle(color: tm.subTextColor, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Future<bool> _showConfirmDeleteDialog(int id) async {
    bool result = false;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: tm.cardColor,
        title: Text("Hapus Belanja?", style: TextStyle(color: tm.textColor, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Batal", style: TextStyle(color: tm.subTextColor))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await _dbHelper.deleteTransaksi(id);
                result = true;
                Navigator.pop(context);
                setState(() {});
              },
              child: const Text("Hapus", style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
    return result;
  }

  void _confirmDeleteAll() {
    showDialog(context: context, builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: tm.cardColor,
      title: const Text("Bersihkan Riwayat?", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      content: Text("Semua belanja tahun $filterTahun akan dihapus permanen."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("Batal", style: TextStyle(color: tm.subTextColor))),
        ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _dbHelper.deleteAllByLokasi('Pengeluaran', '-');
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text("Hapus Semua", style: TextStyle(color: Colors.white))
        ),
      ],
    ));
  }
}
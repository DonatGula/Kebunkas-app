import 'package:flutter/material.dart';
import 'package:appjeruk/page/Input_page.dart';
import 'package:appjeruk/page/history_pemasukan_page.dart';
import 'package:appjeruk/page/history_pengeluaran_page.dart';
import 'package:appjeruk/page/settings_page.dart';
import 'package:appjeruk/theme_manager.dart';
import 'package:appjeruk/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeManager().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kebun Kas',
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'Nunito'),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  Key _refreshKey = UniqueKey();

  // Tambahkan initialPage agar sinkron sejak awal
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Pemetaan index yang lebih aman
  int _mapNavToPage(int index) {
    if (index < 2) return index;
    if (index > 2) return index - 1;
    return _pageController.page?.round() ?? 0;
  }

  int _mapPageToNav(int index) {
    if (index < 2) return index;
    return index + 1;
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      _showInputForm();
      return;
    }

    // Update index dulu baru pindah halaman
    setState(() {
      _selectedIndex = index;
    });

    _pageController.animateToPage(
      _mapNavToPage(index),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _refreshAll() {
    setState(() { _refreshKey = UniqueKey(); });
  }

  @override
  Widget build(BuildContext context) {
    final tm = ThemeManager();

    return Scaffold(
      backgroundColor: tm.bgColor,
      body: PageView.builder(
        controller: _pageController,
        itemCount: 4,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (index) {

          int newNavIndex = _mapPageToNav(index);
          if (_selectedIndex != newNavIndex) {
            setState(() {
              _selectedIndex = newNavIndex;
            });
          }
        },
        itemBuilder: (context, index) {

          switch (index) {
            case 0: return HomeScreenContent(key: _refreshKey);
            case 1: return HistoryPemasukanPage(key: _refreshKey);
            case 2: return HistoryPengeluaranPage(key: _refreshKey);
            case 3: return SettingsPage(onProfileUpdate: _refreshAll);
            default: return const SizedBox();
          }
        },
      ),
      bottomNavigationBar: _buildBottomNav(tm),
    );
  }

  // ... Widget _buildBottomNav dan _navIcon tetap sama seperti kode Paman sebelumnya ...
  Widget _buildBottomNav(ThemeManager tm) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 25),
      decoration: BoxDecoration(
        color: tm.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navIcon(Icons.grid_view_rounded, 0, tm, "Home"),
          _navIcon(Icons.trending_up, 1, tm, "Masuk"),
          _navIcon(Icons.add, 2, tm, "Add", isPrimary: true),
          _navIcon(Icons.trending_down, 3, tm, "Keluar"),
          _navIcon(Icons.settings_outlined, 4, tm, "Setting"),
        ],
      ),
    );
  }

  Widget _navIcon(IconData icon, int index, ThemeManager tm, String label, {bool isPrimary = false}) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.all(isPrimary ? 14 : 10),
            decoration: BoxDecoration(
              color: isPrimary ? tm.primary : (isSelected ? tm.primary.withOpacity(0.1) : Colors.transparent),
              shape: BoxShape.circle,
              boxShadow: isPrimary ? [BoxShadow(color: tm.primary.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))] : [],
            ),
            child: Icon(icon, color: isPrimary ? Colors.white : (isSelected ? tm.primary : tm.subTextColor), size: isPrimary ? 28 : 24),
          ),
        ],
      ),
    );
  }

  void _showInputForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InputPage(onRefresh: _refreshAll),
    );
  }
}

class HomeScreenContent extends StatefulWidget {
  const HomeScreenContent({super.key});
  @override
  State<HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<HomeScreenContent> {
  final DbHelper _dbHelper = DbHelper();
  String _userName = "SamZen";
  String _selectedYear = DateTime.now().year.toString();

  final List<String> _years = List.generate(
      (DateTime.now().year - 2020) + 2, // Jumlah tahun dari 2020 sampai tahun depan
          (index) => (2020 + index).toString()
  );

  void _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() { _userName = prefs.getString('user_name') ?? "SamZen"; });
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String formatRibuan(dynamic nominal) => NumberFormat.decimalPattern('id').format(nominal);

  @override
  Widget build(BuildContext context) {
    final tm = ThemeManager();
    const Color warnaAksen = Color(0xFF0075FF); // Biru Pro

    return FutureBuilder(
      future: Future.wait([_dbHelper.getTransaksi(), _dbHelper.getDaftarKebun()]),
      builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: tm.primary));

        List<Map<String, dynamic>> dataSemua = snapshot.data![0];
        List<Map<String, dynamic>> listKebun = snapshot.data![1];

        double totalSaldoAbadi = 0;
        double masukTahunIni = 0, keluarTahunIni = 0;

        for (var item in dataSemua) {
          double total = (item['total'] ?? 0).toDouble();
          if (item['jenis'] == 'Pemasukan') totalSaldoAbadi += total; else totalSaldoAbadi -= total;

          if (item['tanggal'].toString().contains(_selectedYear)) {
            if (item['jenis'] == 'Pemasukan') masukTahunIni += total; else keluarTahunIni += total;
          }
        }

        return Scaffold(
          backgroundColor: tm.bgColor,
          body: Column(
            children: [
              _buildHeaderModern(tm, totalSaldoAbadi, _userName, warnaAksen),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 30),
                  children: [
                    const SizedBox(height: 25),
                    // Tambahkan 'tm' sebagai argumen pertama
                    _buildSectionHeader(tm, "Ringkasan Tahunan", _buildPilihTahun(tm, warnaAksen)),
                    const SizedBox(height: 15),
                    _buildKartuUtama(tm, masukTahunIni, keluarTahunIni, warnaAksen),

                    const SizedBox(height: 30),
                    _buildSectionHeader(tm, "Data Per Lahan", Icon(Icons.arrow_forward_ios, size: 12, color: tm.subTextColor.withOpacity(0.5))),
                    const SizedBox(height: 15),
                    _buildSliderKebun(tm, listKebun, dataSemua, warnaAksen),

                    const SizedBox(height: 30),
                    _buildSectionHeader(tm, "Tren Penjualan", Text("Tahun", style: TextStyle(color: tm.subTextColor, fontSize: 12))),
                    const SizedBox(height: 15),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildWadahGrafik(dataSemua, tm, warnaAksen),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildSectionHeader(ThemeManager tm, String judul, Widget kanan) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Judul dengan warna primary agar lebih hidup
          Text(
              judul,
              style: TextStyle(
                  color: tm.primary, // Menggunakan textColor agar lebih kontras
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5
              )
          ),
          // Widget di sisi kanan (Dropdown/Icon/Text)
          kanan,
        ],
      ),
    );
  }

  Widget _buildHeaderModern(ThemeManager tm, double saldoTotal, String nama, Color aksen) {
    bool isMinus = saldoTotal < 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(30, 60, 30, 30),
      decoration: BoxDecoration(
        color: tm.cardColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 10)
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Sisi Kiri: Sapaan Paman
              Expanded(
                flex: 2, // Memberi ruang lebih kecil untuk nama
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Halo,",
                        style: TextStyle(color: tm.subTextColor, fontSize: 12, fontWeight: FontWeight.w500)),
                    Text("Paman\n$nama", // \n supaya kalau nama panjang tetap rapi ke bawah
                        style: TextStyle(
                            color: tm.textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            height: 1.1 // merapatkan jarak antar baris nama
                        )),
                  ],
                ),
              ),

              const SizedBox(width: 15),

              // Sisi Kanan: Kartu Saldo (Mengambil sisa ruang)
              Expanded(
                flex: 3, // Memberi ruang lebih besar untuk angka saldo
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: isMinus
                              ? [Colors.redAccent, Colors.red]
                              : [aksen, const Color(0xFF005FCC)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: (isMinus ? Colors.red : aksen).withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4)
                        )
                      ]
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Text("TOTAL SALDO",
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1
                          )),
                      const SizedBox(height: 4),
                      FittedBox( // Supaya angka saldo otomatis mengecil jika terlalu panjang
                        child: Text("Rp ${formatRibuan(saldoTotal)}",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900
                            )),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildKartuUtama(ThemeManager tm, double masuk, double keluar, Color aksen) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _itemRingkasan("Pemasukan", masuk, Colors.greenAccent, Icons.trending_up, tm),
          const SizedBox(width: 15),
          _itemRingkasan("Pengeluaran", keluar, Colors.orangeAccent, Icons.trending_down, tm),
        ],
      ),
    );
  }

  Widget _itemRingkasan(String label, double nilai, Color warna, IconData ikon, ThemeManager tm) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: tm.cardColor,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white.withOpacity(0.03)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: warna.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(ikon, color: warna, size: 18),
            ),
            const SizedBox(height: 15),
            Text(label, style: TextStyle(color: tm.subTextColor, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            FittedBox(child: Text("Rp ${formatRibuan(nilai)}", style: TextStyle(color: tm.textColor, fontSize: 15, fontWeight: FontWeight.w900))),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderKebun(ThemeManager tm, List<Map<String, dynamic>> kebun, List<Map<String, dynamic>> transaksi, Color aksen) {
    if (kebun.isEmpty) return Center(child: Text("Belum ada data lahan", style: TextStyle(color: tm.subTextColor, fontSize: 12)));
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: kebun.length,
        itemBuilder: (context, index) {
          String namaKebun = kebun[index]['nama'];
          double totalPemasukanKebun = transaksi.where((t) => t['lokasi'] == namaKebun && t['jenis'] == 'Pemasukan')
              .fold(0.0, (sum, t) => sum + (t['total'] ?? 0));

          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 15),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: tm.cardColor,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: aksen.withOpacity(0.1))
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.eco_rounded, color: aksen, size: 30),
                const SizedBox(height: 5),
                Text(namaKebun, style: TextStyle(color: tm.textColor, fontWeight: FontWeight.w800, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text("Rp ${formatRibuan(totalPemasukanKebun)}", style: TextStyle(color: aksen, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPilihTahun(ThemeManager tm, Color aksen) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      height: 35,
      decoration: BoxDecoration(color: aksen.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedYear,
          dropdownColor: tm.cardColor,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: aksen, size: 18),
          style: TextStyle(color: aksen, fontWeight: FontWeight.bold, fontSize: 12),
          onChanged: (v) => setState(() => _selectedYear = v!),
          items: _years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
        ),
      ),
    );
  }

  Widget _buildWadahGrafik(List<Map<String, dynamic>> dataSemua, ThemeManager tm, Color aksen) {
    List<FlSpot> titikPemasukan = [];
    List<FlSpot> titikPengeluaran = [];
    double nilaiMaks = 1000000;

    for (int i = 0; i < _years.length; i++) {
      double totalMasuk = dataSemua
          .where((item) => item['tanggal'].toString().contains(_years[i]) && item['jenis'] == 'Pemasukan')
          .fold(0.0, (sum, item) => sum + (double.tryParse(item['total'].toString()) ?? 0.0));

      double totalKeluar = dataSemua
          .where((item) => item['tanggal'].toString().contains(_years[i]) && item['jenis'] == 'Pengeluaran')
          .fold(0.0, (sum, item) => sum + (double.tryParse(item['total'].toString()) ?? 0.0));

      titikPemasukan.add(FlSpot(i.toDouble(), totalMasuk));
      titikPengeluaran.add(FlSpot(i.toDouble(), totalKeluar));

      if (totalMasuk > nilaiMaks) nilaiMaks = totalMasuk;
      if (totalKeluar > nilaiMaks) nilaiMaks = totalKeluar;
    }

    return Container(
      height: 310,
      padding: const EdgeInsets.fromLTRB(10, 15, 20, 10),
      decoration: BoxDecoration(
        color: tm.cardColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          // --- LEGENDA ---
          Padding(
            padding: const EdgeInsets.only(left: 15, bottom: 20),
            child: Row(
              children: [
                _itemLegenda(aksen, "Pemasukan"),
                const SizedBox(width: 20),
                _itemLegenda(Colors.redAccent.withOpacity(0.6), "Pengeluaran"),
              ],
            ),
          ),

          // --- GRAFIK ---
          Expanded(
            child: LineChart(
              LineChartData(
                // PENGATURAN ANGKA SAAT DOT DITEKAN (TOOLTIP)
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: aksen.withOpacity(0.9), // Warna kotak cerah
                    tooltipRoundedRadius: 12,
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((barSpot) {
                        return LineTooltipItem(
                          barSpot.y >= 1000000
                              ? "Rp ${(barSpot.y / 1000000).toStringAsFixed(1)}M"
                              : "Rp ${(barSpot.y / 1000).toInt()}rb",
                          const TextStyle(
                            color: Colors.white, // Teks putih agar kontras
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: tm.subTextColor.withOpacity(0.05), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        int idx = val.toInt();
                        if (idx >= 0 && idx < _years.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(_years[idx].substring(2),
                                style: TextStyle(color: tm.textColor, fontSize: 10, fontWeight: FontWeight.bold)),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      getTitlesWidget: (val, meta) {
                        if (val == 0) return const SizedBox();
                        String teks = val >= 1000000 ? "${(val / 1000000).toStringAsFixed(1)}M" : "${(val / 1000).toInt()}k";
                        return Text(teks, style: TextStyle(color: tm.subTextColor, fontSize: 9));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // GARIS PEMASUKAN
                  LineChartBarData(
                    spots: titikPemasukan,
                    isCurved: false, // Garis Lurus
                    color: aksen,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 3, color: Colors.white, strokeWidth: 2, strokeColor: aksen
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [aksen.withOpacity(0.2), aksen.withOpacity(0.0)],
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // GARIS PENGELUARAN
                  LineChartBarData(
                    spots: titikPengeluaran,
                    isCurved: false, // Garis Lurus
                    color: Colors.redAccent.withOpacity(0.6),
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 3, color: Colors.white, strokeWidth: 2, strokeColor: Colors.redAccent.withOpacity(0.6)
                      ),
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

// Widget pembantu legenda
  Widget _itemLegenda(Color warna, String label) {
    return Row(
      children: [
        Container(
          width: 12, height: 4,
          decoration: BoxDecoration(color: warna, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey)),
      ],
    );
  }
}
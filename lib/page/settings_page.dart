import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart' as exc;
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:pdf/pdf.dart';

import '../db_helper.dart';
import '../theme_manager.dart';

// --- SERVICE EXPORT (Fungsi Paman tetap dipertahankan) ---
class ExportService {
  static final currencyFormatter = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

  static Future<void> exportToExcel(List<Map<String, dynamic>> data) async {
    var excel = exc.Excel.createExcel();
    exc.Sheet sheetObject = excel['Laporan'];
    excel.delete('Sheet1');

    // Variabel untuk Grand Total
    double grandTotalPemasukan = 0;
    double grandTotalPengeluaran = 0;

    // 1. KELOMPOKKAN DATA BERDASARKAN LOKASI (PEMASUKAN)
    Map<String, List<Map<String, dynamic>>> dataPerKebun = {};
    List<Map<String, dynamic>> dataPengeluaran = [];

    for (var item in data) {
      if (item['jenis'] == 'Pemasukan') {
        String lok = item['lokasi'] ?? 'Tanpa Lokasi';
        if (!dataPerKebun.containsKey(lok)) dataPerKebun[lok] = [];
        dataPerKebun[lok]!.add(item);
      } else {
        dataPengeluaran.add(item);
      }
    }

    // --- BAGIAN A: TABEL PEMASUKAN PER KEBUN ---
    sheetObject.appendRow([exc.TextCellValue('LAPORAN PEMASUKAN PER LAHAN')]);
    sheetObject.appendRow([]); // Spasi

    dataPerKebun.forEach((lokasi, listTransaksi) {
      sheetObject.appendRow([exc.TextCellValue(' ')]);
      sheetObject.appendRow([exc.TextCellValue('LOKASI: $lokasi')]);
      sheetObject.appendRow([
        exc.TextCellValue('Tanggal'),
        exc.TextCellValue('Berat (Kg)'),
        exc.TextCellValue('Harga/Kg'),
        exc.TextCellValue('Total (Rp)'),
      ]);

      double subTotalKebun = 0;
      double subTotalBerat = 0;
      for (var row in listTransaksi) {
        double total = double.tryParse(row['total'].toString()) ?? 0;
        subTotalKebun += total;
        subTotalBerat += double.tryParse(row['jumlah'].toString()) ?? 0;
        sheetObject.appendRow([
          exc.TextCellValue(row['tanggal'].toString()),
          exc.DoubleCellValue(double.tryParse(row['jumlah'].toString()) ?? 0),
          exc.DoubleCellValue(double.tryParse(row['harga'].toString()) ?? 0),
          exc.DoubleCellValue(total),
        ]);
      }
      grandTotalPemasukan += subTotalKebun;
      sheetObject.appendRow([exc.TextCellValue('Subtotal $lokasi'), exc.DoubleCellValue(subTotalBerat), exc.TextCellValue(''), exc.DoubleCellValue(subTotalKebun)]);
      sheetObject.appendRow([]); // Spasi antar kebun
    });

    // --- BAGIAN B: TABEL PENGELUARAN ---
    sheetObject.appendRow([exc.TextCellValue(' ')]);
    sheetObject.appendRow([exc.TextCellValue('LAPORAN PENGELUARAN UMUM')]);
    sheetObject.appendRow([
      exc.TextCellValue('Tanggal'),
      exc.TextCellValue('Keterangan'),
      exc.TextCellValue('Total (Rp)'),
    ]);

    for (var row in dataPengeluaran) {
      double total = double.tryParse(row['total'].toString()) ?? 0;
      grandTotalPengeluaran += total;
      sheetObject.appendRow([
        exc.TextCellValue(row['tanggal'].toString()),
        exc.TextCellValue(row['keterangan'] ?? '-'),
        exc.DoubleCellValue(total),
      ]);
    }
    sheetObject.appendRow([exc.TextCellValue('Subtotal Pengeluaran'), exc.TextCellValue(''), exc.DoubleCellValue(grandTotalPengeluaran)]);
    sheetObject.appendRow([]); // Spasi

    // --- BAGIAN C: RINGKASAN AKHIR (GRAND TOTAL) ---
    sheetObject.appendRow([exc.TextCellValue(' ')]);
    sheetObject.appendRow([exc.TextCellValue('RINGKASAN KESELURUHAN')]);
    sheetObject.appendRow([exc.TextCellValue('Total Pemasukan'), exc.DoubleCellValue(grandTotalPemasukan)]);
    sheetObject.appendRow([exc.TextCellValue('Total Pengeluaran'), exc.DoubleCellValue(grandTotalPengeluaran)]);
    sheetObject.appendRow([
      exc.TextCellValue('SALDO AKHIR (NET)'),
      exc.DoubleCellValue(grandTotalPemasukan - grandTotalPengeluaran)
    ]);

    // --- PROSES SIMPAN FILE ---
    try {
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) directory = await getExternalStorageDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final String fileName = 'Laporan_Terperinci_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
      final String fullPath = '${directory!.path}/$fileName';

      var fileBytes = excel.save();
      if (fileBytes != null) {
        File(fullPath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        debugPrint("Excel tersimpan di: $fullPath");
        // SnackBar tidak bisa dipanggil langsung dari fungsi statis tanpa context
        // Pastikan fungsi ini dipanggil dari UI yang menghandle SnackBar
      }
    } catch (e) {
      debugPrint("Gagal simpan Excel: $e");
    }
  }

  static Future<void> exportToPdf(List<Map<String, dynamic>> data) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();

    double grandTotalPemasukan = 0;
    double grandTotalPengeluaran = 0;
    double grandTotalBerat = 0;

    Map<String, List<Map<String, dynamic>>> dataPerKebun = {};
    List<Map<String, dynamic>> dataPengeluaran = [];

    for (var item in data) {
      if (item['jenis'] == 'Pemasukan') {
        String lok = item['lokasi'] ?? 'Tanpa Lokasi';
        if (!dataPerKebun.containsKey(lok)) dataPerKebun[lok] = [];
        dataPerKebun[lok]!.add(item);
      } else {
        dataPengeluaran.add(item);
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        orientation: pw.PageOrientation.landscape,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          List<pw.Widget> widgets = [];

          widgets.add(pw.Text("LAPORAN KEUANGAN TERPERINCI",
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)));
          widgets.add(pw.SizedBox(height: 20));

          // --- PEMASUKAN ---
          dataPerKebun.forEach((lokasi, listTransaksi) {
            double subTotalUang = 0;
            double subTotalBerat = 0;

            // PERUBAHAN DISINI: Pakai List.generate atau map dengan cast eksplisit
            List<List<String>> rows = listTransaksi.map((item) {
              double total = double.tryParse(item['total'].toString()) ?? 0;
              double berat = double.tryParse(item['jumlah'].toString()) ?? 0;
              subTotalUang += total;
              subTotalBerat += berat;

              // Pastikan setiap elemen adalah .toString()
              return <String>[
                item['tanggal'].toString(),
                berat.toStringAsFixed(1),
                currencyFormatter.format(double.tryParse(item['harga'].toString()) ?? 0),
                currencyFormatter.format(total),
              ];
            }).toList();

            rows.add(<String>[
              'TOTAL $lokasi',
              '${subTotalBerat.toStringAsFixed(1)} Kg',
              '',
              currencyFormatter.format(subTotalUang),
            ]);

            widgets.add(pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 5),
              child: pw.Text("Lokasi: $lokasi", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ));

            widgets.add(pw.TableHelper.fromTextArray(
              headers: <String>['Tanggal', 'Berat (Kg)', 'Harga/Kg', 'Total (Rp)'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
              },
              data: rows,
            ));

            grandTotalPemasukan += subTotalUang;
            grandTotalBerat += subTotalBerat;
            widgets.add(pw.SizedBox(height: 15));
          });

          // --- PENGELUARAN ---
          if (dataPengeluaran.isNotEmpty) {
            double subTotalOut = 0;
            List<List<String>> outRows = dataPengeluaran.map((item) {
              double total = double.tryParse(item['total'].toString()) ?? 0;
              subTotalOut += total;
              return <String>[
                item['tanggal'].toString(),
                (item['keterangan'] ?? '-').toString(),
                currencyFormatter.format(total)
              ];
            }).toList();

            outRows.add(<String>['TOTAL PENGELUARAN', '', currencyFormatter.format(subTotalOut)]);

            widgets.add(pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 5),
              child: pw.Text("Pengeluaran Umum", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ));

            widgets.add(pw.TableHelper.fromTextArray(
              headers: <String>['Tanggal', 'Keterangan', 'Total (Rp)'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.red800),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerRight
              },
              data: outRows,
            ));
            grandTotalPengeluaran = subTotalOut;
          }

          // --- RINGKASAN AKHIR ---
          widgets.add(pw.SizedBox(height: 30));
          widgets.add(pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blueGrey, width: 2),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            ),
            child: pw.Column(
              children: [
                _rowRingkasan("Total Berat Panen", "${grandTotalBerat.toStringAsFixed(1)} Kg"),
                _rowRingkasan("Total Pendapatan", currencyFormatter.format(grandTotalPemasukan)),
                _rowRingkasan("Total Pengeluaran", "- ${currencyFormatter.format(grandTotalPengeluaran)}"),
                pw.Divider(),
                _rowRingkasan("SALDO BERSIH", currencyFormatter.format(grandTotalPemasukan - grandTotalPengeluaran), isBold: true),
              ],
            ),
          ));

          return widgets;
        },
      ),
    );

    await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'Laporan_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf'
    );
  }

  // Helper untuk baris ringkasan di PDF
  static pw.Widget _rowRingkasan(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
              label,
              style: pw.TextStyle(
                  fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  fontSize: 12
              )
          ),
          pw.Text(
              value,
              style: pw.TextStyle(
                  fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  fontSize: 12
              )
          ),
        ],
      ),
    );
  }


}

// --- CUSTOM STICKY HEADER DELEGATE ---
class SettingsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  SettingsHeaderDelegate({
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
  bool shouldRebuild(covariant SettingsHeaderDelegate oldDelegate) => true;
}

class SettingsPage extends StatefulWidget {
  final VoidCallback onProfileUpdate;
  const SettingsPage({super.key, required this.onProfileUpdate});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final tm = ThemeManager();
  final DbHelper _dbHelper = DbHelper();
  String _userName = "SamZen";
  List<Map<String, dynamic>> _daftarKebun = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadKebun();
  }

  void _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? "SamZen";
    });
  }

  void _loadKebun() async {
    final data = await _dbHelper.getDaftarKebun();
    setState(() { _daftarKebun = data; });
  }

  // --- UI BUILDER ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tm.bgColor,
      body: CustomScrollView(
        slivers: [
          // STICKY HEADER SERAGAM
          SliverPersistentHeader(
            pinned: true,
            delegate: SettingsHeaderDelegate(
              minHeight: 120,
              maxHeight: 120,
              child: _buildHeader(),
            ),
          ),

          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kartu Info Ringkas
                    Row(
                      children: [
                        _buildInfoBox("Versi", "1.0.0", Icons.verified_user_outlined, Colors.blue),
                        const SizedBox(width: 12),
                        _buildInfoBox("Lahan", "${_daftarKebun.length} Lokasi", Icons.eco_outlined, Colors.green),
                      ],
                    ),

                    _buildSectionTitle("PROFIL & LAHAN"),
                    _buildContainerCard([
                      _buildMenuTile(
                        icon: Icons.person_outline, color: Colors.blue,
                        title: "Nama Pemilik", subtitle: _userName,
                        onTap: _showEditNameDialog,
                      ),
                      const Divider(height: 1, indent: 60, color: Colors.white10),
                      _buildMenuTile(
                        icon: Icons.add_business_outlined, color: Colors.green,
                        title: "Tambah Lahan Baru", subtitle: "Klik untuk menambah",
                        onTap: _showAddKebunDialog,
                        trailing: const Icon(Icons.add_circle, color: Colors.green, size: 28),
                      ),
                      // List Lahan yang sudah ada
                      if (_daftarKebun.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            children: _daftarKebun.map((k) => _buildKebunItem(k)).toList(),
                          ),
                        ),
                    ]),

                    _buildSectionTitle("LAPORAN & CADANGAN"),
                    _buildContainerCard([
                      _buildMenuTile(icon: Icons.picture_as_pdf_outlined, color: Colors.orange, title: "Ekspor Laporan PDF", onTap: () => _handleExport('pdf')),
                      const Divider(height: 1, indent: 60, color: Colors.white10),
                      _buildMenuTile(icon: Icons.table_chart_outlined, color: Colors.green, title: "Ekspor Laporan Excel", onTap: () => _handleExport('excel')),
                      const Divider(height: 1, indent: 60, color: Colors.white10),
                      _buildMenuTile(icon: Icons.cloud_upload_outlined, color: Colors.blue, title: "Backup Data (JSON)", subtitle: "Kirim cadangan data", onTap: _handleJsonExport),
                      const Divider(height: 1, indent: 60, color: Colors.white10),
                      _buildMenuTile(icon: Icons.cloud_download_outlined, color: Colors.purple, title: "Pulihkan Data (JSON)", subtitle: "Import dari file cadangan", onTap: _handleJsonImport),
                    ]),

                    _buildSectionTitle("PERSONALISASI"),
                    _buildContainerCard([
                      _buildMenuTile(
                        icon: Icons.palette_outlined, color: tm.primary,
                        title: "Tema Warna", subtitle: tm.allThemes[tm.themeIndex]['name'],
                        onTap: _showThemePicker,
                      ),
                      const Divider(height: 1, indent: 60, color: Colors.white10),
                      SwitchListTile(
                        secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.dark_mode_outlined, color: Colors.amber, size: 20)
                        ),
                        title: Text("Mode Gelap", style: TextStyle(color: tm.textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                        value: tm.isDarkMode,
                        activeColor: tm.primary,
                        onChanged: (v) async {
                          await tm.saveDarkMode(v);
                          widget.onProfileUpdate();
                          setState(() {});
                        },
                      ),
                    ]),

                    _buildSectionTitle("KEAMANAN DATA"),
                    _buildContainerCard([
                      _buildMenuTile(
                        icon: Icons.delete_forever_outlined, color: Colors.red,
                        title: "Kosongkan Database", textColor: Colors.red,
                        onTap: _showDeleteConfirmDialog,
                      ),
                    ]),

                    const SizedBox(height: 40),
                    Center(child: Text("KEBUN KAS v1.0.0 - Natgul © 2026 ", style: TextStyle(color: tm.subTextColor, fontSize: 10, letterSpacing: 2))),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(25, 35, 25, 10),
      decoration: BoxDecoration(
        color: tm.cardColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(35)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("PENGATURAN", style: TextStyle(color: tm.primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              Text("Paman $_userName", style: TextStyle(color: tm.textColor, fontSize: 20, fontWeight: FontWeight.w900)),
            ],
          ),
          CircleAvatar(
            backgroundColor: tm.primary.withOpacity(0.1),
            child: Icon(Icons.settings_suggest_rounded, color: tm.primary),
          )
        ],
      ),
    );
  }

  Widget _buildInfoBox(String label, String val, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: tm.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: tm.subTextColor, fontSize: 9, fontWeight: FontWeight.bold)),
                Text(val, style: TextStyle(color: tm.textColor, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(left: 10, top: 30, bottom: 12),
    child: Text(title, style: TextStyle(color: tm.primary, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2)),
  );

  Widget _buildContainerCard(List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: tm.cardColor,
      borderRadius: BorderRadius.circular(25),
    ),
    child: Column(children: children),
  );

  Widget _buildMenuTile({required IconData icon, required Color color, required String title, String? subtitle, required VoidCallback onTap, Widget? trailing, Color? textColor}) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22)
      ),
      title: Text(title, style: TextStyle(color: textColor ?? tm.textColor, fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: tm.subTextColor, fontSize: 12)) : null,
      trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: tm.subTextColor.withOpacity(0.3)),
    );
  }

  Widget _buildKebunItem(Map<String, dynamic> k) {
    return Container(
      margin: const EdgeInsets.only(left: 60, right: 15, bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(color: tm.bgColor.withOpacity(0.5), borderRadius: BorderRadius.circular(15)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k['nama'], style: TextStyle(color: tm.textColor, fontWeight: FontWeight.w500, fontSize: 13)),
          GestureDetector(
            onTap: () async { await _dbHelper.deleteKebun(k['id']); _loadKebun(); },
            child: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  // --- LOGIC FUNCTIONS (Tetap Sama) ---

  void _showEditNameDialog() {
    TextEditingController nameController = TextEditingController(text: _userName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: tm.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Ganti Nama Pemilik" , style: TextStyle(color: tm.primary)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: TextStyle(color: tm.textColor),
          decoration: InputDecoration(hintText: "Nama Anda", enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: tm.primary))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Batal", style: TextStyle(color: tm.subTextColor))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: tm.primary),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('user_name', nameController.text);
              _loadData(); widget.onProfileUpdate(); Navigator.pop(context);
            },
            child: const Text("Simpan", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddKebunDialog() {
    TextEditingController kebunController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: tm.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:  Text("Tambah Kebun Baru", style: TextStyle(color: tm.primary)),
        content: TextField(
          controller: kebunController,
          autofocus: true,
          style: TextStyle(color: tm.textColor),
          decoration: const InputDecoration(hintText: "Contoh: Kebun Atas"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Batal", style: TextStyle(color: tm.subTextColor))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: tm.primary),
            onPressed: () async {
              if (kebunController.text.isNotEmpty) {
                await _dbHelper.addKebun(kebunController.text);
                _loadKebun(); Navigator.pop(context);
              }
            },
            child: const Text("Simpan", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: tm.bgColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: tm.subTextColor.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text("Pilih Tema Warna", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: tm.textColor)),
            const SizedBox(height: 25),
            Wrap(
              spacing: 20, runSpacing: 20,
              children: List.generate(tm.allThemes.length, (index) {
                bool isSelected = tm.themeIndex == index;
                return GestureDetector(
                  onTap: () async {
                    await tm.saveTheme(index);
                    widget.onProfileUpdate(); Navigator.pop(context); setState(() {});
                  },
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: tm.allThemes[index]['primary'],
                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 30) : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _handleExport(String type) async {
    final data = await _dbHelper.getTransaksi();

    if (data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Data masih kosong!"),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2), // <--- Set 5 Detik
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    // Tampilkan loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator(color: tm.primary)),
    );

    try {
      if (type == 'pdf') {
        await ExportService.exportToPdf(data);
      } else {
        await ExportService.exportToExcel(data);
      }

      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                    type == 'pdf' ? Icons.picture_as_pdf : Icons.table_view_rounded,
                    color: Colors.white, size: 20
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    type == 'pdf'
                        ? "PDF Berhasil Dibuat & Siap Dibagikan!"
                        : "Excel Tersimpan! Cek di Folder Download.",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2), // <--- Notif ini muncul selama 5 detik
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            action: SnackBarAction(
              label: "OKE",
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Waduh, Gagal: $e"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _handleJsonExport() async {
    final transactions = await _dbHelper.getTransaksi();
    final kebun = await _dbHelper.getDaftarKebun();

    Map<String, dynamic> backupData = {
      'app': 'Catatan Kebun Jeruk', // Nama kunci harus sama dengan Import
      'version': '1.0',
      'date': DateTime.now().toIso8601String(),
      'transactions': transactions,
      'kebun': kebun,
    };

    try {
      String jsonStr = jsonEncode(backupData);
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/backup_kebun_${DateFormat('yyyyMMdd').format(DateTime.now())}.json');

      await file.writeAsString(jsonStr);
      await Share.shareXFiles([XFile(file.path)], text: 'Backup Data Catatan Kebun');
    } catch (e) {
      debugPrint("Gagal Export JSON: $e");
    }
  }

  void _handleJsonImport() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json']
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String content = await file.readAsString();
        Map<String, dynamic> backupData = jsonDecode(content);

        // --- SINKRONISASI KUNCI DI SINI ---
        if (backupData['app'] != 'Catatan Kebun Jeruk') {
          throw "File ini bukan cadangan resmi aplikasi Catatan Kebun!";
        }

        List transactions = backupData['transactions'] ?? [];
        List kebunList = backupData['kebun'] ?? [];

        bool? konfirmasi = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: tm.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            title: Text("Impor Data?", style: TextStyle(color: tm.textColor, fontWeight: FontWeight.bold)),
            content: Text(
              "Ditemukan ${transactions.length} transaksi dan ${kebunList.length} lahan. Data akan digabungkan. Lanjutkan?",
              style: TextStyle(color: tm.subTextColor),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Batal", style: TextStyle(color: tm.subTextColor))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: tm.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Lanjutkan", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );

        if (konfirmasi == true) {
          final db = await _dbHelper.database;
          await db.transaction((txn) async {
            // Impor Kebun (Gunakan ignore agar tidak duplikat nama)
            for (var k in kebunList) {
              await txn.insert('kebun', {'nama': k['nama']}, conflictAlgorithm: ConflictAlgorithm.ignore);
            }
            // Impor Transaksi
            for (var t in transactions) {
              Map<String, dynamic> dataBaru = Map.from(t);
              dataBaru.remove('id'); // ID harus auto-increment baru agar tidak bentrok
              await txn.insert('transaksi', dataBaru);
            }
          });

          // --- REFRESH DATA ---
          _loadKebun(); // Memperbarui list kebun di UI
          if (widget.onProfileUpdate != null) {
            widget.onProfileUpdate!(); // Update statistik di Home jika ada
          }

          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Data berhasil digabungkan!"), backgroundColor: Colors.green)
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal impor: $e"), backgroundColor: Colors.red)
      );
    }
  }

  void _showDeleteConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: tm.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Hapus Total?", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text("Semua transaksi dan daftar kebun akan dihapus permanen. Yakin?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Batal", style: TextStyle(color: tm.subTextColor))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _dbHelper.hapusTotalSemuaData();
              _loadKebun();
              widget.onProfileUpdate();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Semua data telah dibersihkan!")));
              }
            },
            child: const Text("YA, HAPUS", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
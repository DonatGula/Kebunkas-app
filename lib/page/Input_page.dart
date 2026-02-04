import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db_helper.dart';
import '../theme_manager.dart';

class InputPage extends StatefulWidget {
  final VoidCallback? onRefresh;
  const InputPage({super.key, this.onRefresh});

  @override
  State<InputPage> createState() => _InputPageState();
}

class _InputPageState extends State<InputPage> {
  bool isPemasukan = true;
  String? lokasi;
  List<String> _daftarKebun = [];

  final DbHelper _dbHelper = DbHelper();
  final tm = ThemeManager();

  final TextEditingController _tglController = TextEditingController();
  final TextEditingController _jumlahController = TextEditingController();
  final TextEditingController _hargaController = TextEditingController();
  final TextEditingController _totalController = TextEditingController();
  final TextEditingController _ketController = TextEditingController();

  final List<String> _quickKeterangan = ["Pupuk", "Obat", "Bensin", "Mesin"];

  @override
  void initState() {
    super.initState();
    _tglController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _loadDaftarKebun();

    _jumlahController.addListener(() {
      _formatInput(_jumlahController);
      _updateTotal();
    });

    _hargaController.addListener(() {
      _formatInput(_hargaController);
      _updateTotal();
    });

    _totalController.addListener(() {
      if (!isPemasukan) _formatInput(_totalController);
    });
  }

  void _loadDaftarKebun() async {
    final data = await _dbHelper.getDaftarKebun();
    if (mounted) {
      setState(() {
        _daftarKebun = data.map((e) => e['nama'].toString()).toList();
        if (_daftarKebun.isNotEmpty) {
          lokasi = _daftarKebun[0];
        }
      });
    }
  }

  @override
  void dispose() {
    _jumlahController.dispose();
    _hargaController.dispose();
    _totalController.dispose();
    _ketController.dispose();
    _tglController.dispose();
    super.dispose();
  }

  void _formatInput(TextEditingController controller) {
    String value = controller.text.replaceAll('.', '');
    if (value.isEmpty) return;
    double? n = double.tryParse(value);
    if (n == null) return;
    final formatted = NumberFormat.decimalPattern('id').format(n);
    if (controller.text != formatted) {
      controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  void _updateTotal() {
    if (!isPemasukan) return;
    double qty = double.tryParse(_jumlahController.text.replaceAll('.', '')) ?? 0;
    double price = double.tryParse(_hargaController.text.replaceAll('.', '')) ?? 0;
    double total = qty * price;
    _totalController.text = NumberFormat.decimalPattern('id').format(total);
  }

  Future<void> _pilihTanggal() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: isPemasukan ? tm.primary : const Color(0xFFD32F2F),
              onPrimary: Colors.white,
              onSurface: tm.textColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _tglController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  void _simpanData() async {
    double clean(String val) => double.tryParse(val.replaceAll('.', '')) ?? 0;
    if (clean(_totalController.text) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text("Total tidak boleh kosong!"), backgroundColor: tm.primary),
      );
      return;
    }

    Map<String, dynamic> data = {
      'jenis': isPemasukan ? 'Pemasukan' : 'Pengeluaran',
      'lokasi': isPemasukan ? (lokasi ?? '-') : '-',
      'tanggal': _tglController.text,
      'jumlah': clean(_jumlahController.text),
      'harga': clean(_hargaController.text),
      'total': clean(_totalController.text),
      'keterangan': isPemasukan ? "Panen Jeruk $lokasi" : _ketController.text,
    };

    await _dbHelper.insertTransaksi(data);
    if (mounted) {
      if (widget.onRefresh != null) widget.onRefresh!();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    Color activeColor = isPemasukan ? tm.primary : const Color(0xFFD32F2F);

    return Container(
      decoration: BoxDecoration(
        color: tm.bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle Bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            height: 5, width: 50,
            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(25, 0, 25, MediaQuery.of(context).viewInsets.bottom + 30),
              child: Column(
                children: [
                  Text("TAMBAH CATATAN", style: TextStyle(fontWeight: FontWeight.w900, color: tm.textColor, fontSize: 18, letterSpacing: 1.2)),
                  const SizedBox(height: 25),
                  _buildModernToggle(activeColor),
                  const SizedBox(height: 25),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: tm.cardColor,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
                    ),
                    child: Column(
                      children: [
                        _buildLabel("Tanggal Transaksi"),
                        _buildModernField(Icons.calendar_today, "Pilih Tanggal", controller: _tglController, readOnly: true, onTap: _pilihTanggal, activeColor: activeColor),

                        if (isPemasukan) ...[
                          const SizedBox(height: 15),
                          _buildLabel("Lokasi Kebun"),
                          _buildDynamicLocationSelector(activeColor),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Expanded(child: Column(children: [_buildLabel("Berat (Kg)"), _buildModernField(Icons.scale, "0", controller: _jumlahController, type: TextInputType.number, activeColor: activeColor)])),
                              const SizedBox(width: 15),
                              Expanded(child: Column(children: [_buildLabel("Harga/Kg"), _buildModernField(Icons.payments, "0", controller: _hargaController, type: TextInputType.number, activeColor: activeColor)])),
                            ],
                          ),
                        ] else ...[
                          const SizedBox(height: 15),
                          _buildLabel("Keterangan Belanja"),
                          _buildMultiQuickChoices(activeColor),
                          const SizedBox(height: 10),
                          _buildModernField(Icons.edit_note, "Ketik manual di sini...", controller: _ketController, activeColor: activeColor),
                        ],

                        const SizedBox(height: 20),
                        _buildLabel("Total Keseluruhan"),
                        _buildModernField(Icons.calculate, "0", controller: _totalController, readOnly: isPemasukan, colorText: activeColor, fontSize: 20, fontWeight: FontWeight.w900, fill: activeColor.withOpacity(0.05), activeColor: activeColor),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  _buildActionButtons(activeColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicLocationSelector(Color activeColor) {
    if (_daftarKebun.isEmpty) return Text("Belum ada data kebun", style: TextStyle(color: Colors.red.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold));

    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.start,
        children: _daftarKebun.map((nama) {
          bool selected = lokasi == nama;
          return GestureDetector(
            onTap: () => setState(() => lokasi = nama),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? activeColor.withOpacity(0.1) : tm.bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selected ? activeColor : Colors.grey.withOpacity(0.2), width: 2),
              ),
              child: Text(nama, style: TextStyle(color: selected ? activeColor : tm.subTextColor, fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildModernToggle(Color activeColor) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: tm.cardColor, borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          _toggleItem("PEMASUKAN", true, tm.primary),
          _toggleItem("PENGELUARAN", false, const Color(0xFFD32F2F)),
        ],
      ),
    );
  }

  Widget _toggleItem(String title, bool type, Color color) {
    bool active = isPemasukan == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          isPemasukan = type;
          _ketController.clear();
          if(!isPemasukan) _totalController.clear();
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(title, style: TextStyle(color: active ? Colors.white : tm.subTextColor, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),
      ),
    );
  }

  Widget _buildModernField(IconData icon, String hint, {required Color activeColor, TextEditingController? controller, bool readOnly = false, VoidCallback? onTap, TextInputType type = TextInputType.text, Color? colorText, double? fontSize, FontWeight? fontWeight, Color? fill}) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: type,
      style: TextStyle(color: colorText ?? tm.textColor, fontWeight: fontWeight ?? FontWeight.bold, fontSize: fontSize ?? 14),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: activeColor, size: 18),
        hintText: hint,
        filled: fill != null,
        fillColor: fill,
        hintStyle: TextStyle(color: tm.subTextColor, fontSize: 13),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withOpacity(0.2))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: activeColor, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      ),
    );
  }

  Widget _buildMultiQuickChoices(Color color) {
    List<String> selections = _ketController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return Wrap(
      spacing: 8,
      children: _quickKeterangan.map((item) {
        bool isSelected = selections.contains(item);
        return ChoiceChip(
          label: Text(item, style: TextStyle(color: isSelected ? Colors.white : tm.subTextColor, fontSize: 11, fontWeight: FontWeight.bold)),
          selected: isSelected,
          selectedColor: color,
          backgroundColor: tm.bgColor,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          side: BorderSide(color: isSelected ? color : Colors.grey.withOpacity(0.2)),
          onSelected: (val) {
            setState(() {
              if (val) {
                selections.add(item);
              } else {
                selections.remove(item);
              }
              _ketController.text = selections.join(", ");
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(text, style: TextStyle(color: tm.subTextColor, fontWeight: FontWeight.bold, fontSize: 11)),
      ),
    );
  }

  Widget _buildActionButtons(Color activeColor) {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("BATAL", style: TextStyle(color: tm.subTextColor, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: ElevatedButton(
            onPressed: _simpanData,
            style: ElevatedButton.styleFrom(
              backgroundColor: activeColor,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 5,
              shadowColor: activeColor.withOpacity(0.4),
            ),
            child: const Text("SIMPAN DATA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
        ),
      ],
    );
  }
}
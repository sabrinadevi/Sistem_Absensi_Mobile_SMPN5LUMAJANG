import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../styles/app_styles.dart';

class RekapAbsensiPage extends StatefulWidget {
  final bool isGuru;
  const RekapAbsensiPage({super.key, this.isGuru = false});

  @override
  State<RekapAbsensiPage> createState() => _RekapAbsensiPageState();
}

class _RekapAbsensiPageState extends State<RekapAbsensiPage> {
  Map<String, dynamic> _rekapData = {"summary": {}, "details": []};
  List _kelas = [];
  bool _loading = true;
  String _selectedKelas = "Semua Kelas";
  String _selectedPeriod = "harian";
  final String baseUrl = "http://112.78.133.50:8082/api";
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchKelas();
    _fetchRekap();
  }

  // Fungsi tunggal untuk generate PDF, dibedakan aksinya (Print atau Download)
  Future<void> _handlePdfAction({required bool isPrint}) async {
    try {
      final pdf = pw.Document();
      final summary = _rekapData['summary'] ?? {};
      final List details = _rekapData['details'] ?? [];

      if (details.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data tidak ditemukan")));
        return;
      }

      Map<String, List<dynamic>> groupedData = {};
      if (_selectedKelas == "Semua Kelas") {
        for (var d in details) {
          String k = (d['nama_kelas'] ?? 'Lainnya').toString();
          if (!groupedData.containsKey(k)) groupedData[k] = [];
          groupedData[k]!.add(d);
        }
      } else {
        groupedData[_selectedKelas] = details;
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            String periodTitle = "";
            String reportType = _selectedPeriod.toUpperCase();
            
            if (_selectedPeriod == "harian") {
              periodTitle = "TANGGAL: ${DateFormat('dd MMMM yyyy').format(_selectedDate).toUpperCase()}";
            } else if (_selectedPeriod == "mingguan") {
              DateTime monday = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
              DateTime sunday = monday.add(const Duration(days: 6));
              periodTitle = "PERIODE: ${DateFormat('dd MMM').format(monday).toUpperCase()} - ${DateFormat('dd MMM yyyy').format(sunday).toUpperCase()}";
            } else if (_selectedPeriod == "bulanan") {
              periodTitle = "BULAN: ${DateFormat('MMMM yyyy').format(_selectedDate).toUpperCase()}";
            } else {
              periodTitle = "TAHUN: ${DateFormat('yyyy').format(_selectedDate)}";
            }

            return [
              pw.Center(child: pw.Text("LAPORAN REKAPITULASI ABSENSI SISWA", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
              pw.Center(child: pw.Text("SMPN 5 LUMAJANG", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("JENIS REKAP: $reportType", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text(periodTitle, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Divider(thickness: 1.0),
              pw.SizedBox(height: 10),

              ...groupedData.entries.map((entry) {
                final kelas = entry.key;
                final siswaList = entry.value;
                bool isHarian = _selectedPeriod == "harian";

                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 10, bottom: 5),
                      child: pw.Text("KELAS: $kelas", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ),
                    pw.TableHelper.fromTextArray(
                      headers: isHarian ? ['NO', 'NIS', 'NAMA SISWA', 'STATUS'] : ['NO', 'NIS', 'NAMA SISWA', 'H', 'S', 'I', 'A'],
                      data: List<List<dynamic>>.generate(siswaList.length, (index) {
                        final d = siswaList[index];
                        if (isHarian) {
                          int h = (d['hadir'] ?? 0).toInt();
                          int s = (d['sakit'] ?? 0).toInt();
                          int iz = (d['izin'] ?? 0).toInt();
                          int a = (d['alpha'] ?? 0).toInt();
                          String status = h > 0 ? "HADIR" : (s > 0 ? "SAKIT" : (iz > 0 ? "IZIN" : (a > 0 ? "ALPHA" : "-")));
                          return [index + 1, d['nis'] ?? '-', d['nama_siswa'] ?? '-', status];
                        } else {
                          return [index + 1, d['nis'] ?? '-', d['nama_siswa'] ?? '-', d['hadir'] ?? 0, d['sakit'] ?? 0, d['izin'] ?? 0, d['alpha'] ?? 0];
                        }
                      }),
                      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                      cellStyle: const pw.TextStyle(fontSize: 8),
                      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      columnWidths: isHarian 
                        ? {0: const pw.FixedColumnWidth(25), 1: const pw.FixedColumnWidth(70), 3: const pw.FixedColumnWidth(60)}
                        : {0: const pw.FixedColumnWidth(25), 1: const pw.FixedColumnWidth(60), 3: const pw.FixedColumnWidth(25), 4: const pw.FixedColumnWidth(25), 5: const pw.FixedColumnWidth(25), 6: const pw.FixedColumnWidth(25)},
                      cellAlignment: pw.Alignment.centerLeft,
                      cellAlignments: isHarian ? {} : {3: pw.Alignment.center, 4: pw.Alignment.center, 5: pw.Alignment.center, 6: pw.Alignment.center},
                    ),
                    pw.SizedBox(height: 10),
                  ],
                );
              }).toList(),

              if (_selectedPeriod != "harian") 
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 15),
                  child: pw.Text("Keterangan: H (Hadir), S (Sakit), I (Izin), A (Alpha)", style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic)),
                ),

              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("RINGKASAN TOTAL:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      pw.SizedBox(height: 5),
                      pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                        children: [
                          _buildSummaryRow("Total Hadir", "${summary['total_hadir'] ?? 0}"),
                          _buildSummaryRow("Total Sakit", "${summary['total_sakit'] ?? 0}"),
                          _buildSummaryRow("Total Izin", "${summary['total_izin'] ?? 0}"),
                          _buildSummaryRow("Total Alpha", "${summary['total_alpha'] ?? 0}"),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text("LUMAJANG, ${DateFormat('dd MMMM yyyy').format(DateTime.now()).toUpperCase()}", style: const pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(height: 5),
                      pw.Text("PETUGAS / GURU PAMONG,", style: const pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(height: 40),
                      pw.Container(width: 130, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1)))),
                      pw.SizedBox(height: 2),
                      pw.Text("NIP. ...........................", style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ],
              ),
            ];
          },
        ),
      );

      final pdfBytes = await pdf.save();
      String fileSuffix = _selectedPeriod == "harian" ? DateFormat('ddMMyy').format(_selectedDate) :
                         _selectedPeriod == "bulanan" ? DateFormat('MMyy').format(_selectedDate) :
                         _selectedPeriod == "tahunan" ? DateFormat('yyyy').format(_selectedDate) :
                         "Mingguan_${DateFormat('ddMMyy').format(_selectedDate)}";
      final fileName = "Rekap_Absen_$fileSuffix.pdf";

      if (isPrint) {
        await Printing.layoutPdf(onLayout: (format) async => pdfBytes, name: fileName);
      } else {
        await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red));
    }
  }

  pw.TableRow _buildSummaryRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(label, style: const pw.TextStyle(fontSize: 9))),
        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
      ],
    );
  }

  Future<void> _fetchKelas() async {
    try {
      final res = await http.get(Uri.parse("$baseUrl/kelas"));
      if (res.statusCode == 200) setState(() => _kelas = json.decode(res.body));
    } catch (e) { debugPrint("Error: $e"); }
  }

  Future<void> _fetchRekap() async {
    setState(() => _loading = true);
    try {
      final url = "$baseUrl/absensi/rekap?kelas=${Uri.encodeComponent(_selectedKelas)}&tanggal=${DateFormat('yyyy-MM-dd').format(_selectedDate)}&period=$_selectedPeriod";
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) setState(() => _rekapData = json.decode(res.body));
    } catch (e) { debugPrint("Error: $e"); }
    finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    var summary = _rekapData['summary'] ?? {};
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading 
      ? const Center(child: CircularProgressIndicator())
      : ListView(
        padding: const EdgeInsets.symmetric(horizontal: 0),
        children: [
          // HEADER BIRU FULL
          Container(
            padding: const EdgeInsets.fromLTRB(10, 50, 10, 30),
            decoration: AppDecorations.gradientHeader.copyWith(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text("Rekap Absensi", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: "Download PDF",
                          icon: const Icon(Icons.picture_as_pdf, color: Colors.white), 
                          onPressed: () => _handlePdfAction(isPrint: false)
                        ),
                        IconButton(
                          tooltip: "Print",
                          icon: const Icon(Icons.print, color: Colors.white), 
                          onPressed: () => _handlePdfAction(isPrint: true)
                        ),
                        IconButton(
                          icon: const Icon(Icons.calendar_month, color: Colors.white),
                          onPressed: () async {
                            final d = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                            if (d != null) { setState(() => _selectedDate = d); _fetchRekap(); }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _PeriodChip(label: "Harian", value: "harian", selected: _selectedPeriod, onSelected: (v) { setState(() => _selectedPeriod = v); _fetchRekap(); }),
                      _PeriodChip(label: "Mingguan", value: "mingguan", selected: _selectedPeriod, onSelected: (v) { setState(() => _selectedPeriod = v); _fetchRekap(); }),
                      _PeriodChip(label: "Bulanan", value: "bulanan", selected: _selectedPeriod, onSelected: (v) { setState(() => _selectedPeriod = v); _fetchRekap(); }),
                      _PeriodChip(label: "Tahunan", value: "tahunan", selected: _selectedPeriod, onSelected: (v) { setState(() => _selectedPeriod = v); _fetchRekap(); }),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _SummaryItem(label: "Hadir", value: "${summary['total_hadir'] ?? 0}", icon: Icons.check_circle_outline),
                    _SummaryItem(label: "Sakit", value: "${summary['total_sakit'] ?? 0}", icon: Icons.medication_outlined),
                    _SummaryItem(label: "Izin", value: "${summary['total_izin'] ?? 0}", icon: Icons.info_outline),
                    _SummaryItem(label: "Alpha", value: "${summary['total_alpha'] ?? 0}", icon: Icons.cancel_outlined),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Tanggal: ${DateFormat('dd MMM yyyy').format(_selectedDate)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: _selectedKelas,
                  items: [
                    const DropdownMenuItem(value: "Semua Kelas", child: Text("Semua Kelas")),
                    ..._kelas.map((k) => DropdownMenuItem(value: k['namaKelas'].toString(), child: Text("Kelas ${k['namaKelas']}"))),
                  ],
                  onChanged: (v) { setState(() => _selectedKelas = v!); _fetchRekap(); },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _rekapData['details'].isEmpty 
            ? const Padding(padding: EdgeInsets.all(30), child: Center(child: Text("Data Kosong")))
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _rekapData['details'].length,
                itemBuilder: (context, index) {
                  final d = _rekapData['details'][index];
                  String status = (d['hadir'] ?? 0) > 0 ? "Hadir" : ((d['sakit'] ?? 0) > 0 ? "Sakit" : ((d['izin'] ?? 0) > 0 ? "Izin" : ((d['alpha'] ?? 0) > 0 ? "Alpha" : "-")));
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(d['nama_siswa'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text("NIS: ${d['nis'] ?? '-'}", style: const TextStyle(fontSize: 11)),
                      trailing: _statusBadge(status),
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color = Colors.grey;
    if (status == "Hadir") color = Colors.green;
    else if (status == "Sakit") color = Colors.blue;
    else if (status == "Izin") color = Colors.orange;
    else if (status == "Alpha") color = Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
      child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label, value, selected;
  final Function(String) onSelected;
  const _PeriodChip({required this.label, required this.value, required this.selected, required this.onSelected});
  @override
  Widget build(BuildContext context) {
    bool isSelected = selected == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(color: isSelected ? Colors.blue : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        selected: isSelected,
        onSelected: (_) => onSelected(value),
        selectedColor: Colors.white,
        backgroundColor: Colors.white.withOpacity(0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        showCheckmark: false,
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _SummaryItem({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9)),
      ],
    );
  }
}

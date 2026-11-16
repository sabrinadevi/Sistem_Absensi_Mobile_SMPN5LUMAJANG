package com.absensi.attendance_api.controller;

import com.absensi.attendance_api.model.Siswa;
import com.absensi.attendance_api.model.Kelas;
import com.absensi.attendance_api.repository.SiswaRepository;
import com.absensi.attendance_api.repository.KelasRepository;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.InputStream;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@RestController
@RequestMapping("/api/siswa")
@CrossOrigin(origins = "*")
public class SiswaController {

    @Autowired
    private SiswaRepository siswaRepository;

    @Autowired
    private KelasRepository kelasRepository;

    @GetMapping
    public List<Siswa> getAllSiswa() {
        return siswaRepository.findAll();
    }

    @PostMapping("/add")
    public ResponseEntity<?> addSiswa(@RequestBody Map<String, Object> payload) {
        return saveOrUpdate(null, payload);
    }

    @PutMapping("/update/{id}")
    public ResponseEntity<?> updateSiswa(@PathVariable Integer id, @RequestBody Map<String, Object> payload) {
        return saveOrUpdate(id, payload);
    }

    private ResponseEntity<?> saveOrUpdate(Integer id, Map<String, Object> payload) {
        Map<String, Object> response = new HashMap<>();
        try {
            String nisn = payload.get("nisn").toString();
            Siswa siswa;
            
            if (id != null) {
                // Jika ada ID di URL, cari berdasarkan ID
                siswa = siswaRepository.findById(id).orElse(new Siswa());
            } else {
                // Jika tidak ada ID, cari berdasarkan NISN di database
                siswa = siswaRepository.findByNisn(nisn).orElse(new Siswa());
            }
            
            if (payload.containsKey("namaSiswa")) siswa.setNamaSiswa(payload.get("namaSiswa").toString().toUpperCase());
            siswa.setNisn(nisn);
            if (payload.containsKey("jenisKelamin")) siswa.setJenisKelamin(payload.get("jenisKelamin").toString());

            // Logika baru: Bisa pakai id_kelas (angka) ATAU nama_kelas (teks seperti 8A)
            if (payload.containsKey("id_kelas") && payload.get("id_kelas") != null && !payload.get("id_kelas").toString().isEmpty()) {
                try {
                    Integer idKelas = Integer.parseInt(payload.get("id_kelas").toString());
                    kelasRepository.findById(idKelas).ifPresent(siswa::setKelas);
                } catch (Exception e) {
                    // Jika gagal parse id, abaikan
                }
            } else if (payload.containsKey("nama_kelas") && payload.get("nama_kelas") != null) {
                String namaK = payload.get("nama_kelas").toString().toUpperCase();
                Kelas k = kelasRepository.findByNamaKelas(namaK).orElseGet(() -> {
                    Kelas newK = new Kelas();
                    newK.setNamaKelas(namaK);
                    return kelasRepository.save(newK);
                });
                siswa.setKelas(k);
            }

            siswaRepository.save(siswa);
            response.put("status", "success");
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            response.put("status", "error");
            response.put("message", e.getMessage());
            return ResponseEntity.badRequest().body(response);
        }
    }

    @PostMapping("/import")
    public ResponseEntity<?> importSiswa(@RequestParam("file") MultipartFile file) {
        Map<String, Object> response = new HashMap<>();
        int count = 0;
        try {
            String filename = file.getOriginalFilename();
            String classFromFilename = extractClassFromText(filename);

            try (InputStream is = file.getInputStream(); Workbook workbook = new XSSFWorkbook(is)) {
                Sheet sheet = workbook.getSheetAt(0);
                
                // Mulai scan dari baris pertama sampai akhir
                for (int i = 0; i <= sheet.getLastRowNum(); i++) {
                    Row row = sheet.getRow(i);
                    if (row == null) continue;

                    // Berdasarkan gambar: B=NISN/NIS, C=NAMA, D=JK
                    String cellB = getCellValue(row.getCell(1)); // Kolom B
                    String cellC = getCellValue(row.getCell(2)); // Kolom C
                    String cellD = getCellValue(row.getCell(3)); // Kolom D

                    // Filter: Jika Kolom B tidak ada angka sama sekali, abaikan (mungkin header/kosong)
                    if (!cellB.matches(".*\\d+.*")) continue;
                    // Filter: Nama minimal 3 huruf
                    if (cellC.length() < 3) continue;

                    // AMBIL NIS: Jika ada '/', ambil yang belakang. Jika tidak, ambil semua.
                    String nis = cellB;
                    if (cellB.contains("/")) {
                        String[] parts = cellB.split("/");
                        nis = parts[parts.length - 1].trim();
                    }

                    // SIMPAN DATA
                    Siswa siswa = siswaRepository.findByNisn(nis).orElse(new Siswa());
                    siswa.setNamaSiswa(cellC.toUpperCase());
                    siswa.setNisn(nis);
                    siswa.setJenisKelamin(cellD.equalsIgnoreCase("P") ? "Perempuan" : "Laki-laki");

                    // KELAS DARI NAMA FILE
                    if (!classFromFilename.isEmpty()) {
                        final String kFix = classFromFilename;
                        Kelas k = kelasRepository.findByNamaKelas(kFix).orElseGet(() -> {
                            Kelas newK = new Kelas();
                            newK.setNamaKelas(kFix);
                            return kelasRepository.save(newK);
                        });
                        siswa.setKelas(k);
                    }

                    siswaRepository.save(siswa);
                    count++;
                }

                response.put("status", "success");
                response.put("message", "Berhasil import " + count + " siswa ke kelas " + classFromFilename);
                return ResponseEntity.ok(response);
            }
        } catch (Exception e) {
            response.put("status", "error");
            response.put("message", "Error: " + e.getMessage());
            return ResponseEntity.ok(response);
        }
    }

    private String extractClassFromText(String text) {
        if (text == null) return "";
        String nameOnly = text.contains(".") ? text.substring(0, text.lastIndexOf('.')) : text;
        Pattern p = Pattern.compile("([789]|1[012])\\s*[-_]?\\s*([A-Z])");
        Matcher m = p.matcher(nameOnly.toUpperCase());
        if (m.find()) return m.group(1) + m.group(2);
        return nameOnly.toUpperCase();
    }

    private String getCellValue(Cell cell) {
        if (cell == null) return "";
        DataFormatter formatter = new DataFormatter();
        return formatter.formatCellValue(cell).trim();
    }

    @DeleteMapping("/delete/{id}")
    public ResponseEntity<?> deleteSiswa(@PathVariable Integer id) {
        siswaRepository.deleteById(id);
        Map<String, Object> response = new HashMap<>();
        response.put("status", "success");
        return ResponseEntity.ok(response);
    }

    @DeleteMapping("/delete-all")
    public ResponseEntity<?> deleteAllSiswa() {
        siswaRepository.deleteAll();
        Map<String, Object> response = new HashMap<>();
        response.put("status", "success");
        return ResponseEntity.ok(response);
    }
}

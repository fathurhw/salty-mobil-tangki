# SALTY — Sistem Checklist Pemeriksaan Mobil Tangki (PHP + MySQL/phpMyAdmin)

Aplikasi web checklist **Pemeriksaan MT Baru** dan **Inspeksi 6 Bulanan (Keur)** dengan
6 peran login dan approval berjenjang, dibangun dengan PHP murni (tanpa framework) +
MySQL/MariaDB. Cocok dijalankan di XAMPP / Laragon / hosting cPanel.

> Catatan: kode PHP ini tidak berjalan di dalam preview Lovable (preview hanya menjalankan
> aplikasi React). Jalankan di server PHP Anda sendiri.

## 1. Kebutuhan

- PHP 8.0+ (ekstensi `mysqli` aktif)
- MySQL 5.7+ / MariaDB 10.4+
- phpMyAdmin (untuk impor database)

## 2. Instalasi

1. Copy folder `salty-app/` ke direktori web server, misal `C:\xampp\htdocs\salty`.
2. Buka **phpMyAdmin** → tab **Import** → impor berurutan:
   1. `database/schema.sql` (membuat database `salty_checklist`, semua tabel, view, user & data contoh)
   2. `database/seed_items.sql` (493 item checklist hasil ekstraksi dari kedua form PDF resmi)
      → pastikan database aktif `salty_checklist` sebelum mengimpor file ini.
3. Sesuaikan koneksi di `config/config.php` (`DB_USER`, `DB_PASS`, dll).
4. Buka `http://localhost/salty/`.

## 3. Akun contoh (password: `password123`)

| Username | Peran | Hak akses |
|---|---|---|
| `admin` | Admin HSSE | Master data (MT, transportir, item checklist, user), buat & lihat jadwal, monitor jatuh tempo |
| `inspector` | Inspector HSSE | Mengisi checklist MT Baru & 6 Bulanan, ajukan approval |
| `hsse` | HSSE | Lihat jadwal, approve checklist (tahap 1) |
| `distribusi` | Distribusi | Lihat jadwal, approve checklist (tahap 1) |
| `qq` | QQ Distribusi | Lihat jadwal, approve checklist (tahap 1) |
| `itm` | ITM / Manager | Approve final setelah HSSE + Distribusi + QQ setuju |

Ganti password semua akun setelah instalasi (menu **Master User**).

## 4. Alur kerja

```
Admin HSSE                Inspector HSSE            HSSE / Distribusi / QQ         ITM
-----------               ---------------           ----------------------          ---
buat master MT     →      isi checklist       →     approve paralel (3 orang)  →    approve final
buat jadwal               ajukan approval           (tahap 1)                       (tahap 2)
monitor jatuh tempo                                                                 ↓
(peringatan 5 & 3 hari)                                          tanggal inspeksi terakhir MT ter-update
                                                                 jatuh tempo berikutnya = +6 bulan
```

Status checklist: `draft` → `diajukan` → `approve_sebagian` → `disetujui` (atau `ditolak`).
Approval ITM baru terbuka setelah ketiga approver tahap 1 menyetujui — divalidasi di
`includes/helpers.php` (`can_approve()`), bukan hanya di tampilan.

## 5. Struktur file

```
php-app/
├── config/config.php          koneksi DB & konstanta aplikasi
├── includes/
│   ├── auth.php               session, login, peran, CSRF
│   ├── helpers.php            format tanggal, badge, alur approval, jatuh tempo
│   ├── layout.php             sidebar + header sesuai peran
│   └── forbidden.php          halaman 403
├── assets/style.css           tema hijau/merah Pertamina
├── index.php                  halaman login
├── dashboard.php              ringkasan, jatuh tempo, jadwal, approval pending
├── vehicles.php               master mobil tangki
├── transporters.php           master transportir
├── items.php                  master item checklist (2 form)
├── users.php                  master user & peran
├── schedules.php              jadwal pemeriksaan (buat/ubah oleh Admin HSSE)
├── due.php                    monitoring jatuh tempo (filter ≤5 / ≤3 hari / terlewat)
├── inspections.php            daftar checklist
├── inspection_form.php        pengisian checklist oleh inspector
├── inspection_view.php        detail + panel approval
├── print.php                  versi cetak / PDF mirip form resmi
└── database/
    ├── schema.sql             struktur + data awal
    └── seed_items.sql         item checklist kedua form
```

## 6. Tabel utama

`users`, `transporters`, `vehicles`, `checklist_items`, `schedules`, `inspections`,
`inspection_results`, `inspection_approvals`, serta view `v_due_inspections`
(menghitung `sisa_hari` menuju jatuh tempo inspeksi 6 bulanan).

## 7. Catatan keamanan

- Password disimpan dengan `password_hash()` (bcrypt).
- Semua query memakai *prepared statement* (`includes`/`config/config.php`).
- Form POST dilindungi token CSRF.
- Otorisasi peran diperiksa di sisi server pada setiap halaman (`require_role`).

## Verifikasi 2 Langkah (Authenticator) — Admin HSSE
- Akun **admin** (Admin HSSE) wajib memakai aplikasi authenticator
  (Google Authenticator / Microsoft Authenticator / Authy).
- Login: username + password → halaman **Verifikasi 2 Langkah** → pindai QR
  (atau masukkan kunci manual) → isi 6 digit kode.
- Tersimpan 5 **kode pemulihan** sekali pakai bila ponsel hilang.
- Reset perangkat: menu **Keamanan** setelah login (`twofa_setup.php`).
- Kolom database baru: `users.totp_secret`, `users.totp_enabled`, `users.recovery_codes`.
- DB lama: jalankan `database/migration_update_2026.sql`; DB baru: `database/full_import.sql`.

## Update 2026-09 (b) — Data Mobil Tangki & dokumen

- Menu baru **Data Mobil Tangki**: rekap seluruh MT di Integrated Terminal (nopol, transportir, kapasitas KL,
  no. STNK, surat keur, tera metrologi, foto tampak depan/belakang/kanan/kiri, jatuh tempo inspeksi & status),
  lengkap dengan filter (transportir, status, jenis tangki, jatuh tempo, pencarian) dan pengurutan per kolom.
- Tombol **Cetak / PDF** pada halaman tersebut untuk mencetak rekap + lampiran foto & dokumen (STNK, Keur, Tera).
- Master Mobil Tangki kini bisa mengunggah 4 foto tampak MT + scan STNK, Keur, dan Surat Tera (JPG/PNG/WEBP/PDF, maks 8 MB).
  File tersimpan di folder `uploads/mt/`.
- Master Item Checklist **MT Baru** ditambah section `G. DOKUMENTASI FOTO MOBIL TANGKI` (foto tampak depan, belakang, kanan, kiri).
- Cap APPROVED tampil di samping nama & jabatan approver, lengkap tanggal + jam WIB.
- Database baru: import `database/full_import.sql`. Database lama: jalankan `database/migration_update_2026.sql`.

## Data contoh lengkap (foto & dokumen)

- Folder `uploads/mt/` berisi foto contoh MT (depan, belakang, kanan, kiri) serta scan STNK, Buku Keur, dan Surat Tera.
- Folder `uploads/temuan/` berisi foto contoh temuan (seal bottom valve).
- Path file tersebut sudah terpasang otomatis ke seluruh data MT dan checklist demo oleh `database/full_import.sql`.
- Untuk database lama, jalankan `database/seed_demo_media.sql` (atau `database/migration_update_2026.sql`).

## Update terbaru
- Halaman **Jatuh Tempo** kini menghitung jatuh tempo dari yang paling cepat antara inspeksi 6 bulanan, masa berlaku STNK, Buku KEUR, dan Surat Tera (kolom + filter baru).
- Label approval di cetakan: HSSE Inspector, Approval HSSE, Approval Distribusi, Approval QQ.
- DB lama: jalankan `database/migration_update_2026.sql` (view `v_due_inspections` diperbarui).

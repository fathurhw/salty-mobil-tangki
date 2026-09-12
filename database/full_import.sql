-- =====================================================================
-- Database: SIMT (Sistem Inspeksi Mobil Tangki)
-- Checklist Pemeriksaan MT Baru & Inspeksi 6 Bulanan
-- MySQL / MariaDB  (import via phpMyAdmin)
-- =====================================================================

CREATE DATABASE IF NOT EXISTS salty_checklist
  DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE salty_checklist;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS inspection_approvals;
DROP TABLE IF EXISTS inspection_photos;
DROP TABLE IF EXISTS inspection_results;

DROP TABLE IF EXISTS inspections;
DROP TABLE IF EXISTS schedules;
DROP TABLE IF EXISTS checklist_items;
DROP TABLE IF EXISTS vehicles;
DROP TABLE IF EXISTS transporters;
DROP TABLE IF EXISTS users;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- 1. USERS (6 peran)
-- ---------------------------------------------------------------------
CREATE TABLE users (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  username     VARCHAR(50)  NOT NULL UNIQUE,
  password     VARCHAR(255) NOT NULL,          -- password_hash()
  nama         VARCHAR(100) NOT NULL,
  jabatan      VARCHAR(100) DEFAULT NULL,
  role         ENUM('admin_hsse','inspector_hsse','hsse','distribusi','qq','itm') NOT NULL,
  aktif        TINYINT(1) NOT NULL DEFAULT 1,
  -- Verifikasi 2 langkah (authenticator) — wajib untuk role admin_hsse
  totp_secret     VARCHAR(64)  DEFAULT NULL,
  totp_enabled    TINYINT(1)   NOT NULL DEFAULT 0,
  recovery_codes  VARCHAR(255) DEFAULT NULL,
  created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 2. TRANSPORTIR
-- ---------------------------------------------------------------------
CREATE TABLE transporters (
  id        INT AUTO_INCREMENT PRIMARY KEY,
  nama      VARCHAR(150) NOT NULL,
  telepon   VARCHAR(50) DEFAULT NULL,
  alamat    VARCHAR(255) DEFAULT NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 3. MASTER MOBIL TANGKI
-- ---------------------------------------------------------------------
CREATE TABLE vehicles (
  id                 INT AUTO_INCREMENT PRIMARY KEY,
  no_polisi          VARCHAR(30)  NOT NULL UNIQUE,
  no_chasis          VARCHAR(60)  DEFAULT NULL,
  transporter_id     INT DEFAULT NULL,
  merk               VARCHAR(80)  DEFAULT NULL,
  tahun              SMALLINT     DEFAULT NULL,
  pabrikan_tangki    VARCHAR(100) DEFAULT NULL,
  kapasitas_kl       DECIMAL(6,2) DEFAULT NULL,
  jenis_tangki       ENUM('rigid','semi_trailer','gandengan') DEFAULT 'rigid',
  bahan_tangki       VARCHAR(60)  DEFAULT NULL,
  produk             VARCHAR(60)  DEFAULT NULL,
  stnk_no            VARCHAR(60)  DEFAULT NULL,
  stnk_berlaku       DATE DEFAULT NULL,
  keur_no            VARCHAR(60)  DEFAULT NULL,
  keur_berlaku       DATE DEFAULT NULL,
  tera_berlaku       DATE DEFAULT NULL,
  foto_depan         VARCHAR(255) DEFAULT NULL,
  foto_belakang      VARCHAR(255) DEFAULT NULL,
  foto_kanan         VARCHAR(255) DEFAULT NULL,
  foto_kiri          VARCHAR(255) DEFAULT NULL,
  doc_stnk           VARCHAR(255) DEFAULT NULL,
  doc_keur           VARCHAR(255) DEFAULT NULL,
  doc_tera           VARCHAR(255) DEFAULT NULL,
  status             ENUM('aktif','off','nonaktif') NOT NULL DEFAULT 'aktif',
  last_inspection    DATE DEFAULT NULL,   -- tanggal inspeksi 6 bulanan terakhir (final approve)
  next_inspection    DATE DEFAULT NULL,   -- last_inspection + 6 bulan
  created_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_veh_transporter FOREIGN KEY (transporter_id)
    REFERENCES transporters(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4. MASTER ITEM CHECKLIST (dari 2 form PDF)
-- ---------------------------------------------------------------------
CREATE TABLE checklist_items (
  id                  INT AUTO_INCREMENT PRIMARY KEY,
  form_type           ENUM('baru','6bulanan') NOT NULL,
  section             VARCHAR(150) NOT NULL,
  item_no             VARCHAR(10)  DEFAULT NULL,
  item_text           TEXT NOT NULL,
  penjelasan          TEXT DEFAULT NULL,
  prioritas           ENUM('MANDATORY','NON MANDATORY') NOT NULL DEFAULT 'MANDATORY',
  batas_non_mandatory VARCHAR(20) DEFAULT NULL,   -- contoh: "6 HK"
  pelaksana           VARCHAR(30) DEFAULT NULL,   -- HSSE / Distribusi / QQ
  aktif               TINYINT(1) NOT NULL DEFAULT 1,
  sort_order          INT NOT NULL DEFAULT 0,
  INDEX idx_form (form_type, sort_order)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 5. JADWAL PEMERIKSAAN (dibuat oleh Admin HSSE)
-- ---------------------------------------------------------------------
CREATE TABLE schedules (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  vehicle_id    INT NOT NULL,
  form_type     ENUM('baru','6bulanan') NOT NULL,
  tanggal       DATE NOT NULL,
  jam           TIME DEFAULT NULL,
  lokasi        VARCHAR(120) DEFAULT 'Integrated Terminal Palembang',
  inspector_id  INT DEFAULT NULL,
  catatan       VARCHAR(255) DEFAULT NULL,
  status        ENUM('dijadwalkan','proses','selesai','batal') NOT NULL DEFAULT 'dijadwalkan',
  created_by    INT DEFAULT NULL,
  created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_sch_vehicle   FOREIGN KEY (vehicle_id)   REFERENCES vehicles(id) ON DELETE CASCADE,
  CONSTRAINT fk_sch_inspector FOREIGN KEY (inspector_id) REFERENCES users(id)    ON DELETE SET NULL,
  CONSTRAINT fk_sch_creator   FOREIGN KEY (created_by)   REFERENCES users(id)    ON DELETE SET NULL,
  INDEX idx_tanggal (tanggal)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 6. HEADER INSPEKSI (pengisian checklist oleh Inspector HSSE)
--    Alur: draft -> diajukan -> (HSSE + QQ + Distribusi approve) -> ITM approve -> final
-- ---------------------------------------------------------------------
CREATE TABLE inspections (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  no_pemeriksaan  VARCHAR(60) NOT NULL UNIQUE,
  schedule_id     INT DEFAULT NULL,
  vehicle_id      INT NOT NULL,
  form_type       ENUM('baru','6bulanan') NOT NULL,
  tgl_pemeriksaan DATE NOT NULL,
  tgl_terakhir    DATE DEFAULT NULL,
  inspector_id    INT DEFAULT NULL,
  nama_amt        VARCHAR(100) DEFAULT NULL,
  umur_amt        SMALLINT DEFAULT NULL,
  sim_amt         VARCHAR(60) DEFAULT NULL,
  nota_temuan     TEXT DEFAULT NULL,
  hasil_akhir     ENUM('','OK','NOT OK') NOT NULL DEFAULT '',
  status          ENUM('draft','diajukan','approve_sebagian','disetujui','ditolak')
                  NOT NULL DEFAULT 'draft',
  submitted_at    DATETIME DEFAULT NULL,
  finalized_at    DATETIME DEFAULT NULL,
  created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_insp_vehicle  FOREIGN KEY (vehicle_id)  REFERENCES vehicles(id)  ON DELETE CASCADE,
  CONSTRAINT fk_insp_schedule FOREIGN KEY (schedule_id) REFERENCES schedules(id) ON DELETE SET NULL,
  CONSTRAINT fk_insp_user     FOREIGN KEY (inspector_id) REFERENCES users(id)    ON DELETE SET NULL,
  INDEX idx_status (status)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 7. DETAIL HASIL CHECKLIST
-- ---------------------------------------------------------------------
CREATE TABLE inspection_results (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  inspection_id INT NOT NULL,
  item_id       INT NOT NULL,
  hasil         ENUM('baik','tidak','na') NOT NULL DEFAULT 'na',
  keterangan    VARCHAR(255) DEFAULT NULL,
  batas_perbaikan DATE DEFAULT NULL,
  CONSTRAINT fk_res_insp FOREIGN KEY (inspection_id) REFERENCES inspections(id) ON DELETE CASCADE,
  CONSTRAINT fk_res_item FOREIGN KEY (item_id)       REFERENCES checklist_items(id) ON DELETE CASCADE,
  UNIQUE KEY uq_insp_item (inspection_id, item_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 7b. FOTO TEMUAN (bisa lebih dari 1 foto per item pemeriksaan)
-- ---------------------------------------------------------------------
CREATE TABLE inspection_photos (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  inspection_id INT NOT NULL,
  item_id       INT DEFAULT NULL,
  file_path     VARCHAR(255) NOT NULL,
  uploaded_by   INT DEFAULT NULL,
  uploaded_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_foto_insp FOREIGN KEY (inspection_id) REFERENCES inspections(id) ON DELETE CASCADE,
  CONSTRAINT fk_foto_item FOREIGN KEY (item_id)       REFERENCES checklist_items(id) ON DELETE CASCADE,
  CONSTRAINT fk_foto_user FOREIGN KEY (uploaded_by)   REFERENCES users(id)          ON DELETE SET NULL,
  KEY idx_foto_insp (inspection_id, item_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 8. APPROVAL BERJENJANG
--    level 1 = hsse / distribusi / qq (paralel), level 2 = itm (final)
-- ---------------------------------------------------------------------
CREATE TABLE inspection_approvals (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  inspection_id INT NOT NULL,
  role          ENUM('hsse','distribusi','qq','itm') NOT NULL,
  level         TINYINT NOT NULL DEFAULT 1,
  status        ENUM('menunggu','disetujui','ditolak') NOT NULL DEFAULT 'menunggu',
  user_id       INT DEFAULT NULL,
  catatan       VARCHAR(255) DEFAULT NULL,
  acted_at      DATETIME DEFAULT NULL,
  CONSTRAINT fk_app_insp FOREIGN KEY (inspection_id) REFERENCES inspections(id) ON DELETE CASCADE,
  CONSTRAINT fk_app_user FOREIGN KEY (user_id)       REFERENCES users(id)       ON DELETE SET NULL,
  UNIQUE KEY uq_insp_role (inspection_id, role)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- VIEW: MT yang jatuh tempo inspeksi 6 bulanan
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS v_due_inspections;
CREATE VIEW v_due_inspections AS
SELECT v.id, v.no_polisi, t.nama AS transportir, v.last_inspection, v.next_inspection,
       v.stnk_no, v.stnk_berlaku, v.keur_no, v.keur_berlaku, v.tera_berlaku,
       DATEDIFF(v.next_inspection, CURDATE()) AS sisa_inspeksi,
       DATEDIFF(v.stnk_berlaku, CURDATE())    AS sisa_stnk,
       DATEDIFF(v.keur_berlaku, CURDATE())    AS sisa_keur,
       DATEDIFF(v.tera_berlaku, CURDATE())    AS sisa_tera,
       LEAST(
         COALESCE(DATEDIFF(v.next_inspection, CURDATE()), 99999),
         COALESCE(DATEDIFF(v.stnk_berlaku, CURDATE()), 99999),
         COALESCE(DATEDIFF(v.keur_berlaku, CURDATE()), 99999),
         COALESCE(DATEDIFF(v.tera_berlaku, CURDATE()), 99999)
       ) AS sisa_hari,
       CASE LEAST(
         COALESCE(DATEDIFF(v.next_inspection, CURDATE()), 99999),
         COALESCE(DATEDIFF(v.stnk_berlaku, CURDATE()), 99999),
         COALESCE(DATEDIFF(v.keur_berlaku, CURDATE()), 99999),
         COALESCE(DATEDIFF(v.tera_berlaku, CURDATE()), 99999))
         WHEN DATEDIFF(v.next_inspection, CURDATE()) THEN 'Inspeksi 6 Bulanan'
         WHEN DATEDIFF(v.stnk_berlaku, CURDATE())    THEN 'Masa Berlaku STNK'
         WHEN DATEDIFF(v.keur_berlaku, CURDATE())    THEN 'Masa Berlaku Buku KEUR'
         WHEN DATEDIFF(v.tera_berlaku, CURDATE())    THEN 'Masa Berlaku Surat Tera'
         ELSE '-' END AS sumber_jatuh_tempo
FROM vehicles v
LEFT JOIN transporters t ON t.id = v.transporter_id
WHERE v.status = 'aktif'
  AND (v.next_inspection IS NOT NULL OR v.stnk_berlaku IS NOT NULL
       OR v.keur_berlaku IS NOT NULL OR v.tera_berlaku IS NOT NULL);

-- =====================================================================
-- DATA AWAL
-- =====================================================================
-- Semua user contoh memakai password: password123
INSERT INTO users (username, password, nama, jabatan, role) VALUES
('admin',      '$2y$10$1uqWDnPLp2fw0b9Sanqkv.1JHs3oA/Ec4LMdS/udSGvpa4WvTE0jK', 'Admin HSSE',        'Officer HSSE',              'admin_hsse'),
('inspector',  '$2y$10$1uqWDnPLp2fw0b9Sanqkv.1JHs3oA/Ec4LMdS/udSGvpa4WvTE0jK', 'HSSE Support',      'Jr. Spv. I Fleet Safety',   'inspector_hsse'),
('hsse',       '$2y$10$1uqWDnPLp2fw0b9Sanqkv.1JHs3oA/Ec4LMdS/udSGvpa4WvTE0jK', 'Sr Spv II HSSE',    'Approval HSSE',                  'hsse'),
('distribusi', '$2y$10$1uqWDnPLp2fw0b9Sanqkv.1JHs3oA/Ec4LMdS/udSGvpa4WvTE0jK', 'Spv I Fuel Distribusi Kertapati Baru','Approval Distribusi','distribusi'),
('qq',         '$2y$10$1uqWDnPLp2fw0b9Sanqkv.1JHs3oA/Ec4LMdS/udSGvpa4WvTE0jK', 'Sr Spv I QQ',     'Approval QQ',                   'qq'),
('itm',        '$2y$10$1uqWDnPLp2fw0b9Sanqkv.1JHs3oA/Ec4LMdS/udSGvpa4WvTE0jK', 'Okryreza Abdurrachman','Integrated Terminal Manager','itm');

INSERT INTO transporters (nama, telepon) VALUES
('PT Elnusa Petrofin', '0711-000111'),
('PT Patra Niaga Trans', '0711-000222'),
('PT Sumber Kencana Trans', '0711-000333');

INSERT INTO vehicles (no_polisi, no_chasis, transporter_id, merk, tahun, pabrikan_tangki, kapasitas_kl,
                      jenis_tangki, bahan_tangki, produk, stnk_no, stnk_berlaku, keur_no, keur_berlaku,
                      last_inspection, next_inspection) VALUES
('BG 8001 XU', 'MHF1234567890001', 1, 'Hino 500', 2019, 'PT Tangki Nusantara', 16.00, 'semi_trailer', 'Mild steel', 'White oil/Biofuel', 'STNK-8001', '2027-04-11', 'KEUR-8001', '2026-11-30', '2026-03-05', '2026-09-05'),
('BG 8002 XU', 'MHF1234567890002', 1, 'Mitsubishi Fuso', 2021, 'PT Tangki Nusantara', 24.00, 'semi_trailer', 'Alumunium alloy', 'White oil/Biofuel', 'STNK-8002', '2027-01-20', 'KEUR-8002', '2026-10-15', '2026-03-08', '2026-09-08'),
('BG 8003 XU', 'MHF1234567890003', 2, 'Hino 260', 2020, 'PT Karya Tangki', 8.00, 'rigid', 'Mild steel', 'Black oil', 'STNK-8003', '2026-12-01', 'KEUR-8003', '2026-12-20', '2026-03-16', '2026-09-16'),
('BG 8004 XU', 'MHF1234567890004', 2, 'Isuzu Giga', 2023, 'PT Karya Tangki', 32.00, 'semi_trailer', 'Stainless steel', 'White oil/Biofuel', 'STNK-8004', '2028-02-14', 'KEUR-8004', '2027-02-14', NULL, NULL),
('BG 8005 XU', 'MHF1234567890005', 3, 'Hino 500', 2018, 'PT Tangki Nusantara', 16.00, 'rigid', 'Mild steel', 'White oil/Biofuel', 'STNK-8005', '2026-09-30', 'KEUR-8005', '2026-09-25', '2026-02-25', '2026-08-25');

INSERT INTO schedules (vehicle_id, form_type, tanggal, jam, inspector_id, status, created_by) VALUES
(1, '6bulanan', '2026-09-05', '08:00:00', 2, 'dijadwalkan', 1),
(2, '6bulanan', '2026-09-08', '09:00:00', 2, 'dijadwalkan', 1),
(4, 'baru',     '2026-09-04', '08:30:00', 2, 'dijadwalkan', 1),
(5, '6bulanan', '2026-09-02', '13:00:00', 2, 'proses',      1);

-- Item checklist (hasil ekstraksi dari kedua form PDF) ada di file seed_items.sql
-- Import setelah file ini:  salty_checklist  <-  database/seed_items.sql

INSERT INTO checklist_items (form_type, section, item_no, item_text, penjelasan, prioritas, batas_non_mandatory, pelaksana, sort_order) VALUES
('baru','A. GENERAL','1','Pemilik','','NON MANDATORY','','',1),
('baru','A. GENERAL','2','No. Polisi','','NON MANDATORY','','',2),
('baru','A. GENERAL','3','No. Chasis','','NON MANDATORY','','',3),
('baru','A. GENERAL','4','Angkutan [ ] SPBU/Pertashop/Sejenis [ ] Industri [ ] Agen Minyak Tanah [ ] DPPU','','NON MANDATORY','','',4),
('baru','A. GENERAL','5','Produk [ ] White oil/Biofuel [ ] Black oil [ ] Solvent','','NON MANDATORY','','',5),
('baru','A. GENERAL','6','BPKB No.','','NON MANDATORY','','',6),
('baru','A. GENERAL','7','STNK No.','','NON MANDATORY','','',7),
('baru','A. GENERAL','8','Keur kendaraan No','','NON MANDATORY','','',8),
('baru','A. GENERAL','9','Keur tangki semi No','','NON MANDATORY','','',9),
('baru','A. GENERAL','10','Tera Metrologi TUM (Ijkbout) No.','','NON MANDATORY','','',10),
('baru','A. GENERAL','11','Tera Metrologi Meter Arus (Flowmeter) No.','','NON MANDATORY','','',11),
('baru','A. GENERAL','12','Pabrikan tangki','','NON MANDATORY','','',12),
('baru','A. GENERAL','13','Jenis Tangki : [ ] Rigid [ ] Semi trailer [ ] Gandengan','','NON MANDATORY','','',13),
('baru','A. GENERAL','14','Bentuk Tangki* : [ ] Semi elips [ ] Silinder [ ] Lainnya','','MANDATORY','','HSSE',14),
('baru','A. GENERAL','15','Mild steel, innercoating mm','Bahan Tangki* : [ ] Alumunium [ ] Alumunium alloy [ ] Stainless steel','NON MANDATORY','','',15),
('baru','A. GENERAL','15','Lainnya','Bahan Tangki* : [ ] Alumunium [ ] Alumunium alloy [ ] Stainless steel','NON MANDATORY','','',16),
('baru','A. GENERAL','16','15 KL','Volume total* : [ ] 5 KL [ ] 8 KL [ ] 10 KL','NON MANDATORY','','',17),
('baru','A. GENERAL','16','16 KL','Volume total* : [ ] 5 KL [ ] 8 KL [ ] 10 KL','NON MANDATORY','','',18),
('baru','A. GENERAL','16','24 KL','Volume total* : [ ] 5 KL [ ] 8 KL [ ] 10 KL','NON MANDATORY','','',19),
('baru','A. GENERAL','16','32 KL','Volume total* : [ ] 5 KL [ ] 8 KL [ ] 10 KL','NON MANDATORY','','',20),
('baru','A. GENERAL','16','40 KL','Volume total* : [ ] 5 KL [ ] 8 KL [ ] 10 KL','NON MANDATORY','','',21),
('baru','A. GENERAL','16','Lainnya','Volume total* : [ ] 5 KL [ ] 8 KL [ ] 10 KL','NON MANDATORY','','',22),
('baru','B. SISI DEPAN & SISI BELAKANG','17','Tidak ada tangga/salah posisi (terletak pada bagian belakang)','Tangga akses','NON MANDATORY','','',23),
('baru','B. SISI DEPAN & SISI BELAKANG','17','Ada tangga (Semi-trailer, Rigid : Depan)','Tangga akses','NON MANDATORY','','',24),
('baru','B. SISI DEPAN & SISI BELAKANG','17','Tangga dipasang dengan mur-baut','Tangga akses','NON MANDATORY','','',25),
('baru','B. SISI DEPAN & SISI BELAKANG','17','Pijakan dari plat bordes (atau dari material yang anti slip), lebar & spasi pijakan 250 - 300 mm','Tangga akses','NON MANDATORY','','',26),
('baru','B. SISI DEPAN & SISI BELAKANG','17','Jarak bebas antara tangga dengan tangki min. 150 mm','Tangga akses','NON MANDATORY','','',27),
('baru','B. SISI DEPAN & SISI BELAKANG','17','Pegangan bagian atas tangga dinaikan melebihi coaming','Tangga akses','NON MANDATORY','','',28),
('baru','B. SISI DEPAN & SISI BELAKANG','17','Pada bawah tangga dipasang tutup pengaman/pintu akses','Tangga akses','NON MANDATORY','','',29),
('baru','B. SISI DEPAN & SISI BELAKANG','17','Bukaan pintu akses mengarah ke sisi pengemudi (untuk tipe rigid mengarah ke depan) & terhubung ke sistem Interlock','Tangga akses','NON MANDATORY','','',30),
('baru','B. SISI DEPAN & SISI BELAKANG','18','Pabrikan headtruck','','NON MANDATORY','','',31),
('baru','B. SISI DEPAN & SISI BELAKANG','19','Rigid','Jenis Penggerak','NON MANDATORY','','',32),
('baru','B. SISI DEPAN & SISI BELAKANG','19','Prime Mover/Trailer','Jenis Penggerak','NON MANDATORY','','',33),
('baru','B. SISI DEPAN & SISI BELAKANG','20','Rasio tenaga mesin : JBl ≥ 7,4','Mesin Headtruck','NON MANDATORY','','',34),
('baru','B. SISI DEPAN & SISI BELAKANG','20','Rasio tenaga mesin : JBI < 7,4','Mesin Headtruck','NON MANDATORY','','',35),
('baru','B. SISI DEPAN & SISI BELAKANG','21','Dipasang pada dashboard di dalam kabin','Sakelar Master/Safety Switch','NON MANDATORY','','',36),
('baru','B. SISI DEPAN & SISI BELAKANG','21','Diberi tanda/label','Sakelar Master/Safety Switch','NON MANDATORY','','',37),
('baru','B. SISI DEPAN & SISI BELAKANG','21','Dipasang pada bagian luar mobil tangki berdekatan dengan baterai','Sakelar Master/Safety Switch','NON MANDATORY','','',38),
('baru','B. SISI DEPAN & SISI BELAKANG','21','Sambungan kabel baik','Sakelar Master/Safety Switch','NON MANDATORY','','',39),
('baru','B. SISI DEPAN & SISI BELAKANG','21','Dapat dioperasikan dengan baik','Sakelar Master/Safety Switch','NON MANDATORY','','',40),
('baru','B. SISI DEPAN & SISI BELAKANG','22','24 Volt','Baterai','NON MANDATORY','','',41),
('baru','B. SISI DEPAN & SISI BELAKANG','22','Kombinasi serial 12 volt x 2','Baterai','NON MANDATORY','','',42),
('baru','B. SISI DEPAN & SISI BELAKANG','22','12 Volt','Baterai','NON MANDATORY','','',43),
('baru','B. SISI DEPAN & SISI BELAKANG','22','Penutup terminal baterai menggunakan tipe heavy duty dan tahan cuaca','Baterai','NON MANDATORY','','',44),
('baru','B. SISI DEPAN & SISI BELAKANG','22','Di bawah kap mesin','Baterai','NON MANDATORY','','',45),
('baru','B. SISI DEPAN & SISI BELAKANG','22','Diluar kap mesin','Baterai','NON MANDATORY','','',46),
('baru','B. SISI DEPAN & SISI BELAKANG','22','Tutup kotak cukup kuat','Baterai','NON MANDATORY','','',47),
('baru','B. SISI DEPAN & SISI BELAKANG','22','Dalam kotak berventilasi di belakang headtruck pada sisi pengemudi','Baterai','NON MANDATORY','','',48),
('baru','B. SISI DEPAN & SISI BELAKANG','23','Tidak menimbulkan penyalaan (ignition) atau hubungan singkat dalam kondisi pengoperasian','Instalasi Kelistrikan di Belakang Kabin','NON MANDATORY','','',49),
('baru','B. SISI DEPAN & SISI BELAKANG','23','Terdapat perlindungan terhadap benturan, abrasi dan gesekan selama pengoperasian','Instalasi Kelistrikan di Belakang Kabin','NON MANDATORY','','',50),
('baru','B. SISI DEPAN & SISI BELAKANG','24','Setiap komponen mesin, knalpot atau peralatan lainnya yang mengeluarkan panas termasuk sisi bawah chasis terlindungi dari kemungkinan percikan atau tetesan muatan','Pencegahan Risiko Kebakaran atau Penyalaan Sendiri','NON MANDATORY','','',51),
('baru','B. SISI DEPAN & SISI BELAKANG','24','Terbuat dari logam atau bahan yang tidak mudah terbakar','Pencegahan Risiko Kebakaran atau Penyalaan Sendiri','NON MANDATORY','','',52),
('baru','B. SISI DEPAN & SISI BELAKANG','24','Bukan dari bahan yang tidak mudah terbakar','Pencegahan Risiko Kebakaran atau Penyalaan Sendiri','NON MANDATORY','','',53),
('baru','B. SISI DEPAN & SISI BELAKANG','24','Terdapat pelindung belakang kabin','Pencegahan Risiko Kebakaran atau Penyalaan Sendiri','NON MANDATORY','','',54),
('baru','B. SISI DEPAN & SISI BELAKANG','24','Tidak terdapat pelindung','Pencegahan Risiko Kebakaran atau Penyalaan Sendiri','NON MANDATORY','','',55),
('baru','B. SISI DEPAN & SISI BELAKANG','24','Pemantik api dalam kabin dilepas atau ditutup dan dimatikan','Pencegahan Risiko Kebakaran atau Penyalaan Sendiri','NON MANDATORY','','',56),
('baru','B. SISI DEPAN & SISI BELAKANG','24','Terpasang stiker DILARANG MEROKOK','Pencegahan Risiko Kebakaran atau Penyalaan Sendiri','NON MANDATORY','','',57),
('baru','B. SISI DEPAN & SISI BELAKANG','25','Mesin penggerak diberi pelindung','Pencegahan terhadap Resiko Kebakaran atau Penyalaan pada Mesin','NON MANDATORY','','',58),
('baru','B. SISI DEPAN & SISI BELAKANG','25','Bagian blok mesin yang panas diberi pelindung','Pencegahan terhadap Resiko Kebakaran atau Penyalaan pada Mesin','NON MANDATORY','','',59),
('baru','B. SISI DEPAN & SISI BELAKANG','25','Berada di sisi bawah bagian kanan belakang dari pengemudi (berlawanan dengan sisi bongkar muat)','Pencegahan terhadap Resiko Kebakaran atau Penyalaan pada Mesin','NON MANDATORY','','',60),
('baru','B. SISI DEPAN & SISI BELAKANG','25','Tidak melalui sisi bawah tangki produk','Pencegahan terhadap Resiko Kebakaran atau Penyalaan pada Mesin','NON MANDATORY','','',61),
('baru','B. SISI DEPAN & SISI BELAKANG','25','Tidak berada langsung di bawah tangki bahan bakar ownuse','Pencegahan terhadap Resiko Kebakaran atau Penyalaan pada Mesin','NON MANDATORY','','',62),
('baru','B. SISI DEPAN & SISI BELAKANG','26','Kapasitas tangki BBM own use minimal 100 liter','Kelengkapan lain','NON MANDATORY','','',63),
('baru','B. SISI DEPAN & SISI BELAKANG','26','Dilengkapi wind deflektor, jika ketinggian tangki saat kosong > 300mm dihitung dari atap kabin','Kelengkapan lain','NON MANDATORY','','',64),
('baru','B. SISI DEPAN & SISI BELAKANG','26','Dipasang bumper di bawah kabin','Kelengkapan lain','NON MANDATORY','','',65),
('baru','B. SISI DEPAN & SISI BELAKANG','26','Dilengkapi sabuk pengaman','Kelengkapan lain','NON MANDATORY','','',66),
('baru','B. SISI DEPAN & SISI BELAKANG','26','Kursi tengah dilepas, untuk tidak memberikan kesempatan menumpang','Kelengkapan lain','NON MANDATORY','','',67),
('baru','B. SISI DEPAN & SISI BELAKANG','26','Tangga pijakan dan pegangan tangan terbuat dari pipa logam tahan karat, mampu menahan beban 120 kg.','Kelengkapan lain','NON MANDATORY','','',68),
('baru','B. SISI DEPAN & SISI BELAKANG','26','Jika dilengkapi PTO, pada dashboard dalam kabin harus terdapat PTO, lampu indikator PTO, dan printer','Kelengkapan lain','NON MANDATORY','','',69),
('baru','B. SISI DEPAN & SISI BELAKANG','27','Tersedia, kecepatan tidak bisa melebihi 80 km/jam','Alat Pembatas Kecepatan','NON MANDATORY','','',70),
('baru','B. SISI DEPAN & SISI BELAKANG','27','Tidak tersedia, dilengkapi alat pencatat perjalanan (speed counter)','Alat Pembatas Kecepatan','NON MANDATORY','','',71),
('baru','B. SISI DEPAN & SISI BELAKANG','28','Stiker blind spot (reflektif) dan emergency call proporsional sesuai standar','Tulisan Pada Tangki','NON MANDATORY','','',72),
('baru','B. SISI DEPAN & SISI BELAKANG','28','Logo Call Center 135 proporsional dan sesuai warnanya','Tulisan Pada Tangki','NON MANDATORY','','',73),
('baru','B. SISI DEPAN & SISI BELAKANG','29','Tulisan AWAS KENDARAAN PANJANG & LEBAR (stiker reflektif) khusus semi-trailer/trailer','Tulisan Pada Bumper','NON MANDATORY','','',74),
('baru','B. SISI DEPAN & SISI BELAKANG','29','Tulisan AWAS MUDAH TERBAKAR (stiker reflektif)','Tulisan Pada Bumper','NON MANDATORY','','',75),
('baru','B. SISI DEPAN & SISI BELAKANG','30','Stiker strip merah (trailer & rigid) pada badan tangki belakang (stiker reflektif)','Penanda Pembatas bagian Sisi Belakang','NON MANDATORY','','',76),
('baru','B. SISI DEPAN & SISI BELAKANG','30','Stiker strip merah (trailer & rigid) pada pelindung belakang (stiker reflektif)','Penanda Pembatas bagian Sisi Belakang','NON MANDATORY','','',77),
('baru','B. SISI DEPAN & SISI BELAKANG','30','Stiker strip merah-putih pada bumper belakang tangki (stiker reflektif)','Penanda Pembatas bagian Sisi Belakang','NON MANDATORY','','',78),
('baru','B. SISI DEPAN & SISI BELAKANG','31','Menggunakan tegangan 24 Volt','Lampu Bagian Depan','NON MANDATORY','','',79),
('baru','B. SISI DEPAN & SISI BELAKANG','31','Terdapat lampu kabut pada sisi kiri dan kanan bagian depan kendaraan','Lampu Bagian Depan','NON MANDATORY','','',80),
('baru','B. SISI DEPAN & SISI BELAKANG','31','Pada bawah setiap lampu tambahan dipasang stiker pendar bergaris diagonal merah putih','Lampu Bagian Depan','NON MANDATORY','','',81),
('baru','B. SISI DEPAN & SISI BELAKANG','31','Warna lampu rotator atap warna kuning','Lampu Bagian Depan','NON MANDATORY','','',82),
('baru','B. SISI DEPAN & SISI BELAKANG','32','Terdapat lampu belakang kendaraan, mundur','Lampu Bagian Belakang','NON MANDATORY','','',83),
('baru','B. SISI DEPAN & SISI BELAKANG','32','Pada bawah setiap lampu tambahan dipasang stiker pendar bergaris diagonal merah putih','Lampu Bagian Belakang','NON MANDATORY','','',84),
('baru','B. SISI DEPAN & SISI BELAKANG','32','Mundur - warna putih','Lampu Bagian Belakang','NON MANDATORY','','',85),
('baru','B. SISI DEPAN & SISI BELAKANG','32','Rem - warna merah','Lampu Bagian Belakang','NON MANDATORY','','',86),
('baru','B. SISI DEPAN & SISI BELAKANG','32','Belakang - warna merah','Lampu Bagian Belakang','NON MANDATORY','','',87),
('baru','B. SISI DEPAN & SISI BELAKANG','32','Lampu belakang dilindungi teralis dengan mur - baut dan dicat putih','Lampu Bagian Belakang','NON MANDATORY','','',88),
('baru','B. SISI DEPAN & SISI BELAKANG','33','Terdapat lampu belok','Lampu belok','NON MANDATORY','','',89),
('baru','B. SISI DEPAN & SISI BELAKANG','33','Pada bawah setiap lampu tambahan dipasang stiker pendar bergaris diagonal merah putih','Lampu belok','NON MANDATORY','','',90),
('baru','B. SISI DEPAN & SISI BELAKANG','33','Warna lampu belok orange','Lampu belok','NON MANDATORY','','',91),
('baru','B. SISI DEPAN & SISI BELAKANG','34','Buzzer (bunyi pergerakan mundur) berfungsi dengan baik','Perlengkapan listrik lain','NON MANDATORY','','',92),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','35','Tersedia 1 batang terminal grounding/bonding pada sisi penumpang diberi lambang grounding dengan cat warna hitam','Grounding/bonding tangki','NON MANDATORY','','',93),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','35','Tersedia roll kabel grounding/bonding 8 meter dengan clamp pada sisi penumpang','Grounding/bonding tangki','NON MANDATORY','','',94),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','35','Tersedia plat bonding pada coaming sisi penumpang','Grounding/bonding tangki','NON MANDATORY','','',95),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','35','Tersedia grounding strip dari chasis tangki ke jalan, dipastikan menyentuh tanah pada saat axle lift naik ataupun turun diberi tulisan GROUNDING dengan cat warna putih','Grounding/bonding tangki','NON MANDATORY','','',96),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','36','Tidak ada rumah selang/kurang','Rumah selang bagian Sisi Penumpang & Sisi Pengemudi','NON MANDATORY','','',97),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','36','2 rumah selang','Rumah selang bagian Sisi Penumpang & Sisi Pengemudi','NON MANDATORY','','',98),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','36','4 rumah selang','Rumah selang bagian Sisi Penumpang & Sisi Pengemudi','NON MANDATORY','','',99),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','36','Dapat menampung selang 4 inchi panjang 3 meter','Rumah selang bagian Sisi Penumpang & Sisi Pengemudi','NON MANDATORY','','',100),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','36','Dilengkapi pintu penutup belakang dan saluran air dengan valve pada ujung','Rumah selang bagian Sisi Penumpang & Sisi Pengemudi','NON MANDATORY','','',101),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','37','Rumah APAR ada 2, satu tiap sisi tangki, dipasang miring 45o','Rumah APAR bagian Sisi Penumpang & Sisi Pengemudi','NON MANDATORY','','',102),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','37','Tidak ada rumah APAR/kurang','Rumah APAR bagian Sisi Penumpang & Sisi Pengemudi','NON MANDATORY','','',103),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','37','Rumah APAR mudah terlihat dan mudah dijangkau','Rumah APAR bagian Sisi Penumpang & Sisi Pengemudi','NON MANDATORY','','',104),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','37','APAR mudah dikeluarkan dari rumah APAR (kurang dari 10 detik)','Rumah APAR bagian Sisi Penumpang & Sisi Pengemudi','NON MANDATORY','','',105),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','37','Komposisi APAR: 2 APAR 3 kg tipe CO2 pada kabin, 1 APAR 9 kg tipe DCP, dan 1 APAR 9 kg tipe foam dengan merek sesuai ABL Pertamina','Rumah APAR bagian Sisi Penumpang & Sisi Pengemudi','NON MANDATORY','','',106),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','38','Ada kotak peralatan lengkap dengan isinya sesuai yg dipersyaratkan','Kotak Penyimpanan Sisi Penumpang & Sisi Pengemudi','NON MANDATORY','','',107),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','38','Ada kotak spill kit lengkap dengan isinya sesuai yang dipersyaratkan (Sisi Pengemudi)','Kotak Penyimpanan Sisi Penumpang & Sisi Pengemudi','NON MANDATORY','','',108),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','38','Semua kotak penyimpanan tidak lebih menonjol dari sisi terluar tangki','Kotak Penyimpanan Sisi Penumpang & Sisi Pengemudi','NON MANDATORY','','',109),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','39','Tidak ada API adaptor / bottom loading valve pada tiap kompartemen/tidak standar','Bottom Loading di Sisi Penumpang','NON MANDATORY','','',110),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','39','API adaptor / bottom loading valve tiap kompartemen, standar API','Bottom Loading di Sisi Penumpang','NON MANDATORY','','',111),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','39','Dipasang pada Sisi Penumpang','Bottom Loading di Sisi Penumpang','NON MANDATORY','','',112),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','39','Ada Penutup API adaptor / bottom loading valve','Bottom Loading di Sisi Penumpang','NON MANDATORY','','',113),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','39','API adaptor / bottom loading valve dilengkapi palang kunci/bracket. Palang kunci efektif menahan tuas valve tidak terbuka, komponen bracket dilas titik untuk segel','Bottom Loading di Sisi Penumpang','NON MANDATORY','','',114),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','39','Mur dan baut API adaptor / bottom loading valve sudah dilas titik untuk segel','Bottom Loading di Sisi Penumpang','NON MANDATORY','','',115),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','39','Ada indikator jenis produk tipe rotator, min. 4 nama produk. Indikator produk memiliki pin untuk penyegelan','Bottom Loading di Sisi Penumpang','NON MANDATORY','','',116),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','39','Ada plat informasi nomor kompartemen pada masing-masing bottom loading valve','Bottom Loading di Sisi Penumpang','NON MANDATORY','','',117),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','39','Ada plat informasi kapasitas kompartemen pada masing-masing bottom loading valve','Bottom Loading di Sisi Penumpang','NON MANDATORY','','',118),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','39','Ada sight glass flange/cicin 40 mm','Bottom Loading di Sisi Penumpang','NON MANDATORY','','',119),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','39','Tidak ada sight glass flange','Bottom Loading di Sisi Penumpang','NON MANDATORY','','',120),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','39','Sight glass jelas','Bottom Loading di Sisi Penumpang','NON MANDATORY','','',121),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','39','Sight glass buram','Bottom Loading di Sisi Penumpang','NON MANDATORY','','',122),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','40','Hanya 1 soket sensor overfill 3J dengan tutup warna biru - optik','Fitting Lain','NON MANDATORY','','',123),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','40','Ada 1 Dump vent/coaming vent pada ujung sisi samping sebelah dalam coaming sisi-penumpang, dioperasikan secara interlock pneumatic.','Fitting Lain','NON MANDATORY','','',124),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','40','Ada 1 Vapour adapter 4, standar API, lengkap dengan penutup dan Interlock penumatic, pada paling kanan Valve bottom loader','Fitting Lain','NON MANDATORY','','',125),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','40','Ada e-Seal explosion proof (optional)','Fitting Lain','NON MANDATORY','','',126),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','40','Tidak ada e-Seal','Fitting Lain','NON MANDATORY','','',127),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','40','Tanpa printer','Fitting Lain','NON MANDATORY','','',128),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','40','Dengan printer explosion proof','Fitting Lain','NON MANDATORY','','',129),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','40','Dengan printer non explosion proof (kabin)','Fitting Lain','NON MANDATORY','','',130),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','41','Semua Bottom loading valve, vapour valve dan soket terlindung dalam panel','Panel Valve','NON MANDATORY','','',131),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','41','Panel valve dihubungkan dengan mekanisme Interlock','Panel Valve','NON MANDATORY','','',132),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','41','Panel valve tidak lebih menonjol dari dinding tangki','Panel Valve','NON MANDATORY','','',133),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','42','Tidak ada Interlock pneumatic','Interlock Pneumatic','NON MANDATORY','','',134),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','42','Ada Interlock pneumatic, diletakan pada kotak tersendiri/Panel Interlock','Interlock Pneumatic','NON MANDATORY','','',135),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','42','Interlock dilengkapi filter dan meteran penunjuk tekanan udara','Interlock Pneumatic','NON MANDATORY','','',136),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','42','Terdapat tombol master operasi interlock dan indikator','Interlock Pneumatic','NON MANDATORY','','',137),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','42','Terdapat tombol buka/tutup Internal valve tiap kompartemen dan indikator serta tombol diberi nomor yang bersesuaian','Interlock Pneumatic','NON MANDATORY','','',138),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','42','Terdapat indikator kondisi buka/tutup Vapour collection vent/air vent','Interlock Pneumatic','NON MANDATORY','','',139),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','42','Terdapat indikator kondisi buka/tutup Coaming vent/Dump vent','Interlock Pneumatic','NON MANDATORY','','',140),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','42','Panel Interlock terkoneksi dengan sistem pengereman dan kelistrikan mesin (starter) kecuali MT kap. 5 KL','Interlock Pneumatic','NON MANDATORY','','',141),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','42','Ada 3 emergency cut-off button, lengkap dengan label','Interlock Pneumatic','NON MANDATORY','','',142),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','42','Mekanisme urutan kerja Interlock pneumatic berfungsi benar','Interlock Pneumatic','NON MANDATORY','','',143),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','43','Tidak ada','Plakat Simbol Api, tanda bahaya / simbol B3 bagian Sisi Penumpang & Sisi Pengemudi','NON MANDATORY','','',144),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','43','1 di sisi penumpang','Plakat Simbol Api, tanda bahaya / simbol B3 bagian Sisi Penumpang & Sisi Pengemudi','NON MANDATORY','','',145),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','43','1 di sisi pengemudi','Plakat Simbol Api, tanda bahaya / simbol B3 bagian Sisi Penumpang & Sisi Pengemudi','NON MANDATORY','','',146),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','43','1 di sisi depan','Plakat Simbol Api, tanda bahaya / simbol B3 bagian Sisi Penumpang & Sisi Pengemudi','NON MANDATORY','','',147),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','43','1 di sisi belakang','Plakat Simbol Api, tanda bahaya / simbol B3 bagian Sisi Penumpang & Sisi Pengemudi','NON MANDATORY','','',148),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','44','Tidak ada','Plat Sablon Keur','NON MANDATORY','','',149),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','44','Ada pada Sisi Penumpang','Plat Sablon Keur','NON MANDATORY','','',150),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','45','Dipasang plat tera sesuai ketentuan pada tiap kompartemen','Plat Tera','NON MANDATORY','','',151),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','45','Plat tera dipasang dengan mur-baut dan disegel pada coaming Sisi Pengemudi bukan jalur vapour','Plat Tera','NON MANDATORY','','',152),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','46','Stiker blind spot (reflektif) dan emergency call proporsional sesuai standar','Tulisan Pada Tangki bagian Sisi Penumpang & Sisi Pengemudi','NON MANDATORY','','',153),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','46','Tulisan DILARANG MEROKOK proporsional dan sesuai warnanya (stiker reflektif)','Tulisan Pada Tangki bagian Sisi Penumpang & Sisi Pengemudi','NON MANDATORY','','',154),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','46','Tulisan www.pertamina.com proporsional dan sesuai warnanya (stiker reflektif)','Tulisan Pada Tangki bagian Sisi Penumpang & Sisi Pengemudi','NON MANDATORY','','',155),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','47','Stiker strip putih (trailer) / kuning (rigid) pada badan tangki (stiker reflektif)','Penanda Pembatas bagian Sisi Penumpang & Sisi Pengemudi','NON MANDATORY','','',156),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','47','Stiker strip putih (trailer) / kuning (rigid) pada rumah selang dan penutupnya (stiker reflektif)','Penanda Pembatas bagian Sisi Penumpang & Sisi Pengemudi','NON MANDATORY','','',157),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','48','Landing leg tipe manual 2-step dengan kunci pengaman tuas penurun','Landing Leg','NON MANDATORY','','',158),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','48','Ada stiker pengoperasian Landing leg','Landing Leg','NON MANDATORY','','',159),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','48','Ada garis batas minimal ketinggian mengangkat Landing leg saat tersambung','Landing Leg','NON MANDATORY','','',160),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','49','Ukuran velg sesuai dengan tipe dan ukuran ban yang dipakai','Velg/Wheel','NON MANDATORY','','',161),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','50','Ban Radial normal','Ban','NON MANDATORY','','',162),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','50','Ban Radial regroveable','Ban','NON MANDATORY','','',163),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','50','Ban Bias','Ban','NON MANDATORY','','',164),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','50','Ukuran minimal 11 (head truck/rigid)','Ban','NON MANDATORY','','',165),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','50','Ukuran minimal 11 (trailer)','Ban','NON MANDATORY','','',166),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','50','Jumlah play rating minimal 16-PR','Ban','NON MANDATORY','','',167),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','50','Jalan aspal mulus, menggunakan pola tipe rib','Ban','NON MANDATORY','','',168),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','50','Jalan tanah lunak, menggunakan pola telapak tipe lug','Ban','NON MANDATORY','','',169),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','50','Jalan berbatu, menggunakan pola telapak tipe lug - rib','Ban','NON MANDATORY','','',170),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','50','Jalan aspal, aspal tidak rata dan tanah menggunakan pola telapak lug - rib','Ban','NON MANDATORY','','',171),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','50','Segala medan menggunakan pola telapak tipe block','Ban','NON MANDATORY','','',172),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','50','Pada ban tampak keterangan dari pabrik','Ban','NON MANDATORY','','',173),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','50','pola telapak','Ban','NON MANDATORY','','',174),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','50','tipe','Ban','NON MANDATORY','','',175),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','50','ply-rating','Ban','NON MANDATORY','','',176),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','50','ukuran','Ban','NON MANDATORY','','',177),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','50','ketinggian','Ban','NON MANDATORY','','',178),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','50','tekanan angin sesuai','Ban','NON MANDATORY','','',179),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','50','Ban pada sumbu ganda (tri-axle) tidak saling bersentuhan dengan ban lain','Ban','NON MANDATORY','','',180),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','50','Semua pentil ban diberi penutup dari logam/plastik','Ban','NON MANDATORY','','',181),
('baru','C. SISI PENUMPANG & SISI PENGEMUDI','50','Tiap fender ban dipasang stiker atau pelat informasi mengenai tekanan angin ban','Ban','NON MANDATORY','','',182),
('baru','D. SISI BAWAH','51','Tidak ada Internal valve pada setiap dasar kompartemen/tidak standar','Internal Valve/Foot Valve','NON MANDATORY','','',183),
('baru','D. SISI BAWAH','51','Terdapat Internal valve pada setiap dasar kompartemen, standar API','Internal Valve/Foot Valve','NON MANDATORY','','',184),
('baru','D. SISI BAWAH','51','Baut Inter valve pada tangki dan pemipaan sudah dilas titik untuk segel','Internal Valve/Foot Valve','NON MANDATORY','','',185),
('baru','D. SISI BAWAH','51','Dioperasikan Pneumatic','Internal Valve/Foot Valve','NON MANDATORY','','',186),
('baru','D. SISI BAWAH','51','Dioperasikan Mekanik','Internal Valve/Foot Valve','NON MANDATORY','','',187),
('baru','D. SISI BAWAH','52','1 sumbu semi-trailer','Sumbu & Suspensi','NON MANDATORY','','',188),
('baru','D. SISI BAWAH','52','2 sumbu semi-trailer','Sumbu & Suspensi','NON MANDATORY','','',189),
('baru','D. SISI BAWAH','52','3 sumbu semi-trailer','Sumbu & Suspensi','NON MANDATORY','','',190),
('baru','D. SISI BAWAH','52','Sumbu 3 (belakang) bukan self-steering','Sumbu & Suspensi','NON MANDATORY','','',191),
('baru','D. SISI BAWAH','52','Sumbu 3 (belakang) dengan self-steering','Sumbu & Suspensi','NON MANDATORY','','',192),
('baru','D. SISI BAWAH','52','Tangki aluminium semi trailer harus menggunakan air suspension','Sumbu & Suspensi','NON MANDATORY','','',193),
('baru','D. SISI BAWAH','52','Tanpa axle lift','Sumbu & Suspensi','NON MANDATORY','','',194),
('baru','D. SISI BAWAH','52','Dengan axle lift pada sumbu ke','Sumbu & Suspensi','NON MANDATORY','','',195),
('baru','D. SISI BAWAH','52','Kendali axle lift otomatis','Sumbu & Suspensi','NON MANDATORY','','',196),
('baru','D. SISI BAWAH','52','Kendali axle lift manual, lengkap dengan label dan tutup pelindung','Sumbu & Suspensi','NON MANDATORY','','',197),
('baru','D. SISI BAWAH','53','Tanpa ABS/EBS','Rem Semi Trailer','NON MANDATORY','','',198),
('baru','D. SISI BAWAH','53','ABS (wajib untuk MT kap. 8 KL ke atas)','Rem Semi Trailer','NON MANDATORY','','',199),
('baru','D. SISI BAWAH','53','Rem tipe Disc','Rem Semi Trailer','NON MANDATORY','','',200),
('baru','D. SISI BAWAH','53','Rem tipe Drum','Rem Semi Trailer','NON MANDATORY','','',201),
('baru','D. SISI BAWAH','54','Rem operasi','Rem Headtruck','NON MANDATORY','','',202),
('baru','D. SISI BAWAH','54','Rem parkir','Rem Headtruck','NON MANDATORY','','',203),
('baru','D. SISI BAWAH','54','Rem tambahan','Rem Headtruck','NON MANDATORY','','',204),
('baru','D. SISI BAWAH','54','Full air system (wajib untuk MT kap. 8 KL ke atas)','Rem Headtruck','NON MANDATORY','','',205),
('baru','D. SISI BAWAH','54','Hydraulic','Rem Headtruck','NON MANDATORY','','',206),
('baru','D. SISI BAWAH','54','Terdapat buzzer peringatan atau indikator untuk tekanan udara rendah','Rem Headtruck','NON MANDATORY','','',207),
('baru','D. SISI BAWAH','54','Tanpa ABS/EBS','Rem Headtruck','NON MANDATORY','','',208),
('baru','D. SISI BAWAH','54','ABS (wajib untuk MT kap. 8 KL ke atas)','Rem Headtruck','NON MANDATORY','','',209),
('baru','D. SISI BAWAH','54','Jika ABS/EBS dipasang dibelakang kabin, dilengkapi pelindung/perisai panas','Rem Headtruck','NON MANDATORY','','',210),
('baru','D. SISI BAWAH','54','Rem tipe Disc','Rem Headtruck','NON MANDATORY','','',211),
('baru','D. SISI BAWAH','54','Rem tipe Drum','Rem Headtruck','NON MANDATORY','','',212),
('baru','E. SISI ATAS','55','Coaming tidak ada','Coaming','NON MANDATORY','','',213),
('baru','E. SISI ATAS','55','Coaming pendek','Coaming','NON MANDATORY','','',214),
('baru','E. SISI ATAS','55','Ada coaming tanpa sambungan (closed extrude atau juga bending)','Coaming','NON MANDATORY','','',215),
('baru','E. SISI ATAS','55','Coaming sisi-penumpang juga menjadi jalur vapour','Coaming','NON MANDATORY','','',216),
('baru','E. SISI ATAS','55','Tinggi coaming minimal 25 mm lebih tinggi dari fitting manhole tertinggi','Coaming','NON MANDATORY','','',217),
('baru','E. SISI ATAS','55','Ada stiker tulisan kapasitas nominal per kompartemen pada kedua sisi coaming','Coaming','NON MANDATORY','','',218),
('baru','E. SISI ATAS','55','Ada stiker tulisan kapasitas nominal tangki pada sisi tengah belakang coaming','Coaming','NON MANDATORY','','',219),
('baru','E. SISI ATAS','55','Ada stiker tulisan ketinggian tangki pada kedua sisi coaming','Coaming','NON MANDATORY','','',220),
('baru','E. SISI ATAS','56','Walkway licin/polos','Walkway','NON MANDATORY','','',221),
('baru','E. SISI ATAS','56','Walkway dilapisi kawat/plat bordes','Walkway','NON MANDATORY','','',222),
('baru','E. SISI ATAS','56','Walkway dilapisi bahan kasar/anti-slip','Walkway','NON MANDATORY','','',223),
('baru','E. SISI ATAS','56','Ada handrail','Walkway','NON MANDATORY','','',224),
('baru','E. SISI ATAS','56','Ada safety belt rail','Walkway','NON MANDATORY','','',225),
('baru','E. SISI ATAS','56','Tidak ada sama sekali','Walkway','NON MANDATORY','','',226),
('baru','E. SISI ATAS','56','Handrail Pneumatic','Walkway','NON MANDATORY','','',227),
('baru','E. SISI ATAS','56','Handrail Mekanik','Walkway','NON MANDATORY','','',228),
('baru','E. SISI ATAS','56','Saluran air tidak ada/terletak di depan','Walkway','NON MANDATORY','','',229),
('baru','E. SISI ATAS','56','Saluran air ada dibagian belakang kiri-kanan lengkap dengan saringan','Walkway','NON MANDATORY','','',230),
('baru','E. SISI ATAS','56','Ujung buangan saluran air tidak mengenai komponen/bagian kendaraan','Walkway','NON MANDATORY','','',231),
('baru','E. SISI ATAS','57','Tidak ada Manhole/tidak standar','Manhole','NON MANDATORY','','',232),
('baru','E. SISI ATAS','57','Manhole standar API tipe bolted','Manhole','NON MANDATORY','','',233),
('baru','E. SISI ATAS','57','Pressure & Vacuum vent berfungsi baik.','Manhole','NON MANDATORY','','',234),
('baru','E. SISI ATAS','57','Ada Vapor Collection Vent pneumatic.','Manhole','NON MANDATORY','','',235),
('baru','E. SISI ATAS','57','Vapour hose pada vent terpasang dengan clamp','Manhole','NON MANDATORY','','',236),
('baru','E. SISI ATAS','57','Ada Sensor Overfill tipe Optic','Manhole','NON MANDATORY','','',237),
('baru','E. SISI ATAS','57','Ada Dip Stick/Dip Gauge','Manhole','NON MANDATORY','','',238),
('baru','E. SISI ATAS','57','Penutup Dip stick/dip gauge kedap','Manhole','NON MANDATORY','','',239),
('baru','E. SISI ATAS','57','Bukaan tutup lubang manhole mengarah ke depan (kecuali manhole terakhir)','Manhole','NON MANDATORY','','',240),
('baru','E. SISI ATAS','57','Pemasangan engsel tutup manhole sudah dilas titik untuk segel','Manhole','NON MANDATORY','','',241),
('baru','E. SISI ATAS','57','Pemasangan manhole (bolt) sudah dilas titik untuk segel','Manhole','NON MANDATORY','','',242),
('baru','E. SISI ATAS','57','Jika manhole menggunakan leher tambahan, baut leher juga disegel','Manhole','NON MANDATORY','','',243),
('baru','E. SISI ATAS','57','Palang kunci efektif menahan tutup manhole dibuka','Manhole','NON MANDATORY','','',244),
('baru','E. SISI ATAS','58','Ada indeks tera dari logam berupa bidang/lidah','Indeks Tera','NON MANDATORY','','',245),
('baru','E. SISI ATAS','58','Indeks tera diletakan dibawah manhole, ditengah panjang kompartemen tidak lebih dari 50 mm dari tengah panjang kompartemen','Indeks Tera','NON MANDATORY','','',246),
('baru','E. SISI ATAS','58','Indeks tera terlihat jelas','Indeks Tera','NON MANDATORY','','',247),
('baru','E. SISI ATAS','58','Indeks tera dipasang kuat/tidak dapat berubah tanpa memutus segel','Indeks Tera','NON MANDATORY','','',248),
('baru','E. SISI ATAS','59','Dip stick/dip gauge ditera dalam skala milimeter (bukan interpolasi) 10 mm ke arah atas dan 250 mm ke arah bawah dari Volume nominal','Dip Stick/Dip Gauge','NON MANDATORY','','',249),
('baru','E. SISI ATAS','59','Sudah ditera : tgl/bln/thn / / 20','Dip Stick/Dip Gauge','NON MANDATORY','','',250),
('baru','E. SISI ATAS','59','Kondisi Dip stick baik, tidak bengkok dan tidak ada bekas las','Dip Stick/Dip Gauge','NON MANDATORY','','',251),
('baru','E. SISI ATAS','60','Merek / Type','GPS – Tracker (optional)','NON MANDATORY','','',252),
('baru','E. SISI ATAS','60','No. TID (Transponder Identity)','GPS – Tracker (optional)','NON MANDATORY','','',253),
('baru','E. SISI ATAS','60','No. SIM card GSM','GPS – Tracker (optional)','NON MANDATORY','','',254),
('baru','E. SISI ATAS','60','SIM Card GPS terpasang','GPS – Tracker (optional)','NON MANDATORY','','',255),
('baru','E. SISI ATAS','60','Perangkat terpasang di tempat yang mudah terlihat','GPS – Tracker (optional)','NON MANDATORY','','',256),
('baru','E. SISI ATAS','60','Lampu Indikator','GPS – Tracker (optional)','NON MANDATORY','','',257),
('baru','E. SISI ATAS','60','Panic Button','GPS – Tracker (optional)','NON MANDATORY','','',258),
('baru','E. SISI ATAS','60','Tidak','GPS – Tracker (optional)','NON MANDATORY','','',259),
('baru','E. SISI ATAS','60','Pada GPS terdapat fitur untuk mendeteksi overspeed','GPS – Tracker (optional)','NON MANDATORY','','',260),
('baru','E. SISI ATAS','60','Pada GPS terdapat fitur untuk mendeteksi harsh breaking','GPS – Tracker (optional)','NON MANDATORY','','',261),
('baru','E. SISI ATAS','60','Pada GPS terdapat fitur untuk mendeteksi harsh acceleration','GPS – Tracker (optional)','NON MANDATORY','','',262),
('baru','E. SISI ATAS','60','Pada GPS terdapat fitur untuk mendeteksi harsh cornering','GPS – Tracker (optional)','NON MANDATORY','','',263),
('baru','E. SISI ATAS','60','Pada GPS terdapat fitur untuk mendeteksi zona blackzone (geofence)','GPS – Tracker (optional)','NON MANDATORY','','',264),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','61','PTO penggerak shaft','PTO','NON MANDATORY','','',265),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','61','PTO penggerak hidrolik','PTO','NON MANDATORY','','',266),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','61','PTO penggerak lainnya','PTO','NON MANDATORY','','',267),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','61','PTO beroperasi mendekati kecepatan mesin diam (putaran mesin 600 rpm)','PTO','NON MANDATORY','','',268),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','61','Dipasang pelindung pada kopling dengan pompa dan/atau shaft','PTO','NON MANDATORY','','',269),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','61','Kabel listrik wajib *double* insulasi dan kabel negatif tidak boleh diikutkan ke chasis','PTO','MANDATORY','','HSSE',270),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','62','Ada pompa, sesuai dengan jenis BBM/BBK yang dipompakan','Pompa','NON MANDATORY','','',271),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','62','Tidak ada pompa','Pompa','NON MANDATORY','','',272),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','62','Dilengkapi pressure relief valve','Pompa','NON MANDATORY','','',273),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','62','Working pressure sesuai kapasitas pompa, maks. 500 kPa (72,5 PSI) setting disegel','Pompa','NON MANDATORY','','',274),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','62','Jalur outlet dipasang tapped soket dan plug 3/8 NPT untuk pressure gauge','Pompa','NON MANDATORY','','',275),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','62','Flowrate maksimum 50 liter per menit untuk pengisian langsung ke konsumen','Pompa','NON MANDATORY','','',276),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','62','Flowrate pompa maksimum 300 liter per menit untuk pengisian ke tangki pendam/PST','Pompa','NON MANDATORY','','',277),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','62','Kabel listrik wajib *double* insulasi dan kabel negatif tidak boleh diikutkan ke chasis','Pompa','MANDATORY','','HSSE',278),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','62','Peralatan listrik ex. proof dan kelas temperatur sesuai dengan jenis muatan yang diangkut','Pompa','NON MANDATORY','','',279),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','63','Ada Meter custody transfer jenis gravity (tanpa pompa)','Meter','NON MANDATORY','','',280),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','63','Tidak ada meter','Meter','NON MANDATORY','','',281),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','63','Ada Meter custody transfer jenis positive displacement (dengan pompa)','Meter','NON MANDATORY','','',282),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','63','Pembacaan meter harus dalam bentuk digital (5 digit di depan koma dan 1 digit di belakang koma), output berupa liter dan rupiah','Meter','NON MANDATORY','','',283),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','63','Sistem meter diberi kotak pelindung','Meter','NON MANDATORY','','',284),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','63','Dilengkapi strainer diletakan sebelum pompa dan di dalam meter. Ukuran maksimal 30 micron sebelum pompa dan maksimal 10 micron di dalam meter','Meter','NON MANDATORY','','',285),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','63','Dilengkapi air eliminator','Meter','NON MANDATORY','','',286),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','63','Dilengkapi low flow sensor','Meter','NON MANDATORY','','',287),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','63','Dilengkapi stabilisator flowrate yang dikontrol oleh PLC/Batch Controller','Meter','NON MANDATORY','','',288),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','63','Penambahan jalur bypass untuk pelaksanaan tera ulang','Meter','NON MANDATORY','','',289),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','63','Dilengkapi printer di Kabin yang memuat data pelanggan dan harga BBM/BBK yang terkoneksi dengan metering system','Meter','NON MANDATORY','','',290),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','63','Kabel listrik wajib *double* insulasi dan kabel negatif tidak boleh diikutkan ke chasis','Meter','MANDATORY','','HSSE',291),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','63','Peralatan listrik ex. proof dan kelas temperatur sesuai dengan jenis muatan yang diangkut','Meter','NON MANDATORY','','',292),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','64','Manifold setelah tangki dan harus dilengkapi dengan check valve / foot valve','Aspek *safety* tambahan','NON MANDATORY','','',293),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','64','Semua sambungan welded dan flanged','Aspek *safety* tambahan','NON MANDATORY','','',294),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','64','Dilengkapi safety system yang terintegrasi dengan interlock, termasuk terkoneksi dengan tempat nozzle, (logic : pompa hidup, semua ter-lock)','Aspek *safety* tambahan','NON MANDATORY','','',295),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','64','Dilengkapi engine cut off switch/emergency switch yang mematikan mesin dan seluruh dispensing system dalam keadaan darurat dan berada di dekat dispenser','Aspek *safety* tambahan','NON MANDATORY','','',296),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','64','Dilengkapi 1 set Spill kit, safety cone, safety line (barrier)','Aspek *safety* tambahan','NON MANDATORY','','',297),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','64','Dilengkapi dengan brake away coupling (pada pangkal selang nozzle yang tersambung dgn dispenser), usia maksimum 3 tahun','Aspek *safety* tambahan','NON MANDATORY','','',298),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','64','Posisi nozzle mengarah ke atas, dilengkapi vapour recovery, anti electric static, dan vapour guard (cup)','Aspek *safety* tambahan','NON MANDATORY','','',299),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','64','Hose & hose reel dilengkapi static wire dan berwarna merah','Aspek *safety* tambahan','NON MANDATORY','','',300),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','65','Dilengkapi penerangan di bagian atas (lampu sorot) dan di area dispenser yang ex. Proof dengan tingkat iluminasi minimal 1500 lux','Aspek operasi','NON MANDATORY','','',301),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','65','Dilengkapi lampu bongkar, LED (UL atau EN)','Aspek operasi','NON MANDATORY','','',302),
('baru','F. MOBIL TANGKI DENGAN DISPENSING SYSTEM (PTO)','65','Dilengkapi rambu keselamatan portable, minimal 2 (dua) buah','Aspek operasi','NON MANDATORY','','',303),
('6bulanan','A. Umum','1','STNK','','MANDATORY','','',1),
('6bulanan','A. Umum','','PAJAK','','MANDATORY','','',2),
('6bulanan','A. Umum','2','NAMA AMT','','MANDATORY','','',3),
('6bulanan','A. Umum','','UMUR AMT','TAHUN','MANDATORY','','',4),
('6bulanan','A. Umum','3','SIM B I / B II','','MANDATORY','','Distribusi',5),
('6bulanan','A. Umum','4','ID Card','','MANDATORY','','',6),
('6bulanan','A. Umum','5','Surat Tera Metrologi','Perubahan kewenangan, bukti yang disampaikan adalah Surat Pengurusan','MANDATORY','','',7),
('6bulanan','A. Umum','6','Surat Keur DLLAJR','Perpanjangan, disampaikan 2 bulan sebelum Batas Waktu Perpanjangan','MANDATORY','','Distribusi',8),
('6bulanan','A. Umum','7','Kartu Tanda Masuk TBBM','Untuk Mobil Tangki Baru, tidak diperlukan Kartu Tanda Masuk yang Lama','NON MANDATORY','','Distribusi',9),
('6bulanan','A. Umum','8','T1 T2 T3','','MANDATORY','','Distribusi',10),
('6bulanan','A. Umum','9','Keadaan Cat','Setelah 15 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','15 HK','Distribusi',11),
('6bulanan','A. Umum','10','Baut Tera Ruang Kosong','','MANDATORY','','Distribusi',12),
('6bulanan','A. Umum','11','Tulisan Nama dan Nomor Telepon Perusahaan serta Kapasitas Tanki','Setelah 2 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','2 HK','Distribusi',13),
('6bulanan','A. Umum','12','Umur Mobil Tanki (Prime mover)','Pastikan Lihat di STNK jangan lebih 10 Th | Kondisi Khusus bila ada Surat dari S&D Pusat/Region','MANDATORY','','HSSE',14),
('6bulanan','A. Umum','','Umur Kepala (prime mover)','Umur kepala (prime mover) 10 tahun | Kondisi Khusus bila ada Surat dari S&D Pusat/Region','MANDATORY','','HSSE',15),
('6bulanan','A. Umum','','Umur Tangki','Steel 10 thn, Alumunium Alloy 15 thn | Kondisi Khusus bila ada Surat dari S&D Pusat/Region','MANDATORY','','HSSE',16),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','1','Motor','','MANDATORY','','',17),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','a. Safety switch','Dipasang di dalam cabin, mudah dijangkau pengemudi','MANDATORY','','HSSE',18),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Arus listrik yang diputus, arus positif & Negatif menggunakan tipe dual pole untuk memutus arus positif dan negatif','','MANDATORY','','HSSE',19),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Arus yang diputus, arus langsung dari Accu.','','MANDATORY','','HSSE',20),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Harus diberi Label "Master Switch"','Setelah 2 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','2 HK','HSSE',21),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','b. Starter','Sambungan kabel dari knop starter sampai dinamo starter terpasang dengan baik (terisolasi, tidak bocor)','MANDATORY','','HSSE',22),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','2','Knalpot','Ditempatkan di depan, bengkok ke kanan tidak melebihi sisi samping kendaraan dan tidak bocor','MANDATORY','','HSSE',23),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Saringan/Flame Trap Standar menggunakan mess 40','','MANDATORY','','HSSE',24),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','3','Kabel listrik','Semua aliran listrik terisolasi (Seluruh kabel instalasi luar harus diberi konduit pelindung)','MANDATORY','','HSSE',25),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Konduit pelindung tidak ada yang rusak terpotong, pecah atau tertekuk/terjepit','','MANDATORY','','HSSE',26),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Setiap penyambungan kabel harus dilindungi menggunakan junction box (metode lain tidak boleh, kecuali dilindungi junction box seperti menggunakan isolation tape, skun, creamping dll)','','MANDATORY','','HSSE',27),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Junction box dibagian luar tidak boleh bocor/berlubang dan tahan cuaca IP 67, 68 (Bila Ada)','','MANDATORY','','HSSE',28),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','1. Alat listrik non explosion proof harus dipasang di kabin 2. Alat listrik yang perlu/harus dipasang di dalam kompartemen / pipa mobil tangki harus mempunyai sertifikat zona 0 3. alat listrik yang harus dipasang di badan tangki pada jarak 1 meter dari manhole atau BLA, atau Vapor adapter harus memiliki sertifikat minimal zona 1','','MANDATORY','','HSSE',29),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Klakson angin (telolet) tidak boleh dipasang/ tidak ada','Klakson wajib Standard','MANDATORY','','HSSE',30),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Nama Transportir/Kontraktor','PT. | Nomor Polisi','MANDATORY','','',31),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Pemeriksaan Terakhir Tanggal','Produk / Kapasitas | BBM/ KL','MANDATORY','','',32),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Pemeriksaan Tanggal','Pabrikan','MANDATORY','','',33),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Alat Listrik (contoh GPS, SDS, rotary lamp, lampu sein)','Alat GPS harus dipasang didalam kabin (bila ada) | Setelah 6 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','6 HK','HSSE',34),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Printer harus dipasang di dalam kabin (bila ada)','Setelah 6 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','6 HK','HSSE',35),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Kontroler atau alat listrik lainnya yang tidak mempuyai sertifikasi zona 1 harus dipasang didalam area kabin','','MANDATORY','','HSSE',36),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Semua Peralatan Listrik harus dapat diputus arusnya melalui master switch (Tidak boleh mengambil catu daya langsung ke accu)','','MANDATORY','','HSSE',37),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Tidak terdapat alat listrik tambahan','','MANDATORY','','HSSE',38),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Sekring harus asli (bukan kawat sambungan, kapasitas sesuai yang ditentukan)','','MANDATORY','','HSSE',39),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Pemantik api (untuk menyalakan rokok) harus dilepas','','MANDATORY','','HSSE',40),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','4','Baterai (Accu)','Accu tidak boleh di bawah tangki.','MANDATORY','','HSSE',41),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Posisi accu tidak boleh dekat dengan sumber tetesan/ sumber buangan uap BBM minimal 1 m','','MANDATORY','','HSSE',42),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Accu harus diberi penutup dari bahan isolator dan kondisi baik tidak pecah, tidak boleh menggunakan karet ban','','MANDATORY','','HSSE',43),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Bila penutup accu juga difungsikan sebagai walkway/dapat dipijak maka harus mampu menahan beban 120kg','','MANDATORY','','HSSE',44),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Bukan dari jenis logam dan tidak boleh di bawah/berdekatan dengan nozzle in/out','','MANDATORY','','HSSE',45),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Tidak bocor / pecah / retak','','MANDATORY','','HSSE',46),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Terminal accu bebas dari kotoran','','MANDATORY','','HSSE',47),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Kabel baterai terpasang dengan kuat (tidak goyang) dan skun dilengkapi dengan penutup isolator','','MANDATORY','','HSSE',48),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','5','Lampu-lampu dan Buzzer (jauh/dekat, righting, rem, mundur, rotary lamp, lampu kabut)','Semua lampu-lampu menyala','MANDATORY','','HSSE',49),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Kode warna lampu harus sesuai standard (lampu belok kuning, lampu mundur putih)','','MANDATORY','','HSSE',50),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Tidak boleh dilakukan penambahan lampu sendiri/ non pabrikan di area badan tangki / diluar ketentuan di Volume 1','','MANDATORY','','HSSE',51),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Cover lampu tidak boleh ada yang pecah','Bila kondisinya Retak/Buram NON MANDATORY = 5 Hari Kalender','MANDATORY','','HSSE',52),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Lampu rotary warna kuning (bukan lampu blitz) dipasang diatas kabin sisi tengah atau sisi sopir (check ketentuan) kondisi menyala','','MANDATORY','','HSSE',53),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Terdapat Buzzer mundur dan berfungsi baik','Setelah 30 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','30 HK','HSSE',54),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Shell/ dinding tangki Tidak bocor (atas : dengan cara disiram air bagian atas , samping & bawah dengan cara pengamatan visual saat pengisian BBM)','','MANDATORY','','HSSE',55),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Bagian dalam kompartemen tidak terdapat kotoran ataupun objek asing untuk mengurangi volume','','MANDATORY','','HSSE',56),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Badan tangki tidak ada yang penyok ke dalam lebih dari ….mm','','MANDATORY','','Distribusi',57),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Bulk head/ partisi kompartemen tidak bocor','','MANDATORY','','Distribusi',58),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Sealing ring/ celah antar kompartemen berfungsi baik/tidak bocor ke salah satu kompartemen dan dapat mengalir keluar ke lubang drain sisi bawah','','MANDATORY','','Distribusi',59),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Kabel Bonding di dalam masing -masing kompartemen tidak putus (kabel tidak boleh diganti dengan tipe rantai) - coating','','MANDATORY','','HSSE',60),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Coaming tidak boleh bocor/retak (tidak keluar vapor dari coaming saat pengisian)','','MANDATORY','','Distribusi',61),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Selisih ketinggian atas coaming ke semua instrument manhole cover minimal 25 mm','','MANDATORY','','HSSE',62),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Kondisi tangga','','MANDATORY','','HSSE',63),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','1. Tangga Akses naik dalam kondisi baik','','MANDATORY','','HSSE',64),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','2. Terdapat pintu akses pengaman tangga dan dapat dikunci dngan rapat (tidak goyang-goyang)','Setelah 30 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','30 HK','HSSE',65),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','3. Sensor break interlock pada pintu akses pengaman tangga dapat berfungsi (tidak di bypass)','Setelah 30 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','30 HK','HSSE',66),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','6','a. Tangki','4. Berfungsi baik, cara pengetesan dengan cara ketika pintu dibuka maka rem mobil akan aktif secara otomatis, ketika pintu ditutup rem mobil mati otomatis | Setelah 10 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','10 HK','HSSE',67),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Handrail : Handrail tidak ada yang patah dan dapat berfungsi naik turun otomatis','Setelah 30 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','30 HK','HSSE',68),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Walkway atas Tangki tidak licin','','MANDATORY','','HSSE',69),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Saluran pembuangan air tidak tersumbat dan tersedia saringan/filter','','MANDATORY','','HSSE',70),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Valve saluran buangan air tidak macet dan tidak rembes (normally open)','','MANDATORY','','HSSE',71),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Tutup manhole dilengkapi dengan packing, tutup manhole tidak bocor, seal karet kondisi baik, lubang tempel segel, posisi menghadap belakang.','','MANDATORY','','HSSE',72),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Untuk angkutan BBM kelas A dilengkapi pipa buang gas dan PV Valve','','MANDATORY','','HSSE',73),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Untuk angkutan BBM selain kelas A dilengkapi pipa buang gas dan Free Vent','','MANDATORY','','HSSE',74),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Kerangan keluar / Bottom Loading dan ball valve tidak bocor, pada ujungnya dilengkapi dengan tutup dan lubang untuk segel','','MANDATORY','','HSSE',75),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Kebersihan (bersih dari ceceran minyak)','','MANDATORY','','HSSE',76),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Cat dan Logo Pertamina','','MANDATORY','','HSSE',77),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Di lengkapi Safety Valve','','MANDATORY','','HSSE',78),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Bentuk Tangki Square Oval (kotak) dengan ruang kosong yang diijinkan 1,5 % s/d 3 % dari volume nominal.','','MANDATORY','','Distribusi',79),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Bentuk Tangki Oval (bulat) dengan ruang kosong yang diijinkan 0,75 % s/d 1,25 % dari volume nominal.','','MANDATORY','','Distribusi',80),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Saluran pembuangan bordes atas sempurna (memenuhi persyaratan).','','MANDATORY','','HSSE',81),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','b. Kelengkapan / Accesories Tangki','Manhole cover dan aksesoris manhole cover (overfill sensor, vapor vent) 1. dalam kondisi baik, tidak retak, bocor dan lengkap, 2. tidak bocor, terdapat seal karet dan dalam kondisi baik (tidak sobek, terpotong) 3. manhole dan aksesorisnya standar API 4. pemasangan manhole terdapat las titik pada mur baut flange atau mur baut klem | NGS + Volume 1','MANDATORY','','HSSE',82),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Untuk angkutan BBM kelas A masing-masing kompartemen 1. dilengkapi pipa buang gas dan PV Valve 2. standar API 3. dalam kondisi baik, tidak rusak (pada saat manhole ditutup saat pengisian tidak mengeluarkan suling) 4. vapor vent kedap (tidak bocor)','','MANDATORY','','HSSE',83),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Sensor Overfill : 1. sesuai standar API, terdapat pada setiap kompartemen; 2. ujung overfill sensor terpasang pada 1-2 cm di atas batas nominal pengisian (di atas batas eijkbout) 3. berfungsi baik (cara pengujian dengan merendam sensor di dalam air/minyak tanpa dilepas, cek apakah lampu indikator menyala saat sambung, mati saat dilepas, dan mati saat direndam air/minyak sebagai simulasi overfill)','NGS + Volume 1','MANDATORY','','HSSE',84),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Segel Electric (Bila Ada)','Bila sudah dipasang wajib diperiksa','MANDATORY','','HSSE',85),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Seal Delivery System (SDS)','NGS + Volume 1','MANDATORY','','HSSE',86),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','c. Kabin dan Tanki','Jarak +30 sampai dengan 50 cm','MANDATORY','','HSSE',87),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Harus dapat dibuka/ditunggingkan','','MANDATORY','','HSSE',88),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','d. Tanki dan Bemper belakang','Jarak + sampai dengan 30 cm','MANDATORY','','HSSE',89),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','e. Mesin','Harus pakai screen (tertutup)','MANDATORY','','HSSE',90),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Manifold dengan fuel filter harus diberi sekat.','','MANDATORY','','HSSE',91),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Kebersihan','Setelah 1 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','1 HK','HSSE',92),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Oli Mesin tidak bocor','','MANDATORY','','HSSE',93),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','f. Bantalan tanki','Menggunakan kayu/karet.','MANDATORY','','HSSE',94),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','7','Hasil uji emisi (uji asap)','Tidak melebihi baku mutu | Setelah 15 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','15 HK','HSSE',95),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','8','Alat Pemadam Kebakaran','Merk Apar sesuai ABL (Ansul,Angus,Bavaria,Syscofire dan Alpindo) | APAR wajib sesuai dengan vendor list Pertamina','MANDATORY','','HSSE',96),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','a. DCP 20 lbs sebanyak jml mengacu pada Volume 1','Nozzle','MANDATORY','','HSSE',97),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Selang','','MANDATORY','','HSSE',98),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Cat','','MANDATORY','','HSSE',99),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Powder','','MANDATORY','','HSSE',100),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Cartridge (Bila menggunakan APAR type Catridge Pressure)','','MANDATORY','','HSSE',101),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Tanggal Pemeriksaan terakhir','','MANDATORY','','HSSE',102),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','b. CO2 atau 3 lbs di Kabin','Nozzle','MANDATORY','','HSSE',103),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Selang','','MANDATORY','','HSSE',104),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Cat','','MANDATORY','','HSSE',105),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Berat 5 kg','','MANDATORY','','HSSE',106),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Tanggal Pemeriksaan terakhir','','MANDATORY','','HSSE',107),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','c. Apar Foam 20 lbs sebanyak jml mengacu pada Volume 1','Nozzle','MANDATORY','','HSSE',108),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Selang','','MANDATORY','','HSSE',109),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Cat','','MANDATORY','','HSSE',110),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Foam','','MANDATORY','','HSSE',111),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Cartridge (Bila menggunakan APAR type Catridge Pressure)','','MANDATORY','','HSSE',112),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Tanggal Pemeriksaan terakhir','','MANDATORY','','HSSE',113),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','9','Rem kaki dan tangan','1. Data pengujian dan penggantian kampas rem tersedia 2. Power Supply dari sistem ABS seharusnya diambil dari jumper lampu rem --> menimbulkan fenomena dari power yang stand by (accu) bukan 3. Rem berfungsi dengan baik, tidak ada kebocoran angin','MANDATORY','','HSSE',114),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','10','Roda/ban termasuk Ban Serep','Tidak licin/gundul/pecah-pecah (kembangan ban tersisa 2 mm minimal)','MANDATORY','','HSSE',115),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Semua ban sumbu kemudi (umumnya depan) tidak boleh vulkanisir','','MANDATORY','','HSSE',116),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Tinggi seluruh ban dalam satu sumbu harus sama rata','','MANDATORY','','HSSE',117),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Tipe telapak ban (peruntukan ban jalan aspal, jalan tanah, jalan berbatu, segala medan dst) harus sama (boleh beda merk tapi harus sama tipenya)','','MANDATORY','','HSSE',118),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Setiap ban harus diberi pentil penutup dari ban','','MANDATORY','','HSSE',119),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Tekanan setiap ban harus sesuai dengan peruntukan','','MANDATORY','','HSSE',120),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Rating beban ban harus sesuai dengan kelas jalan ban / kapasitas tanki','','MANDATORY','','HSSE',121),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Semua mur baut ban lengkap dan terpasang penuh dengan benar (tinggi baut harus lebih dari mur, mur tidak menggantung karena baut terlalu panjang atau tebal)','','MANDATORY','','HSSE',122),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Pada sumbu yang dobel excel (excel ganda), atau three excel ban antara excel tidak saling bersentuhan (akibat ukuran ban terlalu besar)','','MANDATORY','','HSSE',123),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Sumbu selain sumbu kemudi boleh dengan vulkanisir dengan syarat: 1. Maksimal 2 x vulkanisir dengan menunjukkan catatan 2. Tipe vulkanisir yang diijinkan adalah vulkanisir dingin tidak boleh vulkanisir panas 3. Seluruh ban, kondisi dinding ban dalam kondisi baik, tidak boleh rusak/pecah/sobek','','MANDATORY','','HSSE',124),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Kondisi setiap velg ban baik dan tidak boleh retak','','MANDATORY','','HSSE',125),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','11','Alat kemudi','Olah gerak maksimum 60o','MANDATORY','','HSSE',126),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Dapat digerakkan dengan tenaga yang wajar','','MANDATORY','','HSSE',127),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','12','Selang Bongkar','Selang karet oil resistance, ukuran 4", 2 length per 3 meter','MANDATORY','','Distribusi',128),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Tidak bocor','','MANDATORY','','Distribusi',129),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Dilengkapi Quick Coupling kuningan lengkap dengan rubber Seal','','MANDATORY','','Distribusi',130),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Rumah selang tidak bocor, penempatan selang harus di rumah selang','Setelah 6 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','6 HK','Distribusi',131),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Dilarang Merokok samping kiri dan kanan','Masukan ketentuan dalam panduan','MANDATORY','','HSSE',132),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Dilarang Menumpang (kabin)','','MANDATORY','','HSSE',133),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','13','Tanda Peringatan ukuran sesuai Panduan Volume 1','Rambu Bahan Bakar Cair Mudah Terbakar + Lingkungan (future) kiri belakang, kanan','MANDATORY','','HSSE',134),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Tulisan awas mudah terbakar (bumper belakang)','','MANDATORY','','HSSE',135),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Tulisan Kecepatan Max 60 Km/Jam (belakang)','','MANDATORY','','HSSE',136),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Tulisan lebar dan panjang kendaraan di belakang','','MANDATORY','','HSSE',137),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Rambu rambu keselamatan di dalam kabin (stiker)','Jenis akan disebutkan','MANDATORY','','HSSE',138),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','14','Bendera merah','Sesuai ketentuan Pertamina | Setelah 1 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','1 HK','HSSE',139),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','15','Stiker reflektif merah putih','1. terpasang di bumper samping dan bumper belakang | Setelah 3 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','3 HK','Distribusi',140),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','2. tidak lepas, masih utuh, tidak mengelupas','Setelah 3 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','3 HK','Distribusi',141),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','3. reflektif berfungsi / tidak buram','Setelah 3 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','3 HK','Distribusi',142),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Lain – lain','Grounding cable dan crocodile clamp','MANDATORY','','HSSE',143),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Kotak obat P3K berisi lengkap','Sesuai volume 1','MANDATORY','','HSSE',144),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Kipas kaca','','MANDATORY','','HSSE',145),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Segi tiga pengaman','','MANDATORY','','HSSE',146),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Dongkrak','Sesuai dengan kapasitas isi MT','MANDATORY','','HSSE',147),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Pintu bisa dibuka dengan mudah','','MANDATORY','','HSSE',148),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Body / kabin kendaraan tidak keropos','Setelah 7 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','7 HK','HSSE',149),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Kaca lengkap tidak ada yang pecah','','MANDATORY','','HSSE',150),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Spak bord lengkap','Setelah 7 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','7 HK','HSSE',151),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Spidometer berfungsi','','MANDATORY','','HSSE',152),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Kaca spion lengkap kanan kiri','','MANDATORY','','HSSE',153),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Safety Belt','','MANDATORY','','HSSE',154),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Ganjal Ban (Karet)','Setelah 3 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','3 HK','HSSE',155),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Oil Spill Kits','Setelah 3 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','3 HK','HSSE',156),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Emergency Kits','Setelah 3 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','3 HK','HSSE',157),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Tulisan "Bonding Strip" untuk tempat bonding cable','Setelah 3 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','2 HK','HSSE',158),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Radio tape harus dicabut','','MANDATORY','','HSSE',159),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Tombol emergency cut off (Untuk MT Volume 1)','1. Tersedia 3 pcs di sisi kiri, kanan, dan belakang yang mudah diakses','MANDATORY','','HSSE',160),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','2. terdapat informasi (label) yang mudah dilihat dan mudah terbaca','','MANDATORY','','HSSE',161),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','3. berfungsi dengan baik, pengetesan masing-masing cut off, ketika ditekan semua bottom loading adapter dan vapor vent akan menutup (jika tidak ada indikator akan terdengar suara sebagai tanda penutupan) atau dites ketika pengisian','','MANDATORY','','HSSE',162),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Panel Valve atau Panel Pelindung Bottom Loading Adapter (BLA)','1. tidak menonjol dari badan tanki','MANDATORY','','HSSE',163),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','2. konstruksi panel pelindung dalam keadaan baik, tidak rusak, retak atau pecah','','MANDATORY','','HSSE',164),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','3. pintu panel valve dapat dibuka dan ditutup dengan baik (engsel tidak rusak dll)','','MANDATORY','','HSSE',165),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','4. penahan pintu saat dibuka berfungsi baik (tidak kendor)','','MANDATORY','','HSSE',166),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','5. saat pintu ditutup, pintu tertutup dengan sempurna / tidak mudah goyang (sehingga tidak memicu sensor berulangkali)','','MANDATORY','','HSSE',167),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','6. Bracket Bottom Loader sudah sesua dengan standar bracket API 2020','','MANDATORY','','HSSE',168),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','16','Bottom Loading Adapter','1. ada di tiap kompartemen, standar API | Setelah 6 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','6 HK','Distribusi',169),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','2. pemasangan dengan las titik','Setelah 6 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','6 HK','Distribusi',170),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','3. tidak bocor saat pengisian','Setelah 6 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','6 HK','Distribusi',171),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','4. kedap (saat ada minyak di atas tidak ada rembesan) -> cara pengujian sama dengan foot valve','Setelah 6 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','6 HK','Distribusi',172),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','5. terdapat penutup bottom loader adapter','Setelah 6 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','6 HK','Distribusi',173),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','6. seal karet penutup dalam kondisi baik, tidak bocor','Setelah 6 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','6 HK','Distribusi',174),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','7. tidak rusak, tidak pecah, tidak bocor','Setelah 6 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','6 HK','Distribusi',175),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','8. tersedia bracket untuk mengunci bottom loader adaptor dan menahan tuas operasi bottom loader adaptor (bila bracket dipasang tuas operasi tidak dapat dipakai)','Setelah 6 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','6 HK','Distribusi',176),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','9. Sight glass pada bottom loader adaptor tidak rusak atau pecah','Setelah 6 Hari Kalender belum diperbaiki, maka MT OFF','NON MANDATORY','6 HK','Distribusi',177),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Nama Transportir/Kontraktor','PT. | Nomor Polisi','MANDATORY','','',178),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Pemeriksaan Terakhir Tanggal','Produk / Kapasitas | BBM/ KL','MANDATORY','','',179),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Pemeriksaan Tanggal','Pabrikan','MANDATORY','','',180),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Internal valve/foot valve','Posisi di bawah titik terendah tiap kompartemen 1. dalam kondisi baik, tidak retak, bocor dan lengkap 2. tidak bocor dari sambungan antara flange foot valve dengan badan tangki 3. standar API 4. pengujian kedap (dalam kondisi tertutup tidak ada cairan dari kompartemen yang keluar) 5. terdapat tubing pneumatic (cara pengujian tidak ada pressure turun saat pengisian, sebeum pengisian agar dilakukan pengukuran tekanan)','MANDATORY','','Distribusi',181),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Untuk semi trailer','1. Landing lag baik, tidak retak atau rusak 2. dapar dioperasikan dengan baik naik turunnya 3. tersedia sitker informasi dan batas operasi landing lag','MANDATORY','','HSSE',182),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','king pin dan fifthwheel 1. kondisi baik, tidak retak, rusak 2. kondisi base plate dan kingpin baik tidak rusak 3. pada base plate cukup diberi grease dan tidak boleh goyang / saat semi trailer terpasang fifth wheel dapat mengunci dengan kuat','','MANDATORY','','HSSE',183),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Tangki own use','Tidak boleh bocor','MANDATORY','','HSSE',184),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Tangki own use','Tidak ada modifikasi','MANDATORY','','HSSE',185),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Tangki own use','Terdapat penutup nozlle own use','MANDATORY','','HSSE',186),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Nota Temuan Hasil Pemeriksaan MT','Note','MANDATORY','','',187),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','Checker','Aprroved By | Status','MANDATORY','','',188),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','HSSE Support/HSSE /Distribusi Sr Spv I QQ/QQ','[ ] OK','MANDATORY','','',189),
('6bulanan','B. Keselamatan Kesehatan Kerja dan Lindungan Lingkungan','','[ ] Not OK','','MANDATORY','','',190);

-- =====================================================================
-- DATA CONTOH: 1 checklist MT BARU + 1 checklist INSPEKSI 6 BULANAN
-- yang sudah lengkap terisi dan sudah selesai di-approve.
-- Import SETELAH schema.sql + seed_items.sql (atau sudah termasuk di full_import.sql)
-- =====================================================================

-- ---------- 1. CHECKLIST MT BARU (vehicle BG 8004 XU) ----------
INSERT INTO inspections
  (no_pemeriksaan, schedule_id, vehicle_id, form_type, tgl_pemeriksaan, tgl_terakhir,
   inspector_id, nama_amt, umur_amt, sim_amt, nota_temuan, hasil_akhir, status, submitted_at, finalized_at)
SELECT 'MTB/001/HSSE/PND546000/2026', NULL, v.id, 'baru', '2026-08-20', NULL,
       (SELECT id FROM users WHERE username='inspector'),
       'Ahmad Fauzi', 34, 'SIM B2 Umum — 1671xxxx',
       'Seluruh item mandatory terpenuhi. Stiker identitas perlu penyegaran (non mandatory, batas 6 HK).',
       'OK', 'disetujui', '2026-08-20 15:10:00', '2026-08-22 10:05:00'
FROM vehicles v WHERE v.no_polisi = 'BG 8004 XU';
SET @insp_baru = LAST_INSERT_ID();

INSERT INTO inspection_results (inspection_id, item_id, hasil, keterangan)
SELECT @insp_baru, ci.id,
       CASE WHEN ci.prioritas = 'MANDATORY' THEN 'baik' ELSE 'baik' END,
       CASE WHEN ci.sort_order = 5 THEN 'Stiker identitas dicat ulang' ELSE NULL END
FROM checklist_items ci WHERE ci.form_type = 'baru' AND ci.aktif = 1;

INSERT INTO inspection_approvals (inspection_id, role, level, status, user_id, catatan, acted_at) VALUES
(@insp_baru, 'hsse',       1, 'disetujui', (SELECT id FROM users WHERE username='hsse'),       'Aspek HSSE terpenuhi.',        '2026-08-21 09:00:00'),
(@insp_baru, 'distribusi', 1, 'disetujui', (SELECT id FROM users WHERE username='distribusi'), 'Kelengkapan distribusi OK.',   '2026-08-21 10:30:00'),
(@insp_baru, 'qq',         1, 'disetujui', (SELECT id FROM users WHERE username='qq'),         'Tera & segel sesuai.',         '2026-08-21 13:15:00'),
(@insp_baru, 'itm',        2, 'disetujui', (SELECT id FROM users WHERE username='itm'),        'Disetujui, MT layak operasi.', '2026-08-22 10:05:00');

UPDATE vehicles SET last_inspection = '2026-08-20', next_inspection = '2027-02-20'
WHERE no_polisi = 'BG 8004 XU';

-- ---------- 2. CHECKLIST INSPEKSI 6 BULANAN (vehicle BG 8003 XU) ----------
INSERT INTO inspections
  (no_pemeriksaan, schedule_id, vehicle_id, form_type, tgl_pemeriksaan, tgl_terakhir,
   inspector_id, nama_amt, umur_amt, sim_amt, nota_temuan, hasil_akhir, status, submitted_at, finalized_at)
SELECT 'MT6/001/HSSE/PND546000/2026', NULL, v.id, '6bulanan', '2026-08-25', '2026-03-16',
       (SELECT id FROM users WHERE username='inspector'),
       'Rizky Saputra', 29, 'SIM B2 Umum — 1671yyyy',
       'Ditemukan kebocoran kecil pada seal bottom valve, sudah diperbaiki saat pemeriksaan. Foto temuan terlampir.',
       'OK', 'disetujui', '2026-08-25 14:40:00', '2026-08-26 11:20:00'
FROM vehicles v WHERE v.no_polisi = 'BG 8003 XU';
SET @insp_6b = LAST_INSERT_ID();

INSERT INTO inspection_results (inspection_id, item_id, hasil, keterangan, batas_perbaikan)
SELECT @insp_6b, ci.id,
       CASE WHEN ci.sort_order = 12 THEN 'tidak' ELSE 'baik' END,
       CASE WHEN ci.sort_order = 12 THEN 'Seal bottom valve diganti pada saat pemeriksaan' ELSE NULL END,
       CASE WHEN ci.sort_order = 12 THEN '2026-09-02' ELSE NULL END
FROM checklist_items ci WHERE ci.form_type = '6bulanan' AND ci.aktif = 1;

-- Inspeksi 6 bulanan TIDAK memerlukan approval ITM (cukup HSSE, Distribusi, QQ)
INSERT INTO inspection_approvals (inspection_id, role, level, status, user_id, catatan, acted_at) VALUES
(@insp_6b, 'hsse',       1, 'disetujui', (SELECT id FROM users WHERE username='hsse'),       'Temuan sudah ditindaklanjuti.', '2026-08-26 08:45:00'),
(@insp_6b, 'distribusi', 1, 'disetujui', (SELECT id FROM users WHERE username='distribusi'), 'Siap operasi.',                 '2026-08-26 09:50:00'),
(@insp_6b, 'qq',         1, 'disetujui', (SELECT id FROM users WHERE username='qq'),         'Kalibrasi & segel sesuai.',     '2026-08-26 11:20:00');

UPDATE vehicles SET last_inspection = '2026-08-25', next_inspection = '2027-02-25'
WHERE no_polisi = 'BG 8003 XU';

-- Dokumentasi foto mobil tangki (khusus checklist MT Baru)
INSERT INTO checklist_items (form_type, section, item_no, item_text, penjelasan, prioritas, batas_non_mandatory, pelaksana, sort_order) VALUES
('baru','G. DOKUMENTASI FOTO MOBIL TANGKI','66','Foto tampak depan mobil tangki','Unggah foto tampak depan MT pada kolom Foto','MANDATORY','','HSSE',304),
('baru','G. DOKUMENTASI FOTO MOBIL TANGKI','67','Foto tampak belakang mobil tangki','Unggah foto tampak belakang MT pada kolom Foto','MANDATORY','','HSSE',305),
('baru','G. DOKUMENTASI FOTO MOBIL TANGKI','68','Foto tampak samping kanan mobil tangki','Unggah foto sisi kanan MT pada kolom Foto','MANDATORY','','HSSE',306),
('baru','G. DOKUMENTASI FOTO MOBIL TANGKI','69','Foto tampak samping kiri mobil tangki','Unggah foto sisi kiri MT pada kolom Foto','MANDATORY','','HSSE',307);

-- Lengkapi hasil untuk item dokumentasi foto MT (checklist MT Baru yang sudah ada)
INSERT INTO inspection_results (inspection_id, item_id, hasil, keterangan)
SELECT i.id, ci.id, 'baik', 'Foto terlampir'
FROM inspections i
JOIN checklist_items ci ON ci.form_type = i.form_type AND ci.section = 'G. DOKUMENTASI FOTO MOBIL TANGKI'
WHERE i.form_type = 'baru'
  AND NOT EXISTS (SELECT 1 FROM inspection_results r WHERE r.inspection_id = i.id AND r.item_id = ci.id);

-- =====================================================================
-- DATA CONTOH LENGKAP: FOTO 4 SISI MT, SCAN STNK/KEUR/TERA, FOTO TEMUAN
-- File foto contoh tersedia di folder uploads/mt/ dan uploads/temuan/
-- =====================================================================
UPDATE vehicles SET
  foto_depan    = 'uploads/mt/demo_depan.jpg',
  foto_belakang = 'uploads/mt/demo_belakang.jpg',
  foto_kanan    = 'uploads/mt/demo_kanan.jpg',
  foto_kiri     = 'uploads/mt/demo_kiri.jpg',
  doc_stnk      = 'uploads/mt/demo_stnk.jpg',
  doc_keur      = 'uploads/mt/demo_keur.jpg',
  doc_tera      = 'uploads/mt/demo_tera.jpg',
  tera_berlaku  = COALESCE(tera_berlaku, '2027-05-19');

-- Foto dokumentasi 4 sisi MT pada checklist MT Baru (section G)
INSERT INTO inspection_photos (inspection_id, item_id, file_path, uploaded_by)
SELECT i.id, ci.id,
       CASE
         WHEN ci.item_text LIKE '%depan%'    THEN 'uploads/mt/demo_depan.jpg'
         WHEN ci.item_text LIKE '%belakang%' THEN 'uploads/mt/demo_belakang.jpg'
         WHEN ci.item_text LIKE '%kanan%'    THEN 'uploads/mt/demo_kanan.jpg'
         ELSE 'uploads/mt/demo_kiri.jpg'
       END,
       i.inspector_id
FROM inspections i
JOIN checklist_items ci
  ON ci.form_type = i.form_type
 AND ci.section = 'G. DOKUMENTASI FOTO MOBIL TANGKI'
WHERE i.form_type = 'baru'
  AND NOT EXISTS (
    SELECT 1 FROM inspection_photos p
    WHERE p.inspection_id = i.id AND p.item_id = ci.id);

-- Foto temuan pada checklist inspeksi 6 bulanan (item bermasalah)
INSERT INTO inspection_photos (inspection_id, item_id, file_path, uploaded_by)
SELECT r.inspection_id, r.item_id, 'uploads/temuan/demo_temuan_seal.jpg', i.inspector_id
FROM inspection_results r
JOIN inspections i ON i.id = r.inspection_id
WHERE i.form_type = '6bulanan' AND r.hasil = 'tidak'
  AND NOT EXISTS (
    SELECT 1 FROM inspection_photos p
    WHERE p.inspection_id = r.inspection_id AND p.item_id = r.item_id);

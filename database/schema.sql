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

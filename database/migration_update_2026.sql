-- ---------------------------------------------------------------------
-- MIGRASI: (1) foto temuan multi-file per item, (2) approval ITM hanya MT Baru
-- Jalankan pada database SIMT yang sudah ada (import via phpMyAdmin).
-- ---------------------------------------------------------------------

-- 1. Tabel foto temuan (bisa lebih dari 1 foto per item)
CREATE TABLE IF NOT EXISTS inspection_photos (
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

-- 2. Pindahkan data foto lama (kolom tunggal) bila kolom tersebut ada.
--    Jalankan blok berikut HANYA jika tabel inspection_results masih punya kolom `foto`:
-- INSERT INTO inspection_photos (inspection_id, item_id, file_path)
--   SELECT inspection_id, item_id, foto FROM inspection_results WHERE foto IS NOT NULL AND foto <> '';
-- ALTER TABLE inspection_results DROP COLUMN foto;

-- 3. Hapus baris approval ITM untuk checklist Inspeksi 6 Bulanan yang belum diputuskan
DELETE a FROM inspection_approvals a
JOIN inspections i ON i.id = a.inspection_id
WHERE a.role = 'itm' AND i.form_type = '6bulanan' AND a.status = 'menunggu';

-- ---------------------------------------------------------------------
-- MIGRASI SALTY 2026-09: verifikasi 2 langkah + nama Distribusi
-- ---------------------------------------------------------------------
ALTER TABLE users
  ADD COLUMN totp_secret    VARCHAR(64)  DEFAULT NULL,
  ADD COLUMN totp_enabled   TINYINT(1)   NOT NULL DEFAULT 0,
  ADD COLUMN recovery_codes VARCHAR(255) DEFAULT NULL;

UPDATE users
   SET nama    = 'Spv I Fuel Distribusi Kertapati Baru',
       jabatan = 'Approval Distribusi'
 WHERE username = 'distribusi';

-- 7. Perbarui nama & jabatan pemeriksa HSSE
UPDATE users SET nama='Sr Spv II HSSE', jabatan='Approval HSSE' WHERE username='hsse';
UPDATE users SET jabatan='Approval QQ' WHERE username='qq';

-- ---------------------------------------------------------------------
-- MIGRASI LANJUTAN 2026-09b: dokumen & foto master mobil tangki
-- ---------------------------------------------------------------------

-- 8. Kolom foto tampak MT + dokumen (STNK, Keur, Tera)
ALTER TABLE vehicles
  ADD COLUMN foto_depan    VARCHAR(255) DEFAULT NULL,
  ADD COLUMN foto_belakang VARCHAR(255) DEFAULT NULL,
  ADD COLUMN foto_kanan    VARCHAR(255) DEFAULT NULL,
  ADD COLUMN foto_kiri     VARCHAR(255) DEFAULT NULL,
  ADD COLUMN doc_stnk      VARCHAR(255) DEFAULT NULL,
  ADD COLUMN doc_keur      VARCHAR(255) DEFAULT NULL,
  ADD COLUMN doc_tera      VARCHAR(255) DEFAULT NULL;

-- 9. Item dokumentasi foto MT pada master checklist MT Baru
DELETE FROM checklist_items WHERE form_type='baru' AND section='G. DOKUMENTASI FOTO MOBIL TANGKI';

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


-- =====================================================================
-- UPDATE: jatuh tempo memperhitungkan masa berlaku STNK, KEUR, dan Tera
-- =====================================================================
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

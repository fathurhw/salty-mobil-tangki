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

-- Lengkapi hasil untuk item dokumentasi foto MT (checklist MT Baru yang sudah ada)
INSERT INTO inspection_results (inspection_id, item_id, hasil, keterangan)
SELECT i.id, ci.id, 'baik', 'Foto terlampir'
FROM inspections i
JOIN checklist_items ci ON ci.form_type = i.form_type AND ci.section = 'G. DOKUMENTASI FOTO MOBIL TANGKI'
WHERE i.form_type = 'baru'
  AND NOT EXISTS (SELECT 1 FROM inspection_results r WHERE r.inspection_id = i.id AND r.item_id = ci.id);

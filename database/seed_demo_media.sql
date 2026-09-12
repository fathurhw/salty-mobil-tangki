
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

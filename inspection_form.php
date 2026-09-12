<?php
/**
 * Pengisian checklist oleh Inspector HSSE.
 * - Tahap 1: pilih jadwal / MT + jenis form  -> membuat header inspeksi (draft)
 * - Tahap 2: isi seluruh item checklist, simpan draft atau ajukan approval
 */
require_once __DIR__ . '/includes/layout.php';
require_role(['inspector_hsse']);
csrf_check();

$uid = (int)user()['id'];

/* ---------------- Aksi POST ---------------- */
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $act = $_POST['act'] ?? '';

    if ($act === 'create') {
        $vehicleId  = (int)$_POST['vehicle_id'];
        $formType   = $_POST['form_type'] === 'baru' ? 'baru' : '6bulanan';
        $scheduleId = ((int)($_POST['schedule_id'] ?? 0)) ?: null;
        $tgl        = $_POST['tgl_pemeriksaan'] ?: date('Y-m-d');
        $veh        = q1('SELECT * FROM vehicles WHERE id=?', [$vehicleId]);

        $id = ex('INSERT INTO inspections (no_pemeriksaan, schedule_id, vehicle_id, form_type,
                  tgl_pemeriksaan, tgl_terakhir, inspector_id, status)
                  VALUES (?,?,?,?,?,?,?,"draft")',
            [generate_no($formType), $scheduleId, $vehicleId, $formType, $tgl,
             $veh['last_inspection'] ?? null, $uid]);

        // Siapkan baris hasil untuk semua item aktif
        $items = q('SELECT id FROM checklist_items WHERE form_type=? AND aktif=1 ORDER BY sort_order', [$formType]);
        foreach ($items as $it) {
            ex('INSERT IGNORE INTO inspection_results (inspection_id, item_id, hasil) VALUES (?,?,"na")',
                [$id, (int)$it['id']]);
        }
        if ($scheduleId) ex('UPDATE schedules SET status="proses" WHERE id=?', [$scheduleId]);

        flash('Checklist dibuat. Silakan isi item pemeriksaan.');
        header('Location: inspection_form.php?id=' . $id);
        exit;
    }

    if ($act === 'save' || $act === 'submit') {
        $id = (int)$_POST['id'];
        $insp = q1('SELECT * FROM inspections WHERE id=? AND inspector_id=?', [$id, $uid]);
        if (!$insp) { http_response_code(403); exit('Checklist tidak ditemukan.'); }
        if (!in_array($insp['status'], ['draft', 'ditolak'], true)) {
            flash('Checklist sudah diajukan dan tidak dapat diubah.', 'err');
            header('Location: inspection_view.php?id=' . $id);
            exit;
        }

        ex('UPDATE inspections SET tgl_pemeriksaan=?, nama_amt=?, umur_amt=?, sim_amt=?, nota_temuan=?, hasil_akhir=? WHERE id=?',
            [$_POST['tgl_pemeriksaan'], trim($_POST['nama_amt']), ($_POST['umur_amt'] ?: null),
             trim($_POST['sim_amt']), trim($_POST['nota_temuan']), $_POST['hasil_akhir'] ?? '', $id]);

        foreach (($_POST['hasil'] ?? []) as $itemId => $val) {
            $itemId = (int)$itemId;
            $val = in_array($val, ['baik', 'tidak', 'na'], true) ? $val : 'na';
            $ket = trim($_POST['ket'][$itemId] ?? '');
            ex('INSERT INTO inspection_results (inspection_id, item_id, hasil, keterangan)
                VALUES (?,?,?,?) ON DUPLICATE KEY UPDATE hasil=VALUES(hasil), keterangan=VALUES(keterangan)',
                [$id, $itemId, $val, $ket]);

            // Foto temuan (opsional, bisa lebih dari 1 per item)
            $names = $_FILES['foto']['name'][$itemId] ?? null;
            if (is_array($names)) {
                foreach ($names as $k => $nm) {
                    if (($_FILES['foto']['error'][$itemId][$k] ?? UPLOAD_ERR_NO_FILE) === UPLOAD_ERR_NO_FILE) continue;
                    $one = [
                        'name'     => $nm,
                        'type'     => $_FILES['foto']['type'][$itemId][$k] ?? '',
                        'tmp_name' => $_FILES['foto']['tmp_name'][$itemId][$k] ?? '',
                        'error'    => $_FILES['foto']['error'][$itemId][$k] ?? UPLOAD_ERR_NO_FILE,
                        'size'     => $_FILES['foto']['size'][$itemId][$k] ?? 0,
                    ];
                    $path = save_temuan_photo($one, $id, $itemId);
                    if ($path) {
                        ex('INSERT INTO inspection_photos (inspection_id, item_id, file_path, uploaded_by) VALUES (?,?,?,?)',
                            [$id, $itemId, $path, $uid]);
                    } else {
                        flash('Sebagian foto gagal diunggah (format harus JPG/PNG/WEBP, maks 5 MB).', 'err');
                    }
                }
            }
        }

        // Hapus foto terpilih
        foreach (($_POST['hapus_foto'] ?? []) as $photoId => $v) {
            $photoId = (int)$photoId;
            $ph = q1('SELECT * FROM inspection_photos WHERE id=? AND inspection_id=?', [$photoId, $id]);
            if ($ph) {
                if (is_file(__DIR__ . '/' . $ph['file_path'])) @unlink(__DIR__ . '/' . $ph['file_path']);
                ex('DELETE FROM inspection_photos WHERE id=?', [$photoId]);
            }
        }


        if ($act === 'submit') {
            $belum = q1('SELECT COUNT(*) n FROM inspection_results WHERE inspection_id=? AND hasil="na"', [$id]);
            if ((int)$belum['n'] > 0) {
                flash('Masih ada ' . (int)$belum['n'] . ' item belum dinilai. Draft tersimpan.', 'err');
                header('Location: inspection_form.php?id=' . $id);
                exit;
            }
            ex('UPDATE inspections SET status="diajukan", submitted_at=NOW() WHERE id=?', [$id]);
            ex('DELETE FROM inspection_approvals WHERE inspection_id=?', [$id]);
            $roles = ['hsse' => 1, 'distribusi' => 1, 'qq' => 1];
            if (needs_itm($insp['form_type'])) $roles['itm'] = 2;   // ITM hanya untuk MT Baru
            foreach ($roles as $r => $lvl) {
                ex('INSERT INTO inspection_approvals (inspection_id, role, level, status) VALUES (?,?,?,"menunggu")',
                    [$id, $r, $lvl]);
            }
            flash(needs_itm($insp['form_type'])
                ? 'Checklist diajukan ke HSSE, Distribusi & QQ. Approval final oleh ITM.'
                : 'Checklist diajukan ke HSSE, Distribusi & QQ (tanpa approval ITM).');
            header('Location: inspection_view.php?id=' . $id);
            exit;
        }

        flash('Draft checklist disimpan.');
        header('Location: inspection_form.php?id=' . $id);
        exit;
    }
}

/* ---------------- Tahap 1: buat checklist ---------------- */
$id = (int)($_GET['id'] ?? 0);
if (!$id) {
    $schedId = (int)($_GET['schedule'] ?? 0);
    $sched = $schedId ? q1('SELECT s.*, v.no_polisi FROM schedules s JOIN vehicles v ON v.id=s.vehicle_id WHERE s.id=?', [$schedId]) : null;
    $vehicles = q('SELECT id, no_polisi FROM vehicles WHERE status <> "nonaktif" ORDER BY no_polisi');
    $jadwal = q('SELECT s.*, v.no_polisi FROM schedules s JOIN vehicles v ON v.id=s.vehicle_id
                 WHERE s.status IN ("dijadwalkan","proses")
                   AND (s.inspector_id = ? OR s.inspector_id IS NULL)
                 ORDER BY s.tanggal', [$uid]);

    layout_start('Buat Checklist Pemeriksaan');
    ?>
    <div class="card">
      <h3>Mulai Checklist</h3>
      <form method="post">
        <?= csrf_field() ?>
        <input type="hidden" name="act" value="create">
        <div class="row">
          <div class="field"><label>Ambil dari Jadwal (opsional)</label>
            <select name="schedule_id" id="schedule_id">
              <option value="">— tanpa jadwal —</option>
              <?php foreach ($jadwal as $j): ?>
                <option value="<?= (int)$j['id'] ?>" data-v="<?= (int)$j['vehicle_id'] ?>" data-f="<?= e($j['form_type']) ?>" data-t="<?= e($j['tanggal']) ?>"
                  <?= ($sched && $sched['id'] == $j['id']) ? 'selected' : '' ?>>
                  <?= tgl($j['tanggal']) ?> · <?= e($j['no_polisi']) ?> · <?= e(form_label($j['form_type'])) ?>
                </option>
              <?php endforeach; ?>
            </select>
          </div>
          <div class="field"><label>Mobil Tangki *</label>
            <select name="vehicle_id" id="vehicle_id" required>
              <?php foreach ($vehicles as $v): ?>
                <option value="<?= (int)$v['id'] ?>" <?= ($sched && $sched['vehicle_id'] == $v['id']) ? 'selected' : '' ?>><?= e($v['no_polisi']) ?></option>
              <?php endforeach; ?>
            </select>
          </div>
          <div class="field"><label>Jenis Form *</label>
            <select name="form_type" id="form_type">
              <option value="baru" <?= ($sched && $sched['form_type'] === 'baru') ? 'selected' : '' ?>>Checklist MT Baru</option>
              <option value="6bulanan" <?= (!$sched || $sched['form_type'] === '6bulanan') ? 'selected' : '' ?>>Inspeksi 6 Bulanan</option>
            </select>
          </div>
          <div class="field"><label>Tanggal Pemeriksaan *</label>
            <input name="tgl_pemeriksaan" id="tgl" type="date" required value="<?= e($sched['tanggal'] ?? date('Y-m-d')) ?>">
          </div>
        </div>
        <button class="btn">Buat &amp; Isi Checklist</button>
      </form>
    </div>
    <script>
    document.getElementById('schedule_id').addEventListener('change', function () {
      const o = this.selectedOptions[0];
      if (!o || !o.dataset.v) return;
      document.getElementById('vehicle_id').value = o.dataset.v;
      document.getElementById('form_type').value = o.dataset.f;
      document.getElementById('tgl').value = o.dataset.t;
    });
    </script>
    <?php
    layout_end();
    exit;
}

/* ---------------- Tahap 2: isi item ---------------- */
$insp = q1('SELECT i.*, v.no_polisi, v.merk, v.tahun, v.kapasitas_kl, v.produk, v.pabrikan_tangki,
                   t.nama AS transportir
            FROM inspections i
            JOIN vehicles v ON v.id = i.vehicle_id
            LEFT JOIN transporters t ON t.id = v.transporter_id
            WHERE i.id = ? AND i.inspector_id = ?', [$id, $uid]);
if (!$insp) { http_response_code(404); exit('Checklist tidak ditemukan.'); }
if (!in_array($insp['status'], ['draft', 'ditolak'], true)) {
    header('Location: inspection_view.php?id=' . $id);
    exit;
}

$items = q('SELECT ci.*, r.hasil, r.keterangan
            FROM checklist_items ci
            LEFT JOIN inspection_results r ON r.item_id = ci.id AND r.inspection_id = ?
            WHERE ci.form_type = ? AND ci.aktif = 1
            ORDER BY ci.sort_order', [$id, $insp['form_type']]);

$fotoByItem = [];
foreach (q('SELECT * FROM inspection_photos WHERE inspection_id=? ORDER BY id', [$id]) as $p) {
    $fotoByItem[(int)$p['item_id']][] = $p;
}


layout_start('Isi Checklist — ' . $insp['no_polisi']);
?>
<form method="post" enctype="multipart/form-data">
  <?= csrf_field() ?>
  <input type="hidden" name="id" value="<?= (int)$id ?>">

  <div class="card">
    <h3><?= e(form_label($insp['form_type'])) ?> · <?= e($insp['no_pemeriksaan']) ?></h3>
    <div class="row">
      <div class="field"><label>No. Polisi</label><input value="<?= e($insp['no_polisi']) ?>" disabled></div>
      <div class="field"><label>Transportir</label><input value="<?= e($insp['transportir'] ?: '-') ?>" disabled></div>
      <div class="field"><label>Merk / Tahun</label><input value="<?= e($insp['merk'] . ' / ' . $insp['tahun']) ?>" disabled></div>
      <div class="field"><label>Kapasitas</label><input value="<?= e($insp['kapasitas_kl']) ?> KL" disabled></div>
    </div>
    <div class="row">
      <div class="field"><label>Tanggal Pemeriksaan</label><input name="tgl_pemeriksaan" type="date" value="<?= e($insp['tgl_pemeriksaan']) ?>"></div>
      <div class="field"><label>Pemeriksaan Terakhir</label><input value="<?= e($insp['tgl_terakhir'] ?: '-') ?>" disabled></div>
      <div class="field"><label>Nama AMT</label><input name="nama_amt" value="<?= e($insp['nama_amt']) ?>"></div>
      <div class="field"><label>Umur AMT</label><input name="umur_amt" type="number" value="<?= e($insp['umur_amt']) ?>"></div>
      <div class="field"><label>SIM B I / B II</label><input name="sim_amt" value="<?= e($insp['sim_amt']) ?>"></div>
    </div>
  </div>

  <div class="card">
    <h3>Item Pemeriksaan (<?= count($items) ?>)</h3>
    <div class="table-wrap">
      <table>
        <thead><tr>
          <th style="width:40px">No</th><th>Uraian Pemeriksaan</th>
          <th style="width:60px">Prioritas</th><th style="width:190px">Hasil</th><th style="width:220px">Keterangan</th><th style="width:170px">Foto Temuan</th>
        </tr></thead>
        <tbody>
        <?php $sec = null; foreach ($items as $it): ?>
          <?php if ($it['section'] !== $sec): $sec = $it['section']; ?>
            <tr class="section-row"><td colspan="6"><?= e($sec) ?></td></tr>
          <?php endif; ?>
          <tr class="chk-row">
            <td><?= e($it['item_no']) ?></td>
            <td>
              <?= e($it['item_text']) ?>
              <?php if ($it['penjelasan']): ?><br><span class="muted small"><?= e($it['penjelasan']) ?></span><?php endif; ?>
              <?php if ($it['pelaksana']): ?><br><span class="badge badge-gray"><?= e($it['pelaksana']) ?></span><?php endif; ?>
            </td>
            <td><span class="badge badge-<?= $it['prioritas'] === 'MANDATORY' ? 'red' : 'gray' ?>"><?= $it['prioritas'] === 'MANDATORY' ? 'M' : 'NM' ?></span>
              <?php if ($it['batas_non_mandatory']): ?><br><span class="muted small"><?= e($it['batas_non_mandatory']) ?></span><?php endif; ?></td>
            <td>
              <div class="chk-opts">
                <?php foreach (['baik' => 'Baik', 'tidak' => 'Tidak', 'na' => 'N/A'] as $k => $lbl): ?>
                  <label><input type="radio" name="hasil[<?= (int)$it['id'] ?>]" value="<?= $k ?>"
                    <?= (($it['hasil'] ?? 'na') === $k) ? 'checked' : '' ?>> <?= $lbl ?></label>
                <?php endforeach; ?>
              </div>
            </td>
            <td><input name="ket[<?= (int)$it['id'] ?>]" value="<?= e($it['keterangan']) ?>"></td>
            <td>
              <?php foreach (($fotoByItem[(int)$it['id']] ?? []) as $ph): ?>
                <div style="display:inline-block;margin:0 4px 4px 0;text-align:center">
                  <a href="<?= e($ph['file_path']) ?>" target="_blank"><img src="<?= e($ph['file_path']) ?>" alt="Foto temuan <?= e($it['item_text']) ?>" style="width:70px;height:54px;object-fit:cover;border-radius:6px;border:1px solid var(--line)"></a>
                  <label class="muted small" style="display:block"><input type="checkbox" name="hapus_foto[<?= (int)$ph['id'] ?>]" value="1"> hapus</label>
                </div>
              <?php endforeach; ?>
              <input type="file" name="foto[<?= (int)$it['id'] ?>][]" accept="image/jpeg,image/png,image/webp" class="small" multiple>
            </td>

          </tr>
        <?php endforeach; ?>
        </tbody>
      </table>
    </div>
  </div>

  <div class="card">
    <h3>Nota Temuan &amp; Hasil</h3>
    <div class="field"><label>Nota Temuan Hasil Pemeriksaan MT</label>
      <textarea name="nota_temuan" rows="4"><?= e($insp['nota_temuan']) ?></textarea></div>
    <div class="field" style="max-width:240px"><label>Status Hasil</label>
      <select name="hasil_akhir">
        <option value="" <?= $insp['hasil_akhir'] === '' ? 'selected' : '' ?>>— belum ditentukan —</option>
        <option value="OK" <?= $insp['hasil_akhir'] === 'OK' ? 'selected' : '' ?>>OK</option>
        <option value="NOT OK" <?= $insp['hasil_akhir'] === 'NOT OK' ? 'selected' : '' ?>>NOT OK</option>
      </select>
    </div>
    <div class="sticky-actions">
      <a class="btn btn-muted" href="inspections.php">Batal</a>
      <button class="btn btn-outline" name="act" value="save">Simpan Draft</button>
      <button class="btn" name="act" value="submit" onclick="return confirm('Ajukan checklist untuk approval HSSE, Distribusi, QQ lalu ITM?')">Ajukan Approval</button>
    </div>
  </div>
</form>
<?php layout_end(); ?>

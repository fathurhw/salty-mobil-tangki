<?php
require_once __DIR__ . '/includes/layout.php';
require_role(['admin_hsse']);
csrf_check();

$act = $_POST['act'] ?? '';
if ($act === 'save') {
    $id = (int)($_POST['id'] ?? 0);
    $old = $id ? q1('SELECT * FROM vehicles WHERE id=?', [$id]) : null;
    $noPolisi = trim($_POST['no_polisi']);

    /* upload foto tampak & dokumen (kosong = pakai file lama) */
    $files = [];
    foreach (array_keys(vehicle_files()) as $k) {
        $new = isset($_FILES[$k]) ? save_vehicle_file($_FILES[$k], $noPolisi, $k) : null;
        $files[$k] = $new ?: ($old[$k] ?? null);
    }

    $p = [
        $noPolisi, trim($_POST['no_chasis']), ($_POST['transporter_id'] ?: null),
        trim($_POST['merk']), ($_POST['tahun'] ?: null), trim($_POST['pabrikan_tangki']),
        ($_POST['kapasitas_kl'] ?: null), $_POST['jenis_tangki'], trim($_POST['bahan_tangki']),
        trim($_POST['produk']), trim($_POST['stnk_no']), ($_POST['stnk_berlaku'] ?: null),
        trim($_POST['keur_no']), ($_POST['keur_berlaku'] ?: null), ($_POST['tera_berlaku'] ?: null),
        $_POST['status'], ($_POST['last_inspection'] ?: null),
        ($_POST['last_inspection'] ? next_due($_POST['last_inspection']) : null),
        $files['foto_depan'], $files['foto_belakang'], $files['foto_kanan'], $files['foto_kiri'],
        $files['doc_stnk'], $files['doc_keur'], $files['doc_tera'],
    ];
    if ($id) {
        $p[] = $id;
        ex('UPDATE vehicles SET no_polisi=?, no_chasis=?, transporter_id=?, merk=?, tahun=?,
            pabrikan_tangki=?, kapasitas_kl=?, jenis_tangki=?, bahan_tangki=?, produk=?, stnk_no=?,
            stnk_berlaku=?, keur_no=?, keur_berlaku=?, tera_berlaku=?, status=?, last_inspection=?,
            next_inspection=?, foto_depan=?, foto_belakang=?, foto_kanan=?, foto_kiri=?,
            doc_stnk=?, doc_keur=?, doc_tera=? WHERE id=?', $p);
        flash('Data mobil tangki diperbarui.');
    } else {
        ex('INSERT INTO vehicles (no_polisi, no_chasis, transporter_id, merk, tahun, pabrikan_tangki,
            kapasitas_kl, jenis_tangki, bahan_tangki, produk, stnk_no, stnk_berlaku, keur_no,
            keur_berlaku, tera_berlaku, status, last_inspection, next_inspection,
            foto_depan, foto_belakang, foto_kanan, foto_kiri, doc_stnk, doc_keur, doc_tera)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)', $p);
        flash('Mobil tangki baru ditambahkan.');
    }
    header('Location: vehicles.php');
    exit;
}
if ($act === 'del') {
    ex('DELETE FROM vehicles WHERE id=?', [(int)$_POST['id']]);
    flash('Data mobil tangki dihapus.');
    header('Location: vehicles.php');
    exit;
}

$edit = null;
if (!empty($_GET['edit'])) {
    $edit = q1('SELECT * FROM vehicles WHERE id=?', [(int)$_GET['edit']]);
}
$transporters = q('SELECT * FROM transporters ORDER BY nama');
$rows = q('SELECT v.*, t.nama AS transportir, DATEDIFF(v.next_inspection, CURDATE()) sisa
           FROM vehicles v LEFT JOIN transporters t ON t.id = v.transporter_id
           ORDER BY v.no_polisi');

layout_start('Master Mobil Tangki');
?>
<div class="card">
  <h3><?= $edit ? 'Ubah Mobil Tangki' : 'Tambah Mobil Tangki' ?></h3>
  <form method="post" enctype="multipart/form-data">
    <?= csrf_field() ?>
    <input type="hidden" name="act" value="save">
    <input type="hidden" name="id" value="<?= (int)($edit['id'] ?? 0) ?>">
    <div class="row">
      <div class="field"><label>No. Polisi *</label><input name="no_polisi" required value="<?= e($edit['no_polisi'] ?? '') ?>"></div>
      <div class="field"><label>No. Chasis</label><input name="no_chasis" value="<?= e($edit['no_chasis'] ?? '') ?>"></div>
      <div class="field"><label>Transportir</label>
        <select name="transporter_id">
          <option value="">— pilih —</option>
          <?php foreach ($transporters as $t): ?>
            <option value="<?= (int)$t['id'] ?>" <?= (($edit['transporter_id'] ?? '') == $t['id']) ? 'selected' : '' ?>><?= e($t['nama']) ?></option>
          <?php endforeach; ?>
        </select>
      </div>
    </div>
    <div class="row">
      <div class="field"><label>Merk / Tipe</label><input name="merk" value="<?= e($edit['merk'] ?? '') ?>"></div>
      <div class="field"><label>Tahun</label><input name="tahun" type="number" min="1980" max="2100" value="<?= e($edit['tahun'] ?? '') ?>"></div>
      <div class="field"><label>Pabrikan Tangki</label><input name="pabrikan_tangki" value="<?= e($edit['pabrikan_tangki'] ?? '') ?>"></div>
      <div class="field"><label>Kapasitas (KL)</label><input name="kapasitas_kl" type="number" step="0.01" value="<?= e($edit['kapasitas_kl'] ?? '') ?>"></div>
    </div>
    <div class="row">
      <div class="field"><label>Jenis Tangki</label>
        <select name="jenis_tangki">
          <?php foreach (['rigid' => 'Rigid', 'semi_trailer' => 'Semi trailer', 'gandengan' => 'Gandengan'] as $k => $v): ?>
            <option value="<?= $k ?>" <?= (($edit['jenis_tangki'] ?? '') === $k) ? 'selected' : '' ?>><?= $v ?></option>
          <?php endforeach; ?>
        </select>
      </div>
      <div class="field"><label>Bahan Tangki</label><input name="bahan_tangki" value="<?= e($edit['bahan_tangki'] ?? '') ?>"></div>
      <div class="field"><label>Produk</label><input name="produk" value="<?= e($edit['produk'] ?? '') ?>"></div>
      <div class="field"><label>Status</label>
        <select name="status">
          <?php foreach (['aktif' => 'Aktif', 'off' => 'MT OFF', 'nonaktif' => 'Nonaktif'] as $k => $v): ?>
            <option value="<?= $k ?>" <?= (($edit['status'] ?? 'aktif') === $k) ? 'selected' : '' ?>><?= $v ?></option>
          <?php endforeach; ?>
        </select>
      </div>
    </div>
    <div class="row">
      <div class="field"><label>No. STNK</label><input name="stnk_no" value="<?= e($edit['stnk_no'] ?? '') ?>"></div>
      <div class="field"><label>STNK berlaku s.d.</label><input name="stnk_berlaku" type="date" value="<?= e($edit['stnk_berlaku'] ?? '') ?>"></div>
      <div class="field"><label>No. Keur</label><input name="keur_no" value="<?= e($edit['keur_no'] ?? '') ?>"></div>
      <div class="field"><label>Keur berlaku s.d.</label><input name="keur_berlaku" type="date" value="<?= e($edit['keur_berlaku'] ?? '') ?>"></div>
      <div class="field"><label>Tera metrologi s.d.</label><input name="tera_berlaku" type="date" value="<?= e($edit['tera_berlaku'] ?? '') ?>"></div>
    </div>
    <div class="row">
      <div class="field"><label>Inspeksi 6 bulanan terakhir</label>
        <input name="last_inspection" type="date" value="<?= e($edit['last_inspection'] ?? '') ?>">
        <small class="muted">Jatuh tempo berikutnya dihitung otomatis +<?= INSPECTION_INTERVAL_MONTHS ?> bulan.</small>
      </div>
    </div>

    <h4 style="margin:14px 0 6px">Foto Tampak MT &amp; Dokumen</h4>
    <p class="muted small" style="margin-top:0">Format JPG / PNG / WEBP / PDF, maksimal 8 MB per file. Biarkan kosong bila tidak ingin mengubah file lama.</p>
    <div class="row">
      <?php foreach (vehicle_files() as $key => $label): ?>
        <div class="field">
          <label><?= e($label) ?></label>
          <input type="file" name="<?= $key ?>" accept="image/*,application/pdf">
          <?php if (!empty($edit[$key])): ?>
            <small class="muted"><a href="<?= e($edit[$key]) ?>" target="_blank">Lihat file saat ini</a></small>
          <?php endif; ?>
        </div>
      <?php endforeach; ?>
    </div>

    <button class="btn" type="submit"><?= $edit ? 'Simpan Perubahan' : 'Tambah' ?></button>
    <?php if ($edit): ?><a class="btn btn-muted" href="vehicles.php">Batal</a><?php endif; ?>
  </form>
</div>

<div class="card">
  <h3>Daftar Mobil Tangki (<?= count($rows) ?>)</h3>
  <p class="muted small" style="margin-top:0">Rekap lengkap beserta foto &amp; dokumen dapat dilihat di menu <a href="vehicle_data.php">Data Mobil Tangki</a>.</p>
  <div class="table-wrap">
    <table>
      <thead><tr><th>No. Polisi</th><th>Transportir</th><th>Merk / Th</th><th>Kapasitas</th><th>Jenis</th>
        <th>Insp. Terakhir</th><th>Jatuh Tempo</th><th>Status</th><th></th></tr></thead>
      <tbody>
      <?php foreach ($rows as $r): ?>
        <tr>
          <td><b><?= e($r['no_polisi']) ?></b><br><span class="muted small"><?= e($r['no_chasis']) ?></span></td>
          <td><?= e($r['transportir'] ?: '-') ?></td>
          <td><?= e($r['merk']) ?><br><span class="muted small"><?= e($r['tahun']) ?></span></td>
          <td><?= e($r['kapasitas_kl']) ?> KL</td>
          <td><?= e(str_replace('_', ' ', $r['jenis_tangki'])) ?></td>
          <td><?= tgl($r['last_inspection']) ?></td>
          <td><?= tgl($r['next_inspection']) ?><br><?= due_badge($r['sisa'] === null ? null : (int)$r['sisa']) ?></td>
          <td><span class="badge badge-<?= $r['status'] === 'aktif' ? 'green' : ($r['status'] === 'off' ? 'red' : 'gray') ?>"><?= e(strtoupper($r['status'])) ?></span></td>
          <td style="white-space:nowrap">
            <a class="btn btn-sm btn-outline" href="?edit=<?= (int)$r['id'] ?>">Ubah</a>
            <form method="post" style="display:inline" onsubmit="return confirm('Hapus MT <?= e($r['no_polisi']) ?>? Semua jadwal &amp; checklist terkait ikut terhapus.')">
              <?= csrf_field() ?>
              <input type="hidden" name="act" value="del"><input type="hidden" name="id" value="<?= (int)$r['id'] ?>">
              <button class="btn btn-sm btn-danger" type="submit">Hapus</button>
            </form>
          </td>
        </tr>
      <?php endforeach; ?>
      </tbody>
    </table>
  </div>
</div>
<?php layout_end(); ?>

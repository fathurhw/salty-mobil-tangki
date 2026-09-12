<?php
require_once __DIR__ . '/includes/layout.php';
require_login();
csrf_check();

$isAdmin = role() === 'admin_hsse';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!$isAdmin) { http_response_code(403); exit('Hanya Admin HSSE yang dapat mengubah jadwal.'); }
    $act = $_POST['act'] ?? '';
    if ($act === 'save') {
        $id = (int)($_POST['id'] ?? 0);
        $p = [(int)$_POST['vehicle_id'], $_POST['form_type'], $_POST['tanggal'], ($_POST['jam'] ?: null),
              trim($_POST['lokasi']), ($_POST['inspector_id'] ?: null), trim($_POST['catatan']), $_POST['status']];
        if ($id) {
            $p[] = $id;
            ex('UPDATE schedules SET vehicle_id=?, form_type=?, tanggal=?, jam=?, lokasi=?, inspector_id=?,
                catatan=?, status=? WHERE id=?', $p);
            flash('Jadwal diperbarui.');
        } else {
            $p[] = (int)user()['id'];
            ex('INSERT INTO schedules (vehicle_id, form_type, tanggal, jam, lokasi, inspector_id, catatan, status, created_by)
                VALUES (?,?,?,?,?,?,?,?,?)', $p);
            flash('Jadwal pemeriksaan dibuat.');
        }
    } elseif ($act === 'del') {
        ex('DELETE FROM schedules WHERE id=?', [(int)$_POST['id']]);
        flash('Jadwal dihapus.');
    }
    header('Location: schedules.php');
    exit;
}

$edit = !empty($_GET['edit']) ? q1('SELECT * FROM schedules WHERE id=?', [(int)$_GET['edit']]) : null;
$prefill = [
    'vehicle_id' => $_GET['vehicle'] ?? '',
    'form_type'  => $_GET['form'] ?? '6bulanan',
    'tanggal'    => $_GET['tanggal'] ?? date('Y-m-d'),
];

$fType = $_GET['type'] ?? '';
$where = $fType ? ' WHERE s.form_type = "' . ($fType === 'baru' ? 'baru' : '6bulanan') . '"' : '';

$rows = q('SELECT s.*, v.no_polisi, t.nama AS transportir, u.nama AS inspector,
                  (SELECT i.id FROM inspections i WHERE i.schedule_id = s.id LIMIT 1) AS inspection_id
           FROM schedules s
           JOIN vehicles v ON v.id = s.vehicle_id
           LEFT JOIN transporters t ON t.id = v.transporter_id
           LEFT JOIN users u ON u.id = s.inspector_id' . $where . '
           ORDER BY s.tanggal DESC, s.jam ASC');

$vehicles   = q('SELECT id, no_polisi FROM vehicles ORDER BY no_polisi');
$inspectors = q('SELECT id, nama FROM users WHERE role = "inspector_hsse" AND aktif = 1 ORDER BY nama');

layout_start('Jadwal Pemeriksaan');
?>
<div class="card">
  <a class="btn btn-sm <?= $fType === '' ? '' : 'btn-outline' ?>" href="?">Semua</a>
  <a class="btn btn-sm <?= $fType === 'baru' ? '' : 'btn-outline' ?>" href="?type=baru">MT Baru</a>
  <a class="btn btn-sm <?= $fType === '6bulanan' ? '' : 'btn-outline' ?>" href="?type=6bulanan">6 Bulanan</a>
</div>

<?php if ($isAdmin): ?>
<div class="card">
  <h3><?= $edit ? 'Ubah Jadwal' : 'Buat Jadwal Pemeriksaan' ?></h3>
  <form method="post">
    <?= csrf_field() ?>
    <input type="hidden" name="act" value="save">
    <input type="hidden" name="id" value="<?= (int)($edit['id'] ?? 0) ?>">
    <div class="row">
      <div class="field"><label>Mobil Tangki *</label>
        <select name="vehicle_id" required>
          <option value="">— pilih —</option>
          <?php foreach ($vehicles as $v): ?>
            <option value="<?= (int)$v['id'] ?>" <?= (($edit['vehicle_id'] ?? $prefill['vehicle_id']) == $v['id']) ? 'selected' : '' ?>><?= e($v['no_polisi']) ?></option>
          <?php endforeach; ?>
        </select>
      </div>
      <div class="field"><label>Jenis Pemeriksaan *</label>
        <select name="form_type">
          <option value="baru" <?= (($edit['form_type'] ?? $prefill['form_type']) === 'baru') ? 'selected' : '' ?>>Checklist MT Baru</option>
          <option value="6bulanan" <?= (($edit['form_type'] ?? $prefill['form_type']) === '6bulanan') ? 'selected' : '' ?>>Inspeksi 6 Bulanan</option>
        </select>
      </div>
      <div class="field"><label>Tanggal *</label><input name="tanggal" type="date" required value="<?= e($edit['tanggal'] ?? $prefill['tanggal']) ?>"></div>
      <div class="field"><label>Jam</label><input name="jam" type="time" value="<?= e(substr($edit['jam'] ?? '08:00:00', 0, 5)) ?>"></div>
    </div>
    <div class="row">
      <div class="field"><label>Inspector HSSE</label>
        <select name="inspector_id">
          <option value="">— belum ditentukan —</option>
          <?php foreach ($inspectors as $i): ?>
            <option value="<?= (int)$i['id'] ?>" <?= (($edit['inspector_id'] ?? '') == $i['id']) ? 'selected' : '' ?>><?= e($i['nama']) ?></option>
          <?php endforeach; ?>
        </select>
      </div>
      <div class="field"><label>Lokasi</label><input name="lokasi" value="<?= e($edit['lokasi'] ?? APP_TERMINAL) ?>"></div>
      <div class="field"><label>Status</label>
        <select name="status">
          <?php foreach (['dijadwalkan' => 'Dijadwalkan', 'proses' => 'Proses', 'selesai' => 'Selesai', 'batal' => 'Batal'] as $k => $v): ?>
            <option value="<?= $k ?>" <?= (($edit['status'] ?? 'dijadwalkan') === $k) ? 'selected' : '' ?>><?= $v ?></option>
          <?php endforeach; ?>
        </select>
      </div>
      <div class="field"><label>Catatan</label><input name="catatan" value="<?= e($edit['catatan'] ?? '') ?>"></div>
    </div>
    <button class="btn"><?= $edit ? 'Simpan' : 'Buat Jadwal' ?></button>
    <?php if ($edit): ?><a class="btn btn-muted" href="schedules.php">Batal</a><?php endif; ?>
  </form>
</div>
<?php endif; ?>

<div class="card">
  <h3>Daftar Jadwal (<?= count($rows) ?>)</h3>
  <div class="table-wrap">
    <table>
      <thead><tr><th>Tanggal</th><th>No. Polisi</th><th>Transportir</th><th>Jenis</th><th>Inspector</th><th>Status</th><th>Checklist</th><th></th></tr></thead>
      <tbody>
      <?php if (!$rows): ?><tr><td colspan="8" class="muted">Belum ada jadwal.</td></tr><?php endif; ?>
      <?php foreach ($rows as $r): ?>
        <tr>
          <td><?= tgl($r['tanggal']) ?><br><span class="muted small"><?= $r['jam'] ? substr($r['jam'], 0, 5) : '' ?> · <?= e($r['lokasi']) ?></span></td>
          <td><b><?= e($r['no_polisi']) ?></b></td>
          <td><?= e($r['transportir'] ?: '-') ?></td>
          <td><?= e(form_label($r['form_type'])) ?></td>
          <td><?= e($r['inspector'] ?: '-') ?></td>
          <td><span class="badge badge-<?= ['dijadwalkan' => 'gray', 'proses' => 'blue', 'selesai' => 'green', 'batal' => 'red'][$r['status']] ?>"><?= e(ucfirst($r['status'])) ?></span></td>
          <td>
            <?php if ($r['inspection_id']): ?>
              <a class="btn btn-sm btn-outline" href="inspection_view.php?id=<?= (int)$r['inspection_id'] ?>">Lihat Checklist</a>
            <?php elseif (role() === 'inspector_hsse'): ?>
              <a class="btn btn-sm" href="inspection_form.php?schedule=<?= (int)$r['id'] ?>">Isi Checklist</a>
            <?php else: ?>
              <span class="muted small">Belum diisi</span>
            <?php endif; ?>
          </td>
          <td style="white-space:nowrap">
            <?php if ($isAdmin): ?>
              <a class="btn btn-sm btn-outline" href="?edit=<?= (int)$r['id'] ?>">Ubah</a>
              <form method="post" style="display:inline" onsubmit="return confirm('Hapus jadwal ini?')">
                <?= csrf_field() ?>
                <input type="hidden" name="act" value="del"><input type="hidden" name="id" value="<?= (int)$r['id'] ?>">
                <button class="btn btn-sm btn-danger">Hapus</button>
              </form>
            <?php endif; ?>
          </td>
        </tr>
      <?php endforeach; ?>
      </tbody>
    </table>
  </div>
</div>
<?php layout_end(); ?>

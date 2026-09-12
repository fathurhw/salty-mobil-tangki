<?php
require_once __DIR__ . '/includes/layout.php';
require_role(['admin_hsse']);
csrf_check();

$act = $_POST['act'] ?? '';
if ($act === 'save') {
    $id = (int)($_POST['id'] ?? 0);
    $p = [trim($_POST['nama']), trim($_POST['telepon']), trim($_POST['alamat'])];
    if ($id) {
        $p[] = $id;
        ex('UPDATE transporters SET nama=?, telepon=?, alamat=? WHERE id=?', $p);
        flash('Transportir diperbarui.');
    } else {
        ex('INSERT INTO transporters (nama, telepon, alamat) VALUES (?,?,?)', $p);
        flash('Transportir ditambahkan.');
    }
    header('Location: transporters.php');
    exit;
}
if ($act === 'del') {
    ex('DELETE FROM transporters WHERE id=?', [(int)$_POST['id']]);
    flash('Transportir dihapus.');
    header('Location: transporters.php');
    exit;
}

$edit = !empty($_GET['edit']) ? q1('SELECT * FROM transporters WHERE id=?', [(int)$_GET['edit']]) : null;
$rows = q('SELECT t.*, (SELECT COUNT(*) FROM vehicles v WHERE v.transporter_id=t.id) jml FROM transporters t ORDER BY nama');

layout_start('Master Transportir');
?>
<div class="card">
  <h3><?= $edit ? 'Ubah Transportir' : 'Tambah Transportir' ?></h3>
  <form method="post">
    <?= csrf_field() ?>
    <input type="hidden" name="act" value="save">
    <input type="hidden" name="id" value="<?= (int)($edit['id'] ?? 0) ?>">
    <div class="row">
      <div class="field"><label>Nama Perusahaan *</label><input name="nama" required value="<?= e($edit['nama'] ?? '') ?>"></div>
      <div class="field"><label>Telepon</label><input name="telepon" value="<?= e($edit['telepon'] ?? '') ?>"></div>
      <div class="field"><label>Alamat</label><input name="alamat" value="<?= e($edit['alamat'] ?? '') ?>"></div>
    </div>
    <button class="btn" type="submit"><?= $edit ? 'Simpan' : 'Tambah' ?></button>
    <?php if ($edit): ?><a class="btn btn-muted" href="transporters.php">Batal</a><?php endif; ?>
  </form>
</div>
<div class="card">
  <div class="table-wrap">
    <table>
      <thead><tr><th>Nama</th><th>Telepon</th><th>Alamat</th><th>Jumlah MT</th><th></th></tr></thead>
      <tbody>
      <?php foreach ($rows as $r): ?>
        <tr>
          <td><b><?= e($r['nama']) ?></b></td>
          <td><?= e($r['telepon'] ?: '-') ?></td>
          <td><?= e($r['alamat'] ?: '-') ?></td>
          <td><?= (int)$r['jml'] ?></td>
          <td style="white-space:nowrap">
            <a class="btn btn-sm btn-outline" href="?edit=<?= (int)$r['id'] ?>">Ubah</a>
            <form method="post" style="display:inline" onsubmit="return confirm('Hapus transportir ini?')">
              <?= csrf_field() ?>
              <input type="hidden" name="act" value="del"><input type="hidden" name="id" value="<?= (int)$r['id'] ?>">
              <button class="btn btn-sm btn-danger">Hapus</button>
            </form>
          </td>
        </tr>
      <?php endforeach; ?>
      </tbody>
    </table>
  </div>
</div>
<?php layout_end(); ?>

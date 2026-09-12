<?php
require_once __DIR__ . '/includes/layout.php';
require_role(['admin_hsse']);
csrf_check();

$act = $_POST['act'] ?? '';
if ($act === 'save') {
    $id = (int)($_POST['id'] ?? 0);
    $username = trim($_POST['username']);
    $nama = trim($_POST['nama']);
    $jabatan = trim($_POST['jabatan']);
    $role = $_POST['role'];
    $aktif = isset($_POST['aktif']) ? 1 : 0;
    $pass = $_POST['password'] ?? '';

    if (!array_key_exists($role, ROLE_LABELS)) {
        flash('Peran tidak valid.', 'err');
    } elseif ($id) {
        ex('UPDATE users SET username=?, nama=?, jabatan=?, role=?, aktif=? WHERE id=?',
            [$username, $nama, $jabatan, $role, $aktif, $id]);
        if ($pass !== '') {
            ex('UPDATE users SET password=? WHERE id=?', [password_hash($pass, PASSWORD_DEFAULT), $id]);
        }
        flash('User diperbarui.');
    } else {
        if (strlen($pass) < 6) {
            flash('Password minimal 6 karakter.', 'err');
        } else {
            ex('INSERT INTO users (username, password, nama, jabatan, role, aktif) VALUES (?,?,?,?,?,?)',
                [$username, password_hash($pass, PASSWORD_DEFAULT), $nama, $jabatan, $role, $aktif]);
            flash('User baru dibuat.');
        }
    }
    header('Location: users.php');
    exit;
}
if ($act === 'del') {
    $id = (int)$_POST['id'];
    if ($id === (int)user()['id']) {
        flash('Tidak dapat menghapus akun sendiri.', 'err');
    } else {
        ex('DELETE FROM users WHERE id=?', [$id]);
        flash('User dihapus.');
    }
    header('Location: users.php');
    exit;
}

$edit = !empty($_GET['edit']) ? q1('SELECT * FROM users WHERE id=?', [(int)$_GET['edit']]) : null;
$rows = q('SELECT * FROM users ORDER BY FIELD(role,"admin_hsse","inspector_hsse","hsse","distribusi","qq","itm"), nama');

layout_start('Master User');
?>
<div class="card">
  <h3><?= $edit ? 'Ubah User' : 'Tambah User' ?></h3>
  <form method="post">
    <?= csrf_field() ?>
    <input type="hidden" name="act" value="save">
    <input type="hidden" name="id" value="<?= (int)($edit['id'] ?? 0) ?>">
    <div class="row">
      <div class="field"><label>Username *</label><input name="username" required value="<?= e($edit['username'] ?? '') ?>"></div>
      <div class="field"><label>Nama Lengkap *</label><input name="nama" required value="<?= e($edit['nama'] ?? '') ?>"></div>
      <div class="field"><label>Jabatan</label><input name="jabatan" value="<?= e($edit['jabatan'] ?? '') ?>"></div>
    </div>
    <div class="row">
      <div class="field"><label>Peran *</label>
        <select name="role" required>
          <?php foreach (ROLE_LABELS as $k => $v): ?>
            <option value="<?= $k ?>" <?= (($edit['role'] ?? '') === $k) ? 'selected' : '' ?>><?= e($v) ?></option>
          <?php endforeach; ?>
        </select>
      </div>
      <div class="field"><label>Password <?= $edit ? '(kosongkan bila tidak diubah)' : '*' ?></label>
        <input name="password" type="password" <?= $edit ? '' : 'required' ?>></div>
      <div class="field"><label>&nbsp;</label>
        <label style="font-weight:500"><input type="checkbox" name="aktif" <?= (!$edit || $edit['aktif']) ? 'checked' : '' ?>> Akun aktif</label>
      </div>
    </div>
    <button class="btn" type="submit"><?= $edit ? 'Simpan' : 'Tambah' ?></button>
    <?php if ($edit): ?><a class="btn btn-muted" href="users.php">Batal</a><?php endif; ?>
  </form>
</div>

<div class="card">
  <div class="table-wrap">
    <table>
      <thead><tr><th>Nama</th><th>Username</th><th>Jabatan</th><th>Peran</th><th>Status</th><th></th></tr></thead>
      <tbody>
      <?php foreach ($rows as $r): ?>
        <tr>
          <td><b><?= e($r['nama']) ?></b></td>
          <td><?= e($r['username']) ?></td>
          <td><?= e($r['jabatan'] ?: '-') ?></td>
          <td><?= e(ROLE_LABELS[$r['role']] ?? $r['role']) ?></td>
          <td><span class="badge badge-<?= $r['aktif'] ? 'green' : 'gray' ?>"><?= $r['aktif'] ? 'Aktif' : 'Nonaktif' ?></span></td>
          <td style="white-space:nowrap">
            <a class="btn btn-sm btn-outline" href="?edit=<?= (int)$r['id'] ?>">Ubah</a>
            <form method="post" style="display:inline" onsubmit="return confirm('Hapus user ini?')">
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

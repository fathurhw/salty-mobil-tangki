<?php
require_once __DIR__ . '/includes/layout.php';
require_role(['admin_hsse']);
csrf_check();

$act = $_POST['act'] ?? '';
if ($act === 'save') {
    $id = (int)($_POST['id'] ?? 0);
    $p = [$_POST['form_type'], trim($_POST['section']), trim($_POST['item_no']), trim($_POST['item_text']),
          trim($_POST['penjelasan']), $_POST['prioritas'], trim($_POST['batas_non_mandatory']),
          trim($_POST['pelaksana']), isset($_POST['aktif']) ? 1 : 0, (int)$_POST['sort_order']];
    if ($id) {
        $p[] = $id;
        ex('UPDATE checklist_items SET form_type=?, section=?, item_no=?, item_text=?, penjelasan=?,
            prioritas=?, batas_non_mandatory=?, pelaksana=?, aktif=?, sort_order=? WHERE id=?', $p);
        flash('Item checklist diperbarui.');
    } else {
        ex('INSERT INTO checklist_items (form_type, section, item_no, item_text, penjelasan, prioritas,
            batas_non_mandatory, pelaksana, aktif, sort_order) VALUES (?,?,?,?,?,?,?,?,?,?)', $p);
        flash('Item checklist ditambahkan.');
    }
    header('Location: items.php?type=' . urlencode($_POST['form_type']));
    exit;
}
if ($act === 'toggle') {
    ex('UPDATE checklist_items SET aktif = 1 - aktif WHERE id=?', [(int)$_POST['id']]);
    header('Location: items.php?type=' . urlencode($_POST['type']));
    exit;
}

$type = ($_GET['type'] ?? 'baru') === '6bulanan' ? '6bulanan' : 'baru';
$edit = !empty($_GET['edit']) ? q1('SELECT * FROM checklist_items WHERE id=?', [(int)$_GET['edit']]) : null;
$rows = q('SELECT * FROM checklist_items WHERE form_type=? ORDER BY sort_order', [$type]);

layout_start('Master Item Checklist');
?>
<div class="card">
  <a class="btn btn-sm <?= $type === 'baru' ? '' : 'btn-outline' ?>" href="?type=baru">Form MT Baru (<?= (int)(q1('SELECT COUNT(*) n FROM checklist_items WHERE form_type="baru"')['n']) ?> item)</a>
  <a class="btn btn-sm <?= $type === '6bulanan' ? '' : 'btn-outline' ?>" href="?type=6bulanan">Form Inspeksi 6 Bulanan (<?= (int)(q1('SELECT COUNT(*) n FROM checklist_items WHERE form_type="6bulanan"')['n']) ?> item)</a>
  <p class="muted small" style="margin-bottom:0">Item diambil dari form resmi: <i>Checklist Pemeriksaan MT BBM Standar Volume I di Terminal</i> dan <i>Formulir Checklist Inspeksi 6 Bulanan (Keur)</i>.</p>
</div>

<div class="card">
  <h3><?= $edit ? 'Ubah Item' : 'Tambah Item' ?></h3>
  <form method="post">
    <?= csrf_field() ?>
    <input type="hidden" name="act" value="save">
    <input type="hidden" name="id" value="<?= (int)($edit['id'] ?? 0) ?>">
    <div class="row">
      <div class="field"><label>Form</label>
        <select name="form_type">
          <option value="baru" <?= (($edit['form_type'] ?? $type) === 'baru') ? 'selected' : '' ?>>MT Baru</option>
          <option value="6bulanan" <?= (($edit['form_type'] ?? $type) === '6bulanan') ? 'selected' : '' ?>>Inspeksi 6 Bulanan</option>
        </select>
      </div>
      <div class="field"><label>Bagian / Section *</label><input name="section" required value="<?= e($edit['section'] ?? '') ?>"></div>
      <div class="field"><label>No. Item</label><input name="item_no" value="<?= e($edit['item_no'] ?? '') ?>"></div>
      <div class="field"><label>Urutan</label><input name="sort_order" type="number" value="<?= e($edit['sort_order'] ?? 0) ?>"></div>
    </div>
    <div class="field"><label>Uraian Pemeriksaan *</label><textarea name="item_text" rows="2" required><?= e($edit['item_text'] ?? '') ?></textarea></div>
    <div class="field"><label>Penjelasan</label><textarea name="penjelasan" rows="2"><?= e($edit['penjelasan'] ?? '') ?></textarea></div>
    <div class="row">
      <div class="field"><label>Prioritas</label>
        <select name="prioritas">
          <option value="MANDATORY" <?= (($edit['prioritas'] ?? '') === 'MANDATORY') ? 'selected' : '' ?>>MANDATORY</option>
          <option value="NON MANDATORY" <?= (($edit['prioritas'] ?? '') === 'NON MANDATORY') ? 'selected' : '' ?>>NON MANDATORY</option>
        </select>
      </div>
      <div class="field"><label>Batas Non Mandatory</label><input name="batas_non_mandatory" placeholder="cth. 6 HK" value="<?= e($edit['batas_non_mandatory'] ?? '') ?>"></div>
      <div class="field"><label>Pelaksana</label><input name="pelaksana" placeholder="HSSE / Distribusi / QQ" value="<?= e($edit['pelaksana'] ?? '') ?>"></div>
      <div class="field"><label>&nbsp;</label><label style="font-weight:500"><input type="checkbox" name="aktif" <?= (!$edit || $edit['aktif']) ? 'checked' : '' ?>> Aktif</label></div>
    </div>
    <button class="btn"><?= $edit ? 'Simpan' : 'Tambah' ?></button>
    <?php if ($edit): ?><a class="btn btn-muted" href="items.php?type=<?= e($type) ?>">Batal</a><?php endif; ?>
  </form>
</div>

<div class="card">
  <h3><?= e(form_label($type)) ?> — <?= count($rows) ?> item</h3>
  <div class="table-wrap">
    <table>
      <thead><tr><th style="width:40px">No</th><th>Uraian</th><th>Prioritas</th><th>Batas</th><th>Pelaksana</th><th>Status</th><th></th></tr></thead>
      <tbody>
      <?php $sec = null; foreach ($rows as $r): ?>
        <?php if ($r['section'] !== $sec): $sec = $r['section']; ?>
          <tr class="section-row"><td colspan="7"><?= e($sec) ?></td></tr>
        <?php endif; ?>
        <tr>
          <td><?= e($r['item_no']) ?></td>
          <td><?= e($r['item_text']) ?><?php if ($r['penjelasan']): ?><br><span class="muted small"><?= e($r['penjelasan']) ?></span><?php endif; ?></td>
          <td><span class="badge badge-<?= $r['prioritas'] === 'MANDATORY' ? 'red' : 'gray' ?>"><?= e($r['prioritas']) ?></span></td>
          <td><?= e($r['batas_non_mandatory'] ?: '-') ?></td>
          <td><?= e($r['pelaksana'] ?: '-') ?></td>
          <td><span class="badge badge-<?= $r['aktif'] ? 'green' : 'gray' ?>"><?= $r['aktif'] ? 'Aktif' : 'Off' ?></span></td>
          <td style="white-space:nowrap">
            <a class="btn btn-sm btn-outline" href="?type=<?= e($type) ?>&edit=<?= (int)$r['id'] ?>">Ubah</a>
            <form method="post" style="display:inline">
              <?= csrf_field() ?>
              <input type="hidden" name="act" value="toggle"><input type="hidden" name="id" value="<?= (int)$r['id'] ?>">
              <input type="hidden" name="type" value="<?= e($type) ?>">
              <button class="btn btn-sm btn-muted"><?= $r['aktif'] ? 'Nonaktifkan' : 'Aktifkan' ?></button>
            </form>
          </td>
        </tr>
      <?php endforeach; ?>
      </tbody>
    </table>
  </div>
</div>
<?php layout_end(); ?>

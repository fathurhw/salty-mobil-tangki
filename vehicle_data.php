<?php
/** Data Mobil Tangki — rekap keseluruhan MT di Integrated Terminal, bisa difilter & diurutkan. */
require_once __DIR__ . '/includes/layout.php';
require_login();

$sortable = [
    'no_polisi'       => 'v.no_polisi',
    'transportir'     => 't.nama',
    'kapasitas_kl'    => 'v.kapasitas_kl',
    'keur_berlaku'    => 'v.keur_berlaku',
    'tera_berlaku'    => 'v.tera_berlaku',
    'stnk_berlaku'    => 'v.stnk_berlaku',
    'next_inspection' => 'v.next_inspection',
    'status'          => 'v.status',
];
$sort = isset($_GET['sort'], $sortable[$_GET['sort']]) ? $_GET['sort'] : 'no_polisi';
$dir  = (($_GET['dir'] ?? 'asc') === 'desc') ? 'DESC' : 'ASC';

$where = ['1=1'];
$params = [];
if (($cari = trim($_GET['q'] ?? '')) !== '') {
    $where[] = '(v.no_polisi LIKE ? OR v.no_chasis LIKE ? OR v.stnk_no LIKE ? OR v.keur_no LIKE ?)';
    array_push($params, "%$cari%", "%$cari%", "%$cari%", "%$cari%");
}
if (!empty($_GET['transporter_id'])) { $where[] = 'v.transporter_id = ?'; $params[] = (int)$_GET['transporter_id']; }
if (!empty($_GET['status']))         { $where[] = 'v.status = ?';         $params[] = $_GET['status']; }
if (!empty($_GET['jenis']))          { $where[] = 'v.jenis_tangki = ?';   $params[] = $_GET['jenis']; }
$due = $_GET['due'] ?? '';
if ($due === 'lewat')  $where[] = 'v.next_inspection < CURDATE()';
if ($due === 'h5')     $where[] = 'DATEDIFF(v.next_inspection, CURDATE()) BETWEEN 0 AND 5';
if ($due === 'h30')    $where[] = 'DATEDIFF(v.next_inspection, CURDATE()) BETWEEN 0 AND 30';

$rows = q('SELECT v.*, t.nama AS transportir, DATEDIFF(v.next_inspection, CURDATE()) sisa
           FROM vehicles v LEFT JOIN transporters t ON t.id = v.transporter_id
           WHERE ' . implode(' AND ', $where) . '
           ORDER BY ' . $sortable[$sort] . ' ' . $dir, $params);
$transporters = q('SELECT * FROM transporters ORDER BY nama');

/** Link header untuk sorting. */
function sort_link(string $key, string $label, string $sort, string $dir): string
{
    $qs = $_GET;
    $qs['sort'] = $key;
    $qs['dir'] = ($sort === $key && $dir === 'ASC') ? 'desc' : 'asc';
    $mark = $sort === $key ? ($dir === 'ASC' ? ' &uarr;' : ' &darr;') : '';
    return '<a href="?' . e(http_build_query($qs)) . '" style="color:inherit">' . e($label) . $mark . '</a>';
}

$printQs = http_build_query(array_filter($_GET, fn($v, $k) => $k !== 'print', ARRAY_FILTER_USE_BOTH));

layout_start('Data Mobil Tangki');
?>
<div class="card">
  <h3 style="margin-bottom:2px">Data Mobil Tangki — Integrated Terminal <?= e(APP_KOTA) ?></h3>
  <p class="muted small" style="margin-top:0">Rekap nomor polisi, transportir, kapasitas, surat keur, tera, STNK, foto tampak MT,
    jatuh tempo inspeksi 6 bulanan &amp; status. Klik judul kolom untuk mengurutkan.</p>
  <form method="get" class="row" style="align-items:flex-end">
    <div class="field"><label>Cari (nopol / chasis / no. surat)</label><input name="q" value="<?= e($_GET['q'] ?? '') ?>" placeholder="misal B 9123 XX"></div>
    <div class="field"><label>Transportir</label>
      <select name="transporter_id">
        <option value="">Semua transportir</option>
        <?php foreach ($transporters as $t): ?>
          <option value="<?= (int)$t['id'] ?>" <?= (($_GET['transporter_id'] ?? '') == $t['id']) ? 'selected' : '' ?>><?= e($t['nama']) ?></option>
        <?php endforeach; ?>
      </select>
    </div>
    <div class="field"><label>Status</label>
      <select name="status">
        <option value="">Semua status</option>
        <?php foreach (['aktif' => 'Aktif', 'off' => 'MT OFF', 'nonaktif' => 'Nonaktif'] as $k => $v): ?>
          <option value="<?= $k ?>" <?= (($_GET['status'] ?? '') === $k) ? 'selected' : '' ?>><?= $v ?></option>
        <?php endforeach; ?>
      </select>
    </div>
    <div class="field"><label>Jenis Tangki</label>
      <select name="jenis">
        <option value="">Semua jenis</option>
        <?php foreach (['rigid' => 'Rigid', 'semi_trailer' => 'Semi trailer', 'gandengan' => 'Gandengan'] as $k => $v): ?>
          <option value="<?= $k ?>" <?= (($_GET['jenis'] ?? '') === $k) ? 'selected' : '' ?>><?= $v ?></option>
        <?php endforeach; ?>
      </select>
    </div>
    <div class="field"><label>Jatuh Tempo Inspeksi</label>
      <select name="due">
        <option value="">Semua</option>
        <option value="h5"    <?= $due === 'h5' ? 'selected' : '' ?>>≤ 5 hari lagi</option>
        <option value="h30"   <?= $due === 'h30' ? 'selected' : '' ?>>≤ 30 hari lagi</option>
        <option value="lewat" <?= $due === 'lewat' ? 'selected' : '' ?>>Sudah lewat</option>
      </select>
    </div>
    <div class="field" style="flex:0 0 auto">
      <label>&nbsp;</label>
      <button class="btn" type="submit">Terapkan Filter</button>
      <a class="btn btn-muted" href="vehicle_data.php">Reset</a>
    </div>
  </form>
  <div style="margin-top:10px">
    <a class="btn btn-sm btn-outline" href="vehicle_print.php?<?= e($printQs) ?>" target="_blank">Cetak / PDF Data MT (<?= count($rows) ?> unit)</a>
  </div>
</div>

<div class="card">
  <div class="table-wrap">
    <table>
      <thead><tr>
        <th><?= sort_link('no_polisi', 'No. Polisi', $sort, $dir) ?></th>
        <th><?= sort_link('transportir', 'Transportir', $sort, $dir) ?></th>
        <th><?= sort_link('kapasitas_kl', 'Kapasitas', $sort, $dir) ?></th>
        <th><?= sort_link('stnk_berlaku', 'STNK', $sort, $dir) ?></th>
        <th><?= sort_link('keur_berlaku', 'Keur', $sort, $dir) ?></th>
        <th><?= sort_link('tera_berlaku', 'Tera', $sort, $dir) ?></th>
        <th>Foto Tampak MT</th>
        <th><?= sort_link('next_inspection', 'Jatuh Tempo Inspeksi', $sort, $dir) ?></th>
        <th><?= sort_link('status', 'Status', $sort, $dir) ?></th>
        <th>Keterangan</th>
      </tr></thead>
      <tbody>
      <?php if (!$rows): ?><tr><td colspan="10" class="muted">Tidak ada mobil tangki sesuai filter.</td></tr><?php endif; ?>
      <?php foreach ($rows as $r): ?>
        <tr>
          <td><b><?= e($r['no_polisi']) ?></b><br><span class="muted small"><?= e($r['no_chasis'] ?: '-') ?></span></td>
          <td><?= e($r['transportir'] ?: '-') ?><br><span class="muted small"><?= e(str_replace('_', ' ', $r['jenis_tangki'])) ?></span></td>
          <td><?= e($r['kapasitas_kl']) ?> KL<br><span class="muted small"><?= e($r['produk'] ?: '-') ?></span></td>
          <td><?= e($r['stnk_no'] ?: '-') ?><br><span class="muted small">s.d. <?= tgl($r['stnk_berlaku']) ?></span></td>
          <td><?= e($r['keur_no'] ?: '-') ?><br><span class="muted small">s.d. <?= tgl($r['keur_berlaku']) ?></span></td>
          <td>s.d. <?= tgl($r['tera_berlaku']) ?></td>
          <td style="white-space:nowrap">
            <?php $adaFoto = false; foreach (['foto_depan' => 'Depan', 'foto_belakang' => 'Belakang', 'foto_kanan' => 'Kanan', 'foto_kiri' => 'Kiri'] as $k => $lbl): ?>
              <?php if (!empty($r[$k])): $adaFoto = true; ?>
                <a href="<?= e($r[$k]) ?>" target="_blank" title="Tampak <?= $lbl ?>">
                  <?php if (is_pdf($r[$k])): ?><span class="badge badge-gray"><?= $lbl ?> (PDF)</span>
                  <?php else: ?><img src="<?= e($r[$k]) ?>" alt="Tampak <?= $lbl ?> MT <?= e($r['no_polisi']) ?>" style="width:62px;height:46px;object-fit:cover;border-radius:6px;border:1px solid var(--line);margin:0 3px 3px 0"><?php endif; ?>
                </a>
              <?php endif; ?>
            <?php endforeach; ?>
            <?php if (!$adaFoto): ?><span class="muted small">belum ada foto</span><?php endif; ?>
          </td>
          <td><?= tgl($r['next_inspection']) ?><br><?= due_badge($r['sisa'] === null ? null : (int)$r['sisa']) ?></td>
          <td><span class="badge badge-<?= $r['status'] === 'aktif' ? 'green' : ($r['status'] === 'off' ? 'red' : 'gray') ?>"><?= e(strtoupper($r['status'])) ?></span></td>
          <td style="white-space:nowrap">
            <?php foreach (['doc_stnk' => 'STNK', 'doc_keur' => 'Keur', 'doc_tera' => 'Tera'] as $k => $lbl): ?>
              <?php if (!empty($r[$k])): ?>
                <a class="btn btn-sm btn-outline" href="<?= e($r[$k]) ?>" target="_blank">Lihat <?= $lbl ?></a>
              <?php endif; ?>
            <?php endforeach; ?>
            <a class="btn btn-sm btn-outline" href="vehicle_print.php?id=<?= (int)$r['id'] ?>" target="_blank">PDF</a>
          </td>
        </tr>
      <?php endforeach; ?>
      </tbody>
    </table>
  </div>
</div>
<?php layout_end(); ?>

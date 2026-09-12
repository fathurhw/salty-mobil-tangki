<?php
/** Cetak / PDF Data Mobil Tangki (satu unit atau seluruh hasil filter). */
require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/helpers.php';
require_login();

$id = (int)($_GET['id'] ?? 0);
$params = [];
if ($id) {
    $where = 'v.id = ?';
    $params[] = $id;
} else {
    $w = ['1=1'];
    if (($cari = trim($_GET['q'] ?? '')) !== '') {
        $w[] = '(v.no_polisi LIKE ? OR v.no_chasis LIKE ? OR v.stnk_no LIKE ? OR v.keur_no LIKE ?)';
        array_push($params, "%$cari%", "%$cari%", "%$cari%", "%$cari%");
    }
    if (!empty($_GET['transporter_id'])) { $w[] = 'v.transporter_id = ?'; $params[] = (int)$_GET['transporter_id']; }
    if (!empty($_GET['status']))         { $w[] = 'v.status = ?';         $params[] = $_GET['status']; }
    if (!empty($_GET['jenis']))          { $w[] = 'v.jenis_tangki = ?';   $params[] = $_GET['jenis']; }
    $due = $_GET['due'] ?? '';
    if ($due === 'lewat') $w[] = 'v.next_inspection < CURDATE()';
    if ($due === 'h5')    $w[] = 'DATEDIFF(v.next_inspection, CURDATE()) BETWEEN 0 AND 5';
    if ($due === 'h30')   $w[] = 'DATEDIFF(v.next_inspection, CURDATE()) BETWEEN 0 AND 30';
    $where = implode(' AND ', $w);
}
$rows = q('SELECT v.*, t.nama AS transportir, DATEDIFF(v.next_inspection, CURDATE()) sisa
           FROM vehicles v LEFT JOIN transporters t ON t.id = v.transporter_id
           WHERE ' . $where . ' ORDER BY v.no_polisi', $params);
if (!$rows) { http_response_code(404); exit('Data mobil tangki tidak ditemukan.'); }
?>
<!doctype html>
<html lang="id">
<head>
  <meta charset="utf-8">
  <title>Data Mobil Tangki — <?= e(APP_NAME) ?></title>
  <style>
    body { font-family: Arial, sans-serif; font-size: 10.5px; color: #000; margin: 18px; }
    h1 { font-size: 14px; text-align: center; margin: 0 0 2px; }
    h2 { font-size: 11px; text-align: center; margin: 0 0 14px; font-weight: normal; }
    table { width: 100%; border-collapse: collapse; }
    th, td { border: 1px solid #444; padding: 4px 5px; vertical-align: top; }
    th { background: #eee; font-size: 9.5px; }
    .c { text-align: center; }
    .mt { page-break-inside: avoid; margin-bottom: 16px; }
    .mt h3 { font-size: 12px; margin: 0 0 4px; }
    .fotos td { text-align: center; font-size: 9px; }
    .fotos img { max-width: 100%; max-height: 150px; }
    .muted { color: #555; }
    @media print { .noprint { display: none; } body { margin: 8mm; } }
  </style>
</head>
<body>
<div class="noprint" style="text-align:right;margin-bottom:8px">
  <button onclick="window.print()">Cetak / Simpan PDF</button>
  <a href="vehicle_data.php">Kembali</a>
</div>

<h1>PT PERTAMINA (Persero) — Integrated Terminal <?= e(APP_KOTA) ?></h1>
<h2>DATA MOBIL TANGKI (<?= count($rows) ?> unit)<br>Dicetak <?= date('d/m/Y H:i') ?> WIB</h2>

<table>
  <thead><tr>
    <th style="width:26px">No</th><th>No. Polisi / Chasis</th><th>Transportir</th><th>Kapasitas / Produk</th>
    <th>No. STNK &amp; masa berlaku</th><th>No. Keur &amp; masa berlaku</th><th>Tera Metrologi</th>
    <th>Jatuh Tempo Inspeksi</th><th>Status</th>
  </tr></thead>
  <tbody>
  <?php foreach ($rows as $i => $r): ?>
    <tr>
      <td class="c"><?= $i + 1 ?></td>
      <td><b><?= e($r['no_polisi']) ?></b><br><span class="muted"><?= e($r['no_chasis'] ?: '-') ?></span></td>
      <td><?= e($r['transportir'] ?: '-') ?><br><span class="muted"><?= e(str_replace('_', ' ', $r['jenis_tangki'])) ?></span></td>
      <td><?= e($r['kapasitas_kl']) ?> KL<br><span class="muted"><?= e($r['produk'] ?: '-') ?></span></td>
      <td><?= e($r['stnk_no'] ?: '-') ?><br><span class="muted">s.d. <?= tgl($r['stnk_berlaku']) ?></span></td>
      <td><?= e($r['keur_no'] ?: '-') ?><br><span class="muted">s.d. <?= tgl($r['keur_berlaku']) ?></span></td>
      <td>s.d. <?= tgl($r['tera_berlaku']) ?></td>
      <td><?= tgl($r['next_inspection']) ?><?= $r['sisa'] !== null ? '<br><span class="muted">' . ((int)$r['sisa'] < 0 ? 'lewat ' . abs((int)$r['sisa']) . ' hari' : (int)$r['sisa'] . ' hari lagi') . '</span>' : '' ?></td>
      <td class="c"><?= e(strtoupper($r['status'])) ?></td>
    </tr>
  <?php endforeach; ?>
  </tbody>
</table>

<?php foreach ($rows as $r): ?>
  <div class="mt" style="margin-top:18px">
    <h3>Lampiran Foto &amp; Dokumen — MT <?= e($r['no_polisi']) ?> (<?= e($r['transportir'] ?: '-') ?>)</h3>
    <table class="fotos">
      <tr>
        <?php foreach (['foto_depan' => 'Tampak Depan', 'foto_belakang' => 'Tampak Belakang', 'foto_kanan' => 'Tampak Kanan', 'foto_kiri' => 'Tampak Kiri'] as $k => $lbl): ?>
          <td width="25%">
            <?php if (!empty($r[$k]) && !is_pdf($r[$k])): ?>
              <img src="<?= e($r[$k]) ?>" alt="<?= $lbl ?> MT <?= e($r['no_polisi']) ?>"><br>
            <?php elseif (!empty($r[$k])): ?>
              <span class="muted">Dokumen PDF</span><br>
            <?php else: ?>
              <span class="muted">belum ada foto</span><br>
            <?php endif; ?>
            <b><?= $lbl ?></b>
          </td>
        <?php endforeach; ?>
      </tr>
      <tr>
        <?php foreach (['doc_stnk' => 'STNK', 'doc_keur' => 'Buku Keur', 'doc_tera' => 'Surat Tera'] as $k => $lbl): ?>
          <td>
            <?php if (!empty($r[$k]) && !is_pdf($r[$k])): ?>
              <img src="<?= e($r[$k]) ?>" alt="<?= $lbl ?> MT <?= e($r['no_polisi']) ?>"><br>
            <?php elseif (!empty($r[$k])): ?>
              <span class="muted">Dokumen PDF terlampir</span><br>
            <?php else: ?>
              <span class="muted">belum diunggah</span><br>
            <?php endif; ?>
            <b><?= $lbl ?></b>
          </td>
        <?php endforeach; ?>
        <td><b>Keterangan</b><br><span class="muted">Status <?= e(strtoupper($r['status'])) ?></span></td>
      </tr>
    </table>
  </div>
<?php endforeach; ?>
</body>
</html>

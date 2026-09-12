<?php
/** Versi cetak checklist (mirip form resmi, siap di-print / Save as PDF). */
require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/helpers.php';
require_login();

$id = (int)($_GET['id'] ?? 0);
$insp = q1('SELECT i.*, v.no_polisi, v.merk, v.tahun, v.kapasitas_kl, v.pabrikan_tangki, v.produk,
                   t.nama AS transportir, u.nama AS inspector, u.jabatan AS inspector_jabatan
            FROM inspections i
            JOIN vehicles v ON v.id = i.vehicle_id
            LEFT JOIN transporters t ON t.id = v.transporter_id
            LEFT JOIN users u ON u.id = i.inspector_id
            WHERE i.id = ?', [$id]);
if (!$insp) { http_response_code(404); exit('Data tidak ditemukan.'); }

$items = q('SELECT ci.*, r.hasil, r.keterangan
            FROM checklist_items ci
            JOIN inspection_results r ON r.item_id = ci.id AND r.inspection_id = ?
            WHERE ci.form_type = ? ORDER BY ci.sort_order', [$id, $insp['form_type']]);
$fotos = q('SELECT p.*, ci.item_no, ci.item_text FROM inspection_photos p
            LEFT JOIN checklist_items ci ON ci.id = p.item_id
            WHERE p.inspection_id = ? ORDER BY ci.sort_order, p.id', [$id]);

$apps = q('SELECT a.*, u.nama, u.jabatan FROM inspection_approvals a
           LEFT JOIN users u ON u.id = a.user_id WHERE a.inspection_id = ?
           ORDER BY a.level, FIELD(a.role,"hsse","distribusi","qq","itm")', [$id]);
$byRole = [];
foreach ($apps as $a) $byRole[$a['role']] = $a;

$titleForm = $insp['form_type'] === 'baru'
    ? 'FORM CHECKLIST PEMERIKSAAN MOBIL TANGKI BBM STANDAR VOLUME I DI TERMINAL'
    : 'FORMULIR CHECKLIST INSPEKSI 6 BULANAN — HASIL PEMERIKSAAN (KEUR) MOBIL TANGKI BBM';
?>
<!doctype html>
<html lang="id">
<head>
  <meta charset="utf-8">
  <title><?= e($insp['no_pemeriksaan']) ?></title>
  <style>
    body { font-family: Arial, sans-serif; font-size: 10.5px; color: #000; margin: 18px; }
    h1 { font-size: 14px; text-align: center; margin: 0 0 2px; }
    h2 { font-size: 11px; text-align: center; margin: 0 0 14px; font-weight: normal; }
    table { width: 100%; border-collapse: collapse; }
    .info td { padding: 2px 4px; }
    .items th, .items td { border: 1px solid #444; padding: 3px 5px; vertical-align: top; }
    .items th { background: #eee; font-size: 9.5px; }
    .sec td { background: #ddd; font-weight: bold; }
    .c { text-align: center; }
    .sign { margin-top: 26px; }
    .sign td { padding: 6px; height: 74px; vertical-align: top; font-size: 10px; text-align: center; }
    .sign-row { display:table; width:100%; margin-top:16px; }
    .sign-who, .sign-stamp { display:table-cell; vertical-align:middle; font-size:9.5px; text-align:left; }
    .sign-stamp { text-align:right; white-space:nowrap; width:1%; padding-left:6px; }
    .note { margin-top: 10px; font-size: 9.5px; }
    .stamp { display:inline-block; padding:5px 12px; border:3px double #0b7f4a; border-radius:8px;
      color:#0b7f4a; font-weight:bold; letter-spacing:1.4px; text-transform:uppercase;
      transform:rotate(-7deg); text-align:center; line-height:1.2; }
    .stamp .stamp-main { display:block; font-size:12px; }
    .stamp .stamp-sub { display:block; font-size:7.5px; letter-spacing:.4px; }
    .stamp-lg { padding:9px 20px; } .stamp-lg .stamp-main { font-size:20px; } .stamp-lg .stamp-sub { font-size:9px; }
    .stamp-reject { color:#96082c; border-color:#96082c; }
    .stamp-wait { color:#8a4b06; border-color:#8a4b06; border-style:dashed; transform:none; }
    @media print { .noprint { display: none; } body { margin: 8mm; } }
  </style>
</head>
<body>
<div class="noprint" style="text-align:right;margin-bottom:8px">
  <button onclick="window.print()">Cetak / Simpan PDF</button>
  <a href="inspection_view.php?id=<?= $id ?>">Kembali</a>
</div>

<h1>PT PERTAMINA (Persero) — Subholding Commercial &amp; Trading</h1>
<h2><?= e($titleForm) ?><br>Nomor : <?= e($insp['no_pemeriksaan']) ?></h2>

<table class="info">
  <tr>
    <td width="18%">Nama Transportir</td><td width="32%">: <?= e($insp['transportir'] ?: '-') ?></td>
    <td width="18%">Merk Mobil / Tahun</td><td>: <?= e($insp['merk'] . ' / ' . $insp['tahun']) ?></td>
  </tr>
  <tr>
    <td>Nomor Polisi</td><td>: <b><?= e($insp['no_polisi']) ?></b></td>
    <td>Produk / Kapasitas</td><td>: <?= e($insp['produk'] ?: 'BBM') ?> / <?= e($insp['kapasitas_kl']) ?> KL</td>
  </tr>
  <tr>
    <td>Pemeriksaan Terakhir</td><td>: <?= tgl($insp['tgl_terakhir']) ?></td>
    <td>Pabrikan</td><td>: <?= e($insp['pabrikan_tangki'] ?: '-') ?></td>
  </tr>
  <tr>
    <td>Pemeriksaan Tanggal</td><td>: <?= tgl($insp['tgl_pemeriksaan']) ?></td>
    <td>Nama / Umur AMT</td><td>: <?= e($insp['nama_amt'] ?: '-') ?> <?= $insp['umur_amt'] ? '/ ' . (int)$insp['umur_amt'] . ' th' : '' ?></td>
  </tr>
</table>

<br>
<table class="items">
  <thead>
    <tr><th width="30">NO</th><th>JENIS / URAIAN PEMERIKSAAN</th><th width="34">BAIK</th><th width="38">TIDAK</th>
      <th width="60">PELAKSANA</th><th width="70">PRIORITAS</th><th width="120">KETERANGAN</th></tr>
  </thead>
  <tbody>
  <?php $sec = null; foreach ($items as $it): ?>
    <?php if ($it['section'] !== $sec): $sec = $it['section']; ?>
      <tr class="sec"><td colspan="7"><?= e($sec) ?></td></tr>
    <?php endif; ?>
    <tr>
      <td class="c"><?= e($it['item_no']) ?></td>
      <td><?= e($it['item_text']) ?><?php if ($it['penjelasan']): ?><br><i><?= e($it['penjelasan']) ?></i><?php endif; ?></td>
      <td class="c"><?= $it['hasil'] === 'baik' ? '&#10004;' : '' ?></td>
      <td class="c"><?= $it['hasil'] === 'tidak' ? '&#10004;' : '' ?></td>
      <td class="c"><?= e($it['pelaksana'] ?: '-') ?></td>
      <td class="c"><?= e($it['prioritas']) ?><?= $it['batas_non_mandatory'] ? ' (' . e($it['batas_non_mandatory']) . ')' : '' ?></td>
      <td><?= e($it['keterangan']) ?></td>
    </tr>
  <?php endforeach; ?>
  </tbody>
</table>

<table class="items" style="margin-top:12px">
  <tr><th width="140">Nota Temuan Hasil Pemeriksaan MT</th><td><?= nl2br(e($insp['nota_temuan'] ?: '-')) ?></td>
    <th width="90">Status</th><td width="90" class="c"><b><?= e($insp['hasil_akhir'] ?: '-') ?></b></td></tr>
</table>

<?php if ($fotos): ?>
<table class="items" style="margin-top:12px">
  <tr><th colspan="3">Lampiran Foto Temuan</th></tr>
  <?php foreach (array_chunk($fotos, 3) as $rowFoto): ?>
  <tr>
    <?php foreach ($rowFoto as $f): ?>
      <td width="33%" class="c">
        <img src="<?= e($f['file_path']) ?>" alt="Foto temuan <?= e($f['item_text']) ?>" style="max-width:100%;max-height:150px">

        <div><?= e($f['item_no']) ?>. <?= e($f['item_text']) ?></div>
      </td>
    <?php endforeach; ?>
    <?php for ($k = count($rowFoto); $k < 3; $k++): ?><td></td><?php endfor; ?>
  </tr>
  <?php endforeach; ?>
</table>
<?php endif; ?>

<table class="sign items">
  <tr>
    <td>HSSE Inspector
      <div class="sign-row"><div class="sign-who"><b><?= e($insp['inspector'] ?: '') ?></b><br><?= e($insp['inspector_jabatan'] ?: 'Inspector HSSE') ?></div></div></td>
    <td>HSSE
      <div class="sign-row"><div class="sign-who"><b>Approval HSSE</b></div>
        <div class="sign-stamp"><?= isset($byRole['hsse']) ? stamp($byRole['hsse']['status'], '', 'sm', $byRole['hsse']['acted_at'] ?? null) : '' ?></div></div></td>
    <td>Distribusi
      <div class="sign-row"><div class="sign-who"><b>Approval Distribusi</b></div>
        <div class="sign-stamp"><?= isset($byRole['distribusi']) ? stamp($byRole['distribusi']['status'], '', 'sm', $byRole['distribusi']['acted_at'] ?? null) : '' ?></div></div></td>
    <td>QQ
      <div class="sign-row"><div class="sign-who"><b>Approval QQ</b></div>
        <div class="sign-stamp"><?= isset($byRole['qq']) ? stamp($byRole['qq']['status'], '', 'sm', $byRole['qq']['acted_at'] ?? null) : '' ?></div></div></td>
  </tr>
  <tr>
    <td colspan="4" class="c">
      <?php if ($insp['form_type'] !== 'baru'): ?>
        <?= e(APP_KOTA) ?>, <?= tgl($insp['finalized_at'] ? substr($insp['finalized_at'], 0, 10) : $insp['tgl_pemeriksaan']) ?><br>
        <span>Approval ITM tidak diperlukan untuk Inspeksi 6 Bulanan.</span><br><br>
        <?= $insp['status'] === 'disetujui' ? stamp('disetujui', 'HSSE · Distribusi · QQ', 'lg', $insp['finalized_at'] ?: null) : stamp($insp['status'] === 'ditolak' ? 'ditolak' : 'menunggu', 'Approval Belum Lengkap') ?>
      <?php else: ?>
      <?= e(APP_KOTA) ?>, <?= tgl($insp['finalized_at'] ? substr($insp['finalized_at'], 0, 10) : $insp['tgl_pemeriksaan']) ?><br>
      Mengetahui,<br>Integrated Terminal Manager <?= e(APP_KOTA) ?><br><br><br>
      <b><?= e($byRole['itm']['nama'] ?? '') ?></b><br>
      <?= isset($byRole['itm']) ? stamp($byRole['itm']['status'], 'Integrated Terminal Manager', 'lg', $byRole['itm']['acted_at'] ?? null) : stamp('menunggu', 'Menunggu Approval ITM') ?>
      <?php endif; ?>
    </td>
  </tr>
</table>

<div class="note">
  <b>Catatan :</b><br>
  MANDATORY : Mobil tangki tidak akan dikeluarkan kartu ijin masuk sampai dengan perbaikan selesai dilakukan.<br>
  NON MANDATORY : Mobil tangki tetap dilakukan pemeriksaan, kartu ijin masuk dapat dikeluarkan dengan batas waktu perbaikan
  (bila melebihi batas waktu, kartu ijin masuk dicabut).
</div>
</body>
</html>

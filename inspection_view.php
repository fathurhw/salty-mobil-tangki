<?php
/** Detail checklist + panel approval berjenjang. */
require_once __DIR__ . '/includes/layout.php';
require_login();
csrf_check();

$id = (int)($_GET['id'] ?? 0);
$insp = q1('SELECT i.*, v.no_polisi, v.merk, v.tahun, v.kapasitas_kl, v.pabrikan_tangki, v.produk,
                   t.nama AS transportir, u.nama AS inspector
            FROM inspections i
            JOIN vehicles v ON v.id = i.vehicle_id
            LEFT JOIN transporters t ON t.id = v.transporter_id
            LEFT JOIN users u ON u.id = i.inspector_id
            WHERE i.id = ?', [$id]);
if (!$insp) { http_response_code(404); exit('Checklist tidak ditemukan.'); }

/* ---- aksi approve / reject ---- */
if ($_SERVER['REQUEST_METHOD'] === 'POST' && ($_POST['act'] ?? '') === 'approve') {
    [$ok, $msg] = can_approve($insp, role());
    if (!$ok) {
        flash($msg, 'err');
    } else {
        $keputusan = $_POST['keputusan'] === 'tolak' ? 'ditolak' : 'disetujui';
        ex('INSERT INTO inspection_approvals (inspection_id, role, level, status, user_id, catatan, acted_at)
            VALUES (?,?,?,?,?,?,NOW())
            ON DUPLICATE KEY UPDATE status=VALUES(status), user_id=VALUES(user_id),
                                    catatan=VALUES(catatan), acted_at=NOW()',
            [$id, role(), role() === 'itm' ? 2 : 1, $keputusan, (int)user()['id'], trim($_POST['catatan'] ?? '')]);
        refresh_inspection_status($id);
        flash($keputusan === 'disetujui' ? 'Checklist Anda setujui.' : 'Checklist ditolak.');
    }
    header('Location: inspection_view.php?id=' . $id);
    exit;
}

$items = q('SELECT ci.*, r.hasil, r.keterangan
            FROM checklist_items ci
            JOIN inspection_results r ON r.item_id = ci.id AND r.inspection_id = ?
            WHERE ci.form_type = ?
            ORDER BY ci.sort_order', [$id, $insp['form_type']]);

$fotoByItem = [];
foreach (q('SELECT * FROM inspection_photos WHERE inspection_id=? ORDER BY id', [$id]) as $p) {
    $fotoByItem[(int)$p['item_id']][] = $p;
}


$apps = q('SELECT a.*, u.nama, u.jabatan FROM inspection_approvals a
           LEFT JOIN users u ON u.id = a.user_id
           WHERE a.inspection_id = ?
           ORDER BY a.level, FIELD(a.role,"hsse","distribusi","qq","itm")', [$id]);

$stat = ['baik' => 0, 'tidak' => 0, 'na' => 0];
foreach ($items as $it) $stat[$it['hasil']]++;
$mandatoryTidak = count(array_filter($items, fn($i) => $i['hasil'] === 'tidak' && $i['prioritas'] === 'MANDATORY'));

[$canApprove, $whyNot] = can_approve($insp, role());

layout_start('Checklist ' . $insp['no_polisi']);
?>
<div class="card">
  <div class="row" style="align-items:flex-start">
    <div>
      <h3 style="margin-bottom:4px"><?= e(form_label($insp['form_type'])) ?></h3>
      <div class="muted"><?= e($insp['no_pemeriksaan']) ?></div>
    </div>
    <div style="flex:0 0 auto;text-align:right">
      <?= status_badge($insp['status']) ?>
      <?php if (in_array($insp['status'], ['disetujui','ditolak'], true)): ?>
        <div class="stamp-final-wrap"><?= stamp($insp['status'], $insp['status'] === 'disetujui' ? (needs_itm($insp['form_type']) ? 'Disetujui ITM' : 'Approval Lengkap') : 'Checklist Ditolak', 'lg', $insp['finalized_at'] ?: null) ?></div>
      <?php endif; ?>
      <?php if ($insp['hasil_akhir']): ?>
        <span class="badge badge-<?= $insp['hasil_akhir'] === 'OK' ? 'green' : 'red' ?>">Hasil: <?= e($insp['hasil_akhir']) ?></span>
      <?php endif; ?>
      <br><a class="btn btn-sm btn-outline" style="margin-top:8px" href="print.php?id=<?= $id ?>" target="_blank">Cetak / PDF</a>
    </div>
  </div>
  <hr style="border:0;border-top:1px solid var(--line)">
  <div class="grid grid-3">
    <div><label>No. Polisi</label><b><?= e($insp['no_polisi']) ?></b></div>
    <div><label>Transportir</label><?= e($insp['transportir'] ?: '-') ?></div>
    <div><label>Merk / Tahun</label><?= e($insp['merk'] . ' / ' . $insp['tahun']) ?></div>
    <div><label>Kapasitas</label><?= e($insp['kapasitas_kl']) ?> KL</div>
    <div><label>Pabrikan</label><?= e($insp['pabrikan_tangki'] ?: '-') ?></div>
    <div><label>Tanggal Pemeriksaan</label><?= tgl($insp['tgl_pemeriksaan']) ?></div>
    <div><label>Pemeriksaan Terakhir</label><?= tgl($insp['tgl_terakhir']) ?></div>
    <div><label>Inspector</label><?= e($insp['inspector'] ?: '-') ?></div>
    <div><label>AMT</label><?= e($insp['nama_amt'] ?: '-') ?><?= $insp['umur_amt'] ? ' (' . (int)$insp['umur_amt'] . ' th)' : '' ?></div>
  </div>
</div>

<div class="grid grid-5">
  <div class="stat"><div class="l">Total Item</div><div class="n"><?= count($items) ?></div></div>
  <div class="stat"><div class="l">Baik</div><div class="n" style="color:#075c36"><?= $stat['baik'] ?></div></div>
  <div class="stat"><div class="l">Tidak</div><div class="n" style="color:#96082c"><?= $stat['tidak'] ?></div></div>
  <div class="stat"><div class="l">N/A</div><div class="n"><?= $stat['na'] ?></div></div>
  <div class="stat <?= $mandatoryTidak ? 'warn' : '' ?>"><div class="l">Mandatory Tidak Baik</div><div class="n"><?= $mandatoryTidak ?></div></div>
</div>

<div class="card">
  <h3>Approval Berjenjang</h3>
  <p class="muted small">Tahap 1 (paralel): HSSE, Distribusi, QQ Distribusi<?= needs_itm($insp['form_type']) ? ' &rarr; Tahap 2 (final): ITM / Manager.' : '. Inspeksi 6 Bulanan selesai tanpa approval ITM.' ?></p>
  <?php if (!$apps): ?>
    <p class="muted">Checklist belum diajukan oleh inspector.</p>
  <?php else: foreach ($apps as $a): ?>
    <div class="approval-line">
      <span class="badge badge-<?= $a['level'] == 2 ? 'blue' : 'gray' ?>">Tahap <?= (int)$a['level'] ?></span>
      <div class="who">
        <b><?= e($a['role'] === 'itm' ? 'Integrated Terminal Manager' : ($a['role'] === 'hsse' ? 'Approval HSSE' : ($a['role'] === 'qq' ? 'Approval QQ' : 'Approval Distribusi'))) ?></b>
        <div class="sign-jabatan muted small"><?= $a['acted_at'] ? date('d/m/Y H:i', strtotime($a['acted_at'])) . ' WIB' : 'Menunggu approval' ?></div>
        <?php if ($a['catatan']): ?><span class="muted small">Catatan: <?= e($a['catatan']) ?></span><?php endif; ?>
      </div>
      <span class="sign-stamp-inline"><?= stamp($a['status'], '', 'sm', $a['acted_at'] ?: null) ?></span>
    </div>
  <?php endforeach; endif; ?>

  <?php if (has_role(['hsse', 'distribusi', 'qq', 'itm'])): ?>
    <hr style="border:0;border-top:1px solid var(--line);margin:14px 0">
    <?php if ($canApprove): ?>
      <form method="post">
        <?= csrf_field() ?>
        <input type="hidden" name="act" value="approve">
        <div class="field"><label>Catatan (opsional)</label><input name="catatan"></div>
        <button class="btn" name="keputusan" value="setuju">Setujui sebagai <?= e(strtoupper(role())) ?></button>
        <button class="btn btn-danger" name="keputusan" value="tolak" onclick="return confirm('Tolak checklist ini?')">Tolak</button>
      </form>
    <?php else: ?>
      <p class="muted" style="margin:0"><?= e($whyNot) ?></p>
    <?php endif; ?>
  <?php endif; ?>
</div>

<?php if ($insp['nota_temuan']): ?>
<div class="card">
  <h3>Nota Temuan</h3>
  <p style="white-space:pre-wrap;margin:0"><?= e($insp['nota_temuan']) ?></p>
</div>
<?php endif; ?>

<div class="card">
  <h3>Rincian Item Pemeriksaan</h3>
  <div class="table-wrap">
    <table>
      <thead><tr><th style="width:40px">No</th><th>Uraian</th><th>Prioritas</th><th>Hasil</th><th>Keterangan</th><th style="width:110px">Foto Temuan</th></tr></thead>
      <tbody>
      <?php $sec = null; foreach ($items as $it): ?>
        <?php if ($it['section'] !== $sec): $sec = $it['section']; ?>
          <tr class="section-row"><td colspan="6"><?= e($sec) ?></td></tr>
        <?php endif; ?>
        <tr>
          <td><?= e($it['item_no']) ?></td>
          <td><?= e($it['item_text']) ?><?php if ($it['penjelasan']): ?><br><span class="muted small"><?= e($it['penjelasan']) ?></span><?php endif; ?></td>
          <td><span class="badge badge-<?= $it['prioritas'] === 'MANDATORY' ? 'red' : 'gray' ?>"><?= $it['prioritas'] === 'MANDATORY' ? 'M' : 'NM' ?></span></td>
          <td><span class="badge badge-<?= ['baik' => 'green', 'tidak' => 'red', 'na' => 'gray'][$it['hasil']] ?>"><?= strtoupper($it['hasil'] === 'na' ? 'N/A' : $it['hasil']) ?></span></td>
          <td><?= e($it['keterangan'] ?: '-') ?></td>
          <td><?php $fs = $fotoByItem[(int)$it['id']] ?? []; if ($fs): foreach ($fs as $ph): ?>
            <a href="<?= e($ph['file_path']) ?>" target="_blank"><img src="<?= e($ph['file_path']) ?>" alt="Foto temuan <?= e($it['item_text']) ?>" style="width:70px;height:54px;object-fit:cover;border-radius:6px;border:1px solid var(--line);margin:0 3px 3px 0"></a>
          <?php endforeach; else: ?><span class="muted">-</span><?php endif; ?></td>

        </tr>
      <?php endforeach; ?>
      </tbody>
    </table>
  </div>
</div>
<?php layout_end(); ?>

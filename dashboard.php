<?php
require_once __DIR__ . '/includes/layout.php';
require_login();

$s = dashboard_stats();

$due = q('SELECT * FROM v_due_inspections WHERE sisa_hari <= 30 ORDER BY sisa_hari ASC LIMIT 12');

$jadwal = q('SELECT s.*, v.no_polisi, u.nama AS inspector
             FROM schedules s
             JOIN vehicles v ON v.id = s.vehicle_id
             LEFT JOIN users u ON u.id = s.inspector_id
             WHERE s.status IN ("dijadwalkan","proses")
             ORDER BY s.tanggal ASC LIMIT 10');

$myPending = [];
if (has_role(['hsse', 'distribusi', 'qq', 'itm'])) {
    $myPending = q('SELECT i.*, v.no_polisi
                    FROM inspection_approvals a
                    JOIN inspections i ON i.id = a.inspection_id
                    JOIN vehicles v ON v.id = i.vehicle_id
                    WHERE a.role = ? AND a.status = "menunggu"
                      AND i.status IN ("diajukan","approve_sebagian")
                    ORDER BY i.submitted_at ASC LIMIT 10', [role()]);
}

// Notifikasi inspeksi 6 bulanan yang mendekati jatuh tempo (H-5 / H-3) & terlewat
$notif = q('SELECT * FROM v_due_inspections WHERE sisa_hari <= 5 ORDER BY sisa_hari ASC');

layout_start('Dashboard');
?>
<?php if ($notif): ?>
<div class="card" style="border-left:5px solid var(--accent)">
  <h3 style="margin-top:0">🔔 Notifikasi Inspeksi 6 Bulanan</h3>
  <?php foreach ($notif as $n):
      $sisa = (int)$n['sisa_hari'];
      $cls = $sisa <= 3 ? 'alert-err' : 'alert-info';
      if ($sisa < 0)       $txt = 'TERLEWAT ' . abs($sisa) . ' hari — segera jadwalkan inspeksi ulang.';
      elseif ($sisa === 0) $txt = 'Jatuh tempo HARI INI.';
      else              $txt = 'H-' . $sisa . ' menuju jatuh tempo inspeksi 6 bulanan.';
  ?>
    <div class="alert <?= $cls ?>" style="display:flex;gap:10px;align-items:center;justify-content:space-between">
      <div>
        <b><?= e($n['no_polisi']) ?></b> — <?= e($txt) ?>
        <span class="muted small">(jatuh tempo <?= tgl($n['next_inspection']) ?><?= $n['transportir'] ? ' · ' . e($n['transportir']) : '' ?>)</span>
      </div>
      <?php if (role() === 'admin_hsse'): ?>
        <a class="btn btn-sm" href="schedules.php?new=1&vehicle=<?= (int)$n['id'] ?>&form=6bulanan&tanggal=<?= e($n['next_inspection']) ?>">Buat Jadwal</a>
      <?php endif; ?>
    </div>
  <?php endforeach; ?>
</div>
<?php endif; ?>
<div class="grid grid-5">
  <div class="stat"><div class="l">MT Aktif</div><div class="n"><?= $s['mt'] ?></div></div>
  <div class="stat"><div class="l">Jadwal Aktif</div><div class="n"><?= $s['jadwal'] ?></div></div>
  <div class="stat"><div class="l">Menunggu Approval</div><div class="n"><?= $s['menunggu'] ?></div></div>
  <div class="stat"><div class="l">Checklist Final</div><div class="n"><?= $s['selesai'] ?></div></div>
  <div class="stat warn"><div class="l">Jatuh Tempo &le; 5 Hari</div><div class="n"><?= $s['due'] ?></div></div>
</div>

<?php if ($myPending): ?>
<div class="card">
  <h3>Menunggu approval Anda (<?= count($myPending) ?>)</h3>
  <div class="table-wrap">
    <table>
      <thead><tr><th>No. Pemeriksaan</th><th>No. Polisi</th><th>Jenis</th><th>Tanggal</th><th>Status</th><th></th></tr></thead>
      <tbody>
      <?php foreach ($myPending as $r): ?>
        <tr>
          <td><?= e($r['no_pemeriksaan']) ?></td>
          <td><b><?= e($r['no_polisi']) ?></b></td>
          <td><?= e(form_label($r['form_type'])) ?></td>
          <td><?= tgl($r['tgl_pemeriksaan']) ?></td>
          <td><?= status_badge($r['status']) ?></td>
          <td><a class="btn btn-sm btn-outline" href="inspection_view.php?id=<?= (int)$r['id'] ?>">Periksa</a></td>
        </tr>
      <?php endforeach; ?>
      </tbody>
    </table>
  </div>
</div>
<?php endif; ?>

<div class="grid grid-2">
  <div class="card">
    <h3>MT mendekati jatuh tempo inspeksi 6 bulanan</h3>
    <?php if (!$due): ?><p class="muted">Tidak ada MT yang jatuh tempo dalam 30 hari.</p><?php else: ?>
    <div class="table-wrap">
      <table>
        <thead><tr><th>No. Polisi</th><th>Transportir</th><th>Inspeksi Terakhir</th><th>Jatuh Tempo</th><th>Sisa</th></tr></thead>
        <tbody>
        <?php foreach ($due as $d): ?>
          <tr>
            <td><b><?= e($d['no_polisi']) ?></b></td>
            <td><?= e($d['transportir'] ?: '-') ?></td>
            <td><?= tgl($d['last_inspection']) ?></td>
            <td><?= tgl($d['next_inspection']) ?></td>
            <td><?= due_badge((int)$d['sisa_hari']) ?></td>
          </tr>
        <?php endforeach; ?>
        </tbody>
      </table>
    </div>
    <?php endif; ?>
    <p style="margin-bottom:0"><a href="due.php">Lihat semua jatuh tempo &rarr;</a></p>
  </div>

  <div class="card">
    <h3>Jadwal pemeriksaan terdekat</h3>
    <?php if (!$jadwal): ?><p class="muted">Belum ada jadwal aktif.</p><?php else: ?>
    <div class="table-wrap">
      <table>
        <thead><tr><th>Tanggal</th><th>No. Polisi</th><th>Jenis</th><th>Inspector</th><th>Status</th></tr></thead>
        <tbody>
        <?php foreach ($jadwal as $j): ?>
          <tr>
            <td><?= tgl($j['tanggal']) ?><?= $j['jam'] ? ' · ' . substr($j['jam'], 0, 5) : '' ?></td>
            <td><b><?= e($j['no_polisi']) ?></b></td>
            <td><?= e(form_label($j['form_type'])) ?></td>
            <td><?= e($j['inspector'] ?: '-') ?></td>
            <td><span class="badge badge-<?= $j['status'] === 'proses' ? 'blue' : 'gray' ?>"><?= e(ucfirst($j['status'])) ?></span></td>
          </tr>
        <?php endforeach; ?>
        </tbody>
      </table>
    </div>
    <?php endif; ?>
    <p style="margin-bottom:0"><a href="schedules.php">Lihat semua jadwal &rarr;</a></p>
  </div>
</div>
<?php layout_end(); ?>

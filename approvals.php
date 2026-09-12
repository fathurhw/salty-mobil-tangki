<?php
/** Daftar checklist yang menunggu keputusan approver (HSSE / Distribusi / QQ / ITM). */
require_once __DIR__ . '/includes/layout.php';
require_role(['hsse', 'distribusi', 'qq', 'itm']);

$tab = $_GET['tab'] ?? 'menunggu';

if ($tab === 'riwayat') {
    $rows = q('SELECT i.*, v.no_polisi, t.nama AS transportir, a.status AS my_status, a.acted_at, a.catatan
               FROM inspection_approvals a
               JOIN inspections i ON i.id = a.inspection_id
               JOIN vehicles v ON v.id = i.vehicle_id
               LEFT JOIN transporters t ON t.id = v.transporter_id
               WHERE a.role = ? AND a.status <> "menunggu"
               ORDER BY a.acted_at DESC', [role()]);
} else {
    $rows = q('SELECT i.*, v.no_polisi, t.nama AS transportir, a.status AS my_status, a.acted_at, a.catatan
               FROM inspection_approvals a
               JOIN inspections i ON i.id = a.inspection_id
               JOIN vehicles v ON v.id = i.vehicle_id
               LEFT JOIN transporters t ON t.id = v.transporter_id
               WHERE a.role = ? AND a.status = "menunggu"
                 AND i.status IN ("diajukan","approve_sebagian")
                 AND (a.role <> "itm" OR i.form_type = "baru")
               ORDER BY i.submitted_at ASC', [role()]);
}

layout_start('Approval Checklist — ' . (ROLE_LABELS[role()] ?? ''));
?>
<div class="card">
  <a class="btn btn-sm <?= $tab === 'menunggu' ? '' : 'btn-outline' ?>" href="?tab=menunggu">Menunggu Keputusan</a>
  <a class="btn btn-sm <?= $tab === 'riwayat' ? '' : 'btn-outline' ?>" href="?tab=riwayat">Riwayat Keputusan</a>
  <?php if (role() === 'itm'): ?>
    <p class="muted small" style="margin-bottom:0">Sebagai ITM, Anda hanya menyetujui checklist <b>MT Baru</b>, setelah HSSE, Distribusi, dan QQ Distribusi menyetujui. Inspeksi 6 Bulanan selesai tanpa approval ITM.</p>
  <?php endif; ?>
</div>

<div class="card">
  <div class="table-wrap">
    <table>
      <thead><tr><th>No. Pemeriksaan</th><th>No. Polisi</th><th>Jenis</th><th>Tanggal</th>
        <th>Progress</th><th>Status Checklist</th><th><?= $tab === 'riwayat' ? 'Keputusan Anda' : 'Diajukan' ?></th><th></th></tr></thead>
      <tbody>
      <?php if (!$rows): ?><tr><td colspan="8" class="muted">Tidak ada data.</td></tr><?php endif; ?>
      <?php foreach ($rows as $r): ?>
        <?php
          $done = (int)(q1('SELECT COUNT(*) n FROM inspection_approvals WHERE inspection_id=? AND status="disetujui"', [(int)$r['id']])['n'] ?? 0);
          $l1 = (int)(q1('SELECT COUNT(*) n FROM inspection_approvals WHERE inspection_id=? AND level=1 AND status="disetujui"', [(int)$r['id']])['n'] ?? 0);
        ?>
        <tr>
          <td><?= e($r['no_pemeriksaan']) ?></td>
          <td><b><?= e($r['no_polisi']) ?></b><br><span class="muted small"><?= e($r['transportir'] ?: '') ?></span></td>
          <td><?= e(form_label($r['form_type'])) ?></td>
          <td><?= tgl($r['tgl_pemeriksaan']) ?></td>
          <?php $total = needs_itm($r['form_type']) ? 4 : 3; ?>
          <td>Tahap 1: <?= $l1 ?>/3<br><span class="muted small">Total <?= $done ?>/<?= $total ?></span></td>
          <td><?= status_badge($r['status']) ?></td>
          <td>
            <?php if ($tab === 'riwayat'): ?>
              <span class="badge badge-<?= $r['my_status'] === 'disetujui' ? 'green' : 'red' ?>"><?= e(ucfirst($r['my_status'])) ?></span>
              <br><span class="muted small"><?= $r['acted_at'] ? date('d/m/Y H:i', strtotime($r['acted_at'])) : '' ?></span>
            <?php else: ?>
              <?= $r['submitted_at'] ? date('d/m/Y H:i', strtotime($r['submitted_at'])) : '-' ?>
            <?php endif; ?>
          </td>
          <td><a class="btn btn-sm" href="inspection_view.php?id=<?= (int)$r['id'] ?>">Periksa</a></td>
        </tr>
      <?php endforeach; ?>
      </tbody>
    </table>
  </div>
</div>
<?php layout_end(); ?>

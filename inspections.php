<?php
require_once __DIR__ . '/includes/layout.php';
require_login();

$mine = role() === 'inspector_hsse';
$params = [];
$sql = 'SELECT i.*, v.no_polisi, t.nama AS transportir, u.nama AS inspector
        FROM inspections i
        JOIN vehicles v ON v.id = i.vehicle_id
        LEFT JOIN transporters t ON t.id = v.transporter_id
        LEFT JOIN users u ON u.id = i.inspector_id
        WHERE 1=1';
if ($mine) { $sql .= ' AND i.inspector_id = ?'; $params[] = (int)user()['id']; }
if (!empty($_GET['status'])) { $sql .= ' AND i.status = ?'; $params[] = $_GET['status']; }
if (!empty($_GET['type']))   { $sql .= ' AND i.form_type = ?'; $params[] = $_GET['type']; }
$sql .= ' ORDER BY i.tgl_pemeriksaan DESC, i.id DESC';
$rows = q($sql, $params);

layout_start($mine ? 'Checklist Saya' : 'Data Checklist');
?>
<div class="card">
  <a class="btn btn-sm <?= empty($_GET['status']) && empty($_GET['type']) ? '' : 'btn-outline' ?>" href="?">Semua</a>
  <a class="btn btn-sm btn-outline" href="?type=baru">MT Baru</a>
  <a class="btn btn-sm btn-outline" href="?type=6bulanan">6 Bulanan</a>
  <a class="btn btn-sm btn-outline" href="?status=draft">Draft</a>
  <a class="btn btn-sm btn-outline" href="?status=diajukan">Menunggu Approval</a>
  <a class="btn btn-sm btn-outline" href="?status=disetujui">Disetujui ITM</a>
  <?php if ($mine): ?>
    <a class="btn btn-sm" style="float:right" href="inspection_form.php">+ Checklist Baru</a>
  <?php endif; ?>
</div>

<div class="card">
  <div class="table-wrap">
    <table>
      <thead><tr><th>No. Pemeriksaan</th><th>No. Polisi</th><th>Jenis</th><th>Tanggal</th><th>Inspector</th>
        <th>Progress Approval</th><th>Hasil</th><th>Status</th><th></th></tr></thead>
      <tbody>
      <?php if (!$rows): ?><tr><td colspan="9" class="muted">Belum ada data checklist.</td></tr><?php endif; ?>
      <?php foreach ($rows as $r): ?>
        <?php
          $apps = q('SELECT role, status FROM inspection_approvals WHERE inspection_id=?', [(int)$r['id']]);
          $done = count(array_filter($apps, fn($a) => $a['status'] === 'disetujui'));
        ?>
        <tr>
          <td><?= e($r['no_pemeriksaan']) ?></td>
          <td><b><?= e($r['no_polisi']) ?></b><br><span class="muted small"><?= e($r['transportir'] ?: '') ?></span></td>
          <td><?= e(form_label($r['form_type'])) ?></td>
          <td><?= tgl($r['tgl_pemeriksaan']) ?></td>
          <td><?= e($r['inspector'] ?: '-') ?></td>
          <td><?= $r['status'] === 'draft' ? '<span class="muted small">belum diajukan</span>' : $done . ' / 4 approver' ?></td>
          <td><?= $r['hasil_akhir'] ? '<span class="badge badge-' . ($r['hasil_akhir'] === 'OK' ? 'green' : 'red') . '">' . e($r['hasil_akhir']) . '</span>' : '-' ?></td>
          <td><?= status_badge($r['status']) ?></td>
          <td style="white-space:nowrap">
            <a class="btn btn-sm btn-outline" href="inspection_view.php?id=<?= (int)$r['id'] ?>">Detail</a>
            <?php if ($mine && in_array($r['status'], ['draft', 'ditolak'], true)): ?>
              <a class="btn btn-sm" href="inspection_form.php?id=<?= (int)$r['id'] ?>">Isi / Ubah</a>
            <?php endif; ?>
          </td>
        </tr>
      <?php endforeach; ?>
      </tbody>
    </table>
  </div>
</div>
<?php layout_end(); ?>

<?php
require_once __DIR__ . '/includes/layout.php';
require_login();

$filter = $_GET['f'] ?? 'all';
$sql = 'SELECT * FROM v_due_inspections';
if ($filter === '3')      $sql .= ' WHERE sisa_hari <= 3';
elseif ($filter === '5')  $sql .= ' WHERE sisa_hari BETWEEN 0 AND 5';
elseif ($filter === 'late') $sql .= ' WHERE sisa_hari < 0';
elseif ($filter === 'stnk') $sql .= ' WHERE sisa_stnk IS NOT NULL AND sisa_stnk <= 30';
elseif ($filter === 'keur') $sql .= ' WHERE sisa_keur IS NOT NULL AND sisa_keur <= 30';
elseif ($filter === 'tera') $sql .= ' WHERE sisa_tera IS NOT NULL AND sisa_tera <= 30';
$sql .= ' ORDER BY sisa_hari ASC';
$rows = q($sql);

/** Tampilkan tanggal + badge sisa hari untuk satu dokumen. */
function due_cell(?string $tanggal, $sisa): string
{
    if (!$tanggal) return '<span class="muted small">—</span>';
    return tgl($tanggal) . '<br>' . due_badge((int)$sisa);
}

layout_start('Jatuh Tempo Inspeksi & Dokumen MT');
?>
<div class="card">
  <div class="row" style="align-items:center">
    <div>
      <p class="muted" style="margin:0">
        Jatuh tempo dihitung dari yang <b>paling cepat</b> antara inspeksi 6 bulanan
        (setiap <?= INSPECTION_INTERVAL_MONTHS ?> bulan) dan masa berlaku
        <b>STNK</b>, <b>Buku KEUR</b>, serta <b>Surat Tera</b>.
        Peringatan otomatis pada sisa <b>5 hari</b> dan <b>3 hari</b>.
      </p>
    </div>
    <div style="flex:0 0 auto">
      <a class="btn btn-sm <?= $filter === 'all' ? '' : 'btn-outline' ?>" href="?f=all">Semua</a>
      <a class="btn btn-sm <?= $filter === '5' ? '' : 'btn-outline' ?>" href="?f=5">&le; 5 hari</a>
      <a class="btn btn-sm <?= $filter === '3' ? '' : 'btn-outline' ?>" href="?f=3">&le; 3 hari</a>
      <a class="btn btn-sm <?= $filter === 'late' ? 'btn-danger' : 'btn-outline' ?>" href="?f=late">Terlewat</a>
      <a class="btn btn-sm <?= $filter === 'stnk' ? '' : 'btn-outline' ?>" href="?f=stnk">STNK &le; 30 hari</a>
      <a class="btn btn-sm <?= $filter === 'keur' ? '' : 'btn-outline' ?>" href="?f=keur">KEUR &le; 30 hari</a>
      <a class="btn btn-sm <?= $filter === 'tera' ? '' : 'btn-outline' ?>" href="?f=tera">Tera &le; 30 hari</a>
    </div>
  </div>
</div>

<div class="card">
  <div class="table-wrap">
    <table>
      <thead><tr>
        <th>No. Polisi</th><th>Transportir</th>
        <th>Inspeksi Terakhir</th><th>Jatuh Tempo Inspeksi</th>
        <th>STNK</th><th>Buku KEUR</th><th>Surat Tera</th>
        <th>Paling Cepat</th><th>Sisa Hari</th><th>Tindakan</th>
      </tr></thead>
      <tbody>
      <?php if (!$rows): ?>
        <tr><td colspan="10" class="muted">Tidak ada data.</td></tr>
      <?php endif; ?>
      <?php foreach ($rows as $r): ?>
        <tr>
          <td><b><?= e($r['no_polisi']) ?></b></td>
          <td><?= e($r['transportir'] ?: '-') ?></td>
          <td><?= tgl($r['last_inspection']) ?></td>
          <td><?= due_cell($r['next_inspection'], $r['sisa_inspeksi']) ?></td>
          <td>
            <?php if ($r['stnk_no']): ?><div class="muted small"><?= e($r['stnk_no']) ?></div><?php endif; ?>
            <?= due_cell($r['stnk_berlaku'], $r['sisa_stnk']) ?>
          </td>
          <td>
            <?php if ($r['keur_no']): ?><div class="muted small"><?= e($r['keur_no']) ?></div><?php endif; ?>
            <?= due_cell($r['keur_berlaku'], $r['sisa_keur']) ?>
          </td>
          <td><?= due_cell($r['tera_berlaku'], $r['sisa_tera']) ?></td>
          <td><?= e($r['sumber_jatuh_tempo']) ?></td>
          <td><?= due_badge((int)$r['sisa_hari']) ?></td>
          <td>
            <a class="btn btn-sm btn-outline" href="vehicle_data.php?q=<?= urlencode($r['no_polisi']) ?>">Data MT</a>
            <?php if (role() === 'admin_hsse' && $r['next_inspection']): ?>
              <a class="btn btn-sm btn-outline"
                 href="schedules.php?new=1&vehicle=<?= (int)$r['id'] ?>&form=6bulanan&tanggal=<?= e($r['next_inspection']) ?>">
                 Buat Jadwal</a>
            <?php endif; ?>
          </td>
        </tr>
      <?php endforeach; ?>
      </tbody>
    </table>
  </div>
</div>
<?php layout_end(); ?>

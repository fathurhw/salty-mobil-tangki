<?php
require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/helpers.php';

/** Ikon SVG inline (mobil tangki, jadwal, user, dll). */
function icon(string $name, string $cls = 'icon'): string
{
    $p = [
        'grid'      => '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
        // mobil tangki
        'truck'     => '<path d="M2 8h11a3 3 0 0 1 3 3v5H2z"/><path d="M16 11h3l3 4v1h-6z"/><circle cx="7" cy="18.5" r="1.8"/><circle cx="18" cy="18.5" r="1.8"/><path d="M5 11h8"/>',
        // jadwal
        'calendar'  => '<rect x="3" y="5" width="18" height="16" rx="2.5"/><path d="M3 10h18M8 3v4M16 3v4"/><path d="M8 14h3v3H8z"/>',
        // orang / user
        'user'      => '<circle cx="12" cy="8" r="3.5"/><path d="M4.5 20c0-3.6 3.4-5.5 7.5-5.5s7.5 1.9 7.5 5.5"/>',
        'users'     => '<circle cx="9" cy="8" r="3.2"/><path d="M2.5 20c0-3.4 3-5.2 6.5-5.2s6.5 1.8 6.5 5.2"/><path d="M16.5 5.2a3.2 3.2 0 0 1 0 6.1M18 20c0-2.4-.8-4-2-5"/>',
        'clipboard' => '<rect x="5" y="4" width="14" height="17" rx="2.5"/><path d="M9 4V2.8h6V4"/><path d="M9 10h6M9 14h6M9 18h3"/>',
        'check'     => '<circle cx="12" cy="12" r="9"/><path d="M8 12.5l2.7 2.7L16 9.8"/>',
        'clock'     => '<circle cx="12" cy="12" r="9"/><path d="M12 7.5V12l3.2 2"/>',
        'shield'    => '<path d="M12 3l7 3v5.5c0 4.3-2.9 7.6-7 9.5-4.1-1.9-7-5.2-7-9.5V6z"/><path d="M9 12.2l2.2 2.2L15.2 10"/>',
        'building'  => '<path d="M4 21V6.5L12 3l8 3.5V21"/><path d="M9 21v-5h6v5M9 9h2M13 9h2M9 12.5h2M13 12.5h2"/>',
    ][$name] ?? '';
    return '<svg class="' . $cls . '" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" '
        . 'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' . $p . '</svg>';
}

/**
 * Struktur menu: item tunggal ['link', ...] atau grup
 * ['group', 'Judul', 'ikon', [ [link,label,ikon], ... ]].
 */
function nav_items(): array
{
    $r = role();
    $items = [['link', 'dashboard.php', 'Dashboard', 'grid']];

    if ($r === 'admin_hsse') {
        $items[] = ['group', 'Master Data', 'building', [
            ['vehicles.php', 'Master Mobil Tangki', 'truck'],
            ['vehicle_data.php', 'Data Mobil Tangki', 'truck'],
            ['transporters.php', 'Master Transportir', 'building'],
            ['items.php', 'Master Item Checklist', 'clipboard'],
            ['users.php', 'Master User', 'users'],
        ]];
        $items[] = ['group', 'Jadwal Safety Mobil Tangki', 'calendar', [
            ['schedules.php', 'Jadwal Pemeriksaan', 'calendar'],
            ['due.php', 'Jatuh Tempo Inspeksi', 'clock'],
            ['inspections.php', 'Data Checklist', 'clipboard'],
        ]];
        $items[] = ['link', 'twofa_setup.php', 'Keamanan', 'shield'];
    } elseif ($r === 'inspector_hsse') {
        $items[] = ['group', 'Master Data', 'building', [
            ['vehicle_data.php', 'Data Mobil Tangki', 'truck'],
        ]];
        $items[] = ['group', 'Jadwal Safety Mobil Tangki', 'calendar', [
            ['schedules.php', 'Jadwal Pemeriksaan', 'calendar'],
            ['due.php', 'Jatuh Tempo Inspeksi', 'clock'],
            ['inspections.php', 'Checklist Saya', 'clipboard'],
        ]];
    } else {
        $items[] = ['group', 'Master Data', 'building', [
            ['vehicle_data.php', 'Data Mobil Tangki', 'truck'],
        ]];
        $items[] = ['group', 'Jadwal Safety Mobil Tangki', 'calendar', [
            ['schedules.php', 'Jadwal Pemeriksaan', 'calendar'],
            ['due.php', 'Jatuh Tempo Inspeksi', 'clock'],
            ['approvals.php', 'Approval Checklist', 'check'],
            ['inspections.php', 'Data Checklist', 'clipboard'],
        ]];
    }
    return $items;
}

function layout_start(string $title): void
{
    $current = basename($_SERVER['PHP_SELF']);
    $pending = 0;
    if (has_role(['hsse', 'distribusi', 'qq', 'itm'])) {
        $pending = (int)(q1(
            'SELECT COUNT(*) n FROM inspection_approvals a
             JOIN inspections i ON i.id = a.inspection_id
             WHERE a.role = ? AND a.status = "menunggu"
               AND i.status IN ("diajukan","approve_sebagian")',
            [role()]
        )['n'] ?? 0);
    }
    ?>
<!doctype html>
<html lang="id">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><?= e($title) ?> — <?= e(APP_NAME) ?></title>
  <link rel="stylesheet" href="assets/style.css?v=salty4">
</head>
<body>
<div class="shell">
  <aside class="sidebar">
    <div class="brand">
      <span class="brand-mark"><?= icon('truck', 'icon') ?></span>
      <div>
        <strong>SALTY</strong>
        <small>Checklist Inspeksi Mobil Tangki</small>
      </div>
    </div>
    <nav class="sidenav">
      <?php foreach (nav_items() as $it): ?>
        <?php if ($it[0] === 'link'): [, $href, $label, $ic] = $it; ?>
          <a href="<?= e($href) ?>" class="<?= $current === $href ? 'active' : '' ?>">
            <?= icon($ic) ?><span><?= e($label) ?></span>
          </a>
        <?php else: [, $gtitle, $gicon, $children] = $it;
          $hrefs = array_column($children, 0);
          $open  = in_array($current, $hrefs, true);
          $gPend = $pending > 0 && in_array('approvals.php', $hrefs, true);
        ?>
          <details class="navgroup" <?= $open ? 'open' : '' ?>>
            <summary>
              <?= icon($gicon) ?><span><?= e($gtitle) ?></span>
              <?php if ($gPend && !$open): ?><span class="pill"><?= $pending ?></span><?php endif; ?>
              <svg class="chev" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
                   stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 9l6 6 6-6"/></svg>
            </summary>
            <div class="navsub">
              <?php foreach ($children as [$href, $label, $ic]): ?>
                <a href="<?= e($href) ?>" class="<?= $current === $href ? 'active' : '' ?>">
                  <?= icon($ic) ?><span><?= e($label) ?></span>
                  <?php if ($href === 'approvals.php' && $pending > 0): ?><span class="pill"><?= $pending ?></span><?php endif; ?>
                </a>
              <?php endforeach; ?>
            </div>
          </details>
        <?php endif; ?>
      <?php endforeach; ?>
    </nav>
  </aside>
  <main class="main">
    <header class="appbar">
      <div class="appbar-in">
        <strong class="small"><?= e(APP_TERMINAL) ?></strong>
        <div class="appbar-me">
          <span class="brand-mark" style="width:34px;height:34px;border-radius:10px"><?= icon('user') ?></span>
          <div class="me">
            <strong><?= e(user()['nama']) ?></strong>
            <small><?= e(ROLE_LABELS[role()] ?? role()) ?></small>
          </div>
          <a class="btn btn-ghost btn-sm" href="logout.php">Keluar</a>
        </div>
      </div>
    </header>
    <header class="topbar">
      <h1><?= e($title) ?></h1>
      <div class="muted"><?= e(APP_TERMINAL) ?> · <?= tgl(date('Y-m-d')) ?></div>
    </header>
    <div class="content">
      <?php if ($f = flash()): ?>
        <div class="alert alert-<?= e($f['type']) ?>"><?= e($f['msg']) ?></div>
      <?php endif; ?>
<?php
}

function layout_end(): void
{
    ?>
    </div>
  </main>
</div>
</body>
</html>
<?php
}

<?php require_once __DIR__ . '/helpers.php'; ?>
<!doctype html>
<html lang="id">
<head>
  <meta charset="utf-8">
  <title>Akses ditolak</title>
  <link rel="stylesheet" href="assets/style.css">
</head>
<body class="center-page">
  <div class="card" style="max-width:420px;text-align:center">
    <h2>Akses ditolak</h2>
    <p class="muted">Peran <b><?= e(ROLE_LABELS[role()] ?? role()) ?></b> tidak memiliki akses ke halaman ini.</p>
    <a class="btn" href="dashboard.php">Kembali ke Dashboard</a>
  </div>
</body>
</html>

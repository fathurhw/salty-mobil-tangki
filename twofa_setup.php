<?php
/**
 * Aktivasi verifikasi 2 langkah (authenticator) untuk akun master Admin HSSE.
 * Dipakai saat login pertama (belum aktif) maupun setelah login (reset perangkat).
 */
require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/helpers.php';
require_once __DIR__ . '/includes/layout.php';
require_once __DIR__ . '/includes/totp.php';

$u = user() ?: pending_user();
if (!$u) {
    header('Location: index.php');
    exit;
}
if (!twofa_required($u['role'])) {
    header('Location: dashboard.php');
    exit;
}

$err  = '';
$done = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    csrf_check();
    $secret = $_POST['secret'] ?? '';
    $code   = $_POST['code'] ?? '';
    if (!preg_match('/^[A-Z2-7]{16,64}$/', $secret)) {
        $err = 'Secret tidak valid, muat ulang halaman.';
    } elseif (!totp_verify($secret, $code)) {
        $err = 'Kode salah. Pastikan waktu perangkat tepat lalu masukkan kode terbaru.';
    } else {
        $rec = totp_recovery_codes();
        ex('UPDATE users SET totp_secret=?, totp_enabled=1, recovery_codes=? WHERE id=?',
            [$secret, implode(',', $rec), $u['id']]);
        $done = $rec;
        if (pending_user()) finish_login();
        $_SESSION['user']['totp_enabled'] = 1;
    }
}

if ($done === null) {
    $secret = $_SESSION['totp_setup_secret'] ?? null;
    if (!$secret || !empty($_GET['new'])) {
        $secret = totp_generate_secret();
        $_SESSION['totp_setup_secret'] = $secret;
    }
    $uri = totp_uri($secret, $u['username'], 'SALTY');
}
?>
<!doctype html>
<html lang="id">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Verifikasi 2 Langkah — <?= e(APP_NAME) ?></title>
  <link rel="stylesheet" href="assets/style.css?v=salty3">
</head>
<body class="center-page">
  <div class="login-card" style="max-width:470px">
    <div class="login-brand">
      <span class="brand-mark" style="width:48px;height:48px;border-radius:15px"><?= icon('shield') ?></span>
      <div>
        <h2>Verifikasi 2 Langkah</h2>
        <span class="muted small">Keamanan akun master SALTY</span>
      </div>
    </div>
    <p class="muted">Akun <b><?= e($u['nama']) ?></b> (Admin HSSE) wajib memakai aplikasi authenticator
      (Google Authenticator, Microsoft Authenticator, atau Authy).</p>

    <?php if ($err): ?><div class="alert alert-err"><?= e($err) ?></div><?php endif; ?>

    <?php if ($done !== null): ?>
      <div class="alert alert-ok">Authenticator berhasil diaktifkan.</div>
      <p><b>Simpan kode pemulihan berikut</b> (sekali pakai, untuk masuk bila ponsel hilang):</p>
      <div class="recovery-list">
        <?php foreach ($done as $c): ?><code><?= e($c) ?></code><?php endforeach; ?>
      </div>
      <a class="btn" style="width:100%;margin-top:12px" href="dashboard.php">Lanjut ke Dashboard</a>
    <?php else: ?>
      <ol class="muted small" style="text-align:left;padding-left:18px">
        <li>Buka aplikasi authenticator &rarr; <i>Tambah akun / Scan QR</i>.</li>
        <li>Pindai QR di bawah, atau masukkan kunci manual.</li>
        <li>Masukkan 6 digit kode yang muncul.</li>
      </ol>
      <div style="text-align:center;margin:10px 0">
        <img src="<?= e(totp_qr_url($uri)) ?>" alt="QR authenticator SALTY" width="190" height="190"
             style="border-radius:12px;background:#fff;padding:6px">
      </div>
      <p class="small" style="text-align:center">Kunci manual:<br><code style="word-break:break-all"><?= e($secret) ?></code></p>
      <form method="post">
        <?= csrf_field() ?>
        <input type="hidden" name="secret" value="<?= e($secret) ?>">
        <div class="field">
          <label for="code">Kode 6 digit</label>
          <input id="code" name="code" inputmode="numeric" pattern="[0-9]{6}" maxlength="6" required autofocus placeholder="123456">
        </div>
        <button class="btn" style="width:100%" type="submit">Aktifkan</button>
      </form>
      <p class="small muted" style="text-align:center;margin-top:10px">
        <a href="twofa_setup.php?new=1">Buat kunci baru</a> ·
        <a href="dashboard.php">Kembali</a> ·
        <a href="logout.php">Keluar</a>
      </p>
    <?php endif; ?>
  </div>
</body>
</html>

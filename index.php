<?php
require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/helpers.php';
require_once __DIR__ . '/includes/layout.php';

if (is_logged_in()) {
    header('Location: dashboard.php');
    exit;
}

$err  = '';
$step = pending_user() ? '2fa' : 'login';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    csrf_check();
    $act = $_POST['act'] ?? 'login';

    if ($act === 'login') {
        $res = login(trim($_POST['username'] ?? ''), $_POST['password'] ?? '');
        if ($res === 'ok') {
            header('Location: dashboard.php');
            exit;
        }
        if ($res === 'setup') {
            header('Location: twofa_setup.php');
            exit;
        }
        if ($res === '2fa') {
            $step = '2fa';
        } else {
            $err = 'Username atau password salah, atau akun tidak aktif.';
        }
    } elseif ($act === 'code') {
        if (login_verify_code($_POST['code'] ?? '')) {
            header('Location: dashboard.php');
            exit;
        }
        $err  = 'Kode verifikasi salah atau kedaluwarsa. Coba kode terbaru dari aplikasi authenticator.';
        $step = '2fa';
    } elseif ($act === 'cancel') {
        unset($_SESSION['pending_user']);
        $step = 'login';
    }
}
?>
<!doctype html>
<html lang="id">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Masuk — <?= e(APP_NAME) ?></title>
  <link rel="stylesheet" href="assets/style.css?v=salty3">
</head>
<body class="center-page">
  <form class="login-card" method="post">
    <?= csrf_field() ?>
    <div class="login-brand">
      <span class="brand-mark" style="width:48px;height:48px;border-radius:15px"><?= icon('truck') ?></span>
      <div>
        <h2>SALTY</h2>
        <span class="muted small">Checklist Inspeksi Mobil Tangki</span>
      </div>
    </div>
    <p class="muted">Pemeriksaan MT Baru &amp; Inspeksi 6 Bulanan<br><?= e(APP_TERMINAL) ?></p>

    <?php if ($err): ?><div class="alert alert-err"><?= e($err) ?></div><?php endif; ?>

    <?php if ($step === '2fa'): ?>
      <input type="hidden" name="act" value="code">
      <div class="alert alert-info">Verifikasi 2 langkah aktif untuk akun
        <b><?= e(pending_user()['nama'] ?? '') ?></b>. Masukkan 6 digit kode dari aplikasi authenticator.</div>
      <div class="field">
        <label for="code">Kode Authenticator</label>
        <input id="code" name="code" inputmode="numeric" autocomplete="one-time-code"
               pattern="[0-9A-Za-z\-]{6,11}" maxlength="11" required autofocus placeholder="123456">
        <small class="muted">Bisa juga memakai kode pemulihan (contoh: A1B2-C3D4).</small>
      </div>
      <button class="btn" style="width:100%" type="submit">Verifikasi &amp; Masuk</button>
      <button class="btn btn-muted" style="width:100%;margin-top:8px" name="act" value="cancel" type="submit">Batal</button>
    <?php else: ?>
      <input type="hidden" name="act" value="login">
      <div class="field">
        <label for="username">Username</label>
        <input id="username" name="username" type="text" required autofocus>
      </div>
      <div class="field">
        <label for="password">Password</label>
        <input id="password" name="password" type="password" required>
      </div>
      <button class="btn" style="width:100%" type="submit">Masuk</button>

      <div class="demo-users">
        <b>Akun contoh</b> (password: <code>password123</code>)<br>
        admin — Admin HSSE <b>(wajib authenticator)</b><br>
        inspector — HSSE Support<br>
        hsse — Approver HSSE<br>
        distribusi — Spv I Fuel Distribusi Kertapati Baru<br>
        qq — Sr Spv I QQ<br>
        itm — Okryreza Abdurrachman (approver final)
      </div>
    <?php endif; ?>
  </form>
</body>
</html>

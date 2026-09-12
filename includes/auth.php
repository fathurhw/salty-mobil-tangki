<?php
require_once __DIR__ . '/../config/config.php';

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

const ROLE_LABELS = [
    'admin_hsse'     => 'Admin HSSE (Master Data & Jadwal)',
    'inspector_hsse' => 'Inspector HSSE (Pengisi Checklist)',
    'hsse'           => 'Sr Spv II HSSE (Approver)',
    'distribusi'     => 'Distribusi (Approver)',
    'qq'             => 'QQ Distribusi (Approver)',
    'itm'            => 'ITM / Manager (Approver Final)',
];

/** Role approver level 1 (harus ketiganya setuju sebelum ITM). */
const LEVEL1_ROLES = ['hsse', 'distribusi', 'qq'];

function user(): ?array
{
    return $_SESSION['user'] ?? null;
}

function is_logged_in(): bool
{
    return user() !== null;
}

function role(): string
{
    return user()['role'] ?? '';
}

function has_role(array $roles): bool
{
    return in_array(role(), $roles, true);
}

function require_login(): void
{
    if (!is_logged_in()) {
        header('Location: index.php');
        exit;
    }
}

function require_role(array $roles): void
{
    require_login();
    if (!has_role($roles)) {
        http_response_code(403);
        include __DIR__ . '/forbidden.php';
        exit;
    }
}

/** Role yang WAJIB memakai verifikasi 2 langkah (authenticator). */
const TWOFA_ROLES = ['admin_hsse'];

function twofa_required(string $role): bool
{
    return in_array($role, TWOFA_ROLES, true);
}

/**
 * Tahap 1 login: verifikasi username & password.
 * Return: 'ok' (langsung masuk), '2fa' (butuh kode authenticator),
 *         'setup' (wajib aktifkan authenticator dulu), 'gagal'.
 */
function login(string $username, string $password): string
{
    $u = q1('SELECT * FROM users WHERE username = ? AND aktif = 1', [$username]);
    if (!$u || !password_verify($password, $u['password'])) {
        return 'gagal';
    }
    unset($u['password']);

    if (twofa_required($u['role'])) {
        $_SESSION['pending_user'] = $u;
        if (!empty($u['totp_enabled']) && !empty($u['totp_secret'])) {
            return '2fa';
        }
        return 'setup';
    }

    $_SESSION['user'] = $u;
    return 'ok';
}

function pending_user(): ?array
{
    return $_SESSION['pending_user'] ?? null;
}

/** Tahap 2 login: verifikasi kode authenticator (atau kode pemulihan). */
function login_verify_code(string $code): bool
{
    require_once __DIR__ . '/totp.php';
    $p = pending_user();
    if (!$p) return false;
    $row = q1('SELECT totp_secret, recovery_codes FROM users WHERE id = ?', [$p['id']]);
    if (!$row || empty($row['totp_secret'])) return false;

    $code = trim($code);
    if (totp_verify($row['totp_secret'], $code)) {
        finish_login();
        return true;
    }
    // Kode pemulihan (sekali pakai)
    $list = array_filter(array_map('trim', explode(',', (string)$row['recovery_codes'])));
    $up = strtoupper($code);
    if (in_array($up, array_map('strtoupper', $list), true)) {
        $left = array_values(array_filter($list, fn($c) => strtoupper($c) !== $up));
        ex('UPDATE users SET recovery_codes = ? WHERE id = ?', [implode(',', $left), $p['id']]);
        finish_login();
        return true;
    }
    return false;
}

function finish_login(): void
{
    $p = pending_user();
    if (!$p) return;
    unset($_SESSION['pending_user']);
    $_SESSION['user'] = $p;
}

function logout(): void
{
    $_SESSION = [];
    session_destroy();
}

function csrf_token(): string
{
    if (empty($_SESSION['csrf'])) {
        $_SESSION['csrf'] = bin2hex(random_bytes(16));
    }
    return $_SESSION['csrf'];
}

function csrf_field(): string
{
    return '<input type="hidden" name="_csrf" value="' . csrf_token() . '">';
}

function csrf_check(): void
{
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        if (!hash_equals($_SESSION['csrf'] ?? '', $_POST['_csrf'] ?? '')) {
            die('Token keamanan tidak valid. Muat ulang halaman.');
        }
    }
}

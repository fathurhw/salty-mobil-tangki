<?php
/**
 * Konfigurasi aplikasi & koneksi database (MySQL / phpMyAdmin).
 * Sesuaikan nilai di bawah dengan server Anda (XAMPP/Laragon/hosting).
 */

define('APP_NAME', 'SALTY — Sistem Inspeksi Mobil Tangki');
define('APP_TERMINAL', 'Integrated Terminal Palembang');
define('APP_KOTA', 'Palembang');

// Nilai dapat ditimpa lewat environment variable (opsional).
define('DB_HOST', getenv('SALTY_DB_HOST') ?: '127.0.0.1');
define('DB_NAME', getenv('SALTY_DB_NAME') ?: 'salty_checklist');
define('DB_USER', getenv('SALTY_DB_USER') ?: 'root');
define('DB_PASS', getenv('SALTY_DB_PASS') ?: '');
define('DB_PORT', (int)(getenv('SALTY_DB_PORT') ?: 3306));

// Ambang peringatan jatuh tempo inspeksi 6 bulanan (hari)
define('DUE_WARN_DAYS', [3, 5]);
define('INSPECTION_INTERVAL_MONTHS', 6);

date_default_timezone_set('Asia/Jakarta');

mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

function db(): mysqli
{
    static $conn = null;
    if ($conn === null) {
        try {
            $conn = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME, DB_PORT);
            $conn->set_charset('utf8mb4');
        } catch (Throwable $e) {
            die('<h3 style="font-family:sans-serif">Koneksi database gagal.</h3>'
                . '<p style="font-family:sans-serif">Periksa <code>config/config.php</code>. Detail: '
                . htmlspecialchars($e->getMessage()) . '</p>');
        }
    }
    return $conn;
}

/** Query dengan prepared statement, mengembalikan array asosiatif. */
function q(string $sql, array $params = [], string $types = ''): array
{
    $stmt = db()->prepare($sql);
    if ($params) {
        $types = $types ?: str_repeat('s', count($params));
        $stmt->bind_param($types, ...$params);
    }
    $stmt->execute();
    $res = $stmt->get_result();
    $rows = $res ? $res->fetch_all(MYSQLI_ASSOC) : [];
    $stmt->close();
    return $rows;
}

/** Ambil satu baris. */
function q1(string $sql, array $params = [], string $types = ''): ?array
{
    $rows = q($sql, $params, $types);
    return $rows[0] ?? null;
}

/** Eksekusi INSERT/UPDATE/DELETE, mengembalikan insert_id. */
function ex(string $sql, array $params = [], string $types = ''): int
{
    $stmt = db()->prepare($sql);
    if ($params) {
        $types = $types ?: str_repeat('s', count($params));
        $stmt->bind_param($types, ...$params);
    }
    $stmt->execute();
    $id = db()->insert_id;
    $stmt->close();
    return $id;
}

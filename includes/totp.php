<?php
/**
 * Implementasi TOTP (RFC 6238) murni PHP — kompatibel dengan
 * Google Authenticator / Microsoft Authenticator / Authy.
 */

function totp_base32_encode(string $bin): string
{
    $alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    $out = '';
    $bits = '';
    for ($i = 0; $i < strlen($bin); $i++) {
        $bits .= str_pad(decbin(ord($bin[$i])), 8, '0', STR_PAD_LEFT);
    }
    foreach (str_split($bits, 5) as $chunk) {
        $chunk = str_pad($chunk, 5, '0', STR_PAD_RIGHT);
        $out .= $alphabet[bindec($chunk)];
    }
    return $out;
}

function totp_base32_decode(string $b32): string
{
    $alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    $b32 = strtoupper(preg_replace('/[^A-Z2-7]/i', '', $b32));
    $bits = '';
    for ($i = 0; $i < strlen($b32); $i++) {
        $pos = strpos($alphabet, $b32[$i]);
        if ($pos === false) continue;
        $bits .= str_pad(decbin($pos), 5, '0', STR_PAD_LEFT);
    }
    $bin = '';
    foreach (str_split($bits, 8) as $byte) {
        if (strlen($byte) < 8) break;
        $bin .= chr(bindec($byte));
    }
    return $bin;
}

/** Buat secret baru (base32, 32 karakter). */
function totp_generate_secret(int $bytes = 20): string
{
    return totp_base32_encode(random_bytes($bytes));
}

/** Hitung kode TOTP 6 digit untuk secret pada slot waktu tertentu. */
function totp_code(string $secret, ?int $slot = null, int $digits = 6, int $period = 30): string
{
    $key = totp_base32_decode($secret);
    $slot = $slot ?? (int)floor(time() / $period);
    $bin = pack('N*', 0) . pack('N*', $slot);
    $hash = hash_hmac('sha1', $bin, $key, true);
    $offset = ord(substr($hash, -1)) & 0x0F;
    $part = substr($hash, $offset, 4);
    $value = (unpack('N', $part)[1] & 0x7FFFFFFF) % (10 ** $digits);
    return str_pad((string)$value, $digits, '0', STR_PAD_LEFT);
}

/** Verifikasi kode dengan toleransi ±1 slot (30 detik). */
function totp_verify(string $secret, string $code, int $window = 1): bool
{
    $code = preg_replace('/\D/', '', $code);
    if (strlen($code) !== 6) return false;
    $now = (int)floor(time() / 30);
    for ($i = -$window; $i <= $window; $i++) {
        if (hash_equals(totp_code($secret, $now + $i), $code)) return true;
    }
    return false;
}

/** URI otpauth:// untuk dipindai authenticator. */
function totp_uri(string $secret, string $account, string $issuer): string
{
    return 'otpauth://totp/' . rawurlencode($issuer . ':' . $account)
        . '?secret=' . $secret
        . '&issuer=' . rawurlencode($issuer)
        . '&algorithm=SHA1&digits=6&period=30';
}

/** URL gambar QR (butuh internet); tampilkan juga kode manual sebagai cadangan. */
function totp_qr_url(string $uri): string
{
    return 'https://api.qrserver.com/v1/create-qr-code/?size=190x190&data=' . rawurlencode($uri);
}

/** Buat 5 kode pemulihan (recovery codes) dalam bentuk plain + hash. */
function totp_recovery_codes(int $n = 5): array
{
    $plain = [];
    for ($i = 0; $i < $n; $i++) {
        $plain[] = strtoupper(bin2hex(random_bytes(2)) . '-' . bin2hex(random_bytes(2)));
    }
    return $plain;
}

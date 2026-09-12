<?php
require_once __DIR__ . '/../config/config.php';

function e($v): string
{
    return htmlspecialchars((string)$v, ENT_QUOTES, 'UTF-8');
}

function flash(?string $msg = null, string $type = 'ok')
{
    if ($msg !== null) {
        $_SESSION['flash'] = ['msg' => $msg, 'type' => $type];
        return null;
    }
    $f = $_SESSION['flash'] ?? null;
    unset($_SESSION['flash']);
    return $f;
}

function tgl(?string $d, bool $withDay = false): string
{
    if (!$d || $d === '0000-00-00') return '-';
    $bulan = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    $t = strtotime($d);
    return date('d', $t) . ' ' . $bulan[(int)date('n', $t)] . ' ' . date('Y', $t);
}

function form_label(string $t): string
{
    return $t === 'baru' ? 'MT Baru' : 'Inspeksi 6 Bulanan';
}

/** Hitung tanggal jatuh tempo berikut (6 bulan setelah inspeksi). */
function next_due(string $lastDate): string
{
    return date('Y-m-d', strtotime($lastDate . ' +' . INSPECTION_INTERVAL_MONTHS . ' months'));
}

/** Nomor pemeriksaan otomatis. */
function generate_no(string $formType): string
{
    $prefix = $formType === 'baru' ? 'MTB' : 'MT6';
    $year = date('Y');
    $row = q1("SELECT COUNT(*) AS n FROM inspections WHERE form_type = ? AND YEAR(tgl_pemeriksaan) = ?", [$formType, $year]);
    $n = ((int)($row['n'] ?? 0)) + 1;
    return sprintf('%s/%03d/HSSE/PND546000/%s', $prefix, $n, $year);
}

/** Badge status inspeksi. */
function status_badge(string $status): string
{
    $map = [
        'draft'            => ['Draft', 'gray'],
        'diajukan'         => ['Menunggu Approval', 'amber'],
        'approve_sebagian' => ['Approval Sebagian', 'blue'],
        'disetujui'        => ['Disetujui ITM', 'green'],
        'ditolak'          => ['Ditolak', 'red'],
    ];
    [$label, $color] = $map[$status] ?? [$status, 'gray'];
    return '<span class="badge badge-' . $color . '">' . e($label) . '</span>';
}

function due_badge(?int $sisa): string
{
    if ($sisa === null) return '<span class="badge badge-gray">Belum ada data</span>';
    if ($sisa < 0)  return '<span class="badge badge-red">Lewat ' . abs($sisa) . ' hari</span>';
    if ($sisa <= 3) return '<span class="badge badge-red">' . $sisa . ' hari lagi</span>';
    if ($sisa <= 5) return '<span class="badge badge-amber">' . $sisa . ' hari lagi</span>';
    if ($sisa <= 30) return '<span class="badge badge-blue">' . $sisa . ' hari lagi</span>';
    return '<span class="badge badge-green">' . $sisa . ' hari lagi</span>';
}

/**
 * Stempel "APPROVED" berdesain untuk approval.
 * $status: disetujui | ditolak | menunggu
 * $size: sm | md | lg
 */
function stamp(string $status, string $sub = '', string $size = 'md', ?string $when = null): string
{
    $map = [
        'disetujui' => ['APPROVED', ''],
        'ditolak'   => ['REJECTED', 'stamp-reject'],
        'menunggu'  => ['PENDING', 'stamp-wait'],
    ];
    [$label, $mod] = $map[$status] ?? ['PENDING', 'stamp-wait'];
    $cls = 'stamp' . ($mod ? ' ' . $mod : '') . ($size === 'md' ? '' : ' stamp-' . $size);
    if ($when) {
        $stampWhen = date('d/m/Y', strtotime($when)) . ' &middot; ' . date('H:i', strtotime($when)) . ' WIB';
    } elseif ($status === 'menunggu') {
        $stampWhen = '';
    } else {
        $stampWhen = date('d/m/Y') . ' &middot; ' . date('H:i') . ' WIB';
    }
    return '<span class="' . $cls . '"><span class="stamp-main">' . $label . '</span>'
        . ($stampWhen !== '' ? '<span class="stamp-sub">' . $stampWhen . '</span>' : '')
        . ($sub !== '' ? '<span class="stamp-sub">' . e($sub) . '</span>' : '') . '</span>';
}

/** Apakah checklist ini memerlukan approval final ITM? (hanya MT Baru) */
function needs_itm(string $formType): bool
{
    return $formType === 'baru';
}

/**
 * Sinkronisasi status inspeksi berdasarkan approval.
 * - 3 approver level 1 (HSSE, Distribusi, QQ) harus disetujui.
 * - Khusus MT Baru: setelah itu approval ITM (level 2) terbuka & wajib.
 * - Inspeksi 6 Bulanan: selesai setelah 3 approver level 1 setuju.
 */
function refresh_inspection_status(int $inspectionId): void
{
    $insp = q1('SELECT * FROM inspections WHERE id = ?', [$inspectionId]);
    if (!$insp) return;

    $apps = q('SELECT role, status FROM inspection_approvals WHERE inspection_id = ?', [$inspectionId]);
    $by = [];
    foreach ($apps as $a) $by[$a['role']] = $a['status'];

    if (in_array('ditolak', $by, true)) {
        ex("UPDATE inspections SET status='ditolak' WHERE id=?", [$inspectionId]);
        return;
    }

    $l1done = true;
    foreach (LEVEL1_ROLES as $r) {
        if (($by[$r] ?? 'menunggu') !== 'disetujui') $l1done = false;
    }

    $itmOk = !needs_itm($insp['form_type']) || ($by['itm'] ?? '') === 'disetujui';

    if ($l1done && $itmOk) {
        ex("UPDATE inspections SET status='disetujui', finalized_at=NOW() WHERE id=?", [$inspectionId]);
        // Update jatuh tempo MT untuk inspeksi 6 bulanan & MT baru
        $last = $insp['tgl_pemeriksaan'];
        ex("UPDATE vehicles SET last_inspection=?, next_inspection=? WHERE id=?",
            [$last, next_due($last), $insp['vehicle_id']]);
        if ($insp['schedule_id']) {
            ex("UPDATE schedules SET status='selesai' WHERE id=?", [$insp['schedule_id']]);
        }
        return;
    }

    $anyApproved = in_array('disetujui', $by, true);
    ex("UPDATE inspections SET status=? WHERE id=?",
        [$anyApproved ? 'approve_sebagian' : 'diajukan', $inspectionId]);
}

/** Apakah user boleh approve inspeksi ini sekarang? */
function can_approve(array $insp, string $userRole): array
{
    if (!in_array($userRole, ['hsse', 'distribusi', 'qq', 'itm'], true)) {
        return [false, 'Peran Anda bukan approver.'];
    }
    if (!in_array($insp['status'], ['diajukan', 'approve_sebagian'], true)) {
        return [false, 'Checklist belum diajukan atau sudah selesai.'];
    }
    if ($userRole === 'itm' && !needs_itm($insp['form_type'])) {
        return [false, 'Approval ITM hanya untuk checklist MT Baru.'];
    }
    $row = q1('SELECT * FROM inspection_approvals WHERE inspection_id=? AND role=?', [$insp['id'], $userRole]);
    if ($row && $row['status'] !== 'menunggu') {
        return [false, 'Anda sudah memberikan keputusan.'];
    }
    if ($userRole === 'itm') {
        foreach (LEVEL1_ROLES as $r) {
            $a = q1('SELECT status FROM inspection_approvals WHERE inspection_id=? AND role=?', [$insp['id'], $r]);
            if (($a['status'] ?? 'menunggu') !== 'disetujui') {
                return [false, 'Menunggu approval HSSE, Distribusi & QQ terlebih dahulu.'];
            }
        }
    }
    return [true, ''];
}

/**
 * Simpan foto temuan hasil pemeriksaan.
 * Mengembalikan nama file relatif (uploads/temuan/xxx.jpg) atau null bila gagal.
 */
function save_temuan_photo(array $file, int $inspectionId, int $itemId): ?string
{
    if (($file['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) return null;
    if ($file['size'] > 5 * 1024 * 1024) return null; // maks 5 MB
    $allowed = ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp'];
    $mime = function_exists('mime_content_type') ? mime_content_type($file['tmp_name']) : ($file['type'] ?? '');
    if (!isset($allowed[$mime])) return null;

    $dir = __DIR__ . '/../uploads/temuan';
    if (!is_dir($dir)) @mkdir($dir, 0775, true);
    $name = sprintf('temuan_%d_%d_%s.%s', $inspectionId, $itemId, bin2hex(random_bytes(4)), $allowed[$mime]);
    if (!move_uploaded_file($file['tmp_name'], $dir . '/' . $name)) return null;
    return 'uploads/temuan/' . $name;
}

/** Daftar kolom file dokumen & foto pada master mobil tangki. */
function vehicle_files(): array
{
    return [
        'foto_depan'    => 'Foto Tampak Depan',
        'foto_belakang' => 'Foto Tampak Belakang',
        'foto_kanan'    => 'Foto Tampak Kanan',
        'foto_kiri'     => 'Foto Tampak Kiri',
        'doc_stnk'      => 'Foto / Scan STNK',
        'doc_keur'      => 'Foto / Scan Buku Keur',
        'doc_tera'      => 'Foto / Scan Surat Tera Metrologi',
    ];
}

/**
 * Simpan foto / dokumen mobil tangki (JPG, PNG, WEBP, PDF; maks 8 MB).
 * Mengembalikan path relatif (uploads/mt/xxx.jpg) atau null bila tidak ada / gagal.
 */
function save_vehicle_file(array $file, string $noPolisi, string $kind): ?string
{
    if (($file['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) return null;
    if ($file['size'] > 8 * 1024 * 1024) return null;
    $allowed = [
        'image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp', 'application/pdf' => 'pdf',
    ];
    $mime = function_exists('mime_content_type') ? mime_content_type($file['tmp_name']) : ($file['type'] ?? '');
    if (!isset($allowed[$mime])) return null;

    $dir = __DIR__ . '/../uploads/mt';
    if (!is_dir($dir)) @mkdir($dir, 0775, true);
    $slug = preg_replace('/[^A-Za-z0-9]+/', '', $noPolisi) ?: 'mt';
    $name = sprintf('%s_%s_%s.%s', $slug, $kind, bin2hex(random_bytes(4)), $allowed[$mime]);
    if (!move_uploaded_file($file['tmp_name'], $dir . '/' . $name)) return null;
    return 'uploads/mt/' . $name;
}

/** Apakah path file berupa PDF? */
function is_pdf(?string $path): bool
{
    return $path !== null && strtolower(pathinfo($path, PATHINFO_EXTENSION)) === 'pdf';
}

/** Statistik dashboard. */
function dashboard_stats(): array
{
    $s = [];
    $s['mt']        = (int)(q1('SELECT COUNT(*) n FROM vehicles WHERE status="aktif"')['n'] ?? 0);
    $s['jadwal']    = (int)(q1('SELECT COUNT(*) n FROM schedules WHERE status IN ("dijadwalkan","proses")')['n'] ?? 0);
    $s['menunggu']  = (int)(q1('SELECT COUNT(*) n FROM inspections WHERE status IN ("diajukan","approve_sebagian")')['n'] ?? 0);
    $s['selesai']   = (int)(q1('SELECT COUNT(*) n FROM inspections WHERE status="disetujui"')['n'] ?? 0);
    $s['due']       = (int)(q1('SELECT COUNT(*) n FROM v_due_inspections WHERE sisa_hari <= 5')['n'] ?? 0);
    return $s;
}

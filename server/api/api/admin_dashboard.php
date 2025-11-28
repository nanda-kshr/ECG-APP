<?php
// ...existing code...
// Send CORS headers early so preflight requests don't get blocked
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Vary: Origin');
header('Access-Control-Allow-Headers: Origin, Content-Type, Authorization, X-Requested-With, Accept');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS, PUT, DELETE');
header('Access-Control-Max-Age: 86400');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Enable debug output only in dev. Set environment variable APP_ENV=development or DEBUG=1 in your system/XAMPP.
$is_debug = (getenv('APP_ENV') === 'development' || getenv('DEBUG') === '1');

try {
    // require db.php from parent folder (adjust path if db.php is elsewhere)
    require_once __DIR__ . '/db.php';

    // ensure $pdo exists
    if (!isset($pdo) || !($pdo instanceof PDO)) {
        throw new RuntimeException('Database connection ($pdo) not available');
    }

    // Run queries defensively so one missing table doesn't break the whole endpoint.
    $diagnostics = [];

    // total users by role
    $roles = ['admin' => 0, 'doctor' => 0, 'technician' => 0];
    try {
        $stmt = $pdo->query("SELECT role, COUNT(*) as cnt FROM users GROUP BY role");
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            $roles[$row['role']] = (int)$row['cnt'];
        }
    } catch (Throwable $qe) {
        $diagnostics[] = 'users count failed: ' . $qe->getMessage();
    }

    // total tasks (replacing reports)
    $totalReports = 0;
    try {
        $stmt = $pdo->query("SELECT COUNT(*) as cnt FROM tasks");
        $totalReports = (int)$stmt->fetchColumn();
    } catch (Throwable $qe) {
        $diagnostics[] = 'tasks count failed: ' . $qe->getMessage();
    }

    // recent tasks (replacing reports)
    $recent = [];
    try {
        $stmt = $pdo->query("SELECT t.id, p.name as patient_name, t.doctor_feedback as result, t.created_at, u.name as technician_name
                         FROM tasks t
                         LEFT JOIN users u ON u.id = t.technician_id
                         LEFT JOIN patients p ON p.id = t.patient_id
                         ORDER BY t.created_at DESC
                         LIMIT 10");
        $recent = $stmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Throwable $qe) {
        $diagnostics[] = 'recent tasks failed: ' . $qe->getMessage();
    }

    $response = [
        'success' => true,
        'data' => [
            'totals' => [
                'users' => array_sum($roles),
                'admins' => $roles['admin'] ?? 0,
                'doctors' => $roles['doctor'] ?? 0,
                'technicians' => $roles['technician'] ?? 0,
                'reports' => $totalReports
            ],
            'recent_reports' => $recent
        ]
    ];

    if ($is_debug && !empty($diagnostics)) {
        $response['debug'] = $diagnostics;
    }

    echo json_encode($response);
} catch (Throwable $e) {
    error_log('admin_dashboard error: ' . $e->getMessage() . ' in ' . $e->getFile() . ':' . $e->getLine());
    http_response_code(500);
    if ($is_debug) {
        echo json_encode(['success' => false, 'error' => 'Server error', 'detail' => $e->getMessage()]);
    } else {
        echo json_encode(['success' => false, 'error' => 'Server error']);
    }
}
// ...existing code...
?>
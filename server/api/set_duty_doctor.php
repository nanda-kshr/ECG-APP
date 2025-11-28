<?php
// set_duty_doctor.php - Admin sets the current duty doctor (users.is_duty flag)
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Vary: Origin');
header('Access-Control-Allow-Headers: Origin, Content-Type, Authorization, X-Requested-With, Accept');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS, PUT, DELETE');
header('Access-Control-Max-Age: 86400');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

$is_debug = (getenv('DEBUG') === '1');

try {
    require_once __DIR__ . '/db.php';

    // Allow JSON or form-encoded
    $raw = file_get_contents('php://input');
    $data = json_decode($raw, true);
    if (!is_array($data)) { $data = $_POST; }

    $adminId = isset($data['admin_id']) ? (int)$data['admin_id'] : 0;
    $doctorId = isset($data['doctor_id']) ? (int)$data['doctor_id'] : 0;

    if ($adminId <= 0 || $doctorId <= 0) {
        http_response_code(400);
        echo json_encode(['success'=>false,'error'=>'Missing admin_id or doctor_id']);
        exit;
    }

    // Verify admin role
    $stmt = $pdo->prepare("SELECT role FROM users WHERE id = :id LIMIT 1");
    $stmt->execute(['id' => $adminId]);
    $admin = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$admin || $admin['role'] !== 'admin') {
        http_response_code(403);
        echo json_encode(['success'=>false,'error'=>'Only admins can change duty doctor']);
        exit;
    }

    // Verify target is doctor
    $stmt = $pdo->prepare("SELECT role FROM users WHERE id = :id LIMIT 1");
    $stmt->execute(['id' => $doctorId]);
    $doc = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$doc || $doc['role'] !== 'doctor') {
        http_response_code(400);
        echo json_encode(['success'=>false,'error'=>'doctor_id must be a doctor user']);
        exit;
    }

    $pdo->beginTransaction();

    // Clear existing duty flag for all doctors
    $pdo->exec("UPDATE users SET is_duty = 0 WHERE role = 'doctor'");

    // Set new duty doctor
    $upd = $pdo->prepare("UPDATE users SET is_duty = 1 WHERE id = :id AND role = 'doctor'");
    $upd->execute(['id' => $doctorId]);

    $pdo->commit();

    echo json_encode(['success'=>true, 'duty_doctor_id' => $doctorId]);

} catch (Throwable $e) {
    if (isset($pdo) && $pdo->inTransaction()) { $pdo->rollBack(); }
    error_log('set_duty_doctor error: ' . $e->getMessage());
    http_response_code(500);
    $resp = ['success'=>false,'error'=>'Server error'];
    if ($is_debug) { $resp['detail'] = $e->getMessage(); }
    echo json_encode($resp);
}

<?php
// add_doctor.php - Admin adds a new doctor to the system
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

    $raw = file_get_contents('php://input');
    $data = json_decode($raw, true);
    if (!is_array($data)) { $data = $_POST; }

    $adminId = isset($data['admin_id']) ? (int)$data['admin_id'] : 0;
    $name = isset($data['name']) ? trim((string)$data['name']) : '';
    $email = isset($data['email']) ? trim((string)$data['email']) : '';
    $password = isset($data['password']) ? (string)$data['password'] : '';
    $department = isset($data['department']) ? trim((string)$data['department']) : '';

    // Validation
    if ($adminId <= 0) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'Missing admin_id']);
        exit;
    }

    if ($name === '') {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'Doctor name is required']);
        exit;
    }

    if ($email === '' || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'Valid email is required']);
        exit;
    }

    if ($password === '' || strlen($password) < 6) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'Password must be at least 6 characters']);
        exit;
    }

    // Verify admin role
    $stmt = $pdo->prepare('SELECT role FROM users WHERE id = :id LIMIT 1');
    $stmt->execute(['id' => $adminId]);
    $admin = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$admin || $admin['role'] !== 'admin') {
        http_response_code(403);
        echo json_encode(['success' => false, 'error' => 'Only admins can add doctors']);
        exit;
    }

    // Check if email already exists
    $stmt = $pdo->prepare('SELECT id FROM users WHERE email = :email LIMIT 1');
    $stmt->execute(['email' => $email]);
    if ($stmt->fetch()) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'Email already exists']);
        exit;
    }

    // Hash password securely
    $passwordHash = password_hash($password, PASSWORD_DEFAULT);

    // Check if users table has department column
    $hasDepartment = false;
    try {
        $colStmt = $pdo->query("SHOW COLUMNS FROM users LIKE 'department'");
        $hasDepartment = (bool)$colStmt->fetch();
    } catch (Throwable $ignore) {}

    $pdo->beginTransaction();

    if ($hasDepartment && $department !== '') {
        $ins = $pdo->prepare(
            'INSERT INTO users (email, password_hash, name, department, role, created_at) 
             VALUES (:email, :pass, :name, :dept, :role, NOW())'
        );
        $ins->execute([
            'email' => $email,
            'pass' => $passwordHash,
            'name' => $name,
            'dept' => $department,
            'role' => 'doctor'
        ]);
    } else {
        $ins = $pdo->prepare(
            'INSERT INTO users (email, password_hash, name, role, created_at) 
             VALUES (:email, :pass, :name, :role, NOW())'
        );
        $ins->execute([
            'email' => $email,
            'pass' => $passwordHash,
            'name' => $name,
            'role' => 'doctor'
        ]);
    }

    $newDoctorId = (int)$pdo->lastInsertId();

    $pdo->commit();

    echo json_encode([
        'success' => true,
        'doctor_id' => $newDoctorId,
        'message' => 'Doctor added successfully'
    ]);

} catch (Throwable $e) {
    if (isset($pdo) && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    error_log('add_doctor error: ' . $e->getMessage());
    http_response_code(500);
    $resp = ['success' => false, 'error' => 'Server error'];
    if ($is_debug) { $resp['detail'] = $e->getMessage(); }
    echo json_encode($resp);
}

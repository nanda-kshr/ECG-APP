<?php
// get_duty_doctors.php - Get doctors on duty for a specific date
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

    $date = isset($_GET['date']) ? trim($_GET['date']) : date('Y-m-d');
    $shift = isset($_GET['shift']) ? trim($_GET['shift']) : null;

    // Validate date format
    $dateObj = DateTime::createFromFormat('Y-m-d', $date);
    if (!$dateObj || $dateObj->format('Y-m-d') !== $date) {
        http_response_code(400);
        echo json_encode(['success'=>false,'error'=>'Invalid date format. Use YYYY-MM-DD']);
        exit;
    }

    $where = ['r.duty_date = :date', 'r.is_active = 1', 'u.role = :role'];
    $params = ['date' => $date, 'role' => 'doctor'];

    if ($shift && in_array($shift, ['morning','afternoon','evening','night','full_day'], true)) {
        $where[] = 'r.shift = :shift';
        $params['shift'] = $shift;
    }

    $whereClause = implode(' AND ', $where);

    $sql = "SELECT 
                u.id, u.name, u.email, r.shift, r.duty_date
            FROM duty_roster r
            INNER JOIN users u ON u.id = r.doctor_id
            WHERE $whereClause
            ORDER BY r.shift, u.name";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $doctors = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode(['success'=>true, 'doctors' => $doctors, 'count' => count($doctors)]);

} catch (Throwable $e) {
    error_log('get_duty_doctors error: '.$e->getMessage());
    http_response_code(500);
    $resp = ['success'=>false,'error'=>'Server error'];
    if ($is_debug) { $resp['detail'] = $e->getMessage(); }
    echo json_encode($resp);
}
?>

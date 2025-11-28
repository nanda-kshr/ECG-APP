<?php
// list_tasks.php - List tasks with filters (for admin/doctor/technician)
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

    // Query params
    $status = isset($_GET['status']) ? trim($_GET['status']) : null;
    $doctorId = isset($_GET['doctor_id']) ? (int)$_GET['doctor_id'] : null;
    $technicianId = isset($_GET['technician_id']) ? (int)$_GET['technician_id'] : null;
    $limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 50;
    $offset = isset($_GET['offset']) ? (int)$_GET['offset'] : 0;

    $where = [];
    $params = [];

    if ($status && in_array($status, ['pending','assigned','in_progress','completed','cancelled'], true)) {
        $where[] = 't.status = :status';
        $params['status'] = $status;
    }

    if ($doctorId) {
        $where[] = 't.assigned_doctor_id = :did';
        $params['did'] = $doctorId;
    }

    if ($technicianId) {
        $where[] = 't.technician_id = :tid';
        $params['tid'] = $technicianId;
    }

    $whereClause = !empty($where) ? 'WHERE ' . implode(' AND ', $where) : '';

    $sql = "SELECT 
                t.id, t.patient_id, t.technician_id, t.assigned_doctor_id, t.assigned_by,
                t.status, t.priority, t.technician_notes, t.admin_notes, t.doctor_feedback,
                t.assigned_at, t.completed_at, t.created_at, t.updated_at,
                tech.name as technician_name, tech.email as technician_email,
                doc.name as doctor_name, doc.email as doctor_email,
                admin.name as assigned_by_name,
                p.name as patient_name, p.patient_id as patient_id_str, p.age as patient_age
            FROM tasks t
            LEFT JOIN users tech ON tech.id = t.technician_id
            LEFT JOIN users doc ON doc.id = t.assigned_doctor_id
            LEFT JOIN users admin ON admin.id = t.assigned_by
            LEFT JOIN patients p ON p.id = t.patient_id
            $whereClause
            ORDER BY t.created_at DESC
            LIMIT :limit OFFSET :offset";

    $stmt = $pdo->prepare($sql);
    foreach ($params as $key => $val) {
        $stmt->bindValue(":$key", $val);
    }
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
    $stmt->execute();

    $tasks = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Flatten to a single record per patient id while preserving ordering
    $uniqueTasks = [];
    $seenPatients = [];
    foreach ($tasks as $task) {
        $patientKey = null;
        if (isset($task['patient_id']) && $task['patient_id'] !== null) {
            $patientKey = (string) $task['patient_id'];
        } elseif (isset($task['patient_id_str']) && $task['patient_id_str'] !== null) {
            $patientKey = (string) $task['patient_id_str'];
        }

        if ($patientKey !== null) {
            if (isset($seenPatients[$patientKey])) {
                continue;
            }
            $seenPatients[$patientKey] = true;
        }

        $uniqueTasks[] = $task;
    }

    echo json_encode(['success'=>true, 'tasks' => $uniqueTasks, 'count' => count($uniqueTasks)]);

} catch (Throwable $e) {
    error_log('list_tasks error: '.$e->getMessage());
    http_response_code(500);
    $resp = ['success'=>false,'error'=>'Server error'];
    if ($is_debug) { $resp['detail'] = $e->getMessage(); }
    echo json_encode($resp);
}
?>

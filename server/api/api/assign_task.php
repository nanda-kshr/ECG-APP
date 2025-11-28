<?php
// assign_task.php - Admin assigns a report/task to a doctor
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
    if (!is_array($data)) { 
        http_response_code(400); 
        echo json_encode(['success'=>false,'error'=>'Invalid JSON']); 
        exit; 
    }

    $reportId = trim($data['report_id'] ?? '');
    $taskId = (int)($data['task_id'] ?? 0);
    $doctorId = (int)($data['doctor_id'] ?? 0);
    $assignedBy = (int)($data['assigned_by'] ?? 0); // admin user id
    $notes = trim($data['notes'] ?? '');
    $priority = strtolower(trim($data['priority'] ?? 'normal'));

    if ($taskId <= 0 || $doctorId <= 0 || $assignedBy <= 0) {
        http_response_code(400);
        echo json_encode(['success'=>false,'error'=>'Missing required fields: task_id, doctor_id, assigned_by']);
        exit;
    }

    $allowedPriorities = ['low', 'normal', 'high', 'urgent'];
    if (!in_array($priority, $allowedPriorities, true)) {
        $priority = 'normal';
    }

    // Verify admin role
    $stmtAdmin = $pdo->prepare('SELECT role FROM users WHERE id = :id LIMIT 1');
    $stmtAdmin->execute(['id' => $assignedBy]);
    $admin = $stmtAdmin->fetch(PDO::FETCH_ASSOC);
    if (!$admin || $admin['role'] !== 'admin') {
        http_response_code(403);
        echo json_encode(['success'=>false,'error'=>'Only admins can assign tasks']);
        exit;
    }

    // Verify task exists and is pending
    $stmtTask = $pdo->prepare('SELECT patient_id, technician_id, status FROM tasks WHERE id = :id LIMIT 1');
    $stmtTask->execute(['id' => $taskId]);
    $task = $stmtTask->fetch(PDO::FETCH_ASSOC);
    if (!$task) {
        http_response_code(404);
        echo json_encode(['success'=>false,'error'=>'Task not found']);
        exit;
    }
    if ($task['status'] !== 'pending') {
        http_response_code(400);
        echo json_encode(['success'=>false,'error'=>'Task is already assigned or completed']);
        exit;
    }
    $patientId = (int)$task['patient_id'];
    $technicianId = (int)$task['technician_id'];

    // Verify doctor role
    $stmtDoctor = $pdo->prepare('SELECT role FROM users WHERE id = :id LIMIT 1');
    $stmtDoctor->execute(['id' => $doctorId]);
    $doctor = $stmtDoctor->fetch(PDO::FETCH_ASSOC);
    if (!$doctor || $doctor['role'] !== 'doctor') {
        http_response_code(400);
        echo json_encode(['success'=>false,'error'=>'Assigned user must be a doctor']);
        exit;
    }

    // Get report and technician_id
    $stmtReport = $pdo->prepare('SELECT technician_id FROM reports WHERE id = :id LIMIT 1');
    $stmtReport->execute(['id' => $reportId]);
    $report = $stmtReport->fetch(PDO::FETCH_ASSOC);
    if (!$report) {
        http_response_code(404);
        echo json_encode(['success'=>false,'error'=>'Report not found']);
        exit;
    }
    $technicianId = (int)$report['technician_id'];

    // Insert task
    $pdo->beginTransaction();
    
    $ins = $pdo->prepare(
        'INSERT INTO tasks (report_id, technician_id, assigned_doctor_id, assigned_by, status, priority, notes, assigned_at) 
         VALUES (:rid, :tid, :did, :aid, :status, :priority, :notes, NOW())'
    );
    $ins->execute([
        'rid' => $reportId,
        'tid' => $technicianId,
        'did' => $doctorId,
        'aid' => $assignedBy,
        'status' => 'assigned',
        'priority' => $priority,
        'notes' => $notes
    ]);
    $taskId = (int)$pdo->lastInsertId();

    // Log history
    $hist = $pdo->prepare(
        'INSERT INTO task_history (task_id, changed_by, old_status, new_status, comment) 
         VALUES (:tid, :uid, NULL, :status, :comment)'
    );
    $hist->execute([
        'tid' => $taskId,
        'uid' => $assignedBy,
        'status' => 'assigned',
        'comment' => 'Task assigned to doctor'
    ]);

    $pdo->commit();

    echo json_encode(['success'=>true, 'task_id' => $taskId]);

} catch (Throwable $e) {
    if (isset($pdo) && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    error_log('assign_task error: '.$e->getMessage());
    http_response_code(500);
    $resp = ['success'=>false,'error'=>'Server error'];
    if ($is_debug) { $resp['detail'] = $e->getMessage(); }
    echo json_encode($resp);
}
?>

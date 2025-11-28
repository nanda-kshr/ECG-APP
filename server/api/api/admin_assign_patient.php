<?php
// admin_assign_patient.php - Admin assigns an ECG patient/task to a doctor
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

    $patientId = isset($data['patient_id']) ? (int)$data['patient_id'] : 0;
    $doctorId = isset($data['doctor_id']) ? (int)$data['doctor_id'] : 0;
    $assignedBy = isset($data['assigned_by']) ? (int)$data['assigned_by'] : 0; // admin id
    $priority = isset($data['priority']) ? strtolower(trim((string)$data['priority'])) : 'normal';
    $notes = isset($data['notes']) ? trim((string)$data['notes']) : '';

    if ($patientId <= 0 || $doctorId <= 0 || $assignedBy <= 0) {
        http_response_code(400);
        echo json_encode(['success'=>false,'error'=>'Missing patient_id, doctor_id or assigned_by']);
        exit;
    }

    $allowedPriorities = ['low','normal','high','urgent'];
    if (!in_array($priority, $allowedPriorities, true)) { $priority = 'normal'; }

    // Verify admin
    $stmt = $pdo->prepare('SELECT role FROM users WHERE id = :id LIMIT 1');
    $stmt->execute(['id' => $assignedBy]);
    $admin = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$admin || $admin['role'] !== 'admin') {
        http_response_code(403);
        echo json_encode(['success'=>false,'error'=>'Only admins can assign patients']);
        exit;
    }

    // Verify doctor
    $stmt = $pdo->prepare('SELECT role FROM users WHERE id = :id LIMIT 1');
    $stmt->execute(['id' => $doctorId]);
    $doc = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$doc || $doc['role'] !== 'doctor') {
        http_response_code(400);
        echo json_encode(['success'=>false,'error'=>'doctor_id must be a doctor user']);
        exit;
    }

    // Verify patient exists
    $stmt = $pdo->prepare('SELECT id, status FROM patients WHERE id = :id LIMIT 1');
    $stmt->execute(['id' => $patientId]);
    $patient = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$patient) {
        http_response_code(404);
        echo json_encode(['success'=>false,'error'=>'Patient not found']);
        exit;
    }

    $pdo->beginTransaction();

    // Update patient mapping and status
    $pdo->prepare('UPDATE patients SET assigned_doctor_id = :did, status = :st WHERE id = :pid')
        ->execute(['did' => $doctorId, 'st' => 'in_progress', 'pid' => $patientId]);

    // Find latest pending task for this patient
    $stmt = $pdo->prepare("SELECT id FROM tasks WHERE patient_id = :pid AND status = 'pending' ORDER BY id DESC LIMIT 1");
    $stmt->execute(['pid' => $patientId]);
    $task = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($task) {
        $taskId = (int)$task['id'];
        // Update task to assigned
        $upd = $pdo->prepare('UPDATE tasks SET assigned_doctor_id = :did, assigned_by = :aid, status = :st, priority = :prio, admin_notes = COALESCE(NULLIF(CONCAT(COALESCE(admin_notes,''), :notesAppend),''), admin_notes), assigned_at = NOW() WHERE id = :tid');
        $append = ($notes !== '') ? ("\n" . $notes) : '';
        $upd->execute(['did'=>$doctorId,'aid'=>$assignedBy,'st'=>'assigned','prio'=>$priority,'notesAppend'=>$append,'tid'=>$taskId]);

        // Log history
        $hist = $pdo->prepare('INSERT INTO task_history (task_id, changed_by, old_status, new_status, comment) VALUES (:tid, :uid, :old, :new, :comment)');
        $hist->execute(['tid'=>$taskId,'uid'=>$assignedBy,'old'=>'pending','new'=>'assigned','comment'=>($notes !== ''?'Admin notes: '.substr($notes,0,200):'Assigned to doctor')]);
    } else {
        // No task yet (edge case) -> create one pre-assigned
        // Find technician from images if possible
        $techStmt = $pdo->prepare('SELECT technician_id FROM ecg_images WHERE patient_id = :pid ORDER BY id ASC LIMIT 1');
        $techStmt->execute(['pid' => $patientId]);
        $img = $techStmt->fetch(PDO::FETCH_ASSOC);
        $technicianId = $img && isset($img['technician_id']) ? (int)$img['technician_id'] : $assignedBy; // fallback

        $ins = $pdo->prepare('INSERT INTO tasks (patient_id, technician_id, assigned_doctor_id, assigned_by, status, priority, admin_notes, assigned_at) VALUES (:pid,:tid,:did,:aid,:st,:prio,:notes,NOW())');
        $ins->execute(['pid'=>$patientId,'tid'=>$technicianId,'did'=>$doctorId,'aid'=>$assignedBy,'st'=>'assigned','prio'=>$priority,'notes'=>$notes]);
        $taskId = (int)$pdo->lastInsertId();

        $hist = $pdo->prepare('INSERT INTO task_history (task_id, changed_by, old_status, new_status, comment) VALUES (:tid,:uid,NULL,:new,:comment)');
        $hist->execute(['tid'=>$taskId,'uid'=>$assignedBy,'new'=>'assigned','comment'=>($notes !== ''?'Admin notes: '.substr($notes,0,200):'Assigned to doctor')]);
    }

    $pdo->commit();

    echo json_encode(['success'=>true]);

} catch (Throwable $e) {
    if (isset($pdo) && $pdo->inTransaction()) { $pdo->rollBack(); }
    error_log('admin_assign_patient error: '.$e->getMessage());
    http_response_code(500);
    $resp = ['success'=>false,'error'=>'Server error'];
    if ($is_debug) { $resp['detail'] = $e->getMessage(); }
    echo json_encode($resp);
}

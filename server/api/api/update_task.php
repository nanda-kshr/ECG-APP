<?php
// update_task.php - Update task status and feedback (doctor submits result)
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

    $taskId = (int)($data['task_id'] ?? 0);
    $userId = (int)($data['user_id'] ?? 0); // doctor or admin
    $newStatus = strtolower(trim($data['status'] ?? ''));
    $feedback = trim($data['feedback'] ?? '');

    if ($taskId <= 0 || $userId <= 0) {
        http_response_code(400);
        echo json_encode(['success'=>false,'error'=>'Missing task_id or user_id']);
        exit;
    }

    $allowedStatuses = ['pending','assigned','in_progress','completed','cancelled'];
    if (!in_array($newStatus, $allowedStatuses, true)) {
        http_response_code(400);
        echo json_encode(['success'=>false,'error'=>'Invalid status']);
        exit;
    }

    // Get current task
    $stmtTask = $pdo->prepare('SELECT * FROM tasks WHERE id = :id LIMIT 1');
    $stmtTask->execute(['id' => $taskId]);
    $task = $stmtTask->fetch(PDO::FETCH_ASSOC);
    if (!$task) {
        http_response_code(404);
        echo json_encode(['success'=>false,'error'=>'Task not found']);
        exit;
    }

    // Verify user is authorized (doctor assigned to task or admin)
    $stmtUser = $pdo->prepare('SELECT role FROM users WHERE id = :id LIMIT 1');
    $stmtUser->execute(['id' => $userId]);
    $user = $stmtUser->fetch(PDO::FETCH_ASSOC);
    if (!$user) {
        http_response_code(403);
        echo json_encode(['success'=>false,'error'=>'User not found']);
        exit;
    }

    $isAdmin = ($user['role'] === 'admin');
    $isAssignedDoctor = ((int)$task['assigned_doctor_id'] === $userId);

    if (!$isAdmin && !$isAssignedDoctor) {
        http_response_code(403);
        echo json_encode(['success'=>false,'error'=>'Not authorized to update this task']);
        exit;
    }

    $pdo->beginTransaction();

    $oldStatus = $task['status'];
    $updates = ['status' => $newStatus];
    $setSql = ['status = :status'];
    
    if ($feedback !== '') {
        $updates['feedback'] = $feedback;
        $setSql[] = 'doctor_feedback = :feedback';
    }

    if ($newStatus === 'completed' && $task['completed_at'] === null) {
        $setSql[] = 'completed_at = NOW()';
    }

    $updates['tid'] = $taskId;
    $updateSql = 'UPDATE tasks SET ' . implode(', ', $setSql) . ' WHERE id = :tid';
    $stmtUpdate = $pdo->prepare($updateSql);
    $stmtUpdate->execute($updates);

    // Log history
    $hist = $pdo->prepare(
        'INSERT INTO task_history (task_id, changed_by, old_status, new_status, comment) 
         VALUES (:tid, :uid, :old, :new, :comment)'
    );
    $hist->execute([
        'tid' => $taskId,
        'uid' => $userId,
        'old' => $oldStatus,
        'new' => $newStatus,
        'comment' => $feedback !== '' ? 'Feedback: ' . substr($feedback, 0, 100) : 'Status updated'
    ]);

    $pdo->commit();

    echo json_encode(['success'=>true, 'message' => 'Opinion Updated']);

} catch (Throwable $e) {
    if (isset($pdo) && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    error_log('update_task error: '.$e->getMessage());
    http_response_code(500);
    $resp = ['success'=>false,'error'=>'Server error'];
    if ($is_debug) { $resp['detail'] = $e->getMessage(); }
    echo json_encode($resp);
}
?>

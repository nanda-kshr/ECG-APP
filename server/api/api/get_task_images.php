<?php
// get_task_images.php - Get images associated with a task or patient
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Vary: Origin');
header('Access-Control-Allow-Headers: Origin, Content-Type, Authorization, X-Requested-With, Accept');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Max-Age: 86400');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

$is_debug = (getenv('DEBUG') === '1');

try {
    require_once __DIR__ . '/db.php';

    $taskId = isset($_GET['task_id']) ? (int)$_GET['task_id'] : null;
    $patientId = isset($_GET['patient_id']) ? (int)$_GET['patient_id'] : null;
    $limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 10;
    $offset = isset($_GET['offset']) ? (int)$_GET['offset'] : 0;

    if (!$taskId && !$patientId) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'Either task_id or patient_id is required']);
        exit;
    }

    // If task_id is provided, get the patient_id from the task
    if ($taskId && !$patientId) {
        $taskStmt = $pdo->prepare('SELECT patient_id FROM tasks WHERE id = :tid LIMIT 1');
        $taskStmt->execute(['tid' => $taskId]);
        $task = $taskStmt->fetch(PDO::FETCH_ASSOC);
        if (!$task) {
            http_response_code(404);
            echo json_encode(['success' => false, 'error' => 'Task not found']);
            exit;
        }
        $patientId = (int)$task['patient_id'];
    }

    // Fetch images for the patient
    $sql = 'SELECT 
                id as image_id, 
                image_name, 
                image_path, 
                comment, 
                created_at, 
                status,
                file_size,
                mime_type
            FROM ecg_images 
            WHERE patient_id = :pid 
            ORDER BY created_at DESC 
            LIMIT :limit OFFSET :offset';

    $stmt = $pdo->prepare($sql);
    $stmt->bindValue(':pid', $patientId, PDO::PARAM_INT);
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
    $stmt->execute();

    $images = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Get total count
    $countStmt = $pdo->prepare('SELECT COUNT(*) FROM ecg_images WHERE patient_id = :pid');
    $countStmt->execute(['pid' => $patientId]);
    $totalCount = (int)$countStmt->fetchColumn();

    // Build full URLs for images using get_image.php API
    $baseUrl = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? 'https' : 'http') 
               . '://' . $_SERVER['HTTP_HOST'];
    $scriptPath = dirname($_SERVER['SCRIPT_NAME']); // e.g., /ecg_new/api
    
    foreach ($images as &$img) {
        // Use get_image.php API endpoint
        $img['image_url'] = $baseUrl . $scriptPath . '/get_image.php?image_id=' . $img['image_id'] . '&download=1';
    }
    unset($img);

    echo json_encode([
        'success' => true,
        'images' => $images,
        'count' => count($images),
        'total' => $totalCount,
        'patient_id' => $patientId
    ]);

} catch (Throwable $e) {
    error_log('get_task_images error: ' . $e->getMessage());
    http_response_code(500);
    $resp = ['success' => false, 'error' => 'Server error'];
    if ($is_debug) { $resp['detail'] = $e->getMessage(); }
    echo json_encode($resp);
}
?>

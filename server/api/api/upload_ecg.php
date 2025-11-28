<?php
// upload_ecg.php - Technician uploads ECG with patient info and images
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

    // Verify technician
    $technicianId = (int)($_POST['technician_id'] ?? 0);
    if ($technicianId <= 0) {
        http_response_code(400);
        echo json_encode(['success'=>false,'error'=>'Missing technician_id']);
        exit;
    }

    $stmtTech = $pdo->prepare('SELECT role FROM users WHERE id = :id LIMIT 1');
    $stmtTech->execute(['id' => $technicianId]);
    $tech = $stmtTech->fetch(PDO::FETCH_ASSOC);
    if (!$tech || $tech['role'] !== 'technician') {
        http_response_code(403);
        echo json_encode(['success'=>false,'error'=>'Only technicians can upload ECG']);
        exit;
    }

    // Get patient info
    $patientName = trim($_POST['patient_name'] ?? '');
    $patientAge = isset($_POST['patient_age']) ? (int)$_POST['patient_age'] : null;
    $patientGender = trim($_POST['patient_gender'] ?? '');
    $technicianNotes = trim($_POST['notes'] ?? '');
    $priority = strtolower(trim($_POST['priority'] ?? 'normal'));

    if ($patientName === '') {
        http_response_code(400);
        echo json_encode(['success'=>false,'error'=>'Patient name is required']);
        exit;
    }

    $allowedGenders = ['male', 'female', 'other'];
    if ($patientGender !== '' && !in_array($patientGender, $allowedGenders, true)) {
        $patientGender = null;
    }

    $allowedPriorities = ['low', 'normal', 'high', 'urgent'];
    if (!in_array($priority, $allowedPriorities, true)) {
        $priority = 'normal';
    }

    // Normalize uploaded images into a consistent structure regardless of field naming
    function normalize_files_for_images() {
        // If PHP sent files as $_FILES['images'] (single or array), handle it first
        if (isset($_FILES['images'])) {
            $f = $_FILES['images'];
            if (is_array($f['name'])) return $f;
            return [
                'name' => [$f['name']],
                'tmp_name' => [$f['tmp_name']],
                'size' => [$f['size']],
                'error' => [$f['error']],
                'type' => [$f['type']],
            ];
        }

        // Fallback: look for any uploaded fields that contain 'images' in the name
        $result = ['name'=>[], 'tmp_name'=>[], 'size'=>[], 'error'=>[], 'type'=>[]];
        foreach ($_FILES as $k => $v) {
            if (stripos($k, 'image') !== false || stripos($k, 'images') !== false) {
                if (is_array($v['name'])) {
                    $result['name'] = array_merge($result['name'], $v['name']);
                    $result['tmp_name'] = array_merge($result['tmp_name'], $v['tmp_name']);
                    $result['size'] = array_merge($result['size'], $v['size']);
                    $result['error'] = array_merge($result['error'], $v['error']);
                    $result['type'] = array_merge($result['type'], $v['type']);
                } else {
                    $result['name'][] = $v['name'];
                    $result['tmp_name'][] = $v['tmp_name'];
                    $result['size'][] = $v['size'];
                    $result['error'][] = $v['error'];
                    $result['type'][] = $v['type'];
                }
            }
        }
        if (empty($result['name'])) return null;
        return $result;
    }

    $files = normalize_files_for_images();
    if (!$files) {
        http_response_code(400);
        echo json_encode(['success'=>false,'error'=>'No images uploaded (no files found in request)']);
        exit;
    }

    $pdo->beginTransaction();

    // Generate patient ID (format: PATYYYYMMDDnnn)
    $datePrefix = date('Ymd');
    $stmtCount = $pdo->query("SELECT COUNT(*) FROM patients WHERE patient_id LIKE 'PAT{$datePrefix}%'");
    $count = (int)$stmtCount->fetchColumn();
    $patientIdNumber = str_pad($count + 1, 3, '0', STR_PAD_LEFT);
    $patientId = "PAT{$datePrefix}{$patientIdNumber}";

    // Insert patient
    $insPatient = $pdo->prepare(
        'INSERT INTO patients (patient_id, name, age, gender) VALUES (:pid, :name, :age, :gender)'
    );
    $insPatient->execute([
        'pid' => $patientId,
        'name' => $patientName,
        'age' => $patientAge,
        'gender' => $patientGender
    ]);
    $dbPatientId = (int)$pdo->lastInsertId();

    // Create uploads directory if not exists
    $uploadDir = __DIR__ . '/../uploads/ecg_images/';
    if (!is_dir($uploadDir)) {
        mkdir($uploadDir, 0755, true);
    }

    // Handle multiple image uploads
    $uploadedImages = [];
    $failedUploads = [];
    $fileCount = is_array($files['name']) ? count($files['name']) : 0;

    for ($i = 0; $i < $fileCount; $i++) {
        $fileName = $files['name'][$i] ?? null;
        $fileTmpName = $files['tmp_name'][$i] ?? null;
        $fileSize = $files['size'][$i] ?? null;
        $fileError = $files['error'][$i] ?? UPLOAD_ERR_NO_FILE;
        $fileType = $files['type'][$i] ?? null;

        if ($fileError !== UPLOAD_ERR_OK) {
            continue; // Skip files with errors
        }

        // Validate file type
        $allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif'];
        if (!in_array($fileType, $allowedTypes, true)) {
            continue;
        }

        // Generate unique filename
        $ext = pathinfo($fileName, PATHINFO_EXTENSION);
        $newFileName = $patientId . '_' . time() . '_' . $i . '.' . $ext;
        $targetPath = $uploadDir . $newFileName;

        if (move_uploaded_file($fileTmpName, $targetPath)) {
            // Insert image record
            $insImage = $pdo->prepare(
                'INSERT INTO ecg_images (patient_id, technician_id, image_path, image_name, file_size, mime_type) 
                 VALUES (:pid, :tid, :path, :name, :size, :mime)'
            );
            $insImage->execute([
                'pid' => $dbPatientId,
                'tid' => $technicianId,
                'path' => 'uploads/ecg_images/' . $newFileName,
                'name' => $fileName,
                'size' => $fileSize,
                'mime' => $fileType
            ]);
            $uploadedImages[] = $newFileName;
        } else {
            // Log failed move for debugging
            $failedUploads[] = [
                'name' => $fileName,
                'tmp_name' => $fileTmpName,
                'error' => $fileError,
                'type' => $fileType,
                'target' => $targetPath,
            ];
            if ($is_debug) {
                error_log('upload_ecg move failed for: ' . json_encode(end($failedUploads)) );
            }
        }
    }

    if (empty($uploadedImages)) {
        $pdo->rollBack();
        http_response_code(400);
        $resp = ['success'=>false,'error'=>'No valid images were uploaded'];
        if ($is_debug) {
            $resp['detail'] = 'No images were successfully moved to uploads directory';
            $resp['failed_uploads'] = $failedUploads;
            $resp['post'] = $_POST;
            $resp['files'] = array_map(function($k) { return is_array($k) ? $k : (string)$k; }, $_FILES);
        }
        echo json_encode($resp);
        exit;
    }

    // Create task (pending by default)
    $insTask = $pdo->prepare(
        'INSERT INTO tasks (patient_id, technician_id, status, priority, technician_notes) 
         VALUES (:pid, :tid, :status, :priority, :notes)'
    );
    $insTask->execute([
        'pid' => $dbPatientId,
        'tid' => $technicianId,
        'status' => 'pending',
        'priority' => $priority,
        'notes' => $technicianNotes
    ]);
    $taskId = (int)$pdo->lastInsertId();

    // Patients.status = pending if column exists
    $hasPatientStatus = false;
    try {
        $colStmt = $pdo->prepare("SHOW COLUMNS FROM patients LIKE 'status'");
        $colStmt->execute();
        $hasPatientStatus = (bool)$colStmt->fetch(PDO::FETCH_ASSOC);
    } catch (Throwable $ignore) {}
    if ($hasPatientStatus) {
        $pdo->prepare('UPDATE patients SET status = :st WHERE id = :pid')
            ->execute(['st' => 'pending', 'pid' => $dbPatientId]);
    }

    // Creation history
    $hist = $pdo->prepare(
        'INSERT INTO task_history (task_id, changed_by, old_status, new_status, comment) 
         VALUES (:tid, :uid, NULL, :status, :comment)'
    );
    $hist->execute([
        'tid' => $taskId,
        'uid' => $technicianId,
        'status' => 'pending',
        'comment' => 'Task created by technician'
    ]);

    // Auto-assign to duty doctor if schema supports
    $hasIsDuty = false; $hasAssignedDoctorPatient = false;
    try {
        $c1 = $pdo->prepare("SHOW COLUMNS FROM users LIKE 'is_duty'");
        $c1->execute();
        $hasIsDuty = (bool)$c1->fetch(PDO::FETCH_ASSOC);
    } catch (Throwable $ignore) {}
    try {
        $c2 = $pdo->prepare("SHOW COLUMNS FROM patients LIKE 'assigned_doctor_id'");
        $c2->execute();
        $hasAssignedDoctorPatient = (bool)$c2->fetch(PDO::FETCH_ASSOC);
    } catch (Throwable $ignore) {}

    if ($hasIsDuty && $hasAssignedDoctorPatient) {
        $stmtDuty = $pdo->prepare("SELECT id FROM users WHERE role = 'doctor' AND is_duty = 1 LIMIT 1");
        $stmtDuty->execute();
        $duty = $stmtDuty->fetch(PDO::FETCH_ASSOC);
        if ($duty && isset($duty['id'])) {
            $dutyDoctorId = (int)$duty['id'];

            if ($hasPatientStatus) {
                $pdo->prepare('UPDATE patients SET assigned_doctor_id = :did, status = :st WHERE id = :pid')
                    ->execute(['did' => $dutyDoctorId, 'st' => 'in_progress', 'pid' => $dbPatientId]);
            } else {
                $pdo->prepare('UPDATE patients SET assigned_doctor_id = :did WHERE id = :pid')
                    ->execute(['did' => $dutyDoctorId, 'pid' => $dbPatientId]);
            }

            $pdo->prepare('UPDATE tasks SET assigned_doctor_id = :did, status = :st, assigned_at = NOW() WHERE id = :tid')
                ->execute(['did' => $dutyDoctorId, 'st' => 'assigned', 'tid' => $taskId]);

            $hist2 = $pdo->prepare(
                'INSERT INTO task_history (task_id, changed_by, old_status, new_status, comment) 
                 VALUES (:tid, :uid, :old, :new, :comment)'
            );
            $hist2->execute([
                'tid' => $taskId,
                'uid' => $technicianId,
                'old' => 'pending',
                'new' => 'assigned',
                'comment' => 'Auto-assigned to current duty doctor'
            ]);
        }
    }

    $pdo->commit();

    echo json_encode([
        'success' => true,
        'task_id' => $taskId,
        'patient_id' => $patientId,
        'images_uploaded' => count($uploadedImages)
    ]);

} catch (Throwable $e) {
    if (isset($pdo) && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    // Log exception and optionally request data for debug
    $msg = 'upload_ecg error: '.$e->getMessage();
    if ($is_debug) {
        $msg .= '\nPOST: ' . print_r($_POST, true);
        $msg .= '\nFILES: ' . print_r($_FILES, true);
    }
    error_log($msg);
    http_response_code(500);
    $resp = ['success'=>false,'error'=>'Server error'];
    if ($is_debug) { $resp['detail'] = $e->getMessage(); }
    echo json_encode($resp);
}
?>

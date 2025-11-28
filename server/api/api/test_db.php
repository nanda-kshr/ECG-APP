<?php
// Lightweight DB/API health check — requires your existing db.php
require_once __DIR__ . '/db.php';

header('Content-Type: application/json; charset=utf-8');

try {
    // quick simple check
    $okStmt = $pdo->query('SELECT 1 AS ok');
    $ok = $okStmt ? (bool) $okStmt->fetchColumn() : false;

    // get DB version (optional)
    $verStmt = $pdo->query('SELECT VERSION() AS v');
    $version = $verStmt ? $verStmt->fetchColumn() : null;

    echo json_encode([
        'success' => true,
        'db' => [
            'connected' => $ok,
            'version' => $version ?: 'unknown'
        ]
    ]);
} catch (Throwable $e) {
    http_response_code(500);
    if (!empty($is_debug)) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    } else {
        echo json_encode(['success' => false, 'error' => 'DB connection failed']);
    }
}

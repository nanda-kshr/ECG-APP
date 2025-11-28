<?php
// test_list_doctors.php - Quick test for list_doctors endpoint
error_reporting(E_ALL);
ini_set('display_errors', 1);

echo "Testing list_doctors.php endpoint...\n\n";

// Include the actual endpoint
$_SERVER['REQUEST_METHOD'] = 'GET';
$_GET = [];

ob_start();
try {
    include __DIR__ . '/api/api/list_doctors.php';
    $output = ob_get_clean();
    
    echo "Output:\n";
    echo $output . "\n\n";
    
    $decoded = json_decode($output, true);
    if ($decoded) {
        echo "JSON Valid: Yes\n";
        echo "Success: " . ($decoded['success'] ? 'true' : 'false') . "\n";
        if (isset($decoded['doctors'])) {
            echo "Doctors count: " . count($decoded['doctors']) . "\n";
        }
        if (isset($decoded['error'])) {
            echo "Error: " . $decoded['error'] . "\n";
        }
    } else {
        echo "JSON Valid: No\n";
        echo "JSON Error: " . json_last_error_msg() . "\n";
    }
} catch (Exception $e) {
    ob_end_clean();
    echo "Exception: " . $e->getMessage() . "\n";
}

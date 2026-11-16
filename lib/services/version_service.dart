import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';

class VersionCheckResult {
  final bool needsUpdate;
  final String currentVersion;
  final String targetVersion;
  final String storeUrl;
  final String title;
  final String message;

  const VersionCheckResult({
    required this.needsUpdate,
    required this.currentVersion,
    required this.targetVersion,
    required this.storeUrl,
    required this.title,
    required this.message,
  });
}

class VersionService {
  /// Compares two semver-like version strings (e.g., '3.0.2' vs '3.0.3').
  /// Returns 1 if v1 > v2, -1 if v1 < v2, and 0 if equal.
  static int compareVersions(String v1, String v2) {
    List<int> parseParts(String v) {
      final withoutBuild = v.split('+').first;
      final clean = withoutBuild.replaceAll(RegExp(r'[^0-9.]'), '');
      return clean
          .split('.')
          .map((p) => int.tryParse(p) ?? 0)
          .toList();
    }

    final parts1 = parseParts(v1);
    final parts2 = parseParts(v2);
    final maxLen = parts1.length > parts2.length ? parts1.length : parts2.length;

    for (int i = 0; i < maxLen; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 > p2) return 1;
      if (p1 < p2) return -1;
    }
    return 0;
  }

  /// Checks the backend API for required updates against the locally installed version.
  static Future<VersionCheckResult?> checkVersion() async {
    try {
      final url = Uri.parse('${apiBaseUrl}app_version.php');
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> || data['success'] != true) {
        return null;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g. "3.0.2"

      String targetVersion = data['min_version']?.toString() ?? '1.0.0';
      String storeUrl = '';
      final title = data['title']?.toString() ?? 'Update Required';
      final message = data['message']?.toString() ??
          'A new version ($targetVersion) of the app is available. Please update to continue.';

      if (defaultTargetPlatform == TargetPlatform.iOS && data['ios'] is Map) {
        final iosData = data['ios'] as Map<String, dynamic>;
        targetVersion = iosData['min_version']?.toString() ?? targetVersion;
        storeUrl = iosData['store_url']?.toString() ?? '';
      } else if (defaultTargetPlatform == TargetPlatform.android &&
          data['android'] is Map) {
        final androidData = data['android'] as Map<String, dynamic>;
        targetVersion = androidData['min_version']?.toString() ?? targetVersion;
        storeUrl = androidData['store_url']?.toString() ?? '';
      }

      // If backend target version is greater than installed version, update is required
      final needsUpdate = compareVersions(targetVersion, currentVersion) > 0;

      return VersionCheckResult(
        needsUpdate: needsUpdate,
        currentVersion: currentVersion,
        targetVersion: targetVersion,
        storeUrl: storeUrl,
        title: title,
        message: message,
      );
    } catch (e) {
      debugPrint('Version check failed: $e');
      return null;
    }
  }

  /// Displays a non-dismissible dialog that forces the user to update.
  static void showUpdateDialog(BuildContext context, VersionCheckResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.system_update,
                  color: Theme.of(dialogContext).primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.message),
                const SizedBox(height: 12),
                Text(
                  'Current Version: ${result.currentVersion}\nLatest Version: ${result.targetVersion}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (result.storeUrl.isNotEmpty) {
                      final uri = Uri.parse(result.storeUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    }
                  },
                  child: const Text(
                    'Update Now',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

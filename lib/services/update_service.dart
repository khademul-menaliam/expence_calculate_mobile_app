import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';

class UpdateInfo {
  final String latestVersion;
  final String releaseUrl;
  final String? releaseNotes;
  final bool hasUpdate;

  const UpdateInfo({
    required this.latestVersion,
    required this.releaseUrl,
    this.releaseNotes,
    required this.hasUpdate,
  });
}

class UpdateService {
  static const String currentVersion = '2.0.1';

  // Your GitHub Repository
  static const String githubRepo = 'khademul-menaliam/expence_calculate_mobile_app';
  static String updateWebsiteUrl = 'https://github.com/$githubRepo/releases';

  static bool _hasCheckedThisSession = false;

  /// Check GitHub releases API automatically
  static Future<UpdateInfo?> checkGitHubRelease() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final request = await client.getUrl(
        Uri.parse('https://api.github.com/repos/$githubRepo/releases/latest'),
      );
      request.headers.set('User-Agent', 'Flutter-Expense-App');
      final response = await request.close().timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final tagName = (json['tag_name'] as String? ?? '').replaceAll('v', '').trim();
        final releaseUrl = json['html_url'] as String? ?? updateWebsiteUrl;
        final releaseNotes = json['body'] as String?;

        final hasUpdate = _isVersionGreater(tagName, currentVersion);
        return UpdateInfo(
          latestVersion: tagName.isNotEmpty ? tagName : currentVersion,
          releaseUrl: releaseUrl,
          releaseNotes: releaseNotes,
          hasUpdate: hasUpdate,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Automatically check in background on app launch
  static Future<void> checkOnStartup(BuildContext context) async {
    if (_hasCheckedThisSession) return;
    _hasCheckedThisSession = true;

    final info = await checkGitHubRelease();
    if (info != null && info.hasUpdate && context.mounted) {
      showUpdateAvailableDialog(context, info);
    }
  }

  /// Manual check from Settings Screen
  static Future<void> checkFromSettings(BuildContext context) async {
    AppToast.show(context, 'Checking GitHub for updates...');
    final info = await checkGitHubRelease();
    if (!context.mounted) return;

    if (info != null && info.hasUpdate) {
      showUpdateAvailableDialog(context, info);
    } else if (info != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: AppTheme.incomeColor),
              SizedBox(width: 8),
              Text('Up to Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: const Text(
            'You are on the latest version (v$currentVersion). No update needed!',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                openUrl(updateWebsiteUrl);
              },
              child: const Text('View Releases'),
            ),
          ],
        ),
      );
    } else {
      // Fallback if no releases created yet on GitHub or offline
      showUpdateDialog(context);
    }
  }

  static bool _isVersionGreater(String newVer, String currentVer) {
    try {
      final newParts = newVer.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final curParts = currentVer.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      for (int i = 0; i < 3; i++) {
        final n = i < newParts.length ? newParts[i] : 0;
        final c = i < curParts.length ? curParts[i] : 0;
        if (n > c) return true;
        if (n < c) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Display popup when an update is found on GitHub
  static Future<void> showUpdateAvailableDialog(BuildContext context, UpdateInfo info) async {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.system_update_rounded, color: AppTheme.primaryAccent),
              SizedBox(width: 8),
              Text('Update Available!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Installed:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const Text('v$currentVersion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const Text('•', style: TextStyle(color: AppTheme.textSecondary)),
                    const Text('Latest:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    Text('v${info.latestVersion}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryAccent)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'A newer release is available on GitHub. Tap below to download the latest APK update.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              if (info.releaseNotes != null && info.releaseNotes!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    info.releaseNotes!.trim(),
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Later'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Download Update'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                openUrl(info.releaseUrl);
              },
            ),
          ],
        );
      },
    );
  }

  /// Launch external URL safely
  static Future<bool> openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Standard fallback dialog
  static Future<void> showUpdateDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.system_update_rounded, color: AppTheme.primaryAccent),
              SizedBox(width: 8),
              Text('Check for Update', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Current Installed Version:', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    Text('v$currentVersion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryAccent)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Visit the official GitHub Releases page to download the latest release or APK updates.',
                style: TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_browser, size: 18),
              label: const Text('Open GitHub Releases'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                openUrl(updateWebsiteUrl);
              },
            ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';

class UpdateService {
  static const String currentVersion = '1.0.0';

  // Configurable update / download website URL
  // Replace this with your actual website, APK download link, or GitHub releases page:
  static String updateWebsiteUrl = 'https://github.com';

  /// Launch the update website in external browser
  static Future<bool> openUpdateWebsite(BuildContext context) async {
    final uri = Uri.tryParse(updateWebsiteUrl);
    if (uri == null) {
      if (context.mounted) {
        AppToast.show(context, 'Invalid update URL configured.');
      }
      return false;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        AppToast.show(context, 'Could not launch website: $updateWebsiteUrl');
      }
      return launched;
    } catch (e) {
      if (context.mounted) {
        AppToast.show(context, 'Error opening website: $e');
      }
      return false;
    }
  }

  /// Show interactive "Check for Update" dialog
  static Future<void> showUpdateDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.system_update_rounded, color: AppTheme.primaryAccent),
              SizedBox(width: 10),
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
                'Tap the button below to visit the official website and download the latest release or APK update.',
                style: TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.4),
              ),
              const SizedBox(height: 8),
              Text(
                'Website: $updateWebsiteUrl',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
              label: const Text('Open Website'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                openUpdateWebsite(context);
              },
            ),
          ],
        );
      },
    );
  }
}

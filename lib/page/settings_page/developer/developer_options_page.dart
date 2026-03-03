import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/page/settings_page/developer/vibration_test_page.dart';
import 'package:anx_reader/page/settings_page/subpage/log_page.dart';
import 'package:anx_reader/widgets/settings/settings_section.dart';
import 'package:anx_reader/widgets/settings/settings_tile.dart';
import 'package:anx_reader/widgets/settings/settings_title.dart';
import 'package:flutter/material.dart';

class DeveloperOptionsPage extends StatefulWidget {
  const DeveloperOptionsPage({super.key});

  @override
  State<DeveloperOptionsPage> createState() => _DeveloperOptionsPageState();
}

class _DeveloperOptionsPageState extends State<DeveloperOptionsPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return settingsSections(
      sections: [
        SettingsSection(
          title: Text(l10n.settingsDeveloperOptions),
          tiles: [
            SettingsTile.switchTile(
              leading: const Icon(Icons.developer_mode),
              title: Text(l10n.settingsDeveloperOptionsEnable),
              description: Text(l10n.settingsDeveloperOptionsEnableDesc),
              initialValue: Prefs().developerOptionsEnabled,
              onToggle: (value) {
                setState(() {
                  Prefs().developerOptionsEnabled = value;
                });
                if (!value && Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
            ),
            SettingsTile.navigation(
              leading: const Icon(Icons.vibration_outlined),
              title: Text(l10n.settingsVibrationTest),
              description: Text(l10n.settingsVibrationTestDesc),
              onPressed: (context) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const VibrationTestPage(),
                  ),
                );
              },
            ),
          ],
        ),
        SettingsSection(
          title: Text(l10n.settingsAiDebugTitle),
          tiles: [
            SettingsTile.switchTile(
              leading: const Icon(Icons.bug_report),
              title: Text(l10n.settingsAiDebugEnable),
              description: Text(l10n.settingsAiDebugEnableDesc),
              initialValue: Prefs().aiDebugLogsEnabled,
              onToggle: (value) {
                setState(() {
                  Prefs().aiDebugLogsEnabled = value;
                });
              },
            ),
            SettingsTile.navigation(
              leading: const Icon(Icons.list_alt),
              title: Text(l10n.settingsAdvancedLog),
              onPressed: (context) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LogPage()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

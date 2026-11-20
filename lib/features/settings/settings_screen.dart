import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/scope/app_scope.dart';
import '../../data/repositories/settings_repository.dart';
import '../../main.dart';
import '../../navigation/app_router.dart';
import '../../theme/app_themes.dart';
import '../../theme/app_tokens.dart';
import '../ai/ai_provider.dart';
import '../ai/remote_ai_provider.dart';
import '../data/export_import.dart';

/// Settings hub: appearance, companion, daily, conversations, accessibility,
/// privacy/data, about. Everything persists locally; nothing leaves the device.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoReply = true;
  bool _dailyGreeting = true;
  bool _dailyQuestion = true;
  double _textScale = 1.0;
  bool _reducedMotion = false;
  bool _loaded = false;

  // --- AI section state (Phase 6; local-only by default). ---
  bool _aiEnabled = false;
  String _aiMode = 'auto';
  bool _keyConfigured = false;
  bool _testingConnection = false;
  late TextEditingController _aiBaseUrl;
  late TextEditingController _aiModel;
  late TextEditingController _aiKey;

  @override
  void initState() {
    super.initState();
    _aiBaseUrl = TextEditingController();
    _aiModel = TextEditingController();
    _aiKey = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _aiBaseUrl.dispose();
    _aiModel.dispose();
    _aiKey.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final scope = AppScope.of(context);
      final s = scope.settings;
      final results = await Future.wait([
        s.autoReply(),
        s.dailyGreeting(),
        s.dailyQuestion(),
        s.textScale(),
        s.reducedMotion(),
        s.aiEnabled(),
        s.aiModeName(),
        s.aiBaseUrl(),
        s.aiModel(),
        scope.credentials.hasKey(),
      ]);
      if (!mounted) return;
      setState(() {
        _autoReply = results[0] as bool;
        _dailyGreeting = results[1] as bool;
        _dailyQuestion = results[2] as bool;
        _textScale = results[3] as double;
        _reducedMotion = results[4] as bool;
        _aiEnabled = results[5] as bool;
        _aiMode = results[6] as String;
        _aiBaseUrl.text = results[7] as String;
        _aiModel.text = results[8] as String;
        _keyConfigured = results[9] as bool;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _pickTheme() async {
    final current = themeSelection.value;
    // Captured before any async gap (lint: use_build_context_synchronously).
    final settings = AppScope.of(context).settings;
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showDialog<AppThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Theme'),
        children: [
          RadioGroup<AppThemeMode>(
            groupValue: current,
            onChanged: (v) => Navigator.of(context).pop(v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final m in AppThemeMode.values)
                  RadioListTile<AppThemeMode>(
                    title: Text(m.name),
                    value: m,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked != null) {
      themeSelection.value = picked;
      // Persist so restart restores the choice (FR-THEME-01). Best-effort:
      // the live switch already applied; a failed write just means the
      // next launch falls back to the last persisted value.
      try {
        await settings.setThemeMode(picked);
      } catch (_) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Theme applied, but could not save it.')),
        );
      }
    }
  }

  Future<void> _setAiEnabled(bool v) async {
    setState(() => _aiEnabled = v);
    try {
      final settings = AppScope.of(context).settings;
      await settings.setAiEnabled(v);
      if (v) {
        // Enabling with no explicit mode selects Auto fallback.
        final mode = await settings.aiModeName();
        if (mode == 'localOnly') {
          await settings.setAiModeName('auto');
          if (mounted) setState(() => _aiMode = 'auto');
        }
      }
    } catch (_) {}
  }

  Future<void> _setAiMode(String v) async {
    setState(() => _aiMode = v);
    try {
      await AppScope.of(context).settings.setAiModeName(v);
    } catch (_) {}
  }

  Future<void> _saveAiEndpoint() async {
    try {
      // Validate before persisting: rejects non-https (except loopback).
      RemoteAIProvider.resolveEndpoint(_aiBaseUrl.text, 'chat/completions');
      final settings = AppScope.of(context).settings;
      await settings.setAiBaseUrl(_aiBaseUrl.text);
      await settings.setAiModel(_aiModel.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI service settings saved.')),
        );
      }
    } on AiFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.userMessage)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save AI settings.')),
        );
      }
    }
  }

  Future<void> _saveKey() async {
    final key = _aiKey.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an API key first.')),
      );
      return;
    }
    try {
      await AppScope.of(context).credentials.writeKey(key);
      if (!mounted) return;
      setState(() {
        _keyConfigured = true;
      });
      _aiKey.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API key stored in this device\u2019s secure storage.'),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not store the key.')),
        );
      }
    }
  }

  Future<void> _testConnection() async {
    if (_testingConnection) return;
    setState(() => _testingConnection = true);
    try {
      final scope = AppScope.of(context);
      final probe = RemoteAIProvider.withDefaultClient(
        readApiKey: scope.credentials.readKey,
        baseUrl: _aiBaseUrl.text,
        model: _aiModel.text,
      );
      await probe.testConnection();
      await probe.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connected to the AI service.')),
        );
      }
    } on AiFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.userMessage)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection test failed.')),
        );
      }
    } finally {
      if (mounted) setState(() => _testingConnection = false);
    }
  }

  Future<void> _clearAi() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear AI configuration?'),
        content: const Text(
          'Deletes the stored API key and resets the service address, '
          'model, and mode. The app returns to local-only replies.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final scope = AppScope.of(context);
      await scope.credentials.deleteKey();
      await scope.settings.setAiEnabled(false);
      await scope.settings.setAiModeName('localOnly');
      await scope.settings.setAiBaseUrl(AiModeDefaults.baseUrl);
      await scope.settings.setAiModel(AiModeDefaults.model);
      if (!mounted) return;
      setState(() {
        _aiEnabled = false;
        _aiMode = 'localOnly';
        _keyConfigured = false;
        _aiBaseUrl.text = AiModeDefaults.baseUrl;
        _aiModel.text = AiModeDefaults.model;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI configuration cleared.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not clear AI settings.')),
        );
      }
    }
  }

  Future<void> _export() async {
    try {
      final payload = await buildExport(AppScope.of(context));
      final text = const JsonEncoder.withIndent('  ').convert(payload);
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Export copied (${text.length} chars). Paste it somewhere safe.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed.')),
        );
      }
    }
  }

  /// Import from clipboard: validate first, show counts, confirm, then
  /// write. Existing data is never overwritten (fresh ids on import).
  Future<void> _import() async {
    Map<String, Object?>? payload;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      if (text.trim().isEmpty) {
        throw const FormatException('empty');
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map) throw const FormatException('not an object');
      payload = decoded.map((k, v) => MapEntry('$k', v));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Clipboard has no valid export. Copy an export first.'),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    // Dry-run validation pass: import into nothing by checking shape first.
    final probe = _summarize(payload);
    if (probe == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Not a compatible export. Nothing imported.')),
        );
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import data?'),
        content: Text(
          'Found ${probe.conversations} conversation(s) with '
          '${probe.messages} message(s). They will be added as new '
          'entries — existing data stays untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final result =
          await importData(AppScope.of(context), payload);
      if (!mounted) return;
      if (!result.ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.errors.join(' '))),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${result.importedConversations} conversation(s), '
            '${result.importedMessages} message(s)'
            '${result.skippedRows > 0 ? ', skipped ${result.skippedRows} bad row(s)' : ''}.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Import failed. Nothing written.')),
        );
      }
    }
  }

  /// Read-only shape summary for the confirm dialog (no writes).
  _ImportSummary? _summarize(Map<String, Object?> payload) {
    if (payload['format'] != ExportFormat.format) return null;
    if (payload['version'] != ExportFormat.version) return null;
    final rawConvs = payload['conversations'];
    if (rawConvs is! List) return null;
    var msgs = 0;
    for (final c in rawConvs) {
      if (c is Map) {
        final m = c['messages'];
        if (m is List) msgs += m.length;
      }
    }
    return _ImportSummary(rawConvs.length, msgs);
  }

  Future<void> _deleteAllConversations() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all conversations?'),
        content: const Text(
          'Every conversation and message on this device will be '
          'permanently deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await AppScope.of(context).conversations.clearAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All conversations deleted.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delete failed.')),
        );
      }
    }
  }

  Future<void> _resetApp() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset application?'),
        content: const Text(
          'Clears conversations, drafts, companion settings, and all '
          'preferences on this device, then restarts onboarding. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset everything'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await AppScope.of(context).resetAll();
      themeSelection.value = AppThemeMode.system;
      textScaleSelection.value = 1.0;
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.onboarding,
          (_) => false,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reset failed.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  _section('Appearance'),
                  ListTile(
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text('Theme'),
                    subtitle: ValueListenableBuilder<AppThemeMode>(
                      valueListenable: themeSelection,
                      builder: (context, m, _) => Text(m.name),
                    ),
                    onTap: _pickTheme,
                  ),
                  _section('Companion'),
                  ListTile(
                    leading: const Icon(Icons.smart_toy_outlined),
                    title: const Text('Customize companion'),
                    subtitle: const Text(
                        'Name, look, style, your name'),
                    onTap: () => Navigator.of(context)
                        .pushNamed(AppRoutes.customize),
                  ),
                  _section('Daily companion (on-device)'),
                  SwitchListTile(
                    title: const Text('Daily greeting on Home'),
                    value: _dailyGreeting,
                    onChanged: (v) async {
                      setState(() => _dailyGreeting = v);
                      try {
                        await AppScope.of(context)
                            .settings
                            .setDailyGreeting(v);
                      } catch (_) {}
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Daily question on Home'),
                    value: _dailyQuestion,
                    onChanged: (v) async {
                      setState(() => _dailyQuestion = v);
                      try {
                        await AppScope.of(context)
                            .settings
                            .setDailyQuestion(v);
                      } catch (_) {}
                    },
                  ),
                  _section('Conversations'),
                  SwitchListTile(
                    title: const Text('Programmed replies'),
                    subtitle: const Text(
                      'Companion answers with prewritten replies. '
                      'Never AI-generated.',
                    ),
                    value: _autoReply,
                    onChanged: (v) async {
                      setState(() => _autoReply = v);
                      try {
                        await AppScope.of(context)
                            .settings
                            .setAutoReply(v);
                      } catch (_) {}
                    },
                  ),
                  _section('AI companion (optional, remote)'),
                  SwitchListTile(
                    title: const Text('Enable remote AI'),
                    subtitle: const Text(
                      'Off by default. When off, everything stays on-device.',
                    ),
                    value: _aiEnabled,
                    onChanged: _setAiEnabled,
                  ),
                  if (_aiEnabled) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.spaceMd,
                      ),
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'auto',
                            label: Text('Auto fallback'),
                          ),
                          ButtonSegment(
                            value: 'remoteOnly',
                            label: Text('Remote only'),
                          ),
                        ],
                        selected: {_aiMode},
                        onSelectionChanged: (s) => _setAiMode(s.first),
                      ),
                    ),
                    const ListTile(
                      leading: Icon(Icons.cloud_outlined),
                      title: Text('OpenAI-compatible service'),
                      subtitle: Text(
                        'Chat Completions API. More providers can plug in '
                        'later without changing this screen.',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.spaceMd,
                      ),
                      child: TextField(
                        controller: _aiBaseUrl,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Service address (https)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.spaceSm),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.spaceMd,
                      ),
                      child: TextField(
                        controller: _aiModel,
                        decoration: const InputDecoration(
                          labelText: 'Model',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.spaceSm),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.spaceMd,
                      ),
                      child: SizedBox(
                        height: AppTokens.touchTarget,
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _saveAiEndpoint,
                          child: const Text('Save service settings'),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.spaceSm),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.spaceMd,
                      ),
                      child: TextField(
                        controller: _aiKey,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: _keyConfigured
                              ? 'API key (configured — enter to replace)'
                              : 'API key (stored securely on this device)',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.spaceSm),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.spaceMd,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: AppTokens.touchTarget,
                              child: OutlinedButton(
                                onPressed: _saveKey,
                                child: const Text('Save key'),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTokens.spaceSm),
                          Expanded(
                            child: SizedBox(
                              height: AppTokens.touchTarget,
                              child: OutlinedButton(
                                onPressed: _testingConnection
                                    ? null
                                    : _testConnection,
                                child: Text(_testingConnection
                                    ? 'Testing…'
                                    : 'Test connection'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: const Text('Clear AI configuration'),
                      subtitle: const Text(
                          'Deletes the key and returns to local-only.'),
                      onTap: _clearAi,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTokens.spaceMd,
                      ),
                      child: Text(
                        'Privacy: with remote AI enabled, the messages you '
                        'send may be transmitted to the configured AI service '
                        'to generate replies. Local-only mode sends nothing '
                        'anywhere. You can return to local-only at any time '
                        'by turning remote AI off or clearing this section. '
                        'This app makes no claim about how the remote service '
                        'encrypts, retains, or deletes your data — check the '
                        'provider\u2019s own policy.',
                      ),
                    ),
                  ],
                  _section('Accessibility'),
                  ListTile(
                    leading: const Icon(Icons.text_fields),
                    title: Text(
                        'Text size: ${(_textScale * 100).round()}%'),
                    subtitle: Slider(
                      value: _textScale,
                      min: 0.8,
                      max: 1.3,
                      divisions: 10,
                      label: '${(_textScale * 100).round()}%',
                      onChanged: (v) async {
                        setState(() => _textScale = v);
                        textScaleSelection.value = v;
                        try {
                          await AppScope.of(context)
                              .settings
                              .setTextScale(v);
                        } catch (_) {}
                      },
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Reduced motion'),
                    subtitle: const Text(
                        'Disables animated transitions.'),
                    value: _reducedMotion,
                    onChanged: (v) async {
                      setState(() => _reducedMotion = v);
                      try {
                        await AppScope.of(context)
                            .settings
                            .setReducedMotion(v);
                      } catch (_) {}
                    },
                  ),
                  _section('Privacy & data (this device only)'),
                  ListTile(
                    leading: const Icon(Icons.ios_share),
                    title: const Text('Export data'),
                    subtitle: const Text(
                        'Copies everything to the clipboard as JSON.'),
                    onTap: _export,
                  ),
                  ListTile(
                    leading: const Icon(Icons.file_download_outlined),
                    title: const Text('Import data'),
                    subtitle: const Text(
                        'Pastes a previously copied export. Adds as new entries.'),
                    onTap: _import,
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Delete all conversations'),
                    onTap: _deleteAllConversations,
                  ),
                  ListTile(
                    leading: const Icon(Icons.restart_alt_outlined),
                    title: const Text('Reset application'),
                    subtitle: const Text(
                        'Clears everything and restarts onboarding.'),
                    onTap: _resetApp,
                  ),
                  _section('About'),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('About this app'),
                    subtitle: const Text(
                      'Version, local-only guarantee, and programmed-reply note.',
                    ),
                    onTap: () => Navigator.of(context)
                        .pushNamed(AppRoutes.about),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.spaceMd,
          AppTokens.spaceMd,
          AppTokens.spaceMd,
          AppTokens.spaceXs,
        ),
        child: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
}

class _ImportSummary {
  final int conversations;
  final int messages;
  const _ImportSummary(this.conversations, this.messages);
}

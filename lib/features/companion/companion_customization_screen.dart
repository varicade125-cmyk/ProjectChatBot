import 'package:flutter/material.dart';

import '../../core/scope/app_scope.dart';
import '../../data/models/companion_profile.dart';
import '../../theme/app_tokens.dart';
import 'avatars.dart';

/// Companion customization. All fields persist to `companion_profile`.
/// Edits apply only when Save is tapped (no silent partial writes).
class CompanionCustomizationScreen extends StatefulWidget {
  const CompanionCustomizationScreen({super.key});

  @override
  State<CompanionCustomizationScreen> createState() =>
      _CompanionCustomizationScreenState();
}

class _CompanionCustomizationScreenState
    extends State<CompanionCustomizationScreen> {
  CompanionProfile? _profile;
  String? _error;
  bool _saving = false;

  late TextEditingController _name;
  late TextEditingController _userName;
  late TextEditingController _interests;
  late TextEditingController _avoid;
  String? _avatarRef;
  String _respLength = 'medium';
  int _humor = 50;
  int _emoji = 50;
  Map<String, int> _axes = Map.of(CompanionProfile.defaultAxes);

  static const _axisLabels = {
    'formal': 'Formal ↔ Casual',
    'talkative': 'Quiet ↔ Talkative',
    'playful': 'Serious ↔ Playful',
    'gentle': 'Direct ↔ Gentle',
    'energetic': 'Calm ↔ Energetic',
  };

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _userName = TextEditingController();
    _interests = TextEditingController();
    _avoid = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final p = await AppScope.of(context).companion.getOrCreate();
      if (!mounted) return;
      setState(() {
        _profile = p;
        _name.text = p.name;
        _userName.text = p.userName ?? '';
        _interests.text = p.interests.join(', ');
        _avoid.text = p.avoidTopics.join(', ');
        _avatarRef = p.avatarRef;
        _respLength = p.respLength;
        _humor = p.humor;
        _emoji = p.emoji;
        _axes = Map.of(p.axes);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _userName.dispose();
    _interests.dispose();
    _avoid.dispose();
    super.dispose();
  }

  List<String> _csv(TextEditingController c) => c.text
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _save() async {
    final base = _profile;
    if (base == null || _saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Companion needs a name.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final scope = AppScope.of(context);
      final saved = await scope.companion.save(
        base.copyWith(
          name: name,
          avatarRef: () => _avatarRef,
          axes: Map.of(_axes),
          humor: _humor,
          emoji: _emoji,
          respLength: _respLength,
          interests: _csv(_interests),
          avoidTopics: _csv(_avoid),
          userName: () =>
              _userName.text.trim().isEmpty ? null : _userName.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _profile = saved;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Companion saved on this device.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Nothing was changed.')),
      );
    }
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset companion?'),
        content: const Text(
          'Name, look, and preferences return to defaults. '
          'Your conversations are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await AppScope.of(context).companion.resetToDefaults();
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not reset.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customize companion'),
        actions: [
          IconButton(
            tooltip: 'Reset to defaults',
            onPressed: _reset,
            icon: const Icon(Icons.restart_alt_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: _error != null
            ? Center(child: Text('Could not load profile.\n$_error'))
            : _profile == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding:
                        const EdgeInsets.all(AppTokens.spaceMd),
                    children: [
                      TextField(
                        controller: _name,
                        maxLength: 30,
                        decoration: const InputDecoration(
                          labelText: 'Companion name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AppTokens.spaceMd),
                      TextField(
                        controller: _userName,
                        maxLength: 30,
                        decoration: const InputDecoration(
                          labelText: 'Your preferred name (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AppTokens.spaceMd),
                      Text('Look',
                          style:
                              Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppTokens.spaceSm),
                      Wrap(
                        spacing: AppTokens.spaceSm,
                        children: [
                          for (final e in companionAvatars.entries)
                            ChoiceChip(
                              label: Icon(e.value),
                              selected: _avatarRef == e.key,
                              onSelected: (_) =>
                                  setState(() => _avatarRef = e.key),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppTokens.spaceMd),
                      Text('Reply length',
                          style:
                              Theme.of(context).textTheme.titleMedium),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: 'short', label: Text('Short')),
                          ButtonSegment(
                              value: 'medium', label: Text('Medium')),
                          ButtonSegment(
                              value: 'long', label: Text('Long')),
                        ],
                        selected: {_respLength},
                        onSelectionChanged: (s) =>
                            setState(() => _respLength = s.first),
                      ),
                      _slider('Humor', _humor,
                          (v) => setState(() => _humor = v)),
                      _slider('Emoji use', _emoji,
                          (v) => setState(() => _emoji = v)),
                      for (final e in _axisLabels.entries)
                        _slider(e.value, _axes[e.key] ?? 50,
                            (v) => setState(() => _axes[e.key] = v)),
                      const SizedBox(height: AppTokens.spaceSm),
                      TextField(
                        controller: _interests,
                        decoration: const InputDecoration(
                          labelText: 'Interests (comma separated)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AppTokens.spaceMd),
                      TextField(
                        controller: _avoid,
                        decoration: const InputDecoration(
                          labelText: 'Topics to avoid (comma separated)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AppTokens.spaceLg),
                      SizedBox(
                        height: AppTokens.touchTarget,
                        child: FilledButton(
                          key: const ValueKey(
                              'customizeSaveButton'),
                          onPressed: _saving ? null : _save,
                          child: Text(
                              _saving ? 'Saving…' : 'Save'),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _slider(String label, int value, ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppTokens.spaceSm),
        Text('$label: $value'),
        Slider(
          value: value.toDouble(),
          min: 0,
          max: 100,
          divisions: 20,
          label: '$value',
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}

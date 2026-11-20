import 'package:flutter/material.dart';

import '../../core/scope/app_scope.dart';
import '../../core/utils/format.dart';
import '../../data/models/conversation.dart';
import '../../navigation/app_router.dart';
import '../../theme/app_tokens.dart';

/// Conversation history: search, active/archived filter, open, create,
/// rename, pin, archive, delete (destructive actions confirmed).
/// Local-only; backed by ConversationRepository.
class ConversationHistoryScreen extends StatefulWidget {
  const ConversationHistoryScreen({super.key});

  @override
  State<ConversationHistoryScreen> createState() =>
      _ConversationHistoryScreenState();
}

class _ConversationHistoryScreenState
    extends State<ConversationHistoryScreen> {
  final TextEditingController _search = TextEditingController();
  List<Conversation> _items = const [];
  bool _loading = true;
  String? _error;
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _query => _search.text.trim();

  Future<void> _reload() async {
    try {
      final items = await AppScope.of(context).conversations.search(
            _query,
            archived: _showArchived,
            limit: 100,
          );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _open(String id) async {
    await Navigator.of(context)
        .pushNamed(AppRoutes.chat, arguments: {'conversationId': id});
    _reload();
  }

  Future<void> _create() async {
    try {
      final conv = await AppScope.of(context)
          .conversations
          .create(title: 'New conversation');
      if (!mounted) return;
      await Navigator.of(context)
          .pushNamed(AppRoutes.chat, arguments: {'conversationId': conv.id});
      _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create conversation.')),
        );
      }
    }
  }

  Future<void> _rename(Conversation c) async {
    final next = await showDialog<String>(
      context: context,
      builder: (context) => _RenameDialog(initial: c.title),
    );
    if (next == null || next.isEmpty || !mounted) return;
    try {
      await AppScope.of(context).conversations.rename(c.id, next);
      _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not rename.')),
        );
      }
    }
  }

  Future<void> _togglePin(Conversation c) async {
    try {
      await AppScope.of(context)
          .conversations
          .setPinned(c.id, !c.isPinned);
      _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update pin.')),
        );
      }
    }
  }

  Future<void> _toggleArchive(Conversation c) async {
    try {
      await AppScope.of(context)
          .conversations
          .setArchived(c.id, !c.isArchived);
      _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update archive.')),
        );
      }
    }
  }

  Future<void> _delete(Conversation c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: Text(
          '"${c.title}" and its ${c.messageCount} message(s) will be '
          'permanently deleted from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await AppScope.of(context).conversations.delete(c.id);
      _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conversations')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        tooltip: 'New conversation',
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.spaceMd,
                AppTokens.spaceSm,
                AppTokens.spaceMd,
                0,
              ),
              child: TextField(
                controller: _search,
                onChanged: (_) => _reload(),
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search conversations',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppTokens.spaceSm),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Active')),
                  ButtonSegment(value: true, label: Text('Archived')),
                ],
                selected: {_showArchived},
                onSelectionChanged: (s) {
                  setState(() => _showArchived = s.first);
                  _reload();
                },
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                  'Could not load conversations.'),
                              FilledButton(
                                onPressed: _reload,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _items.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(
                                    AppTokens.spaceLg),
                                child: Text(
                                  _query.isNotEmpty
                                      ? 'No matches for "$_query".'
                                      : _showArchived
                                          ? 'No archived conversations.'
                                          : 'No conversations yet.\nTap New to start one.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _items.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final c = _items[i];
                                return ListTile(
                                  leading: c.isPinned
                                      ? const Icon(
                                          Icons.push_pin_outlined,
                                          size: 20,
                                        )
                                      : null,
                                  title: Text(c.title),
                                  subtitle: Text(
                                    '${c.lastMessagePreview ?? 'No messages yet'}'
                                    '\n${formatMessageTime(c.updatedAt)}'
                                    ' • ${c.messageCount} message(s)',
                                  ),
                                  isThreeLine: true,
                                  onTap: () => _open(c.id),
                                  trailing: PopupMenuButton<String>(
                                    tooltip: 'Conversation options',
                                    onSelected: (v) {
                                      if (v == 'rename') _rename(c);
                                      if (v == 'pin') _togglePin(c);
                                      if (v == 'archive') {
                                        _toggleArchive(c);
                                      }
                                      if (v == 'delete') _delete(c);
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'rename',
                                        child: Text('Rename'),
                                      ),
                                      PopupMenuItem(
                                        value: 'pin',
                                        child: Text(c.isPinned
                                            ? 'Unpin'
                                            : 'Pin'),
                                      ),
                                      PopupMenuItem(
                                        value: 'archive',
                                        child: Text(c.isArchived
                                            ? 'Unarchive'
                                            : 'Archive'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rename dialog owning its controller: disposal happens in State.dispose,
/// which the route guarantees runs after the dialog tree is gone.
/// (Disposing synchronously after `await showDialog` is a use-after-dispose
/// race against the exit transition.)
class _RenameDialog extends StatefulWidget {
  final String initial;
  const _RenameDialog({required this.initial});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename conversation'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 60,
        decoration: const InputDecoration(labelText: 'Title'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

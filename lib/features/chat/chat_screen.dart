import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/scope/app_scope.dart';
import '../../core/utils/format.dart';
import '../../data/models/conversation.dart';
import '../../data/models/message.dart';
import '../../theme/app_tokens.dart';
import '../ai/ai_provider.dart';
import '../ai/chat_pipeline.dart';

/// S3 Chat — conversation log with optional AI backend (Phase 6).
/// - Opens [conversationId] or the default thread; messages + drafts persist.
/// - Default is local programmed replies ([LocalResponder], captioned).
/// - When remote AI is enabled, replies come from the configured provider
///   (captioned "AI reply"); failures persist NOTHING fake and show retry UI.
/// See docs/17-phase6-ai-integration.md.
class ChatScreen extends StatefulWidget {
  final String? initialPrompt;
  final String? conversationId;
  const ChatScreen({super.key, this.initialPrompt, this.conversationId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _composer = TextEditingController();
  ChatPipeline? _pipeline;
  Conversation? _conversation;
  List<Message> _thread = const []; // oldest-first for rendering
  String? _loadError;
  bool _sending = false;

  /// Remote-only failure awaiting retry. No assistant row was persisted.
  AiFailure? _sendError;
  String? _failedUserText;

  @override
  void initState() {
    super.initState();
    // Deferred: AppScope.of subscribes to an InheritedWidget, which is
    // illegal during initState itself. Post-frame keeps routing intact.
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    try {
      final scope = AppScope.of(context);
      _pipeline ??= ChatPipeline(scope: scope, ai: scope.ai);
      Conversation? conv;
      if (widget.conversationId != null) {
        conv = await scope.conversations.byId(widget.conversationId!);
      }
      conv ??= await scope.conversations.ensureDefault();
      await _reloadThread(conv);
      final draft =
          widget.initialPrompt ?? await scope.drafts.get(conv.id);
      if (!mounted) return;
      setState(() {
        _conversation = conv;
        if (draft != null) _composer.text = draft;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = '$e');
    }
  }

  Future<void> _reloadThread(Conversation conv) async {
    final scope = AppScope.of(context);
    final newestFirst = await scope.messages.page(conv.id, limit: 100);
    if (!mounted) return;
    setState(() => _thread = newestFirst.reversed.toList());
  }

  Future<void> _onSend() async {
    final text = _composer.text.trim();
    final conv = _conversation;
    final pipe = _pipeline;
    if (text.isEmpty || conv == null || pipe == null || _sending) return;
    setState(() {
      _sending = true;
      _sendError = null;
      _failedUserText = null;
    });
    try {
      final scope = AppScope.of(context);
      final result = await pipe.send(conv.id, text);
      await scope.drafts.clear(conv.id);
      if (!mounted) return;
      await _reloadThread(conv);
      if (!mounted) return;
      setState(() => _composer.clear());
      if (result.outcome == ChatSendOutcome.remoteFailed) {
        setState(() {
          _sendError = result.failure;
          _failedUserText = result.userText;
        });
      } else if (result.fallbackUsed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'AI unavailable — programmed reply used instead.'),
          ),
        );
      }
    } catch (_) {
      // Never silently lose the message: text stays in the composer
      // and the user can retry.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not save — kept in composer. Retry.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _onRetry() async {
    final conv = _conversation;
    final pipe = _pipeline;
    final userText = _failedUserText;
    if (conv == null || pipe == null || userText == null || _sending) return;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final result = await pipe.retry(conv.id, userText);
      if (!mounted) return;
      await _reloadThread(conv);
      if (!mounted) return;
      if (result.outcome == ChatSendOutcome.remoteFailed) {
        setState(() {
          _sendError = result.failure;
          _failedUserText = result.userText;
        });
      } else {
        setState(() => _failedUserText = null);
        if (result.fallbackUsed && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'AI unavailable — programmed reply used instead.'),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _sendError = AiFailure.network();
          _failedUserText = userText;
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _onUseProgrammed() async {
    final conv = _conversation;
    final pipe = _pipeline;
    final userText = _failedUserText;
    if (conv == null || pipe == null || userText == null || _sending) return;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      await pipe.sendLocalFallback(conv.id, userText);
      if (!mounted) return;
      await _reloadThread(conv);
      if (!mounted) return;
      setState(() => _failedUserText = null);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save reply.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  static String _preview(String body) =>
      body.length <= 120 ? body : '${body.substring(0, 120)}…';

  @override
  void dispose() {
    _pipeline?.cancel();
    _composer.dispose();
    super.dispose();
  }

  Future<void> _deleteMessage(Message m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text('Delete message?'),
        content: Text('This message will be removed from this device.'),
        actions: [
          _CancelButton(),
          _ConfirmDeleteButton(),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final scope = AppScope.of(context);
      await scope.messages.delete(m.id);
      final conv = _conversation!;
      final count = await scope.messages.count(conv.id);
      final newest = await scope.messages.page(conv.id, limit: 100);
      await scope.conversations.touch(
        id: conv.id,
        preview: newest.isEmpty ? '' : _preview(newest.first.body),
        messageCount: count,
      );
      if (!mounted) return;
      setState(() => _thread = newest.reversed.toList());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete message.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_conversation?.title ?? 'Chat')),
      body: SafeArea(
        child: _loadError != null
            ? _LoadError(
                message: _loadError!,
                onRetry: () {
                  setState(() => _loadError = null);
                  _boot();
                })
            : _conversation == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Expanded(
                        child: _thread.isEmpty && !_sending
                            ? _EmptyState(
                                onPick: (s) => _composer.text = s)
                            : ListView.builder(
                                padding: const EdgeInsets.all(
                                    AppTokens.spaceMd),
                                itemCount: _thread.length +
                                    (_sending ? 1 : 0),
                                itemBuilder: (context, i) {
                                  if (i >= _thread.length) {
                                    return const _TypingBubble();
                                  }
                                  return _Bubble(
                                    message: _thread[i],
                                    onDelete: () =>
                                        _deleteMessage(_thread[i]),
                                  );
                                },
                              ),
                      ),
                      if (_sendError != null)
                        _SendErrorCard(
                          message: _sendError!.userMessage,
                          busy: _sending,
                          onRetry: _onRetry,
                          onUseProgrammed: _onUseProgrammed,
                        ),
                      const Divider(height: 1),
                      Padding(
                        padding:
                            const EdgeInsets.all(AppTokens.spaceSm),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _composer,
                                minLines: 1,
                                maxLines: AppTokens.maxComposerLines,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _onSend(),
                                onChanged: (v) {
                                  final id = _conversation?.id;
                                  if (id != null) {
                                    // Fire-and-forget draft autosave; a
                                    // failed write only loses the draft,
                                    // never the conversation.
                                    AppScope.of(context)
                                        .drafts
                                        .set(id, v);
                                  }
                                },
                                decoration: const InputDecoration(
                                  hintText: 'Message',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTokens.spaceSm),
                            SizedBox(
                              height: AppTokens.touchTarget,
                              width: AppTokens.touchTarget,
                              child: IconButton.filled(
                                tooltip: 'Send',
                                onPressed:
                                    _sending ? null : _onSend,
                                icon: _sending
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.send_outlined),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Message message;
  final VoidCallback onDelete;
  const _Bubble({required this.message, required this.onDelete});

  Future<void> _showOptions(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copy'),
              onTap: () => Navigator.of(context).pop('copy'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (choice == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.body));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message copied.')),
        );
      }
    } else if (choice == 'delete') {
      onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = message.role == MessageRole.user;
    final theme = Theme.of(context);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showOptions(context),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.spaceSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message.body),
                  const SizedBox(height: 2),
                  Text(
                    formatMessageTime(message.createdAt),
                    style: theme.textTheme.labelSmall,
                  ),
                  if (!mine)
                    Text(
                      message.provider == MessageProvider.remote
                          ? 'AI reply • remote service'
                          : 'programmed reply • not AI',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Card(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}

/// Non-technical remote-failure card. The user's message is already
/// persisted and untouched; Retry re-attempts without duplicating it.
class _SendErrorCard extends StatelessWidget {
  final String message;
  final bool busy;
  final VoidCallback onRetry;
  final VoidCallback onUseProgrammed;
  const _SendErrorCard({
    required this.message,
    required this.busy,
    required this.onRetry,
    required this.onUseProgrammed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.all(AppTokens.spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: TextStyle(color: scheme.onErrorContainer),
          ),
          const SizedBox(height: AppTokens.spaceXs),
          Row(
            children: [
              FilledButton(
                onPressed: busy ? null : onRetry,
                child: const Text('Retry'),
              ),
              const SizedBox(width: AppTokens.spaceSm),
              OutlinedButton(
                onPressed: busy ? null : onUseProgrammed,
                child: const Text('Use programmed reply'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => Navigator.of(context).pop(false),
      child: const Text('Cancel'),
    );
  }
}

class _ConfirmDeleteButton extends StatelessWidget {
  const _ConfirmDeleteButton();

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () => Navigator.of(context).pop(true),
      child: const Text('Delete'),
    );
  }
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: AppTokens.spaceSm),
            const Text('Could not load this conversation.'),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppTokens.spaceSm),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final void Function(String) onPick;
  const _EmptyState({required this.onPick});

  static const _chips = ['Say hi', 'Plan my day', 'Tell me a story'];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      children: [
        const Icon(Icons.chat_bubble_outline, size: 56),
        const SizedBox(height: AppTokens.spaceMd),
        Text(
          'Start talking',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppTokens.spaceSm),
        const Text(
          'Write freely — everything stays on this device.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppTokens.spaceMd),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppTokens.spaceSm,
          children: [
            for (final c in _chips)
              ActionChip(label: Text(c), onPressed: () => onPick(c)),
          ],
        ),
      ],
    );
  }
}

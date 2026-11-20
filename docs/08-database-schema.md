# 08 — Database Schema (v1, as built)
(Reconstructed 2026-09-25; matches `AppDb._createV1` exactly.)

`user_profile(id, displayName, createdAt, updatedAt)`.
`companion_profile(id, name, avatarRef, axesJson, humor, emoji, respLength,
interests, avoidTopics, userName, commPrefs, version, createdAt, updatedAt)`.
`conversations(id, title, isArchived, isPinned, createdAt, updatedAt,
lastMessagePreview, messageCount, summary)` + index
`idx_conv_updated(isArchived, isPinned DESC, updatedAt DESC)`.
`messages(id, conversationId FK CASCADE, role user|assistant|system, body,
status {sending,sent,failed_retryable,failed_final,queued_offline,
streaming,interrupted}, createdAt, updatedAt, requestId)` + index
`idx_msg_conv(conversationId, createdAt)`.
`memories(...)` + `idx_mem_key` (reserved, unused). `notification_schedules`,
`journal_entries`, `app_settings(key,value,updatedAt)`,
`kv_drafts(conversationId, body, updatedAt)`.

Version 1, WAL + foreign_keys=ON, batch create, transactional writes,
paged reads (50 default). Migration path reserved (`_migrate`, tested via
reopen test). FTS5/vector tables reserved, not created.

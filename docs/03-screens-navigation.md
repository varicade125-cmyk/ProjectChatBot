# 03 — Screen / Navigation Map
(Reconstructed 2026-09-25; matches as-built screens and AppRoutes.)

S1 Onboarding: skippable 3-page pager, persists flag, reduced-motion aware.
S2 Home: companion card (name/avatar), daily card (toggles), Resume,
Conversations, Activities, starters. S3 Chat: thread/drafts/persisted send,
programmed reply with caption, timestamps, copy/delete, empty/error states.
S4 History: search, Active/Archived segments, open/new/rename/pin/archive/
delete with confirms. S5 Companion customization: name/avatar/axes/humor/
emoji/length/interests/avoid/user-name, Save + reset-with-confirm.
S6 Activities: 7 prompt sets + coin/dice, copy/another/open-in-chat.
S7 Settings: theme, companion, daily, programmed replies, text size,
reduced motion, export/import, delete-all, reset, about.
S8 About: version + local-only guarantee.

Navigation: named routes /onboarding /home /chat /history /activities
/customize /settings /about; chat takes {conversationId?, initialPrompt?}
(or legacy String prompt); unknown → home; destructive actions confirmed;
last state restored after restart (onboarding flag, theme, drafts, threads).
Simple stack over tab-bar-everywhere (chat-first product).

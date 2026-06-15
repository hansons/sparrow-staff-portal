-- Sparrow Staff Portal — @mention notifications for chat messages.
-- Extends the notification_type enum with 'mentioned', adds a channel_id
-- column so the notification links back to the conversation, and exposes a
-- SECURITY DEFINER RPC so the client can insert mention rows (the notifications
-- table has no INSERT policy by design — only definer functions may write to it).
-- Run after 0013_chat.sql and 0003_notifications.sql.

-- 1. Extend the enum (idempotent — safe to re-run)
alter type notification_type add value if not exists 'mentioned';

-- 2. Link mention notifications back to their conversation
alter table notifications
  add column if not exists channel_id uuid references chat_channels(id) on delete cascade;

-- 3. Generic entity pointer columns (used by future notification types)
alter table notifications
  add column if not exists entity text;
alter table notifications
  add column if not exists entity_id uuid;

-- 4. SECURITY DEFINER RPC called by the client after sending a message.
--    Inserts one 'mentioned' notification per unique mentioned user, skipping
--    the sender themselves.
create or replace function chat_notify_mentions(
  p_mentioned_ids uuid[],
  p_actor_id      uuid,
  p_channel_id    uuid,
  p_body          text
) returns void
  language plpgsql security definer set search_path = public as $$
declare
  uid uuid;
begin
  if p_mentioned_ids is null or array_length(p_mentioned_ids, 1) is null then
    return;
  end if;
  foreach uid in array p_mentioned_ids loop
    if uid is distinct from p_actor_id then
      insert into notifications (user_id, actor_id, type, channel_id, body)
      values (uid, p_actor_id, 'mentioned', p_channel_id, p_body);
    end if;
  end loop;
end $$;

grant execute on function chat_notify_mentions(uuid[], uuid, uuid, text) to authenticated;

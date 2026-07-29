-- Migration: WorthIt Notifications Automation Schema Update
-- Standardizes public.notifications table structure for automated system events (PRICE_DROP, PRO_EXPIRING, etc.)

alter table public.notifications
    add column if not exists body text,
    add column if not exists type varchar(50) not null default 'INFO',
    add column if not exists payload jsonb default '{}'::jsonb;

-- Migrate data from legacy 'message' column if present
do $$
begin
    if exists (
        select 1 from information_schema.columns 
        where table_schema = 'public' and table_name = 'notifications' and column_name = 'message'
    ) then
        update public.notifications set body = message where (body is null or body = '');
    end if;
end $$;

-- Optimize index for querying unread & latest notifications per user
create index if not exists idx_notifications_user_unread
    on public.notifications(user_id, is_read, created_at desc);

create index if not exists idx_notifications_user_type_created
    on public.notifications(user_id, type, created_at desc);

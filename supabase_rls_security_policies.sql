-- WorthIt production RLS hardening.
-- Run this in Supabase SQL Editor, or via the Supabase MCP/CLI.

-- User-owned tables.
alter table public.users enable row level security;
alter table public.subscriptions enable row level security;
alter table public.scan_history enable row level security;
alter table public.favorite_products enable row level security;
alter table public.notifications enable row level security;
alter table public.monthly_shopping_lists enable row level security;
alter table public.shopping_list_items enable row level security;
alter table public.purchase_history enable row level security;

-- Catalog/reference tables: readable by the app, not writable from public clients.
alter table public.products enable row level security;
alter table public.price_history enable row level security;
alter table public.weekly_prices enable row level security;

-- Helpful indexes for owner checks used by RLS.
create index if not exists idx_subscriptions_user_id on public.subscriptions (user_id);
create index if not exists idx_scan_history_user_id on public.scan_history (user_id);
create index if not exists idx_favorite_products_user_id on public.favorite_products (user_id);
create index if not exists idx_notifications_user_id on public.notifications (user_id);
create index if not exists idx_monthly_shopping_lists_user_id on public.monthly_shopping_lists (user_id);
create index if not exists idx_purchase_history_user_id on public.purchase_history (user_id);
create index if not exists idx_shopping_list_items_list_id on public.shopping_list_items (list_id);

-- public.users
drop policy if exists "users_select_own" on public.users;
drop policy if exists "users_insert_own" on public.users;
drop policy if exists "users_update_own" on public.users;
drop policy if exists "users_delete_own" on public.users;

create policy "users_select_own"
on public.users for select
to authenticated
using ((select auth.uid()) = id);

create policy "users_insert_own"
on public.users for insert
to authenticated
with check ((select auth.uid()) = id);

create policy "users_update_own"
on public.users for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

create policy "users_delete_own"
on public.users for delete
to authenticated
using ((select auth.uid()) = id);

-- public.subscriptions
drop policy if exists "subscriptions_select_own" on public.subscriptions;
drop policy if exists "subscriptions_insert_own" on public.subscriptions;
drop policy if exists "subscriptions_update_own" on public.subscriptions;
drop policy if exists "subscriptions_delete_own" on public.subscriptions;

create policy "subscriptions_select_own"
on public.subscriptions for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "subscriptions_insert_own"
on public.subscriptions for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "subscriptions_update_own"
on public.subscriptions for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "subscriptions_delete_own"
on public.subscriptions for delete
to authenticated
using ((select auth.uid()) = user_id);

-- public.scan_history (analysis history)
drop policy if exists "scan_history_select_own" on public.scan_history;
drop policy if exists "scan_history_insert_own" on public.scan_history;
drop policy if exists "scan_history_update_own" on public.scan_history;
drop policy if exists "scan_history_delete_own" on public.scan_history;

create policy "scan_history_select_own"
on public.scan_history for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "scan_history_insert_own"
on public.scan_history for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "scan_history_update_own"
on public.scan_history for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "scan_history_delete_own"
on public.scan_history for delete
to authenticated
using ((select auth.uid()) = user_id);

-- public.favorite_products (favorites)
drop policy if exists "favorite_products_select_own" on public.favorite_products;
drop policy if exists "favorite_products_insert_own" on public.favorite_products;
drop policy if exists "favorite_products_update_own" on public.favorite_products;
drop policy if exists "favorite_products_delete_own" on public.favorite_products;

create policy "favorite_products_select_own"
on public.favorite_products for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "favorite_products_insert_own"
on public.favorite_products for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "favorite_products_update_own"
on public.favorite_products for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "favorite_products_delete_own"
on public.favorite_products for delete
to authenticated
using ((select auth.uid()) = user_id);

-- public.notifications
drop policy if exists "notifications_select_own" on public.notifications;
drop policy if exists "notifications_insert_own" on public.notifications;
drop policy if exists "notifications_update_own" on public.notifications;
drop policy if exists "notifications_delete_own" on public.notifications;

create policy "notifications_select_own"
on public.notifications for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "notifications_insert_own"
on public.notifications for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "notifications_update_own"
on public.notifications for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "notifications_delete_own"
on public.notifications for delete
to authenticated
using ((select auth.uid()) = user_id);

-- public.monthly_shopping_lists
drop policy if exists "monthly_shopping_lists_select_own" on public.monthly_shopping_lists;
drop policy if exists "monthly_shopping_lists_insert_own" on public.monthly_shopping_lists;
drop policy if exists "monthly_shopping_lists_update_own" on public.monthly_shopping_lists;
drop policy if exists "monthly_shopping_lists_delete_own" on public.monthly_shopping_lists;
drop policy if exists "Users can view their own monthly shopping lists." on public.monthly_shopping_lists;
drop policy if exists "Users can create their own monthly shopping lists." on public.monthly_shopping_lists;
drop policy if exists "Users can update their own monthly shopping lists." on public.monthly_shopping_lists;
drop policy if exists "Users can delete their own monthly shopping lists." on public.monthly_shopping_lists;

create policy "monthly_shopping_lists_select_own"
on public.monthly_shopping_lists for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "monthly_shopping_lists_insert_own"
on public.monthly_shopping_lists for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "monthly_shopping_lists_update_own"
on public.monthly_shopping_lists for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "monthly_shopping_lists_delete_own"
on public.monthly_shopping_lists for delete
to authenticated
using ((select auth.uid()) = user_id);

-- public.shopping_list_items (owned through monthly_shopping_lists)
drop policy if exists "shopping_list_items_select_own" on public.shopping_list_items;
drop policy if exists "shopping_list_items_insert_own" on public.shopping_list_items;
drop policy if exists "shopping_list_items_update_own" on public.shopping_list_items;
drop policy if exists "shopping_list_items_delete_own" on public.shopping_list_items;
drop policy if exists "Users can view their own shopping list items." on public.shopping_list_items;
drop policy if exists "Users can create their own shopping list items." on public.shopping_list_items;
drop policy if exists "Users can update their own shopping list items." on public.shopping_list_items;
drop policy if exists "Users can delete their own shopping list items." on public.shopping_list_items;

create policy "shopping_list_items_select_own"
on public.shopping_list_items for select
to authenticated
using (
  exists (
    select 1
    from public.monthly_shopping_lists lists
    where lists.id = shopping_list_items.list_id
      and lists.user_id = (select auth.uid())
  )
);

create policy "shopping_list_items_insert_own"
on public.shopping_list_items for insert
to authenticated
with check (
  exists (
    select 1
    from public.monthly_shopping_lists lists
    where lists.id = shopping_list_items.list_id
      and lists.user_id = (select auth.uid())
  )
);

create policy "shopping_list_items_update_own"
on public.shopping_list_items for update
to authenticated
using (
  exists (
    select 1
    from public.monthly_shopping_lists lists
    where lists.id = shopping_list_items.list_id
      and lists.user_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.monthly_shopping_lists lists
    where lists.id = shopping_list_items.list_id
      and lists.user_id = (select auth.uid())
  )
);

create policy "shopping_list_items_delete_own"
on public.shopping_list_items for delete
to authenticated
using (
  exists (
    select 1
    from public.monthly_shopping_lists lists
    where lists.id = shopping_list_items.list_id
      and lists.user_id = (select auth.uid())
  )
);

-- public.purchase_history (expenses)
drop policy if exists "purchase_history_select_own" on public.purchase_history;
drop policy if exists "purchase_history_insert_own" on public.purchase_history;
drop policy if exists "purchase_history_update_own" on public.purchase_history;
drop policy if exists "purchase_history_delete_own" on public.purchase_history;
drop policy if exists "Users can view their own purchase history." on public.purchase_history;
drop policy if exists "Users can create their own purchase history." on public.purchase_history;
drop policy if exists "Users can update their own purchase history." on public.purchase_history;
drop policy if exists "Users can delete their own purchase history." on public.purchase_history;

create policy "purchase_history_select_own"
on public.purchase_history for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "purchase_history_insert_own"
on public.purchase_history for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "purchase_history_update_own"
on public.purchase_history for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "purchase_history_delete_own"
on public.purchase_history for delete
to authenticated
using ((select auth.uid()) = user_id);

-- Catalog/reference tables: SELECT only. No INSERT/UPDATE/DELETE policies means
-- anon/authenticated clients cannot write to these tables while RLS is enabled.
drop policy if exists "products_select_catalog" on public.products;
drop policy if exists "price_history_select_catalog" on public.price_history;
drop policy if exists "weekly_prices_select_catalog" on public.weekly_prices;

create policy "products_select_catalog"
on public.products for select
to anon, authenticated
using (true);

create policy "price_history_select_catalog"
on public.price_history for select
to anon, authenticated
using (true);

create policy "weekly_prices_select_catalog"
on public.weekly_prices for select
to anon, authenticated
using (true);

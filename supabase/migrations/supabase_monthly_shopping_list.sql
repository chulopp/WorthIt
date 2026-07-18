-- WorthIt monthly shopping list schema for Supabase/PostgreSQL.
-- One active shopping list per user per YYYY-MM period.

create extension if not exists pgcrypto;

create table if not exists public.monthly_shopping_lists (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    period_month varchar(7) not null,
    total_budget integer not null default 0,
    created_at timestamptz not null default now(),
    constraint monthly_shopping_lists_user_period_unique unique (user_id, period_month),
    constraint monthly_shopping_lists_period_month_format check (period_month ~ '^[0-9]{4}-[0-9]{2}$')
);

create table if not exists public.shopping_list_items (
    id uuid primary key default gen_random_uuid(),
    list_id uuid not null references public.monthly_shopping_lists(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete restrict,
    quantity integer not null default 1,
    is_bought boolean not null default false,
    created_at timestamptz not null default now(),
    constraint shopping_list_items_quantity_positive check (quantity > 0),
    constraint shopping_list_items_list_product_unique unique (list_id, product_id)
);

create index if not exists idx_monthly_shopping_lists_user_period
    on public.monthly_shopping_lists(user_id, period_month);

create index if not exists idx_shopping_list_items_list_id
    on public.shopping_list_items(list_id);

create index if not exists idx_shopping_list_items_product_id
    on public.shopping_list_items(product_id);

alter table public.monthly_shopping_lists enable row level security;
alter table public.shopping_list_items enable row level security;

drop policy if exists "Users can view their own monthly shopping lists."
    on public.monthly_shopping_lists;
create policy "Users can view their own monthly shopping lists."
    on public.monthly_shopping_lists
    for select
    to authenticated
    using ((select auth.uid()) = user_id);

drop policy if exists "Users can create their own monthly shopping lists."
    on public.monthly_shopping_lists;
create policy "Users can create their own monthly shopping lists."
    on public.monthly_shopping_lists
    for insert
    to authenticated
    with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own monthly shopping lists."
    on public.monthly_shopping_lists;
create policy "Users can update their own monthly shopping lists."
    on public.monthly_shopping_lists
    for update
    to authenticated
    using ((select auth.uid()) = user_id)
    with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their own monthly shopping lists."
    on public.monthly_shopping_lists;
create policy "Users can delete their own monthly shopping lists."
    on public.monthly_shopping_lists
    for delete
    to authenticated
    using ((select auth.uid()) = user_id);

drop policy if exists "Users can view their own shopping list items."
    on public.shopping_list_items;
create policy "Users can view their own shopping list items."
    on public.shopping_list_items
    for select
    to authenticated
    using (
        exists (
            select 1
            from public.monthly_shopping_lists lists
            where lists.id = shopping_list_items.list_id
              and lists.user_id = (select auth.uid())
        )
    );

drop policy if exists "Users can create their own shopping list items."
    on public.shopping_list_items;
create policy "Users can create their own shopping list items."
    on public.shopping_list_items
    for insert
    to authenticated
    with check (
        exists (
            select 1
            from public.monthly_shopping_lists lists
            where lists.id = shopping_list_items.list_id
              and lists.user_id = (select auth.uid())
        )
    );

drop policy if exists "Users can update their own shopping list items."
    on public.shopping_list_items;
create policy "Users can update their own shopping list items."
    on public.shopping_list_items
    for update
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

drop policy if exists "Users can delete their own shopping list items."
    on public.shopping_list_items;
create policy "Users can delete their own shopping list items."
    on public.shopping_list_items
    for delete
    to authenticated
    using (
        exists (
            select 1
            from public.monthly_shopping_lists lists
            where lists.id = shopping_list_items.list_id
              and lists.user_id = (select auth.uid())
        )
    );

grant select, insert, update, delete on public.monthly_shopping_lists to authenticated, service_role;
grant select, insert, update, delete on public.shopping_list_items to authenticated, service_role;

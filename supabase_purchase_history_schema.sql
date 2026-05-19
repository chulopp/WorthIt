-- WorthIt purchase history and scan analysis snapshot schema.

create extension if not exists pgcrypto;

create table if not exists public.purchase_history (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references public.users(id) on delete set null,
    product_id uuid not null references public.products(id) on delete restrict,
    purchased_price integer not null,
    quantity integer not null default 1,
    purchased_at timestamptz not null default now(),
    constraint purchase_history_purchased_price_nonnegative check (purchased_price >= 0),
    constraint purchase_history_quantity_positive check (quantity > 0)
);

alter table public.scan_history
    add column if not exists urgency integer,
    add column if not exists weight_gram numeric,
    add column if not exists analysis_snapshot jsonb;

create index if not exists idx_purchase_history_user_id
    on public.purchase_history(user_id);

create index if not exists idx_purchase_history_product_id
    on public.purchase_history(product_id);

create index if not exists idx_purchase_history_user_purchased_at
    on public.purchase_history(user_id, purchased_at desc);

create index if not exists idx_scan_history_user_product_created
    on public.scan_history(user_id, product_id, created_at desc);

alter table public.purchase_history enable row level security;

drop policy if exists "Users can view their own purchase history."
    on public.purchase_history;
create policy "Users can view their own purchase history."
    on public.purchase_history
    for select
    to authenticated
    using ((select auth.uid()) = user_id);

drop policy if exists "Users can create their own purchase history."
    on public.purchase_history;
create policy "Users can create their own purchase history."
    on public.purchase_history
    for insert
    to authenticated
    with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own purchase history."
    on public.purchase_history;
create policy "Users can update their own purchase history."
    on public.purchase_history
    for update
    to authenticated
    using ((select auth.uid()) = user_id)
    with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their own purchase history."
    on public.purchase_history;
create policy "Users can delete their own purchase history."
    on public.purchase_history
    for delete
    to authenticated
    using ((select auth.uid()) = user_id);

grant select, insert, update, delete on public.purchase_history to authenticated, service_role;

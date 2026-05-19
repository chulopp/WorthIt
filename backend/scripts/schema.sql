-- WorthIt Supabase/PostgreSQL schema
-- Mirrors ERD_WorthIt.md plus the PRD conceptual substitutions mapping.

create extension if not exists pgcrypto;

insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do update set public = excluded.public;

do $$ begin
    create type subscription_tier as enum ('FREE', 'PRO');
exception when duplicate_object then null; end $$;

do $$ begin
    create type subscription_status as enum ('ACTIVE', 'CANCELED', 'EXPIRED');
exception when duplicate_object then null; end $$;

do $$ begin
    create type session_status as enum ('ACTIVE', 'COMPLETED');
exception when duplicate_object then null; end $$;

do $$ begin
    create type cart_action as enum ('BUY', 'SUBSTITUTE', 'SKIP');
exception when duplicate_object then null; end $$;

create table if not exists users (
    id uuid primary key default gen_random_uuid(),
    email varchar(255) unique not null,
    full_name varchar(255) not null,
    monthly_budget numeric(12,2) not null default 0.00,
    subscription_tier subscription_tier not null default 'FREE',
    pro_expires_at timestamptz,
    monthly_scan_count integer not null default 0,
    last_scan_reset_date timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists subscriptions (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references users(id) on delete cascade,
    google_order_id varchar(255) unique not null,
    purchase_token text unique not null,
    status subscription_status not null,
    purchased_at timestamptz not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists products (
    id uuid primary key default gen_random_uuid(),
    name varchar(255) not null,
    brand varchar(100),
    category varchar(100) not null,
    base_weight_gram numeric(10,2) not null,
    image_url text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (name, category)
);

alter table products add column if not exists image_url text;

create table if not exists price_history (
    id uuid primary key default gen_random_uuid(),
    product_id uuid not null references products(id) on delete cascade,
    price numeric(12,2) not null,
    weight_gram numeric(10,2) not null,
    unit_label text,
    recorded_at date not null default current_date,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists shopping_sessions (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references users(id) on delete cascade,
    budget_start numeric(12,2) not null,
    status session_status not null default 'ACTIVE',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists cart_items (
    id uuid primary key default gen_random_uuid(),
    session_id uuid not null references shopping_sessions(id) on delete cascade,
    product_id uuid not null references products(id) on delete restrict,
    price_paid numeric(12,2) not null,
    action_taken cart_action not null,
    decision_score integer check (decision_score between 0 and 100),
    wma_insight text,
    snr_insight text,
    is_fake_discount boolean not null default false,
    is_shrinkflation boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists scan_history (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references users(id) on delete cascade,
    session_id uuid references shopping_sessions(id) on delete set null,
    product_id uuid not null references products(id) on delete cascade,
    scan_result_score integer check (scan_result_score between 0 and 100),
    decision text,
    scanned_price numeric(12,2),
    normal_price numeric(12,2),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists favorite_products (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references users(id) on delete cascade,
    product_id uuid not null references products(id) on delete cascade,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (user_id, product_id)
);

create table if not exists notifications (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references users(id) on delete cascade,
    title varchar(255) not null,
    message text not null,
    is_read boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists substitutions (
    id uuid primary key default gen_random_uuid(),
    product_id uuid not null references products(id) on delete cascade,
    substitute_product_id uuid not null references products(id) on delete cascade,
    price_per_gram_ratio numeric(8,4) not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (product_id, substitute_product_id),
    check (product_id <> substitute_product_id)
);

create index if not exists idx_users_email on users(email);
create index if not exists idx_users_subscription_tier on users(subscription_tier);
create index if not exists idx_subscriptions_user_id on subscriptions(user_id);
create index if not exists idx_subscriptions_google_order_id on subscriptions(google_order_id);
create index if not exists idx_subscriptions_status on subscriptions(status);
create index if not exists idx_products_category on products(category);
create index if not exists idx_products_brand on products(brand);
create index if not exists idx_products_name_trgm on products using gin (to_tsvector('simple', name));
create index if not exists idx_price_history_product_id on price_history(product_id);
create index if not exists idx_price_history_recorded_at on price_history(recorded_at);
create index if not exists idx_price_history_product_recorded on price_history(product_id, recorded_at);
create index if not exists idx_shopping_sessions_user_id on shopping_sessions(user_id);
create index if not exists idx_shopping_sessions_status on shopping_sessions(status);
create index if not exists idx_shopping_sessions_created_at on shopping_sessions(created_at);
create index if not exists idx_cart_items_session_id on cart_items(session_id);
create index if not exists idx_cart_items_product_id on cart_items(product_id);
create index if not exists idx_cart_items_action_taken on cart_items(action_taken);
create index if not exists idx_cart_items_session_action on cart_items(session_id, action_taken);
create index if not exists idx_scan_history_user_id on scan_history(user_id);
create index if not exists idx_scan_history_product_id on scan_history(product_id);
create index if not exists idx_scan_history_created_at on scan_history(created_at);
create index if not exists idx_favorite_products_user_id on favorite_products(user_id);
create index if not exists idx_favorite_products_product_id on favorite_products(product_id);
create index if not exists idx_notifications_user_id on notifications(user_id);
create index if not exists idx_notifications_is_read on notifications(is_read);
create index if not exists idx_substitutions_product_id on substitutions(product_id);
create index if not exists idx_substitutions_substitute_product_id on substitutions(substitute_product_id);

create or replace function set_updated_at()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

drop trigger if exists set_users_updated_at on users;
create trigger set_users_updated_at before update on users for each row execute function set_updated_at();
drop trigger if exists set_subscriptions_updated_at on subscriptions;
create trigger set_subscriptions_updated_at before update on subscriptions for each row execute function set_updated_at();
drop trigger if exists set_products_updated_at on products;
create trigger set_products_updated_at before update on products for each row execute function set_updated_at();
drop trigger if exists set_price_history_updated_at on price_history;
create trigger set_price_history_updated_at before update on price_history for each row execute function set_updated_at();
drop trigger if exists set_shopping_sessions_updated_at on shopping_sessions;
create trigger set_shopping_sessions_updated_at before update on shopping_sessions for each row execute function set_updated_at();
drop trigger if exists set_cart_items_updated_at on cart_items;
create trigger set_cart_items_updated_at before update on cart_items for each row execute function set_updated_at();
drop trigger if exists set_scan_history_updated_at on scan_history;
create trigger set_scan_history_updated_at before update on scan_history for each row execute function set_updated_at();
drop trigger if exists set_favorite_products_updated_at on favorite_products;
create trigger set_favorite_products_updated_at before update on favorite_products for each row execute function set_updated_at();
drop trigger if exists set_notifications_updated_at on notifications;
create trigger set_notifications_updated_at before update on notifications for each row execute function set_updated_at();
drop trigger if exists set_substitutions_updated_at on substitutions;
create trigger set_substitutions_updated_at before update on substitutions for each row execute function set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    profile_name text;
begin
    profile_name := coalesce(
        nullif(new.raw_user_meta_data ->> 'full_name', ''),
        nullif(new.raw_user_meta_data ->> 'name', ''),
        split_part(coalesce(new.email, ''), '@', 1),
        'WorthIt User'
    );

    insert into public.users (id, email, full_name, monthly_budget, subscription_tier)
    values (
        new.id,
        coalesce(new.email, new.id::text || '@auth.local'),
        profile_name,
        0,
        'FREE'
    )
    on conflict (id) do update
    set email = excluded.email,
        full_name = excluded.full_name;

    return new;
end;
$$;

revoke all on function public.handle_new_user() from public;
revoke all on function public.handle_new_user() from anon;
revoke all on function public.handle_new_user() from authenticated;
grant execute on function public.handle_new_user() to supabase_auth_admin;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

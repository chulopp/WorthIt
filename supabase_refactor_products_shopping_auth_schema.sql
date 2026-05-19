-- WorthIt refactor: align live schema with product/search, monthly shopping list,
-- account deletion, and scan history without legacy shopping sessions/cart items.

alter table public.price_history
    add column if not exists created_at timestamptz not null default now(),
    add column if not exists updated_at timestamptz not null default now();

alter table public.favorite_products
    add column if not exists created_at timestamptz not null default now(),
    add column if not exists updated_at timestamptz not null default now();

alter table public.notifications
    add column if not exists created_at timestamptz not null default now(),
    add column if not exists updated_at timestamptz not null default now();

with ranked as (
    select id,
           row_number() over (
               partition by user_id, product_id
               order by created_at desc, id desc
           ) as rn
    from public.favorite_products
    where user_id is not null and product_id is not null
)
delete from public.favorite_products fp
using ranked r
where fp.id = r.id and r.rn > 1;

alter table public.favorite_products
    alter column user_id set not null,
    alter column product_id set not null;

alter table public.favorite_products
    add constraint favorite_products_user_product_unique unique (user_id, product_id);

create index if not exists idx_products_category_name
    on public.products(category, name);

create index if not exists idx_price_history_product_recorded_desc
    on public.price_history(product_id, recorded_at desc);

create index if not exists idx_favorite_products_user_created
    on public.favorite_products(user_id, created_at desc);

create index if not exists idx_notifications_user_created
    on public.notifications(user_id, created_at desc);

alter table public.scan_history
    drop constraint if exists scan_history_session_id_fkey;

drop index if exists public.idx_scan_history_session_id;

alter table public.scan_history
    drop column if exists session_id;

drop table if exists public.cart_items cascade;
drop table if exists public.shopping_sessions cascade;

drop type if exists public.action_type;
drop type if exists public.cart_action;
drop type if exists public.session_status_type;

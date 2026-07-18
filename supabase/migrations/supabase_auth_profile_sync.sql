-- WorthIt Supabase Auth -> public.users profile sync.
-- Run after the base public.users table exists.

alter table public.users
    add column if not exists full_name varchar(255);

update public.users
set full_name = coalesce(nullif(full_name, ''), split_part(email, '@', 1))
where full_name is null or full_name = '';

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

insert into public.users (id, email, full_name, monthly_budget, subscription_tier)
select
    au.id,
    coalesce(au.email, au.id::text || '@auth.local'),
    coalesce(
        nullif(au.raw_user_meta_data ->> 'full_name', ''),
        nullif(au.raw_user_meta_data ->> 'name', ''),
        split_part(coalesce(au.email, ''), '@', 1),
        'WorthIt User'
    ),
    0,
    'FREE'
from auth.users au
where not exists (
    select 1
    from public.users pu
    where pu.id = au.id
)
on conflict (id) do nothing;

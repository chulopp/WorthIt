-- Add checklist state for existing WorthIt shopping list deployments.

alter table public.shopping_list_items
    add column if not exists is_bought boolean not null default false;

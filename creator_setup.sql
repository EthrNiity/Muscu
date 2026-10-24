-- À exécuter dans Supabase > SQL Editor (après messages_setup.sql).
-- Remplace messages_announcements.sql : il refait la règle d'envoi en y ajoutant le blocage de comptes.
-- Idempotent : tu peux le relancer sans risque.

-- 1) Configuration globale de l'appli (maintenance, message épinglé, « Quoi de neuf ? », fonctions, badges…)
create table if not exists public.app_config (
  key text primary key,
  value jsonb not null default 'null'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.app_config enable row level security;

drop policy if exists "app_config_read" on public.app_config;
create policy "app_config_read" on public.app_config
  for select to anon, authenticated using (true);

drop policy if exists "app_config_admin_write" on public.app_config;
create policy "app_config_admin_write" on public.app_config
  for all to authenticated
  using (auth.uid() = '4a1e763c-e0fa-403f-baa2-25e995f2a624')
  with check (auth.uid() = '4a1e763c-e0fa-403f-baa2-25e995f2a624');

-- 2) Modération : l'admin voit et supprime tous les messages
drop policy if exists "messages_admin_select" on public.messages;
create policy "messages_admin_select" on public.messages
  for select to authenticated using (auth.uid() = '4a1e763c-e0fa-403f-baa2-25e995f2a624');

drop policy if exists "messages_admin_delete" on public.messages;
create policy "messages_admin_delete" on public.messages
  for delete to authenticated using (auth.uid() = '4a1e763c-e0fa-403f-baa2-25e995f2a624');

-- 3) Envoi de messages : soi-même uniquement, annonces réservées à l'admin, comptes bloqués refusés
drop policy if exists "messages_insert_own" on public.messages;
create policy "messages_insert_own" on public.messages
  for insert to authenticated
  with check (
    sender_key = auth.uid()::text
    and (
      group_code is distinct from '_announcements'
      or auth.uid() = '4a1e763c-e0fa-403f-baa2-25e995f2a624'
    )
    and not exists (
      select 1 from public.app_config c
      where c.key = 'blocked' and c.value @> to_jsonb(auth.uid()::text)
    )
  );

-- 4) Date de création des codes amis (pour la courbe « nouveaux comptes » ; l'historique démarre à l'exécution de ce script)
alter table public.profile_codes add column if not exists created_at timestamptz default now();

-- Audio Typing Assessment: Supabase schema
-- Paste this whole file into Supabase → SQL Editor → New query → Run.
-- Safe to run again (it drops and recreates its own policies).
-- Note: "anon" below is the Postgres role used by requests made with the publishable key (sb_publishable_...).
-- It is unrelated to the deprecated legacy "anon" API key.

------------------------------------------------------------
-- Tables
------------------------------------------------------------
create table if not exists public.assessors (
  email text primary key
);

create table if not exists public.tests (
  id         text primary key,
  doc        jsonb not null,
  active     boolean generated always as (coalesce((doc->>'active')::boolean, false)) stored,
  created_at timestamptz not null default now()
);

create table if not exists public.submissions (
  id         text primary key,
  doc        jsonb not null,
  test_id    text generated always as (doc->>'testId') stored,
  created_at timestamptz not null default now()
);

create table if not exists public.settings (
  id  text primary key,
  doc jsonb not null
);

insert into public.settings (id, doc)
values ('settings', '{"id":"settings","wordWeight":40,"fieldWeight":60,"passMark":85,"ignoreCase":false,"ignorePunct":false,"audioFormat":"wav"}')
on conflict (id) do nothing;

------------------------------------------------------------
-- Helper functions
------------------------------------------------------------
-- True when the logged-in user's email is in the assessors table.
create or replace function public.is_assessor() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.assessors
    where lower(email) = lower(coalesce(auth.jwt()->>'email', ''))
  );
$$;

create or replace function public.test_is_active(p_id text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.tests where id = p_id and active);
$$;

-- What candidates may see: the list of active passages (no text).
create or replace function public.candidate_tests() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', id, 'title', doc->>'title', 'kind', doc->>'kind', 'active', true
         ) order by created_at), '[]'::jsonb)
  from public.tests where active;
$$;

-- One passage for a candidate. The answer text is withheld for uploaded-audio
-- listening passages (it is only needed for read-aloud and computer-voice passages).
create or replace function public.candidate_test(test_id text) returns jsonb
language sql stable security definer set search_path = public as $$
  select case
           when doc->>'kind' = 'speak' or coalesce(doc->>'mode', 'tts') <> 'file' then doc
           else (doc - 'text') || jsonb_build_object('text', '')
         end
  from public.tests t where t.id = candidate_test.test_id and t.active;
$$;

grant execute on function public.is_assessor()        to anon, authenticated;
grant execute on function public.test_is_active(text) to anon, authenticated;
grant execute on function public.candidate_tests()    to anon, authenticated;
grant execute on function public.candidate_test(text) to anon, authenticated;

------------------------------------------------------------
-- Row level security
------------------------------------------------------------
alter table public.assessors   enable row level security;  -- no policies: managed from the dashboard only
alter table public.tests       enable row level security;
alter table public.submissions enable row level security;
alter table public.settings    enable row level security;

grant select, insert, update, delete on public.tests, public.submissions, public.settings to authenticated;
grant insert on public.submissions to anon;
grant select on public.settings    to anon;

drop policy if exists "assessors manage tests"       on public.tests;
drop policy if exists "assessors manage submissions" on public.submissions;
drop policy if exists "candidates submit"            on public.submissions;
drop policy if exists "anyone reads settings"        on public.settings;
drop policy if exists "assessors manage settings"    on public.settings;

create policy "assessors manage tests" on public.tests
  for all to authenticated using (public.is_assessor()) with check (public.is_assessor());

create policy "assessors manage submissions" on public.submissions
  for all to authenticated using (public.is_assessor()) with check (public.is_assessor());

-- Candidates can only add a new submission for an active passage, and cannot pre-fill the assessor's decision.
create policy "candidates submit" on public.submissions
  for insert to anon, authenticated
  with check (
    public.test_is_active(doc->>'testId')
    and (doc->>'finalScore') is null
    and coalesce(doc->>'decision', '') = ''
  );

create policy "anyone reads settings" on public.settings
  for select to anon, authenticated using (true);

create policy "assessors manage settings" on public.settings
  for all to authenticated using (public.is_assessor()) with check (public.is_assessor());

------------------------------------------------------------
-- Storage buckets (private) and policies
------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit)
values ('recordings', 'recordings', false, 52428800),
       ('test-audio', 'test-audio', false, 52428800)
on conflict (id) do nothing;

drop policy if exists "candidates upload recordings" on storage.objects;
drop policy if exists "assessors read recordings"    on storage.objects;
drop policy if exists "assessors delete recordings"  on storage.objects;
drop policy if exists "anyone reads test audio"      on storage.objects;
drop policy if exists "assessors manage test audio"  on storage.objects;

-- Candidates can upload a recording but never list, read or overwrite recordings.
create policy "candidates upload recordings" on storage.objects
  for insert to anon, authenticated with check (bucket_id = 'recordings');

create policy "assessors read recordings" on storage.objects
  for select to authenticated using (bucket_id = 'recordings' and public.is_assessor());

create policy "assessors delete recordings" on storage.objects
  for delete to authenticated using (bucket_id = 'recordings' and public.is_assessor());

-- Candidates need to play uploaded passage audio.
create policy "anyone reads test audio" on storage.objects
  for select to anon, authenticated using (bucket_id = 'test-audio');

create policy "assessors manage test audio" on storage.objects
  for all to authenticated
  using (bucket_id = 'test-audio' and public.is_assessor())
  with check (bucket_id = 'test-audio' and public.is_assessor());

------------------------------------------------------------
-- LAST STEP: add your assessor email(s). Change the address below, then run this line.
------------------------------------------------------------
-- insert into public.assessors (email) values ('assessor@yourcompany.com');

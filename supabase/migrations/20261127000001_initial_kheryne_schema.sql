-- Kheryne initial Supabase PostgreSQL schema, RLS policies, and Storage buckets.
-- Project: wxdacmoxlvblmakrwkog (ap-southeast-1)

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default 'Researcher',
  institution text not null default 'Visayas State University',
  preferred_system text not null default 'nemys2026' check (preferred_system in ('nemys2026', 'classic')),
  language text not null default 'English',
  scan_always_dark boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data->>'full_name'), ''),
      nullif(trim(new.raw_user_meta_data->>'name'), ''),
      split_part(coalesce(new.email, 'Researcher'), '@', 1)
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

revoke execute on function private.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

create table public.calibration_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_label text not null default 'Default',
  objective integer not null check (objective in (4, 10, 20, 40, 60, 100)),
  micrometres_per_pixel double precision not null check (micrometres_per_pixel > 0),
  reference_micrometres double precision not null check (reference_micrometres > 0),
  saved_at timestamptz not null default now(),
  unique (user_id, device_label, objective)
);
create index calibration_profiles_user_id_idx on public.calibration_profiles (user_id);

create table public.taxonomy_orders (
  name text primary key,
  sort_order integer not null default 0
);

create table public.taxonomy_families (
  name text primary key,
  order_name text not null references public.taxonomy_orders(name) on delete cascade,
  sort_order integer not null default 0
);
create index taxonomy_families_order_name_idx on public.taxonomy_families (order_name);

create table public.genera (
  name text primary key,
  family_name text not null references public.taxonomy_families(name) on delete cascade,
  order_name text not null references public.taxonomy_orders(name) on delete cascade,
  common_name text not null default '',
  summary text not null default '',
  crops text[] not null default '{}',
  image_seeds integer[] not null default '{}',
  reference_image_urls text[] not null default '{}',
  recorded_in_philippines boolean not null default false,
  typical_morphometrics jsonb
);
create index genera_family_name_idx on public.genera (family_name);
create index genera_order_name_idx on public.genera (order_name);
create index genera_philippines_idx on public.genera (recorded_in_philippines) where recorded_in_philippines = true;

create table public.genus_traits (
  id bigint generated always as identity primary key,
  genus_name text not null references public.genera(name) on delete cascade,
  sort_order integer not null default 0,
  name text not null,
  value text not null,
  why text not null,
  region text not null check (region in ('head', 'stylet', 'esophagus', 'vulva', 'tail')),
  illustration text not null
);
create index genus_traits_genus_name_idx on public.genus_traits (genus_name);

create table public.similar_genera (
  id bigint generated always as identity primary key,
  genus_name text not null references public.genera(name) on delete cascade,
  similar_genus_name text not null,
  how_to_tell text not null
);
create index similar_genera_genus_name_idx on public.similar_genera (genus_name);

create table public.dichotomous_key_nodes (
  id text primary key,
  sort_order integer not null default 0,
  question text not null,
  hint text not null,
  yes_target text not null,
  no_target text not null,
  yes_illustration text not null,
  no_illustration text not null,
  yes_label text not null,
  no_label text not null,
  is_start boolean not null default false
);

create table public.specimens (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  seed integer not null default 1,
  file_name text not null,
  storage_path text,
  objective integer not null default 40,
  source text not null default 'upload' check (source in ('camera', 'upload', 'phone', 'batch')),
  blurry boolean not null default false,
  dark boolean not null default false,
  worms jsonb not null default '[]'::jsonb,
  captured_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index specimens_user_captured_idx on public.specimens (user_id, captured_at desc);

create table public.detections (
  id uuid primary key,
  specimen_id uuid not null references public.specimens(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  rect jsonb not null,
  kind text not null check (kind in ('ai', 'user', 'confirmed', 'rejected')),
  confidence double precision,
  reject_reason text,
  created_at timestamptz not null default now()
);
create index detections_specimen_id_idx on public.detections (specimen_id);
create index detections_user_id_idx on public.detections (user_id);

create table public.reports (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  specimen_id uuid not null references public.specimens(id) on delete cascade,
  detection_id uuid references public.detections(id) on delete set null,
  classification jsonb not null,
  traits jsonb not null default '[]'::jsonb,
  regions jsonb not null default '{}'::jsonb,
  morphometrics jsonb,
  crop text,
  sample_code text,
  notes text not null default '',
  inference_source text not null default 'on_device' check (inference_source in ('on_device', 'cloud_python')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index reports_user_created_idx on public.reports (user_id, created_at desc);
create index reports_specimen_id_idx on public.reports (specimen_id);
create index reports_detection_id_idx on public.reports (detection_id);

create table public.ml_model_releases (
  id uuid primary key default gen_random_uuid(),
  model_type text not null check (model_type in ('detector', 'classifier')),
  version text not null,
  storage_path text not null,
  size_mb double precision not null,
  sha256 text,
  notes text not null default '',
  is_active boolean not null default true,
  published_at timestamptz not null default now(),
  unique (model_type, version)
);
create index ml_model_releases_active_idx on public.ml_model_releases (model_type, published_at desc) where is_active = true;

alter table public.profiles enable row level security;
alter table public.calibration_profiles enable row level security;
alter table public.taxonomy_orders enable row level security;
alter table public.taxonomy_families enable row level security;
alter table public.genera enable row level security;
alter table public.genus_traits enable row level security;
alter table public.similar_genera enable row level security;
alter table public.dichotomous_key_nodes enable row level security;
alter table public.specimens enable row level security;
alter table public.detections enable row level security;
alter table public.reports enable row level security;
alter table public.ml_model_releases enable row level security;

grant select on public.taxonomy_orders, public.taxonomy_families, public.genera, public.genus_traits, public.similar_genera, public.dichotomous_key_nodes, public.ml_model_releases to anon, authenticated;
grant select, insert, update, delete on public.profiles, public.calibration_profiles, public.specimens, public.detections, public.reports to authenticated;

create policy taxonomy_orders_read on public.taxonomy_orders for select to anon, authenticated using (true);
create policy taxonomy_families_read on public.taxonomy_families for select to anon, authenticated using (true);
create policy genera_read on public.genera for select to anon, authenticated using (true);
create policy genus_traits_read on public.genus_traits for select to anon, authenticated using (true);
create policy similar_genera_read on public.similar_genera for select to anon, authenticated using (true);
create policy dichotomous_key_nodes_read on public.dichotomous_key_nodes for select to anon, authenticated using (true);
create policy ml_model_releases_read on public.ml_model_releases for select to anon, authenticated using (is_active = true);

create policy profiles_select on public.profiles for select to authenticated using ((select auth.uid()) = id);
create policy profiles_insert on public.profiles for insert to authenticated with check ((select auth.uid()) = id);
create policy profiles_update on public.profiles for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
create policy profiles_delete on public.profiles for delete to authenticated using ((select auth.uid()) = id);

create policy calibrations_select on public.calibration_profiles for select to authenticated using ((select auth.uid()) = user_id);
create policy calibrations_insert on public.calibration_profiles for insert to authenticated with check ((select auth.uid()) = user_id);
create policy calibrations_update on public.calibration_profiles for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy calibrations_delete on public.calibration_profiles for delete to authenticated using ((select auth.uid()) = user_id);

create policy specimens_select on public.specimens for select to authenticated using ((select auth.uid()) = user_id);
create policy specimens_insert on public.specimens for insert to authenticated with check ((select auth.uid()) = user_id);
create policy specimens_update on public.specimens for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy specimens_delete on public.specimens for delete to authenticated using ((select auth.uid()) = user_id);

create policy detections_select on public.detections for select to authenticated using ((select auth.uid()) = user_id);
create policy detections_insert on public.detections for insert to authenticated with check ((select auth.uid()) = user_id);
create policy detections_update on public.detections for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy detections_delete on public.detections for delete to authenticated using ((select auth.uid()) = user_id);

create policy reports_select on public.reports for select to authenticated using ((select auth.uid()) = user_id);
create policy reports_insert on public.reports for insert to authenticated with check ((select auth.uid()) = user_id);
create policy reports_update on public.reports for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy reports_delete on public.reports for delete to authenticated using ((select auth.uid()) = user_id);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('specimens', 'specimens', false, 52428800, array['image/jpeg', 'image/png', 'image/webp', 'image/tiff']),
  ('reference-gallery', 'reference-gallery', true, 52428800, array['image/jpeg', 'image/png', 'image/webp']),
  ('ml-models', 'ml-models', false, 524288000, array['application/octet-stream', 'application/json'])
on conflict (id) do nothing;

create policy storage_specimens_select on storage.objects
  for select to authenticated
  using (bucket_id = 'specimens' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy storage_specimens_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'specimens' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy storage_specimens_update on storage.objects
  for update to authenticated
  using (bucket_id = 'specimens' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'specimens' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy storage_specimens_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'specimens' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy storage_reference_gallery_select on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'reference-gallery');

create policy storage_ml_models_select on storage.objects
  for select to authenticated
  using (bucket_id = 'ml-models');

-- 2-Way Nematode Model Training Pipeline, Scientist Verification Queue,
-- Role-protected Profiles, and Real Phone-to-Computer Pairing Sessions.

update public.ml_model_releases
set is_active = false
where version = '2.3.0'
  and storage_path in (
    'detector/nematode_detector_v2.3.0.onnx',
    'classifier/genus_classifier_v2.3.0.onnx'
  );

alter table public.profiles
  add column if not exists role text not null default 'user' check (role in ('user', 'scientist', 'owner')),
  add column if not exists training_opt_in boolean not null default true;

update public.profiles
set role = 'owner'
where id = (select id from public.profiles order by created_at asc limit 1)
  and not exists (select 1 from public.profiles where role = 'owner');

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  assigned_role text := 'user';
begin
  if not exists (select 1 from public.profiles where role = 'owner') then
    assigned_role := 'owner';
  end if;

  insert into public.profiles (id, full_name, institution, role)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data->>'full_name'), ''),
      nullif(trim(new.raw_user_meta_data->>'name'), ''),
      split_part(coalesce(new.email, 'Researcher'), '@', 1)
    ),
    coalesce(
      nullif(trim(new.raw_user_meta_data->>'institution'), ''),
      'Visayas State University'
    ),
    assigned_role
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

revoke execute on function private.handle_new_user() from public, anon, authenticated;

grant usage on schema private to authenticated;

create or replace function private.is_scientist_or_owner()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role in ('scientist', 'owner')
  );
$$;

revoke execute on function private.is_scientist_or_owner() from public, anon;
grant execute on function private.is_scientist_or_owner() to authenticated;

create or replace function private.guard_profile_role()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  caller_role text;
begin
  if new.role is distinct from old.role and caller_id is not null then
    select role into caller_role from public.profiles where id = caller_id;
    if caller_role is distinct from 'owner' then
      new.role := old.role;
    end if;
  end if;
  return new;
end;
$$;

revoke execute on function private.guard_profile_role() from public, anon, authenticated;

create trigger guard_profile_role_trigger
  before update on public.profiles
  for each row execute function private.guard_profile_role();

create table public.training_samples (
  id uuid primary key default gen_random_uuid(),
  submitted_by uuid not null references auth.users(id) on delete cascade,
  specimen_id uuid references public.specimens(id) on delete set null,
  report_id uuid references public.reports(id) on delete set null,
  source_type text not null check (source_type in ('scientist_lab', 'user_submission')),
  review_status text not null default 'pending_review' check (
    review_status in (
      'verified_gold',
      'verified_silver',
      'pending_review',
      'priority_review',
      'quarantined_quality',
      'rejected'
    )
  ),
  storage_bucket text not null default 'training-dataset',
  storage_path text not null,
  file_name text not null,
  image_width integer,
  image_height integer,
  objective integer not null default 40,
  life_stage text not null default 'unknown' check (
    life_stage in ('juvenile_j2', 'adult_female', 'adult_male', 'cyst', 'mixed', 'unknown')
  ),
  crop text,
  sample_code text,
  locality text,
  ai_predicted_genus text,
  ai_confidence double precision,
  key_disagreed boolean not null default false,
  verified_order text,
  verified_family text,
  verified_genus text,
  reviewed_by uuid references auth.users(id) on delete set null,
  review_notes text not null default '',
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index training_samples_submitted_by_idx on public.training_samples (submitted_by);
create index training_samples_specimen_id_idx on public.training_samples (specimen_id);
create index training_samples_report_id_idx on public.training_samples (report_id);
create index training_samples_reviewed_by_idx on public.training_samples (reviewed_by);
create index training_samples_status_created_idx on public.training_samples (review_status, created_at desc);
create index training_samples_verified_genus_idx on public.training_samples (verified_genus)
  where review_status in ('verified_gold', 'verified_silver');

create table public.training_annotations (
  id uuid primary key default gen_random_uuid(),
  sample_id uuid not null references public.training_samples(id) on delete cascade,
  rect jsonb not null,
  class_label text not null default 'nematode' check (
    class_label in ('nematode', 'debris', 'root_tissue', 'hyphae', 'free_living')
  ),
  genus_label text,
  confidence double precision,
  is_ground_truth boolean not null default false,
  created_at timestamptz not null default now()
);

create index training_annotations_sample_id_idx on public.training_annotations (sample_id);

alter table public.training_samples enable row level security;
alter table public.training_annotations enable row level security;

grant select, insert, update, delete on public.training_samples, public.training_annotations to authenticated;

create policy training_samples_select on public.training_samples
  for select to authenticated
  using (submitted_by = (select auth.uid()) or (select private.is_scientist_or_owner()));

create policy training_samples_insert on public.training_samples
  for insert to authenticated
  with check (
    submitted_by = (select auth.uid())
    and (
      (source_type = 'user_submission' and review_status in ('pending_review', 'priority_review', 'quarantined_quality'))
      or (select private.is_scientist_or_owner())
    )
  );

create policy training_samples_update on public.training_samples
  for update to authenticated
  using ((select private.is_scientist_or_owner()))
  with check ((select private.is_scientist_or_owner()));

create policy training_samples_delete on public.training_samples
  for delete to authenticated
  using (submitted_by = (select auth.uid()) or (select private.is_scientist_or_owner()));

create policy training_annotations_select on public.training_annotations
  for select to authenticated
  using (
    (select private.is_scientist_or_owner())
    or exists (
      select 1 from public.training_samples s
      where s.id = training_annotations.sample_id and s.submitted_by = (select auth.uid())
    )
  );

create policy training_annotations_insert on public.training_annotations
  for insert to authenticated
  with check (
    (select private.is_scientist_or_owner())
    or exists (
      select 1 from public.training_samples s
      where s.id = training_annotations.sample_id and s.submitted_by = (select auth.uid())
    )
  );

create policy training_annotations_update on public.training_annotations
  for update to authenticated
  using ((select private.is_scientist_or_owner()))
  with check ((select private.is_scientist_or_owner()));

create policy training_annotations_delete on public.training_annotations
  for delete to authenticated
  using (
    (select private.is_scientist_or_owner())
    or exists (
      select 1 from public.training_samples s
      where s.id = training_annotations.sample_id and s.submitted_by = (select auth.uid())
    )
  );

grant insert, update on public.ml_model_releases to authenticated;
create policy ml_model_releases_write on public.ml_model_releases
  for insert to authenticated
  with check ((select private.is_scientist_or_owner()));
create policy ml_model_releases_update on public.ml_model_releases
  for update to authenticated
  using ((select private.is_scientist_or_owner()))
  with check ((select private.is_scientist_or_owner()));

create table public.pairing_sessions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  desktop_user_id uuid not null references auth.users(id) on delete cascade,
  phone_user_id uuid references auth.users(id) on delete set null,
  desktop_name text not null,
  phone_name text,
  status text not null default 'waiting' check (status in ('waiting', 'connected', 'closed')),
  expires_at timestamptz not null default (now() + interval '15 minutes'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index pairing_sessions_desktop_user_idx on public.pairing_sessions (desktop_user_id);
create index pairing_sessions_phone_user_idx on public.pairing_sessions (phone_user_id);
create index pairing_sessions_code_idx on public.pairing_sessions (code) where status = 'waiting';

create table public.pairing_frames (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.pairing_sessions(id) on delete cascade,
  sender_user_id uuid not null references auth.users(id) on delete cascade,
  storage_path text not null,
  file_name text not null default 'frame.jpg',
  objective integer not null default 40,
  created_at timestamptz not null default now()
);

create index pairing_frames_session_created_idx on public.pairing_frames (session_id, created_at desc);
create index pairing_frames_sender_idx on public.pairing_frames (sender_user_id);

alter table public.pairing_sessions enable row level security;
alter table public.pairing_frames enable row level security;

grant select, insert, update, delete on public.pairing_sessions, public.pairing_frames to authenticated;

create policy pairing_sessions_select on public.pairing_sessions
  for select to authenticated
  using (
    desktop_user_id = (select auth.uid())
    or phone_user_id = (select auth.uid())
    or (status = 'waiting' and expires_at > now())
  );

create policy pairing_sessions_insert on public.pairing_sessions
  for insert to authenticated
  with check (desktop_user_id = (select auth.uid()));

create policy pairing_sessions_update on public.pairing_sessions
  for update to authenticated
  using (
    desktop_user_id = (select auth.uid())
    or phone_user_id = (select auth.uid())
    or (status = 'waiting' and expires_at > now())
  )
  with check (
    desktop_user_id = (select auth.uid())
    or phone_user_id = (select auth.uid())
  );

create policy pairing_sessions_delete on public.pairing_sessions
  for delete to authenticated
  using (desktop_user_id = (select auth.uid()));

create policy pairing_frames_select on public.pairing_frames
  for select to authenticated
  using (
    sender_user_id = (select auth.uid())
    or exists (
      select 1 from public.pairing_sessions ps
      where ps.id = pairing_frames.session_id
        and (ps.desktop_user_id = (select auth.uid()) or ps.phone_user_id = (select auth.uid()))
    )
  );

create policy pairing_frames_insert on public.pairing_frames
  for insert to authenticated
  with check (
    sender_user_id = (select auth.uid())
    and exists (
      select 1 from public.pairing_sessions ps
      where ps.id = pairing_frames.session_id
        and (ps.desktop_user_id = (select auth.uid()) or ps.phone_user_id = (select auth.uid()))
    )
  );

alter publication supabase_realtime add table public.pairing_sessions;
alter publication supabase_realtime add table public.pairing_frames;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('training-dataset', 'training-dataset', false, 52428800, array['image/jpeg', 'image/png', 'image/webp', 'image/tiff']),
  ('pairing-frames', 'pairing-frames', false, 20971520, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy storage_training_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'training-dataset'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or (select private.is_scientist_or_owner())
    )
  );

create policy storage_training_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'training-dataset'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy storage_training_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'training-dataset'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or (select private.is_scientist_or_owner())
    )
  )
  with check (
    bucket_id = 'training-dataset'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or (select private.is_scientist_or_owner())
    )
  );

create policy storage_training_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'training-dataset'
    and (select private.is_scientist_or_owner())
  );

create policy storage_pairing_select on storage.objects
  for select to authenticated
  using (bucket_id = 'pairing-frames');

create policy storage_pairing_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'pairing-frames'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

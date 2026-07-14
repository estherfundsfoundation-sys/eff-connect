create extension if not exists "pgcrypto";

create type public.membership_status as enum ('pending','active','paused','expired','revoked','declined');
create type public.claim_status as enum ('not_sent','sent','delivered','opened','claimed','expired','needs_help','cancelled');

create table public.organizations (
  id uuid primary key default gen_random_uuid(), slug text unique not null,
  name text not null, short_name text not null, description text,
  brand jsonb not null default '{}'::jsonb, active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null, first_name text, last_name text, phone text, birth_date date,
  school text, major text, graduation_year integer, city text, state text,
  profile_photo_url text, bio text, pronouns text,
  directory_visible boolean not null default false,
  email_opt_in boolean not null default true, sms_opt_in boolean not null default false,
  onboarding_complete boolean not null default false,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table public.membership_types (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),
  slug text not null, name text not null, description text, price_cents integer not null default 0 check(price_cents >= 0),
  billing_interval text not null default 'once' check(billing_interval in ('free','once','monthly','annual')),
  active boolean not null default true, unique(organization_id, slug)
);

create table public.memberships (
  id uuid primary key default gen_random_uuid(), profile_id uuid not null references public.profiles(id) on delete cascade,
  membership_type_id uuid not null references public.membership_types(id), status public.membership_status not null default 'pending',
  member_number text unique, started_at timestamptz, expires_at timestamptz, source text not null default 'eff_connect',
  source_record_id text, metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(profile_id, membership_type_id)
);

create table public.membership_status_history (
  id uuid primary key default gen_random_uuid(), membership_id uuid not null references public.memberships(id) on delete cascade,
  previous_status public.membership_status, new_status public.membership_status not null,
  reason text, changed_by uuid references auth.users(id), created_at timestamptz not null default now()
);

create table public.regions (id uuid primary key default gen_random_uuid(), name text not null, code text unique not null);
create table public.chapters (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),
  region_id uuid references public.regions(id), name text not null, institution text, city text, state text,
  status text not null default 'active', created_at timestamptz not null default now()
);
create table public.chapter_affiliations (
  id uuid primary key default gen_random_uuid(), profile_id uuid not null references public.profiles(id) on delete cascade,
  chapter_id uuid not null references public.chapters(id) on delete cascade, role_name text not null default 'Member',
  starts_on date, ends_on date, active boolean not null default true, unique(profile_id, chapter_id, role_name)
);

create table public.agreement_documents (
  id uuid primary key default gen_random_uuid(), organization_id uuid references public.organizations(id),
  slug text not null, title text not null, active boolean not null default true, unique(organization_id,slug)
);
create table public.agreement_versions (
  id uuid primary key default gen_random_uuid(), document_id uuid not null references public.agreement_documents(id) on delete cascade,
  version text not null, body_markdown text not null, effective_at timestamptz not null, retired_at timestamptz,
  unique(document_id,version)
);
create table public.agreement_acceptances (
  id uuid primary key default gen_random_uuid(), profile_id uuid not null references public.profiles(id) on delete cascade,
  version_id uuid not null references public.agreement_versions(id), accepted_at timestamptz not null default now(),
  ip_address inet, user_agent text, unique(profile_id,version_id)
);

create table public.products (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),
  slug text not null, name text not null, price_cents integer not null check(price_cents >= 0),
  stripe_price_id text, active boolean not null default true, unique(organization_id,slug)
);
create table public.payments (
  id uuid primary key default gen_random_uuid(), profile_id uuid references public.profiles(id), product_id uuid references public.products(id),
  stripe_checkout_session_id text unique, stripe_payment_intent_id text unique, amount_cents integer not null,
  currency text not null default 'usd', status text not null default 'pending', receipt_url text,
  metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table public.admin_roles (id uuid primary key default gen_random_uuid(), slug text unique not null, name text not null, permissions text[] not null default '{}');
create table public.admin_assignments (
  id uuid primary key default gen_random_uuid(), profile_id uuid not null references public.profiles(id) on delete cascade,
  role_id uuid not null references public.admin_roles(id), organization_id uuid references public.organizations(id),
  chapter_id uuid references public.chapters(id), active boolean not null default true,
  granted_by uuid references auth.users(id), created_at timestamptz not null default now(), unique(profile_id,role_id,organization_id,chapter_id)
);

create table public.resources (
  id uuid primary key default gen_random_uuid(), organization_id uuid references public.organizations(id), title text not null,
  description text, category text not null, url text, active boolean not null default false,
  audience jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);

create table public.campaigns (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),
  created_by uuid not null references auth.users(id), name text not null, subject text not null, html_body text not null,
  filters jsonb not null default '{}'::jsonb, status text not null default 'draft',
  scheduled_at timestamptz, sent_at timestamptz, created_at timestamptz not null default now()
);
create table public.campaign_recipients (
  id uuid primary key default gen_random_uuid(), campaign_id uuid not null references public.campaigns(id) on delete cascade,
  profile_id uuid references public.profiles(id), email text not null, provider_message_id text,
  status text not null default 'queued', event_at timestamptz, error text, unique(campaign_id,email)
);

create table public.import_jobs (
  id uuid primary key default gen_random_uuid(), source text not null default 'join_it', filename text not null,
  status text not null default 'staged', total_rows integer not null default 0, valid_rows integer not null default 0,
  invalid_rows integer not null default 0, duplicate_rows integer not null default 0,
  created_by uuid not null references auth.users(id), created_at timestamptz not null default now(), completed_at timestamptz
);
create table public.import_rows (
  id uuid primary key default gen_random_uuid(), job_id uuid not null references public.import_jobs(id) on delete cascade,
  row_number integer not null, raw jsonb not null, normalized_email text, validation_errors text[] not null default '{}',
  resolution text not null default 'pending', matched_profile_id uuid references public.profiles(id),
  created_at timestamptz not null default now(), unique(job_id,row_number)
);

create table public.legacy_member_claims (
  id uuid primary key default gen_random_uuid(), import_row_id uuid references public.import_rows(id),
  email text not null, first_name text, last_name text, imported_profile jsonb not null default '{}'::jsonb,
  token_hash text unique, token_expires_at timestamptz, status public.claim_status not null default 'not_sent',
  sent_at timestamptz, delivered_at timestamptz, opened_at timestamptz, claimed_at timestamptz,
  claimed_profile_id uuid references public.profiles(id), last_error text, resend_count integer not null default 0,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index legacy_claim_email_idx on public.legacy_member_claims(lower(email));
create index legacy_claim_status_idx on public.legacy_member_claims(status);

create table public.audit_events (
  id bigint generated always as identity primary key, actor_id uuid references auth.users(id), action text not null,
  entity_type text not null, entity_id text, organization_id uuid references public.organizations(id),
  metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);

create or replace function public.is_admin(permission_name text default null) returns boolean language sql stable security definer set search_path=public as $$
  select exists (
    select 1 from admin_assignments aa join admin_roles ar on ar.id=aa.role_id
    where aa.profile_id=auth.uid() and aa.active and (permission_name is null or permission_name=any(ar.permissions) or '*'=any(ar.permissions))
  );
$$;

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into profiles(id,email,first_name,last_name)
  values(new.id,new.email,coalesce(new.raw_user_meta_data->>'first_name',''),coalesce(new.raw_user_meta_data->>'last_name',''))
  on conflict(id) do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.memberships enable row level security;
alter table public.chapter_affiliations enable row level security;
alter table public.agreement_acceptances enable row level security;
alter table public.payments enable row level security;
alter table public.campaigns enable row level security;
alter table public.campaign_recipients enable row level security;
alter table public.import_jobs enable row level security;
alter table public.import_rows enable row level security;
alter table public.legacy_member_claims enable row level security;
alter table public.audit_events enable row level security;

create policy "profile owner read" on public.profiles for select using(id=auth.uid() or public.is_admin('people.read'));
create policy "profile owner update" on public.profiles for update using(id=auth.uid()) with check(id=auth.uid());
create policy "membership owner read" on public.memberships for select using(profile_id=auth.uid() or public.is_admin('memberships.read'));
create policy "affiliation owner read" on public.chapter_affiliations for select using(profile_id=auth.uid() or public.is_admin('chapters.read'));
create policy "acceptance owner read" on public.agreement_acceptances for select using(profile_id=auth.uid() or public.is_admin('memberships.read'));
create policy "payment owner read" on public.payments for select using(profile_id=auth.uid() or public.is_admin('payments.read'));
create policy "campaign admin all" on public.campaigns for all using(public.is_admin('campaigns.manage')) with check(public.is_admin('campaigns.manage'));
create policy "recipient admin all" on public.campaign_recipients for all using(public.is_admin('campaigns.manage')) with check(public.is_admin('campaigns.manage'));
create policy "import admin all" on public.import_jobs for all using(public.is_admin('imports.manage')) with check(public.is_admin('imports.manage'));
create policy "import row admin all" on public.import_rows for all using(public.is_admin('imports.manage')) with check(public.is_admin('imports.manage'));
create policy "claim admin read" on public.legacy_member_claims for select using(public.is_admin('imports.manage'));
create policy "audit admin read" on public.audit_events for select using(public.is_admin('audit.read'));

insert into public.organizations(slug,name,short_name,description,brand) values
('eff','Esther Funds Foundation','EFF','Faith-based student success and leadership organization','{"primary":"#42127F","accent":"#C9A66B"}'),
('pgws','Pretty Girls Who Serve','PGWS','A sisterhood of faith, service, leadership, and scholarship','{"primary":"#E9A5BE","ink":"#181416"}')
on conflict(slug) do update set name=excluded.name,brand=excluded.brand;

insert into public.membership_types(organization_id,slug,name,description,price_cents,billing_interval)
select id,'national','National Membership','Free national membership',0,'free' from public.organizations where slug='eff'
on conflict(organization_id,slug) do nothing;
insert into public.membership_types(organization_id,slug,name,description,price_cents,billing_interval)
select id,'lifetime','Lifetime Membership','One-time Pretty Girls Who Serve membership',2000,'once' from public.organizations where slug='pgws'
on conflict(organization_id,slug) do nothing;
insert into public.products(organization_id,slug,name,price_cents)
select id,'pgws-lifetime','PGWS Lifetime Membership',2000 from public.organizations where slug='pgws'
on conflict(organization_id,slug) do nothing;
insert into public.products(organization_id,slug,name,price_cents)
select id,'executive-board-commitment','Executive Board Commitment',1500 from public.organizations where slug='eff'
on conflict(organization_id,slug) do nothing;

insert into public.admin_roles(slug,name,permissions) values
('founder','Founder / Super Administrator',array['*']),
('national_admin','National Administrator',array['people.read','memberships.read','memberships.manage','chapters.read','chapters.manage','campaigns.manage','imports.manage','payments.read','audit.read']),
('chapter_admin','Chapter Administrator',array['people.read','memberships.read','chapters.read'])
on conflict(slug) do update set permissions=excluded.permissions;

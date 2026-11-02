-- Gusukuma OS Supabase Schema
-- Run in Supabase SQL Editor

create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text,
  role text not null default 'staff' check (role in ('admin', 'sales', 'coordinator', 'staff')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.companies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  industry text,
  location text,
  contact text,
  phone text,
  email text,
  status text not null default '見込み' check (status in ('見込み', '商談中', '契約中', '休眠', '失注')),
  last_contact date,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.deals (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  title text not null,
  job_type text,
  headcount int not null default 1,
  hourly_rate int,
  stage text not null default '見込み' check (stage in ('見込み', 'ヒアリング', '提案中', '契約交渉', '受注', '失注')),
  start_date date,
  expected_revenue bigint default 0,
  probability int default 50,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.staff (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  name_kana text,
  age int,
  phone text,
  status text not null default '待機中' check (status in ('待機中', '稼働中', '休職中', '退会')),
  preferred_areas text[] default '{}',
  skills text[] default '{}',
  hourly_rate_min int,
  current_client text,
  current_job text,
  deal_id uuid references public.deals(id) on delete set null,
  evaluation numeric(2,1) default 3.5,
  nearest_station text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references public.staff(id) on delete cascade,
  work_date date not null,
  client text,
  clock_in time,
  clock_out time,
  break_min int default 60,
  status text not null default '出勤中' check (status in ('出勤中', '確定', '欠勤', '有給')),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (staff_id, work_date)
);

create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  invoice_no text not null unique,
  company_id uuid references public.companies(id) on delete set null,
  client_name text,
  month text not null,
  amount bigint not null default 0,
  status text not null default '未請求' check (status in ('未請求', '請求済', '入金済', '取消')),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.contracts (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  company_id uuid not null references public.companies(id) on delete cascade,
  deal_id uuid references public.deals(id) on delete set null,
  start_date date,
  end_date date,
  headcount int default 1,
  status text not null default '有効' check (status in ('有効', '終了', '解除', '下書き')),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.activities (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  activity_type text not null default '訪問',
  activity_date date not null default current_date,
  summary text not null,
  user_name text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create or replace function public.set_updated_at() returns trigger as $$
begin new.updated_at = now(); return new; end; $$ language plpgsql;

create or replace function public.handle_new_user() returns trigger as $$
begin
  insert into public.profiles (id, email, display_name, role)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)), coalesce(new.raw_user_meta_data->>'role', 'coordinator'));
  return new;
end; $$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.companies enable row level security;
alter table public.deals enable row level security;
alter table public.staff enable row level security;
alter table public.attendance enable row level security;
alter table public.invoices enable row level security;
alter table public.contracts enable row level security;
alter table public.activities enable row level security;

create policy "companies_all_auth" on public.companies for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "deals_all_auth" on public.deals for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "staff_all_auth" on public.staff for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "attendance_all_auth" on public.attendance for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "invoices_all_auth" on public.invoices for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "contracts_all_auth" on public.contracts for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "activities_all_auth" on public.activities for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "profiles_own" on public.profiles for select using (auth.uid() = id);

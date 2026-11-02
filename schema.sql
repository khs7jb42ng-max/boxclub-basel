-- BOXCLUB BASEL production database starter. Run in Supabase SQL Editor.
create extension if not exists pgcrypto;
create type public.member_role as enum ('member','coach','admin','super_admin');
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null default '', phone text, bio text, avatar_url text,
 role public.member_role not null default 'member', created_at timestamptz not null default now()
);
create table public.memberships (
 id uuid primary key default gen_random_uuid(), member_id uuid not null references public.profiles(id) on delete cascade,
 plan_name text not null, status text not null default 'pending' check(status in ('pending','active','paused','cancelled','expired')),
 payment_status text not null default 'unpaid' check(payment_status in ('unpaid','pending','paid','overdue','refunded')),
 starts_at date, valid_until date, price_chf integer not null default 0, created_at timestamptz not null default now()
);
create table public.payments (
 id uuid primary key default gen_random_uuid(), member_id uuid not null references public.profiles(id) on delete cascade,
 membership_id uuid references public.memberships(id) on delete set null, amount_chf integer not null,
 currency text not null default 'chf', status text not null default 'pending', provider text, provider_reference text,
 created_at timestamptz not null default now()
);
create table public.posts (
 id uuid primary key default gen_random_uuid(), author_id uuid not null references public.profiles(id) on delete cascade,
 body text not null default '', media_url text, media_type text, status text not null default 'pending' check(status in ('pending','published','rejected')),
 created_at timestamptz not null default now()
);
create table public.post_likes (post_id uuid references public.posts(id) on delete cascade, user_id uuid references public.profiles(id) on delete cascade, created_at timestamptz default now(), primary key(post_id,user_id));
create table public.comments (id uuid primary key default gen_random_uuid(), post_id uuid references public.posts(id) on delete cascade, author_id uuid references public.profiles(id) on delete cascade, body text not null, created_at timestamptz default now());
create table public.follows (follower_id uuid references public.profiles(id) on delete cascade, followed_id uuid references public.profiles(id) on delete cascade, created_at timestamptz default now(), primary key(follower_id,followed_id), check(follower_id<>followed_id));
create table public.stories (id uuid primary key default gen_random_uuid(), author_id uuid references public.profiles(id) on delete cascade, media_url text not null, expires_at timestamptz not null default now()+interval '24 hours', created_at timestamptz default now());
create table public.training_sessions (id uuid primary key default gen_random_uuid(), title text not null, level text, starts_at timestamptz not null, ends_at timestamptz, capacity integer, coach_id uuid references public.profiles(id), created_at timestamptz default now());
create table public.attendance (id uuid primary key default gen_random_uuid(), session_id uuid references public.training_sessions(id) on delete cascade, member_id uuid references public.profiles(id) on delete cascade, attended boolean not null default false, checked_by uuid references public.profiles(id), created_at timestamptz default now(), unique(session_id,member_id));
create table public.events (id uuid primary key default gen_random_uuid(), title text not null, description text, starts_at timestamptz not null, location text, live_url text, published boolean not null default false, created_at timestamptz default now());
create table public.announcements (id uuid primary key default gen_random_uuid(), body text not null, created_by uuid references public.profiles(id), published boolean not null default true, created_at timestamptz default now());
create table public.notifications (id uuid primary key default gen_random_uuid(), user_id uuid references public.profiles(id) on delete cascade, title text not null, body text not null, read_at timestamptz, created_at timestamptz default now());
create or replace function public.is_staff() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from profiles where id=auth.uid() and role in ('coach','admin','super_admin')) $$;
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from profiles where id=auth.uid() and role in ('admin','super_admin')) $$;
create or replace function public.is_super_admin() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from profiles where id=auth.uid() and role='super_admin') $$;
-- Auto-create a regular member profile. Never let users set their own role via signup metadata.
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$ begin insert into public.profiles(id,full_name) values(new.id,coalesce(new.raw_user_meta_data->>'full_name','')); return new; end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

alter table profiles enable row level security; alter table memberships enable row level security; alter table payments enable row level security;
alter table posts enable row level security; alter table post_likes enable row level security; alter table comments enable row level security;
alter table follows enable row level security; alter table stories enable row level security; alter table training_sessions enable row level security;
alter table attendance enable row level security; alter table events enable row level security; alter table announcements enable row level security; alter table notifications enable row level security;
create policy "profiles readable by signed in" on profiles for select to authenticated using(true);
-- Prevent members from granting themselves admin privileges: only these profile columns are client-updatable.
revoke update on public.profiles from authenticated;
grant update(full_name,phone,bio,avatar_url) on public.profiles to authenticated;
create policy "members update own profile" on profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy "admins manage profiles" on profiles for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "members read own memberships" on memberships for select to authenticated using(member_id=auth.uid() or public.is_admin());
create policy "admins manage memberships" on memberships for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "members read own payments" on payments for select to authenticated using(member_id=auth.uid() or public.is_admin());
create policy "admins manage payments" on payments for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "published posts visible" on posts for select to authenticated using(status='published' or author_id=auth.uid() or public.is_admin());
create policy "members create pending posts" on posts for insert to authenticated with check(author_id=auth.uid() and status='pending');
create policy "authors update own pending posts" on posts for update to authenticated using(author_id=auth.uid() and status='pending') with check(author_id=auth.uid() and status='pending');
create policy "admins moderate posts" on posts for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admins delete posts" on posts for delete to authenticated using(public.is_admin());
create policy "likes visible" on post_likes for select to authenticated using(true);
create policy "like as self" on post_likes for insert to authenticated with check(user_id=auth.uid());
create policy "unlike as self" on post_likes for delete to authenticated using(user_id=auth.uid());
create policy "comments visible" on comments for select to authenticated using(true);
create policy "comment as self" on comments for insert to authenticated with check(author_id=auth.uid());
create policy "comment delete self or admin" on comments for delete to authenticated using(author_id=auth.uid() or public.is_admin());
create policy "follows visible" on follows for select to authenticated using(true);
create policy "follow self" on follows for insert to authenticated with check(follower_id=auth.uid());
create policy "unfollow self" on follows for delete to authenticated using(follower_id=auth.uid());
create policy "stories visible while active" on stories for select to authenticated using(expires_at>now());
create policy "create own story" on stories for insert to authenticated with check(author_id=auth.uid());
create policy "staff manage training" on training_sessions for all to authenticated using(public.is_staff()) with check(public.is_staff());
create policy "members read training" on training_sessions for select to authenticated using(true);
create policy "attendance self or staff" on attendance for select to authenticated using(member_id=auth.uid() or public.is_staff());
create policy "staff manage attendance" on attendance for all to authenticated using(public.is_staff()) with check(public.is_staff());
create policy "published events visible" on events for select to authenticated using(published or public.is_staff());
create policy "staff manage events" on events for all to authenticated using(public.is_staff()) with check(public.is_staff());
create policy "published announcements visible" on announcements for select to authenticated using(published or public.is_staff());
create policy "admins manage announcements" on announcements for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "own notifications" on notifications for select to authenticated using(user_id=auth.uid() or public.is_admin());
create policy "own notification update" on notifications for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "admins send notifications" on notifications for insert to authenticated with check(public.is_admin());

-- Create the first super-admin manually after signup, replacing the UUID:
-- update public.profiles set role='super_admin' where id='YOUR_AUTH_USER_UUID';
-- Never expose Supabase service_role key in app/config.js or client-side code.

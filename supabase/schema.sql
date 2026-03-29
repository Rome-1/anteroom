-- Anteroom database schema
-- Run this in the Supabase SQL editor to set up all tables

-- Enable UUID generation
create extension if not exists "uuid-ossp";

-- ============================================================================
-- USERS
-- ============================================================================
-- Extends Supabase auth.users with app-specific profile data
create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================================
-- FIGURES
-- ============================================================================
-- AI figures/personas that users can chat with
create table public.figures (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  slug text not null unique,
  description text,
  system_prompt text not null,
  avatar_url text,
  model_provider text not null default 'anthropic',
  model_id text not null default 'claude-sonnet-4-6',
  is_public boolean not null default false,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================================
-- CONVERSATIONS
-- ============================================================================
create table public.conversations (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  figure_id uuid not null references public.figures(id) on delete cascade,
  title text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================================
-- MESSAGES
-- ============================================================================
create table public.messages (
  id uuid primary key default uuid_generate_v4(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  role text not null check (role in ('user', 'assistant', 'system')),
  content text not null,
  token_count integer,
  created_at timestamptz not null default now()
);

-- ============================================================================
-- SUBSCRIPTIONS
-- ============================================================================
create table public.subscriptions (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  stripe_customer_id text unique,
  stripe_subscription_id text unique,
  plan text not null default 'free' check (plan in ('free', 'pro')),
  status text not null default 'active' check (status in ('active', 'canceled', 'past_due', 'trialing')),
  current_period_start timestamptz,
  current_period_end timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- One subscription per user
create unique index subscriptions_user_id_idx on public.subscriptions(user_id);

-- ============================================================================
-- INDEXES
-- ============================================================================
create index conversations_user_id_idx on public.conversations(user_id);
create index conversations_figure_id_idx on public.conversations(figure_id);
create index messages_conversation_id_idx on public.messages(conversation_id);
create index messages_created_at_idx on public.messages(created_at);

-- ============================================================================
-- UPDATED_AT TRIGGER
-- ============================================================================
create or replace function public.handle_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger users_updated_at
  before update on public.users
  for each row execute function public.handle_updated_at();

create trigger figures_updated_at
  before update on public.figures
  for each row execute function public.handle_updated_at();

create trigger conversations_updated_at
  before update on public.conversations
  for each row execute function public.handle_updated_at();

create trigger subscriptions_updated_at
  before update on public.subscriptions
  for each row execute function public.handle_updated_at();

-- ============================================================================
-- AUTH TRIGGER: auto-create user profile on signup
-- ============================================================================
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.users (id, email, display_name, avatar_url)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
    new.raw_user_meta_data->>'avatar_url'
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

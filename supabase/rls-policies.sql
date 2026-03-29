-- Row Level Security policies for multi-tenant isolation
-- Run this after schema.sql

-- ============================================================================
-- Enable RLS on all tables
-- ============================================================================
alter table public.users enable row level security;
alter table public.figures enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.subscriptions enable row level security;

-- ============================================================================
-- USERS policies
-- ============================================================================
-- Users can read their own profile
create policy "users_select_own"
  on public.users for select
  using (auth.uid() = id);

-- Users can update their own profile
create policy "users_update_own"
  on public.users for update
  using (auth.uid() = id);

-- ============================================================================
-- FIGURES policies
-- ============================================================================
-- Anyone authenticated can view public figures
create policy "figures_select_public"
  on public.figures for select
  using (is_public = true);

-- Creators can view their own (including non-public) figures
create policy "figures_select_own"
  on public.figures for select
  using (auth.uid() = created_by);

-- Creators can update their own figures
create policy "figures_update_own"
  on public.figures for update
  using (auth.uid() = created_by);

-- Authenticated users can create figures
create policy "figures_insert"
  on public.figures for insert
  with check (auth.uid() = created_by);

-- ============================================================================
-- CONVERSATIONS policies
-- ============================================================================
-- Users can only see their own conversations
create policy "conversations_select_own"
  on public.conversations for select
  using (auth.uid() = user_id);

-- Users can create conversations for themselves
create policy "conversations_insert_own"
  on public.conversations for insert
  with check (auth.uid() = user_id);

-- Users can update their own conversations
create policy "conversations_update_own"
  on public.conversations for update
  using (auth.uid() = user_id);

-- Users can delete their own conversations
create policy "conversations_delete_own"
  on public.conversations for delete
  using (auth.uid() = user_id);

-- ============================================================================
-- MESSAGES policies
-- ============================================================================
-- Users can read messages in their own conversations
create policy "messages_select_own"
  on public.messages for select
  using (
    exists (
      select 1 from public.conversations
      where conversations.id = messages.conversation_id
        and conversations.user_id = auth.uid()
    )
  );

-- Users can insert messages into their own conversations
create policy "messages_insert_own"
  on public.messages for insert
  with check (
    exists (
      select 1 from public.conversations
      where conversations.id = messages.conversation_id
        and conversations.user_id = auth.uid()
    )
  );

-- ============================================================================
-- SUBSCRIPTIONS policies
-- ============================================================================
-- Users can view their own subscription
create policy "subscriptions_select_own"
  on public.subscriptions for select
  using (auth.uid() = user_id);

-- Only service role can insert/update subscriptions (via Stripe webhooks)
-- No insert/update policies for anon/authenticated — handled server-side

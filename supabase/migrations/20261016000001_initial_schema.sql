-- ==============================================================================
-- Migration: 20261016000001_initial_schema.sql
-- Description: Core Schema for Private WhatsApp-Like Chat App
-- Features:
--   - Profiles with approval workflow and admin flag
--   - 1-to-1 conversations with strict 2-member guarantee and deduplication
--   - Message history with cursor pagination index and anti-spoofing constraints
--   - Row Level Security (RLS) on all exposed tables
-- ==============================================================================

-- 1. PROFILES TABLE
-- References auth.users created by Supabase Auth
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL,
    is_approved BOOLEAN NOT NULL DEFAULT FALSE,
    is_admin BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Trigger to update updated_at on profiles
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_profiles_updated_at ON public.profiles;
CREATE TRIGGER tr_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- 2. CONVERSATIONS TABLE
CREATE TABLE IF NOT EXISTS public.conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

DROP TRIGGER IF EXISTS tr_conversations_updated_at ON public.conversations;
CREATE TRIGGER tr_conversations_updated_at
    BEFORE UPDATE ON public.conversations
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- 3. CONVERSATION_MEMBERS TABLE
CREATE TABLE IF NOT EXISTS public.conversation_members (
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (conversation_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_conv_members_user ON public.conversation_members(user_id);
CREATE INDEX IF NOT EXISTS idx_conv_members_conversation ON public.conversation_members(conversation_id);

-- 4. CONVERSATION PAIR UNIQUE MAPPING
-- Enforces that exactly one 1-to-1 conversation exists between any two distinct users
CREATE TABLE IF NOT EXISTS public.direct_conversation_pairs (
    user_low UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    user_high UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    PRIMARY KEY (user_low, user_high),
    CONSTRAINT user_order_check CHECK (user_low < user_high)
);

CREATE INDEX IF NOT EXISTS idx_direct_conv_id ON public.direct_conversation_pairs(conversation_id);

-- 5. MESSAGES TABLE
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL CONSTRAINT message_content_length CHECK (char_length(trim(content)) > 0 AND char_length(content) <= 4000),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Index for cursor-based pagination (ORDER BY created_at DESC, id DESC)
CREATE INDEX IF NOT EXISTS idx_messages_conversation_cursor
    ON public.messages(conversation_id, created_at DESC, id DESC);

-- Trigger to update conversation updated_at when a new message arrives
CREATE OR REPLACE FUNCTION public.handle_new_message()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.conversations
    SET updated_at = NEW.created_at
    WHERE id = NEW.conversation_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_message_created ON public.messages;
CREATE TRIGGER tr_message_created
    AFTER INSERT ON public.messages
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_message();

-- 6. ROW LEVEL SECURITY (RLS) POLICIES

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.direct_conversation_pairs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Profiles:
-- Any authenticated user can view approved profiles (needed for user discovery / conversation display)
DROP POLICY IF EXISTS "Authenticated users can read approved profiles" ON public.profiles;
CREATE POLICY "Authenticated users can read approved profiles"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (is_approved = true OR id = auth.uid());

-- Users can update only their own profile display_name
DROP POLICY IF EXISTS "Users can update their own display_name" ON public.profiles;
CREATE POLICY "Users can update their own display_name"
    ON public.profiles FOR UPDATE
    TO authenticated
    USING (id = auth.uid())
    WITH CHECK (
        id = auth.uid()
        -- Ensure users cannot elevate themselves or toggle approval
        AND is_approved = (SELECT p.is_approved FROM public.profiles p WHERE p.id = auth.uid())
        AND is_admin = (SELECT p.is_admin FROM public.profiles p WHERE p.id = auth.uid())
    );

-- Conversations:
-- Users can select conversations they belong to
DROP POLICY IF EXISTS "Users can view conversations they belong to" ON public.conversations;
CREATE POLICY "Users can view conversations they belong to"
    ON public.conversations FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.conversation_members cm
            WHERE cm.conversation_id = id
            AND cm.user_id = auth.uid()
        )
    );

-- Conversation Members:
-- Users can view member lists only for conversations they belong to
DROP POLICY IF EXISTS "Users can view members of their conversations" ON public.conversation_members;
CREATE POLICY "Users can view members of their conversations"
    ON public.conversation_members FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.conversation_members cm
            WHERE cm.conversation_id = conversation_members.conversation_id
            AND cm.user_id = auth.uid()
        )
    );

-- Direct Conversation Pairs:
-- Users can view pair mappings they participate in
DROP POLICY IF EXISTS "Users can view pair mappings they belong to" ON public.direct_conversation_pairs;
CREATE POLICY "Users can view pair mappings they belong to"
    ON public.direct_conversation_pairs FOR SELECT
    TO authenticated
    USING (user_low = auth.uid() OR user_high = auth.uid());

-- Messages:
-- Users can view messages only in conversations they belong to
DROP POLICY IF EXISTS "Users can view messages in their conversations" ON public.messages;
CREATE POLICY "Users can view messages in their conversations"
    ON public.messages FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.conversation_members cm
            WHERE cm.conversation_id = messages.conversation_id
            AND cm.user_id = auth.uid()
        )
    );

-- Users can insert messages ONLY if:
-- 1. The sender_id is auth.uid() (no impersonation)
-- 2. The user is a member of the conversation
-- 3. The user's profile is approved
DROP POLICY IF EXISTS "Approved members can insert their own messages" ON public.messages;
CREATE POLICY "Approved members can insert their own messages"
    ON public.messages FOR INSERT
    TO authenticated
    WITH CHECK (
        sender_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM public.conversation_members cm
            WHERE cm.conversation_id = messages.conversation_id
            AND cm.user_id = auth.uid()
        )
        AND EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid()
            AND p.is_approved = true
        )
    );

-- 7. FUNCTION: Create or Get 1-on-1 Conversation
-- Ensures exact 2 approved members and prevents race conditions in conversation creation
CREATE OR REPLACE FUNCTION public.create_or_get_direct_conversation(target_user_id UUID)
RETURNS UUID AS $$
DECLARE
    current_uid UUID;
    low_uid UUID;
    high_uid UUID;
    existing_conv_id UUID;
    new_conv_id UUID;
    caller_approved BOOLEAN;
    target_approved BOOLEAN;
BEGIN
    current_uid := auth.uid();
    IF current_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF current_uid = target_user_id THEN
        RAISE EXCEPTION 'Cannot start a conversation with yourself';
    END IF;

    -- Verify both users exist and are approved
    SELECT is_approved INTO caller_approved FROM public.profiles WHERE id = current_uid;
    SELECT is_approved INTO target_approved FROM public.profiles WHERE id = target_user_id;

    IF caller_approved IS NOT TRUE THEN
        RAISE EXCEPTION 'Your account has not been approved';
    END IF;

    IF target_approved IS NOT TRUE THEN
        RAISE EXCEPTION 'Target user has not been approved';
    END IF;

    -- Determine canonical order
    IF current_uid < target_user_id THEN
        low_uid := current_uid;
        high_uid := target_user_id;
    ELSE
        low_uid := target_user_id;
        high_uid := current_uid;
    END IF;

    -- Check if conversation already exists
    SELECT conversation_id INTO existing_conv_id
    FROM public.direct_conversation_pairs
    WHERE user_low = low_uid AND user_high = high_uid;

    IF existing_conv_id IS NOT NULL THEN
        RETURN existing_conv_id;
    END IF;

    -- Create new conversation
    INSERT INTO public.conversations DEFAULT VALUES RETURNING id INTO new_conv_id;

    -- Insert exactly two members
    INSERT INTO public.conversation_members (conversation_id, user_id)
    VALUES (new_conv_id, low_uid), (new_conv_id, high_uid);

    -- Record pair mapping
    INSERT INTO public.direct_conversation_pairs (user_low, user_high, conversation_id)
    VALUES (low_uid, high_uid, new_conv_id);

    RETURN new_conv_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. TRIGGER: Create Profile upon Supabase Auth User Signup
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER AS $$
DECLARE
    raw_name TEXT;
BEGIN
    raw_name := coalesce(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1));
    IF raw_name IS NULL OR trim(raw_name) = '' THEN
        raw_name := 'Member';
    END IF;

    INSERT INTO public.profiles (id, display_name, is_approved, is_admin)
    VALUES (
        NEW.id,
        raw_name,
        FALSE, -- Default unapproved for invitation-only access
        FALSE
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();

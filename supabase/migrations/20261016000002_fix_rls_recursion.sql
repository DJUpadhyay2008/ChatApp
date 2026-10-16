-- Migration: 20261016000002_fix_rls_recursion.sql
-- Description: Fix infinite recursion in conversation_members and related RLS policies

-- 1. Helper function with SECURITY DEFINER to break RLS recursion
CREATE OR REPLACE FUNCTION public.is_member_of_conversation(conv_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.conversation_members
        WHERE conversation_id = conv_id
          AND user_id = auth.uid()
    );
$$;

-- 2. Update Conversations policy
DROP POLICY IF EXISTS "Users can view conversations they belong to" ON public.conversations;
CREATE POLICY "Users can view conversations they belong to"
    ON public.conversations FOR SELECT
    TO authenticated
    USING (public.is_member_of_conversation(id));

-- 3. Update Conversation Members policy (resolves error 42P17)
DROP POLICY IF EXISTS "Users can view members of their conversations" ON public.conversation_members;
CREATE POLICY "Users can view members of their conversations"
    ON public.conversation_members FOR SELECT
    TO authenticated
    USING (public.is_member_of_conversation(conversation_id));

-- 4. Update Messages SELECT policy
DROP POLICY IF EXISTS "Users can view messages in their conversations" ON public.messages;
CREATE POLICY "Users can view messages in their conversations"
    ON public.messages FOR SELECT
    TO authenticated
    USING (public.is_member_of_conversation(conversation_id));

-- 5. Update Messages INSERT policy
DROP POLICY IF EXISTS "Approved members can insert their own messages" ON public.messages;
CREATE POLICY "Approved members can insert their own messages"
    ON public.messages FOR INSERT
    TO authenticated
    WITH CHECK (
        sender_id = auth.uid()
        AND public.is_member_of_conversation(conversation_id)
        AND EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid()
            AND p.is_approved = true
        )
    );

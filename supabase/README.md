# Supabase Setup & Security Guide

This project relies on **Supabase Auth** for user authentication and **Supabase PostgreSQL** for persistent data with strict **Row Level Security (RLS)**.

---

## 1. Supabase Dashboard Configuration

### Step 1.1: Create a Free Supabase Project
1. Go to [supabase.com](https://supabase.com) and create a free project.
2. Note your **Project URL** and keys in **Project Settings -> API**:
   - `Project URL`: `https://<project-ref>.supabase.co`
   - `anon public key`: `eyJh...` (Safe for Flutter / Web)
   - `service_role key`: `eyJh...` (**STRICTLY SERVER-SIDE ONLY** for FastAPI)

### Step 1.2: Enforce Invitation-Only Access (Disable Public Sign-ups)
1. In the Supabase Dashboard, navigate to **Authentication -> Providers -> Email**.
2. **Turn OFF** "Enable Signups" / "Allow new users to sign up".
3. **Turn OFF** "Enable Email Confirmations" if you plan to create members with pre-verified accounts.
4. This ensures random users cannot register public accounts.

---

## 2. Apply Database Migrations & RLS

1. Go to **SQL Editor** in the Supabase Dashboard.
2. Open the file [`supabase/migrations/20261016000001_initial_schema.sql`](./migrations/20261016000001_initial_schema.sql).
3. Paste the contents into the SQL Editor and click **Run**.
4. This creates:
   - `public.profiles`
   - `public.conversations`
   - `public.conversation_members`
   - `public.direct_conversation_pairs`
   - `public.messages`
   - Automatic user profile creation trigger `on_auth_user_created`
   - Canonical 1-on-1 stored function `create_or_get_direct_conversation`
   - Strict Row Level Security policies on every table.

---

## 3. Provisioning the Group Administrator & Members

Since public sign-ups are disabled, the administrator provisions the 7–8 group members directly via the Supabase Dashboard or FastAPI:

### Option A: Via Supabase Dashboard (Recommended for initial setup)
1. Go to **Authentication -> Users** in the Supabase Dashboard.
2. Click **Add User -> Create User**.
3. Enter the email and a temporary password for the member.
4. In the SQL Editor, approve the member and make the administrator an admin:
   ```sql
   -- Approve all initial members
   UPDATE public.profiles
   SET is_approved = true
   WHERE id IN (
     SELECT id FROM auth.users WHERE email IN ('member1@example.com', 'member2@example.com')
   );

   -- Grant admin role to designated administrator
   UPDATE public.profiles
   SET is_approved = true, is_admin = true
   WHERE id = (SELECT id FROM auth.users WHERE email = 'admin@example.com');
   ```

### Option B: Via FastAPI Admin Endpoint
Once the admin user is marked `is_admin = true`:
- The admin can approve any newly added user by sending a `POST /admin/approve-user` request:
  ```bash
  curl -X POST https://your-backend.onrender.com/admin/approve-user \
    -H "Authorization: Bearer <ADMIN_JWT_TOKEN>" \
    -H "Content-Type: application/json" \
    -d '{"user_id": "<TARGET_USER_UUID>", "approve": true}'
  ```

---

## 4. Testing RLS Policies

Run the following test in the Supabase SQL Editor to verify RLS isolation:

```sql
-- Simulate User A
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "00000000-0000-0000-0000-000000000001"}';

-- User A reads messages (only their conversations will be returned)
SELECT * FROM public.messages;

-- Reset role
RESET ROLE;
```

-- ================================================================
--  MESSAGERIE APP — CONFIGURATION SUPABASE (VERSION FINALE)
-- ================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ════════════════════════════════════════════════════════════════
--  1. TABLE PROFILES
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email       TEXT NOT NULL,
  username    TEXT NOT NULL CHECK (char_length(username) BETWEEN 3 AND 50),
  avatar_url  TEXT,
  is_online   BOOLEAN DEFAULT false,
  last_seen   TIMESTAMPTZ DEFAULT NOW(),
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles(username);
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select" ON public.profiles FOR SELECT TO authenticated USING (true);
CREATE POLICY "profiles_insert" ON public.profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);
CREATE POLICY "profiles_update" ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);


-- ════════════════════════════════════════════════════════════════
--  2. TABLE CONVERSATIONS (INSERT seulement, SELECT/UPDATE à l'étape 4)
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.conversations (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name         TEXT,
  is_group     BOOLEAN DEFAULT false,
  group_avatar TEXT,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_conversations_updated ON public.conversations(updated_at DESC);
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "conversations_insert" ON public.conversations FOR INSERT TO authenticated WITH CHECK (true);


-- ════════════════════════════════════════════════════════════════
--  3. TABLE CONVERSATION_PARTICIPANTS
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.conversation_participants (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id  UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  user_id          UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  joined_at        TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(conversation_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_participants_conversation ON public.conversation_participants(conversation_id);
CREATE INDEX IF NOT EXISTS idx_participants_user         ON public.conversation_participants(user_id);
ALTER TABLE public.conversation_participants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "participants_select" ON public.conversation_participants FOR SELECT TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.conversation_participants cp2
      WHERE cp2.conversation_id = conversation_participants.conversation_id
        AND cp2.user_id = auth.uid()
    )
  );
CREATE POLICY "participants_insert" ON public.conversation_participants FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "participants_delete" ON public.conversation_participants FOR DELETE TO authenticated USING (user_id = auth.uid());


-- ════════════════════════════════════════════════════════════════
--  4. POLICIES CONVERSATIONS (conversation_participants existe maintenant)
-- ════════════════════════════════════════════════════════════════
CREATE POLICY "conversations_select" ON public.conversations FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.conversation_participants
      WHERE conversation_id = conversations.id AND user_id = auth.uid()
    )
  );

CREATE POLICY "conversations_update" ON public.conversations FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.conversation_participants
      WHERE conversation_id = conversations.id AND user_id = auth.uid()
    )
  );


-- ════════════════════════════════════════════════════════════════
--  5. TABLE MESSAGES
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.messages (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id  UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id        UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type             TEXT NOT NULL DEFAULT 'text' CHECK (type IN ('text', 'image', 'video')),
  content          TEXT,
  media_url        TEXT,
  thumbnail_url    TEXT,
  media_width      FLOAT,
  media_height     FLOAT,
  media_duration   INTEGER,
  is_read          BOOLEAN DEFAULT false,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_messages_conversation ON public.messages(conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_sender       ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_unread       ON public.messages(conversation_id, is_read) WHERE is_read = false;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "messages_select" ON public.messages FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.conversation_participants
      WHERE conversation_id = messages.conversation_id AND user_id = auth.uid()
    )
  );

CREATE POLICY "messages_insert" ON public.messages FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM public.conversation_participants
      WHERE conversation_id = messages.conversation_id AND user_id = auth.uid()
    )
  );

CREATE POLICY "messages_update" ON public.messages FOR UPDATE TO authenticated
  USING (sender_id = auth.uid()) WITH CHECK (sender_id = auth.uid());

CREATE POLICY "messages_delete" ON public.messages FOR DELETE TO authenticated
  USING (sender_id = auth.uid());


-- ════════════════════════════════════════════════════════════════
--  6. TRIGGER : Création automatique du profil à l'inscription
-- ════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, username)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1))
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ════════════════════════════════════════════════════════════════
--  7. FONCTION : Trouver une conversation directe existante
-- ════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.get_direct_conversation(user1_id UUID, user2_id UUID)
RETURNS TABLE(id UUID) LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT c.id
  FROM public.conversations c
  WHERE c.is_group = false
    AND (SELECT COUNT(*) FROM public.conversation_participants WHERE conversation_id = c.id) = 2
    AND EXISTS (SELECT 1 FROM public.conversation_participants WHERE conversation_id = c.id AND user_id = user1_id)
    AND EXISTS (SELECT 1 FROM public.conversation_participants WHERE conversation_id = c.id AND user_id = user2_id)
  LIMIT 1;
END;
$$;


-- ════════════════════════════════════════════════════════════════
--  8. REALTIME
-- ════════════════════════════════════════════════════════════════
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;


-- ════════════════════════════════════════════════════════════════
--  9. STORAGE BUCKETS
-- ════════════════════════════════════════════════════════════════
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('chat-images', 'chat-images', true, 10485760,
        ARRAY['image/jpeg','image/jpg','image/png','image/gif','image/webp'])
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('chat-videos', 'chat-videos', true, 52428800,
        ARRAY['video/mp4','video/quicktime','video/x-msvideo','video/webm','video/3gpp'])
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars', 'avatars', true, 5242880,
        ARRAY['image/jpeg','image/jpg','image/png','image/webp'])
ON CONFLICT (id) DO NOTHING;


-- ════════════════════════════════════════════════════════════════
--  10. STORAGE POLICIES
--  CORRECTION : owner est TEXT dans storage.objects
--  donc on caste auth.uid() en TEXT avec ::text
-- ════════════════════════════════════════════════════════════════

-- chat-images
CREATE POLICY "chat_images_select" ON storage.objects FOR SELECT
  USING (bucket_id = 'chat-images');

CREATE POLICY "chat_images_insert" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'chat-images'
    AND (storage.foldername(name))[1] = 'messages'
  );

CREATE POLICY "chat_images_delete" ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'chat-images'
    AND owner::text = (auth.uid())::text   -- cast des deux côtés en TEXT
  );

-- chat-videos
CREATE POLICY "chat_videos_select" ON storage.objects FOR SELECT
  USING (bucket_id = 'chat-videos');

CREATE POLICY "chat_videos_insert" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'chat-videos'
    AND (storage.foldername(name))[1] = 'messages'
  );

CREATE POLICY "chat_videos_delete" ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'chat-videos'
    AND owner::text = (auth.uid())::text
  );

-- avatars
CREATE POLICY "avatars_select" ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

CREATE POLICY "avatars_insert" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = (auth.uid())::text
  );

CREATE POLICY "avatars_update" ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'avatars'
    AND owner::text = (auth.uid())::text
  );


-- ════════════════════════════════════════════════════════════════
--  VÉRIFICATION FINALE
-- ════════════════════════════════════════════════════════════════
SELECT
  table_name,
  (SELECT COUNT(*) FROM information_schema.columns c
   WHERE c.table_name = t.table_name AND c.table_schema = 'public') AS colonnes
FROM information_schema.tables t
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
ORDER BY table_name;
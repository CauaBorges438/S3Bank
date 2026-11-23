/// Configuração pública do Supabase.
/// A anon key é pública por design: a segurança dos dados vem das
/// políticas de RLS (ver supabase/migrations). NUNCA coloque a
/// service_role key neste projeto.
class SupabaseConfig {
  static const String url = 'https://pvddwerrlqefgrvipxzh.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB2ZGR3ZXJybHFlZmdydmlweHpoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg4NDU2MTEsImV4cCI6MjEwNDQyMTYxMX0.ha-4LA7MFrwKCcLq8lEj5IHyeR15B4unLsdvcpTWr_M';
}

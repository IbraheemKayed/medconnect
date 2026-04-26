import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = 'https://nlyjwwldpmseknigjiri.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5seWp3d2xkcG1zZWtuaWdqaXJpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU4Mzk0NDEsImV4cCI6MjA5MTQxNTQ0MX0.oLCXuG8wS4kh_YJTwGp7HqEoVT77HWBw_n-jcXYbXm8';
  static const String serviceRoleKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5seWp3d2xkcG1zZWtuaWdqaXJpIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTgzOTQ0MSwiZXhwIjoyMDkxNDE1NDQxfQ.KLid3DKfdHxA1GDfDGIoV3WrrYQaVVFcCpcJA2PIWrY';

  static SupabaseClient get client => Supabase.instance.client;

  static SupabaseClient get adminClient => SupabaseClient(url, serviceRoleKey);
}
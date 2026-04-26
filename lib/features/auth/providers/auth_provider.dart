import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_config.dart';

// Model للمستخدم الحالي
class AppUser {
  final String id;
  final String tenantId;
  final String fullName;
  final String role;
  final String? phone;
  final bool isActive;
  final String? selectedClinicId;
  final String? selectedClinicName;

  const AppUser({
    required this.id,
    required this.tenantId,
    required this.fullName,
    required this.role,
    this.phone,
    required this.isActive,
    this.selectedClinicId,
    this.selectedClinicName,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      fullName: map['full_name'] as String,
      role: map['role'] as String,
      phone: map['phone'] as String?,
      isActive: map['is_active'] as bool,
    );
  }

  AppUser copyWith({
    String? selectedClinicId,
    String? selectedClinicName,
  }) {
    return AppUser(
      id: id,
      tenantId: tenantId,
      fullName: fullName,
      role: role,
      phone: phone,
      isActive: isActive,
      selectedClinicId: selectedClinicId ?? this.selectedClinicId,
      selectedClinicName: selectedClinicName ?? this.selectedClinicName,
    );
  }

  bool get needsClinicSelection => [
        'doctor',
        'clinic_receptionist',
        'nurse',
        'lab_technician',
        'radiology_technician',
      ].contains(role);
}

// State للـ auth
class AuthState {
  final AppUser? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
  AppUser? user,
  bool? isLoading,
  String? error,
}) {
  return AuthState(
    user: user ?? this.user,
    isLoading: isLoading ?? this.isLoading,
    error: error ?? this.error,
  );
}
}

// Notifier
class AuthNotifier extends Notifier<AuthState> {
 @override
AuthState build() {
  Future.microtask(() => _init());
  return const AuthState(isLoading: true);
}

void selectClinic(String clinicId, String clinicName) {
  if (state.user == null) return;
  state = state.copyWith(
    user: state.user!.copyWith(
      selectedClinicId: clinicId,
      selectedClinicName: clinicName,
    ),
  );
}

Future<void> _init() async {
  try {
    final session = SupabaseConfig.client.auth.currentSession;
    debugPrint('Session: ${session?.user.id}');
    if (session != null) {
      await _loadUser(session.user.id);
    } else {
      state = const AuthState(isLoading: false);
    }
  } catch (e) {
    debugPrint('Auth init error: $e');
    state = const AuthState(isLoading: false);
  }
}

  Future<void> _loadUser(String userId) async {
    try {
      final data = await SupabaseConfig.client
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      state = AuthState(user: AppUser.fromMap(data));
    } catch (e) {
      state = const AuthState();
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await SupabaseConfig.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user != null) {
        await _loadUser(response.user!.id);
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        error: 'البريد الإلكتروني أو كلمة المرور غير صحيحة',
      );
      return false;
    } on AuthException {
      state = state.copyWith(
        isLoading: false,
        error: 'البريد الإلكتروني أو كلمة المرور غير صحيحة',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'حدث خطأ، حاول مرة أخرى',
      );
      return false;
    }
  }

 Future<void> logout() async {
  await SupabaseConfig.client.auth.signOut();
  state = const AuthState();
}
}

// Providers
final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authProvider).user;
});
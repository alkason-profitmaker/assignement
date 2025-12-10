import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import 'service_providers.dart';
import 'auth_provider.dart';

/// State for society data
class SocietyState {
  final Society? currentSociety;
  final List<Station> stations;
  final bool isLoading;
  final String? errorMessage;

  SocietyState({
    this.currentSociety,
    this.stations = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  SocietyState copyWith({
    Society? currentSociety,
    List<Station>? stations,
    bool? isLoading,
    String? errorMessage,
  }) {
    return SocietyState(
      currentSociety: currentSociety ?? this.currentSociety,
      stations: stations ?? this.stations,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  /// Get active stations
  List<Station> get activeStations => stations.where((s) => s.isActive).toList();

  /// Check if society has any active stations
  bool get hasActiveStations => activeStations.isNotEmpty;
}

/// Society notifier
class SocietyNotifier extends StateNotifier<SocietyState> {
  final SupabaseService _supabaseService;
  final Ref _ref;

  SocietyNotifier(this._supabaseService, this._ref) : super(SocietyState());

  /// Load society and stations for current user
  Future<void> loadSocietyData() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final society = await _supabaseService.getSociety(user.societyId);
      final stations = await _supabaseService.getStations(user.societyId);

      state = state.copyWith(
        currentSociety: society,
        stations: stations,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load society data: ${e.toString()}',
      );
    }
  }

  /// Refresh station statuses
  Future<void> refreshStations() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    try {
      final stations = await _supabaseService.getStations(user.societyId);
      state = state.copyWith(stations: stations);
    } catch (e) {
      // Silently fail on refresh
    }
  }

  /// Subscribe to station updates
  void subscribeToStations() {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    _supabaseService.subscribeToStations(user.societyId).listen((stations) {
      state = state.copyWith(stations: stations);
    });
  }
}

/// Society provider
final societyProvider = StateNotifierProvider<SocietyNotifier, SocietyState>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return SocietyNotifier(supabaseService, ref);
});

/// Current society provider
final currentSocietyProvider = Provider<Society?>((ref) {
  return ref.watch(societyProvider).currentSociety;
});

/// Stations provider
final stationsProvider = Provider<List<Station>>((ref) {
  return ref.watch(societyProvider).stations;
});

/// Active stations provider
final activeStationsProvider = Provider<List<Station>>((ref) {
  return ref.watch(societyProvider).activeStations;
});

/// Search societies provider
final searchSocietiesProvider = FutureProvider.family<List<Society>, SocietySearchParams>(
  (ref, params) async {
    final supabaseService = ref.read(supabaseServiceProvider);
    return supabaseService.searchSocieties(
      city: params.city,
      pincode: params.pincode,
      query: params.query,
    );
  },
);

/// Society search parameters
class SocietySearchParams {
  final String? city;
  final String? pincode;
  final String? query;

  SocietySearchParams({
    this.city,
    this.pincode,
    this.query,
  });
}

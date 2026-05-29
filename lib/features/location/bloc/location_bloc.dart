import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/auth_service.dart';
import 'location_event.dart';
import 'location_state.dart';

class LocationBloc extends Bloc<LocationEvent, LocationState> {
  final LocationService _locationService;
  final AuthService _authService;
  StreamSubscription? _friendLocationsSubscription;

  LocationBloc({
    required LocationService locationService,
    required AuthService authService,
  })  : _locationService = locationService,
        _authService = authService,
        super(const LocationInitial()) {
    on<LoadUserLocation>(_onLoadUserLocation);
    on<StartSharingLocation>(_onStartSharingLocation);
    on<StopSharingLocation>(_onStopSharingLocation);
    on<LoadFriendLocations>(_onLoadFriendLocations);
    on<UpdateFriendLocations>(_onUpdateFriendLocations);
  }

  Future<void> _onLoadUserLocation(
    LoadUserLocation event,
    Emitter<LocationState> emit,
  ) async {
    emit(const LocationLoading());

    try {
      final hasPermission = await _locationService.checkPermissions();
      if (!hasPermission) {
        emit(const LocationPermissionDenied());
        return;
      }

      final position = await _locationService.getCurrentPosition();

      // Check if user is already sharing
      final userId = _authService.currentUser?.uid;
      bool isSharing = false;

      if (userId != null) {
        final userLocation = await _locationService.getUserLocation(userId);
        isSharing = userLocation?.isSharing ?? false;
      }

      emit(LocationLoaded(
        currentPosition: position,
        isSharing: isSharing,
      ));
    } catch (e) {
      emit(LocationError('فشل جلب الموقع: $e'));
    }
  }

  Future<void> _onStartSharingLocation(
    StartSharingLocation event,
    Emitter<LocationState> emit,
  ) async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) {
      emit(const LocationError('المستخدم غير مسجل دخول'));
      return;
    }

    try {
      await _locationService.startSharingLocation(userId);

      final currentState = state;
      if (currentState is LocationLoaded) {
        emit(currentState.copyWith(isSharing: true));
      }
    } catch (e) {
      emit(LocationError('فشل بدء المشاركة: $e'));
    }
  }

  Future<void> _onStopSharingLocation(
    StopSharingLocation event,
    Emitter<LocationState> emit,
  ) async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    try {
      await _locationService.stopSharingLocation(userId);

      final currentState = state;
      if (currentState is LocationLoaded) {
        emit(currentState.copyWith(isSharing: false));
      }
    } catch (e) {
      emit(LocationError('فشل إيقاف المشاركة: $e'));
    }
  }

  Future<void> _onLoadFriendLocations(
    LoadFriendLocations event,
    Emitter<LocationState> emit,
  ) async {
    await _friendLocationsSubscription?.cancel();

    if (event.friendIds.isEmpty) return;

    _friendLocationsSubscription = _locationService
        .watchFriendLocations(event.friendIds)
        .listen((locations) {
      add(UpdateFriendLocations(locations));
    });
  }

  Future<void> _onUpdateFriendLocations(
    UpdateFriendLocations event,
    Emitter<LocationState> emit,
  ) async {
    final currentState = state;
    if (currentState is LocationLoaded) {
      emit(currentState.copyWith(
        friendLocations: event.locations.cast<UserLocation>(),
      ));
    }
  }

  @override
  Future<void> close() {
    _friendLocationsSubscription?.cancel();
    _locationService.dispose();
    return super.close();
  }
}

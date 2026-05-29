import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';
import '../../../data/services/location_service.dart';

abstract class LocationState extends Equatable {
  const LocationState();

  @override
  List<Object?> get props => [];
}

class LocationInitial extends LocationState {
  const LocationInitial();
}

class LocationLoading extends LocationState {
  const LocationLoading();
}

class LocationLoaded extends LocationState {
  final Position? currentPosition;
  final bool isSharing;
  final List<UserLocation> friendLocations;

  const LocationLoaded({
    this.currentPosition,
    required this.isSharing,
    this.friendLocations = const [],
  });

  LocationLoaded copyWith({
    Position? currentPosition,
    bool? isSharing,
    List<UserLocation>? friendLocations,
  }) {
    return LocationLoaded(
      currentPosition: currentPosition ?? this.currentPosition,
      isSharing: isSharing ?? this.isSharing,
      friendLocations: friendLocations ?? this.friendLocations,
    );
  }

  @override
  List<Object?> get props => [currentPosition, isSharing, friendLocations];
}

class LocationError extends LocationState {
  final String message;

  const LocationError(this.message);

  @override
  List<Object?> get props => [message];
}

class LocationPermissionDenied extends LocationState {
  const LocationPermissionDenied();
}

import 'package:equatable/equatable.dart';

abstract class LocationEvent extends Equatable {
  const LocationEvent();

  @override
  List<Object?> get props => [];
}

class LoadUserLocation extends LocationEvent {
  const LoadUserLocation();
}

class StartSharingLocation extends LocationEvent {
  const StartSharingLocation();
}

class StopSharingLocation extends LocationEvent {
  const StopSharingLocation();
}

class LoadFriendLocations extends LocationEvent {
  final List<String> friendIds;

  const LoadFriendLocations(this.friendIds);

  @override
  List<Object?> get props => [friendIds];
}

class UpdateFriendLocations extends LocationEvent {
  final List<dynamic> locations;

  const UpdateFriendLocations(this.locations);

  @override
  List<Object?> get props => [locations];
}

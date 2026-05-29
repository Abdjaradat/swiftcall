import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/auth_service.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/location_bloc.dart';
import '../bloc/location_event.dart';
import '../bloc/location_state.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    final authService = context.read<AuthService>();
    final friendIds = authService.currentUser?.contacts ?? [];

    context.read<LocationBloc>().add(const LoadUserLocation());
    if (friendIds.isNotEmpty) {
      context.read<LocationBloc>().add(LoadFriendLocations(friendIds));
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _updateMapStyle(controller);
  }

  Future<void> _updateMapStyle(GoogleMapController controller) async {
    const String mapStyle = '''
    [
      {
        "elementType": "geometry",
        "stylers": [{"color": "#1d2c4d"}]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#8ec3b9"}]
      },
      {
        "elementType": "labels.text.stroke",
        "stylers": [{"color": "#1a3646"}]
      },
      {
        "featureType": "road",
        "elementType": "geometry",
        "stylers": [{"color": "#38414e"}]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [{"color": "#0e1626"}]
      }
    ]
    ''';
    await controller.setMapStyle(mapStyle);
  }

  void _updateMarkers(LocationState state) {
    if (state is! LocationLoaded) return;

    _markers.clear();

    // My location (blue marker)
    if (state.currentPosition != null) {
      final pos = state.currentPosition!;
      _markers.add(
        Marker(
          markerId: const MarkerId('my_location'),
          position: LatLng(pos.latitude, pos.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'موقعي'),
        ),
      );

      // Move camera to my location
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(pos.latitude, pos.longitude),
          14.0,
        ),
      );
    }

    // Friend locations (green markers)
    for (final friendLoc in state.friendLocations) {
      if (friendLoc.isRecent) {
        _markers.add(
          Marker(
            markerId: MarkerId(friendLoc.userId),
            position: LatLng(friendLoc.lat, friendLoc.lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(
              title: friendLoc.userId,
              snippet: 'آخر تحديث: ${_formatTime(friendLoc.timestamp)}',
            ),
          ),
        );
      }
    }

    setState(() {});
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'الخريطة',
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocConsumer<LocationBloc, LocationState>(
        listener: (context, state) {
          if (state is LocationPermissionDenied) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'يرجى تفعيل صلاحيات الموقع من الإعدادات',
                  style: GoogleFonts.cairo(),
                ),
                backgroundColor: AppColors.accent,
                action: SnackBarAction(
                  label: 'فتح الإعدادات',
                  textColor: Colors.white,
                  onPressed: () {
                    // Open app settings
                    // You can use permission_handler's openAppSettings()
                  },
                ),
              ),
            );
          } else if (state is LocationError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message, style: GoogleFonts.cairo()),
                backgroundColor: AppColors.accent,
              ),
            );
          } else if (state is LocationLoaded) {
            _updateMarkers(state);
          }
        },
        builder: (context, state) {
          if (state is LocationLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (state is LocationPermissionDenied) {
            return _buildPermissionDenied();
          }

          if (state is LocationLoaded) {
            return Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: state.currentPosition != null
                        ? LatLng(
                            state.currentPosition!.latitude,
                            state.currentPosition!.longitude,
                          )
                        : const LatLng(31.9454, 35.9284), // Amman, Jordan
                    zoom: 14.0,
                  ),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: true,
                ),
                _buildSharingToggle(state),
                _buildLegend(),
              ],
            );
          }

          return const Center(
            child: Text('حدث خطأ غير متوقع'),
          );
        },
      ),
    );
  }

  Widget _buildSharingToggle(LocationLoaded state) {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              state.isSharing ? Icons.location_on : Icons.location_off,
              color: state.isSharing ? AppColors.primary : AppColors.textHint,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              state.isSharing ? 'مشاركة نشطة' : 'مشاركة متوقفة',
              style: GoogleFonts.cairo(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: state.isSharing,
              onChanged: (value) {
                if (value) {
                  context.read<LocationBloc>().add(const StartSharingLocation());
                } else {
                  context.read<LocationBloc>().add(const StopSharingLocation());
                }
              },
              activeColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Positioned(
      bottom: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLegendItem(
              color: Colors.blue,
              label: 'موقعي',
            ),
            const SizedBox(height: 8),
            _buildLegendItem(
              color: Colors.green,
              label: 'أصدقائي',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.cairo(
            color: AppColors.textPrimary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_off_rounded,
              size: 80,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 24),
            Text(
              'صلاحيات الموقع مطلوبة',
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'يرجى تفعيل صلاحيات الموقع من الإعدادات لاستخدام هذه الميزة',
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                context.read<LocationBloc>().add(const LoadUserLocation());
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                'إعادة المحاولة',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

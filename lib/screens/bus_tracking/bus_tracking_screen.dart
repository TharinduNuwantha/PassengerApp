import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/active_trip_models.dart';
import '../../services/bus_tracking_service.dart';
import '../../services/route_polyline_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_style.dart';

/// Bus Tracking Screen - Shows real-time bus location on map
class BusTrackingScreen extends StatefulWidget {
  final String scheduledTripId;
  final String routeNumber;
  final String? routeName;

  const BusTrackingScreen({
    super.key,
    required this.scheduledTripId,
    required this.routeNumber,
    this.routeName,
  });

  @override
  State<BusTrackingScreen> createState() => _BusTrackingScreenState();
}

class _BusTrackingScreenState extends State<BusTrackingScreen> {
  GoogleMapController? _mapController;
  Position? _userLocation;
  ActiveTrip? _activeTrip;
  bool _isLoading = true;
  bool _isLoadingRoute = true;
  String? _errorMessage;
  Timer? _pollingTimer;

  /// When true, map camera automatically follows the bus on every location update.
  /// Set to false when the user manually pans the map.
  bool _autoFollowBus = true;
  
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final BusTrackingService _trackingService = BusTrackingService();
  final RoutePolylineService _polylineService = RoutePolylineService();

  // Default camera position (Colombo, Sri Lanka)
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(6.9271, 79.8612),
    zoom: 12.0,
  );

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _getUserLocation();
    await _loadRoutePolyline();
    await _loadActiveTrip();
    _startPolling();
    setState(() => _isLoading = false);
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _userLocation = position;
          _updateUserMarker(position);
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _loadRoutePolyline() async {
    try {
      debugPrint('🗺️ Loading route polyline for route: ${widget.routeNumber}');

      // 1. Try by route_number first (fast exact match)
      Map<String, dynamic>? polylineData;
      if (widget.routeNumber.isNotEmpty) {
        polylineData = await _polylineService.getRoutePolylineData(
          widget.routeNumber,
        );
      }

      // 2. Fall back to route_name lookup if number lookup failed
      if (polylineData == null && (widget.routeName?.isNotEmpty ?? false)) {
        debugPrint('🔄 Falling back to name-based lookup: ${widget.routeName}');
        polylineData = await _polylineService.getRoutePolylineByName(
          widget.routeName!,
        );
      }

      if (polylineData != null && mounted) {
        final encodedPolyline = polylineData['encoded_polyline'] as String?;
        final originCity = polylineData['origin_city'] as String?;
        final destinationCity = polylineData['destination_city'] as String?;
        final fetchedRouteName = polylineData['route_name'] as String?;

        if (encodedPolyline != null && encodedPolyline.isNotEmpty) {
          final points = _polylineService.decodePolyline(encodedPolyline);

          debugPrint('✅ Decoded ${points.length} polyline points');

          setState(() {
            // Use the fetched route_number/name for the polyline ID
            final polylineId = polylineData!['route_number'] as String? ??
                widget.routeNumber;
            final polyline = _polylineService.createPolylineFromPoints(
              polylineId: 'route_$polylineId',
              points: points,
              color: AppColors.primary,
              width: 6,
            );

            _polylines.clear();
            _polylines.add(polyline);

            // Start / end markers with real city names
            if (points.isNotEmpty) {
              _markers.removeWhere((m) =>
                  m.markerId.value == 'route_start' ||
                  m.markerId.value == 'route_end');

              _markers.add(
                Marker(
                  markerId: const MarkerId('route_start'),
                  position: points.first,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen,
                  ),
                  infoWindow: InfoWindow(
                    title: originCity ?? 'Origin',
                    snippet: fetchedRouteName,
                  ),
                ),
              );

              _markers.add(
                Marker(
                  markerId: const MarkerId('route_end'),
                  position: points.last,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed,
                  ),
                  infoWindow: InfoWindow(
                    title: destinationCity ?? 'Destination',
                    snippet: fetchedRouteName,
                  ),
                ),
              );
            }

            _isLoadingRoute = false;
          });

          // Fit camera to show entire route
          if (points.isNotEmpty && _mapController != null) {
            final bounds = _polylineService.getPolylineBounds(points);
            _mapController!.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, 50),
            );
          }
        } else {
          setState(() => _isLoadingRoute = false);
        }
      } else {
        setState(() => _isLoadingRoute = false);
      }
    } catch (e) {
      debugPrint('❌ Error loading route polyline: $e');
      setState(() => _isLoadingRoute = false);
    }
  }

  Future<void> _loadActiveTrip() async {
    try {
      debugPrint('🚌 Loading active trip: ${widget.scheduledTripId}');

      final response = await _trackingService.getActiveTripByScheduledTripId(
        widget.scheduledTripId,
      );

      if (mounted) {
        if (response.hasActiveTrip && response.activeTrip != null) {
          setState(() {
            _activeTrip = response.activeTrip;
            _errorMessage = null;
            _updateBusMarker(response.activeTrip!);
          });
        } else {
          setState(() {
            _errorMessage = response.message ?? 'Trip has not started yet';
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading active trip: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load bus location';
        });
      }
    }
  }

  void _startPolling() {
    // Poll for location updates every 10 seconds
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _loadActiveTrip();
      }
    });
  }

  void _updateUserMarker(Position position) {
    _markers.removeWhere((m) => m.markerId.value == 'user');
    _markers.add(
      Marker(
        markerId: const MarkerId('user'),
        position: LatLng(position.latitude, position.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Your Location'),
      ),
    );
  }

  void _updateBusMarker(ActiveTrip trip) {
    if (!trip.hasLocation) return;

    _markers.removeWhere((m) => m.markerId.value == 'bus');
    _markers.add(
      Marker(
        markerId: const MarkerId('bus'),
        position: LatLng(trip.currentLatitude!, trip.currentLongitude!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(
          title: 'Bus Location',
          snippet: 'Updated: ${_formatTime(trip.lastLocationUpdate)}',
        ),
      ),
    );

    // Auto-follow: animate camera to bus location on every update when enabled
    if (_mapController != null && _autoFollowBus) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(trip.currentLatitude!, trip.currentLongitude!),
          15.0,
        ),
      );
    }
  }

  void _centerOnBus() {
    if (_activeTrip != null &&
        _activeTrip!.hasLocation &&
        _mapController != null) {
      setState(() => _autoFollowBus = true);
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(
            _activeTrip!.currentLatitude!,
            _activeTrip!.currentLongitude!,
          ),
          15.0,
        ),
      );
    }
  }

  void _centerOnUser() {
    if (_userLocation != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_userLocation!.latitude, _userLocation!.longitude),
          16.0,
        ),
      );
    }
  }

  /// Called when the user starts dragging the map — disable auto-follow.
  void _onCameraMoveStarted() {
    if (_autoFollowBus) {
      setState(() => _autoFollowBus = false);
    }
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Status banner appearance — mirrors driver app style
    final bool tripActive = _activeTrip != null;
    final Color bannerColor = tripActive ? const Color(0xFF388E3C) : AppColors.primary;
    final String bannerTitle = widget.routeName ?? (widget.routeNumber.isNotEmpty
        ? 'Route ${widget.routeNumber}'
        : 'Bus Tracking');
    final String bannerSubtitle = tripActive
        ? 'Trip in progress - Tracking...'
        : (_errorMessage?.isNotEmpty == true
            ? _errorMessage!
            : 'Waiting for trip to start...');

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Text(
          widget.routeName ?? 'Bus Tracking',
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  // Map Container
                  Expanded(
                    flex: 2,
                    child: Stack(
                      children: [
                        GoogleMap(
                          initialCameraPosition: _initialPosition,
                          markers: _markers,
                          polylines: _polylines,
                          myLocationEnabled: true,
                          myLocationButtonEnabled: false,
                          onCameraMoveStarted: _onCameraMoveStarted,
                          onMapCreated: (controller) {
                            _mapController = controller;
                          },
                        ),
                        // Route status banner (top of map — mirrors driver app)
                        Positioned(
                          top: 12,
                          left: 12,
                          right: 72, // leave room for FABs
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: bannerColor,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  tripActive
                                      ? Icons.gps_fixed
                                      : Icons.gps_not_fixed,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        bannerTitle,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        bannerSubtitle,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Auto-follow bus FAB (orange = active, grey = paused)
                        Positioned(
                          right: 16,
                          bottom: 80,
                          child: FloatingActionButton(
                            mini: false,
                            heroTag: 'follow_bus',
                            onPressed: _activeTrip != null && _activeTrip!.hasLocation
                                ? _centerOnBus
                                : null,
                            backgroundColor: _autoFollowBus
                                ? const Color(0xFFF57C00)
                                : Colors.grey.shade400,
                            tooltip: _autoFollowBus
                                ? 'Auto-following bus'
                                : 'Tap to follow bus',
                            child: Icon(
                              _autoFollowBus
                                  ? Icons.gps_fixed
                                  : Icons.gps_not_fixed,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        // Center on my location FAB
                        if (_userLocation != null)
                          Positioned(
                            right: 16,
                            bottom: 16,
                            child: FloatingActionButton(
                              mini: false,
                              heroTag: 'my_location',
                              onPressed: _centerOnUser,
                              backgroundColor: isDark
                                  ? colorScheme.surfaceContainerHigh
                                  : Colors.white,
                              tooltip: 'My location',
                              child: Icon(
                                Icons.my_location,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        // Re-centre chip — shown when auto-follow is off
                        if (_activeTrip != null &&
                            _activeTrip!.hasLocation &&
                            !_autoFollowBus)
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 100,
                            child: Center(
                              child: GestureDetector(
                                onTap: _centerOnBus,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.gps_not_fixed,
                                          color: Colors.white, size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        'Tap to re-centre on bus',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Loading overlay for route
                        if (_isLoadingRoute)
                          Container(
                            color: Colors.black26,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Bus Information Panel
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Handle bar
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: colorScheme.onSurface.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        if (_activeTrip != null) ...[
                          _buildInfoRow(
                            context: context,
                            icon: Icons.directions_bus,
                            label: 'Status',
                            value: _activeTrip!.status.displayName,
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            context: context,
                            icon: Icons.update,
                            label: 'Last Update',
                            value: _formatTime(_activeTrip!.lastLocationUpdate),
                          ),
                          if (_activeTrip!.currentSpeedKmh != null) ...[
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              context: context,
                              icon: Icons.speed,
                              label: 'Speed',
                              value:
                                  '${_activeTrip!.currentSpeedKmh!.toStringAsFixed(1)} km/h',
                            ),
                          ],
                        ] else ...[
                          Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.directions_bus_filled,
                                  size: 48,
                                  color: colorScheme.onSurface.withOpacity(0.35),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Trip Not Started',
                                  style: AppTextStyles.h3.copyWith(
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _errorMessage ?? 'Waiting for bus to start...',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color:
                                        colorScheme.onSurface.withOpacity(0.55),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.55),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

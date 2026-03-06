import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Service to fetch and decode route polylines from Supabase
class RoutePolylineService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch route polyline data from Supabase master_routes table by route_number
  Future<Map<String, dynamic>?> getRoutePolylineData(String routeNumber) async {
    try {
      debugPrint('📡 Fetching route polyline for route: "$routeNumber"');

      final response = await _supabase
          .from('master_routes')
          .select('route_number, route_name, encoded_polyline')
          .eq('route_number', routeNumber)
          .maybeSingle()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⏱️ Supabase query timed out after 10 seconds');
          return null;
        },
      );

      if (response == null) {
        debugPrint('❌ No route found for route number: "$routeNumber"');
        return null;
      }

      final polylineLength =
          (response['encoded_polyline'] as String?)?.length ?? 0;
      debugPrint('✅ Route polyline data fetched successfully');
      debugPrint('📊 Polyline length: $polylineLength characters');

      return response;
    } catch (e) {
      debugPrint('❌ Error fetching route polyline: $e');
      return null;
    }
  }

  /// Fetch route polyline by route name (exact or partial match).
  /// Tries exact match first, then falls back to checking origin/destination cities.
  Future<Map<String, dynamic>?> getRoutePolylineByName(String routeName) async {
    if (routeName.isEmpty) return null;
    try {
      debugPrint('📡 Fetching route polyline by name: "$routeName"');

      // 1. Exact route_name match
      var response = await _supabase
          .from('master_routes')
          .select('route_number, route_name, origin_city, destination_city, encoded_polyline')
          .ilike('route_name', routeName)
          .maybeSingle()
          .timeout(const Duration(seconds: 10), onTimeout: () => null);

      if (response != null) {
        debugPrint('✅ Found by exact name match: ${response['route_name']}');
        return response;
      }

      // 2. Partial match — route_name contains the search term
      final List<Map<String, dynamic>> rows = await _supabase
          .from('master_routes')
          .select('route_number, route_name, origin_city, destination_city, encoded_polyline')
          .ilike('route_name', '%$routeName%')
          .limit(1)
          .timeout(const Duration(seconds: 10), onTimeout: () => <Map<String, dynamic>>[]);

      if (rows.isNotEmpty) {
        debugPrint('✅ Found by partial name match: ${rows.first['route_name']}');
        return rows.first;
      }

      // 3. Try matching origin or destination city from the route name parts
      final parts = routeName.split(RegExp(r'[\s\-–]+'));
      for (final part in parts) {
        if (part.trim().length < 3) continue;
        final cityRows = await _supabase
            .from('master_routes')
            .select('route_number, route_name, origin_city, destination_city, encoded_polyline')
            .or('origin_city.ilike.%${part.trim()}%,destination_city.ilike.%${part.trim()}%')
            .limit(1)
            .timeout(const Duration(seconds: 10), onTimeout: () => <Map<String, dynamic>>[]);
        if (cityRows.isNotEmpty) {
          debugPrint('✅ Found by city match "$part": ${cityRows.first['route_name']}');
          return cityRows.first;
        }
      }

      debugPrint('❌ No route found for name: "$routeName"');
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching route polyline by name: $e');
      return null;
    }
  }

  /// Decode polyline string to list of LatLng points
  List<LatLng> decodePolyline(String encodedPolyline) {
    try {
      debugPrint('🔄 Decoding polyline...');
      debugPrint('📝 Encoded string length: ${encodedPolyline.length} chars');

      if (encodedPolyline.isEmpty) {
        debugPrint('❌ Empty polyline string');
        return [];
      }

      // Unescape special characters from JSON
      String unescapedPolyline = encodedPolyline
          .replaceAll('\\\\', '\\')
          .replaceAll('\\"', '"')
          .replaceAll('\\/', '/');

      // Use manual decoder to avoid length limits
      final points = _manualDecodePolyline(unescapedPolyline);

      debugPrint('✅ Decoded ${points.length} points');
      if (points.isNotEmpty) {
        debugPrint(
          '📍 First point: ${points.first.latitude}, ${points.first.longitude}',
        );
        debugPrint(
          '📍 Last point: ${points.last.latitude}, ${points.last.longitude}',
        );
      }

      return points;
    } catch (e) {
      debugPrint('❌ Error decoding polyline: $e');
      return [];
    }
  }

  /// Manual polyline decoder implementing Google's Encoded Polyline Algorithm
  List<LatLng> _manualDecodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int b;
      int shift = 0;
      int result = 0;

      // Decode latitude
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;

      // Decode longitude
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  /// Create polyline from points
  Polyline createPolylineFromPoints({
    required String polylineId,
    required List<LatLng> points,
    required Color color,
    required int width,
  }) {
    return Polyline(
      polylineId: PolylineId(polylineId),
      points: points,
      color: color,
      width: width,
      geodesic: true,
    );
  }

  /// Get bounds for a list of points (for camera positioning)
  LatLngBounds getPolylineBounds(List<LatLng> points) {
    double? north, south, east, west;

    for (final point in points) {
      north = north == null
          ? point.latitude
          : (point.latitude > north ? point.latitude : north);
      south = south == null
          ? point.latitude
          : (point.latitude < south ? point.latitude : south);
      east = east == null
          ? point.longitude
          : (point.longitude > east ? point.longitude : east);
      west = west == null
          ? point.longitude
          : (point.longitude < west ? point.longitude : west);
    }

    return LatLngBounds(
      southwest: LatLng(south!, west!),
      northeast: LatLng(north!, east!),
    );
  }
}

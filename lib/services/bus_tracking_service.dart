import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../models/active_trip_models.dart';
import '../utils/error_handler.dart';
import 'api_service.dart';

/// Service for tracking bus locations in real-time
class BusTrackingService {
  static final BusTrackingService _instance = BusTrackingService._internal();
  factory BusTrackingService() => _instance;
  BusTrackingService._internal();

  final ApiService _apiService = ApiService();
  final Logger _logger = Logger();

  /// Get active trip by scheduled trip ID
  ///
  /// [scheduledTripId] - The scheduled trip ID from booking
  ///
  /// Returns [ActiveTripResponse] with current bus location if trip is active
  Future<ActiveTripResponse> getActiveTripByScheduledTripId(
    String scheduledTripId,
  ) async {
    try {
      _logger.i('Fetching active trip for scheduled trip: $scheduledTripId');

      final response = await _apiService.get(
        '/api/v1/active-trips/by-scheduled-trip/$scheduledTripId',
      );

      _logger.d('Active trip response: ${response.data}');

      final activeTripResponse = ActiveTripResponse.fromJson(response.data);

      if (activeTripResponse.hasActiveTrip &&
          activeTripResponse.activeTrip != null) {
        final trip = activeTripResponse.activeTrip!;
        _logger.i(
          'Active trip found: ${trip.id}, Status: ${trip.status.displayName}, '
          'Location: ${trip.hasLocation ? "(${trip.currentLatitude}, ${trip.currentLongitude})" : "No location"}',
        );
      } else {
        _logger.i('No active trip found for scheduled trip: $scheduledTripId');
      }

      return activeTripResponse;
    } on DioException catch (e) {
      _logger.e('Failed to get active trip: ${e.message}');

      // Handle 404 - no active trip found
      if (e.response?.statusCode == 404) {
        return ActiveTripResponse(
          hasActiveTrip: false,
          message: 'Trip has not started yet',
        );
      }

      throw ErrorHandler.handleError(e);
    } catch (e) {
      _logger.e('Unexpected error getting active trip: $e');

      // ApiService converts DioExceptions to Strings before rethrowing,
      // so a 404 arrives here as a "not found" string — treat it gracefully.
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('not found') ||
          errStr.contains('resource not found') ||
          errStr.contains('404')) {
        return ActiveTripResponse(
          hasActiveTrip: false,
          message: 'Trip has not started yet',
        );
      }

      throw Exception('Failed to get bus location: $e');
    }
  }
}

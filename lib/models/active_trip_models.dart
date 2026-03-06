/// Models for Active Trip tracking (bus real-time location)

class ActiveTrip {
  final String id;
  final String scheduledTripId;
  final String busId;
  final String permitId;
  final String driverId;
  final String? conductorId;
  
  // Location data
  final double? currentLatitude;
  final double? currentLongitude;
  final DateTime? lastLocationUpdate;
  final double? currentSpeedKmh;
  final double? heading;
  
  // Trip progress
  final String? currentStopId;
  final String? nextStopId;
  final List<String> stopsCompleted;
  
  // Timing
  final DateTime? actualDepartureTime;
  final DateTime? estimatedArrivalTime;
  final DateTime? actualArrivalTime;
  
  // Status
  final ActiveTripStatus status;
  final int currentPassengerCount;
  
  final DateTime createdAt;
  final DateTime updatedAt;

  ActiveTrip({
    required this.id,
    required this.scheduledTripId,
    required this.busId,
    required this.permitId,
    required this.driverId,
    this.conductorId,
    this.currentLatitude,
    this.currentLongitude,
    this.lastLocationUpdate,
    this.currentSpeedKmh,
    this.heading,
    this.currentStopId,
    this.nextStopId,
    required this.stopsCompleted,
    this.actualDepartureTime,
    this.estimatedArrivalTime,
    this.actualArrivalTime,
    required this.status,
    required this.currentPassengerCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ActiveTrip.fromJson(Map<String, dynamic> json) {
    return ActiveTrip(
      id: json['id'] as String? ?? '',
      scheduledTripId: json['scheduled_trip_id'] as String? ?? '',
      busId: json['bus_id'] as String? ?? '',
      permitId: json['permit_id'] as String? ?? '',
      driverId: json['driver_id'] as String? ?? '',
      conductorId: json['conductor_id'] as String?,
      currentLatitude: (json['current_latitude'] as num?)?.toDouble(),
      currentLongitude: (json['current_longitude'] as num?)?.toDouble(),
      lastLocationUpdate: json['last_location_update'] != null
          ? DateTime.parse(json['last_location_update'] as String)
          : null,
      currentSpeedKmh: (json['current_speed_kmh'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      currentStopId: json['current_stop_id'] as String?,
      nextStopId: json['next_stop_id'] as String?,
      stopsCompleted: (json['stops_completed'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      actualDepartureTime: json['actual_departure_time'] != null
          ? DateTime.parse(json['actual_departure_time'] as String)
          : null,
      estimatedArrivalTime: json['estimated_arrival_time'] != null
          ? DateTime.parse(json['estimated_arrival_time'] as String)
          : null,
      actualArrivalTime: json['actual_arrival_time'] != null
          ? DateTime.parse(json['actual_arrival_time'] as String)
          : null,
      status: ActiveTripStatus.fromString(json['status'] as String?),
      currentPassengerCount: json['current_passenger_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  bool get hasLocation =>
      currentLatitude != null && currentLongitude != null;

  bool get isActive =>
      status == ActiveTripStatus.inTransit ||
      status == ActiveTripStatus.atStop;
}

enum ActiveTripStatus {
  notStarted,
  inTransit,
  atStop,
  completed,
  cancelled;

  static ActiveTripStatus fromString(String? value) {
    switch (value) {
      case 'not_started':
        return ActiveTripStatus.notStarted;
      case 'in_transit':
      case 'ongoing': // legacy value written by older driver app versions
        return ActiveTripStatus.inTransit;
      case 'at_stop':
        return ActiveTripStatus.atStop;
      case 'completed':
        return ActiveTripStatus.completed;
      case 'cancelled':
        return ActiveTripStatus.cancelled;
      default:
        return ActiveTripStatus.notStarted;
    }
  }

  String toJson() {
    switch (this) {
      case ActiveTripStatus.notStarted:
        return 'not_started';
      case ActiveTripStatus.inTransit:
        return 'in_transit';
      case ActiveTripStatus.atStop:
        return 'at_stop';
      case ActiveTripStatus.completed:
        return 'completed';
      case ActiveTripStatus.cancelled:
        return 'cancelled';
    }
  }

  String get displayName {
    switch (this) {
      case ActiveTripStatus.notStarted:
        return 'Not Started';
      case ActiveTripStatus.inTransit:
        return 'In Transit';
      case ActiveTripStatus.atStop:
        return 'At Stop';
      case ActiveTripStatus.completed:
        return 'Completed';
      case ActiveTripStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Response for active trip tracking
class ActiveTripResponse {
  final bool hasActiveTrip;
  final ActiveTrip? activeTrip;
  final String? message;

  ActiveTripResponse({
    required this.hasActiveTrip,
    this.activeTrip,
    this.message,
  });

  factory ActiveTripResponse.fromJson(Map<String, dynamic> json) {
    return ActiveTripResponse(
      hasActiveTrip: json['has_active_trip'] as bool? ?? false,
      activeTrip: json['active_trip'] != null
          ? ActiveTrip.fromJson(json['active_trip'] as Map<String, dynamic>)
          : null,
      message: json['message'] as String?,
    );
  }
}

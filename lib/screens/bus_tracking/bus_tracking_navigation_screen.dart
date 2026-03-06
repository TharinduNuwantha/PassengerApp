import 'package:flutter/material.dart';
import '../../models/booking_models.dart';
import '../../services/booking_service.dart';
import '../../theme/app_colors.dart';
import 'bus_tracking_screen.dart';

/// Helper to extract a route number from a route name string
String? _extractRouteNumber(String? name) {
  if (name == null || name.isEmpty) return null;
  final match = RegExp(r'\d+').firstMatch(name);
  return match?.group(0);
}

/// Wrapper screen for bus tracking from navigation
/// Shows list of trackable bookings or navigates directly if only one
class BusTrackingNavigationScreen extends StatefulWidget {
  const BusTrackingNavigationScreen({super.key});

  @override
  State<BusTrackingNavigationScreen> createState() =>
      _BusTrackingNavigationScreenState();
}

class _BusTrackingNavigationScreenState
    extends State<BusTrackingNavigationScreen> {
  final BookingService _bookingService = BookingService();
  List<BookingListItem> _trackableBookings = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTrackableBookings();
  }

  Future<void> _loadTrackableBookings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get upcoming bookings that might be trackable
      final bookings = await _bookingService.getUpcomingBookings(limit: 10);

      // Filter to only bus bookings that are confirmed or in progress
      final trackable = bookings.where((booking) {
        return booking.bookingType == BookingType.busOnly ||
            booking.bookingType == BookingType.busWithLounge;
      }).toList();

      setState(() {
        _trackableBookings = trackable;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToTracking(BookingListItem booking) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch full booking details to get the real scheduledTripId
      final response = await _bookingService.getBookingById(booking.id);
      final busBooking = response.busBooking;

      if (!mounted) return;
      Navigator.of(context).pop(); // Dismiss loading dialog

      if (busBooking == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load bus booking details'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Try to extract route number from the full route name
      final routeNumber = _extractRouteNumber(busBooking.routeName) ?? '';

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BusTrackingScreen(
            scheduledTripId: busBooking.scheduledTripId,
            routeNumber: routeNumber,
            routeName: busBooking.routeName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Dismiss loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading booking: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'Track Your Bus',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : _trackableBookings.isEmpty
                  ? _buildEmptyState()
                  : _buildBookingsList(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Failed to Load Bookings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'An error occurred',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _loadTrackableBookings,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 36,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Retry',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.directions_bus_outlined,
                size: 56,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Active Bookings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'You don\'t have any upcoming bus bookings to track.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                final navigator = Navigator.of(context);
                if (navigator.canPop()) {
                  navigator.pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please use the Home tab to search and book a bus'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.search, size: 18),
              label: const Text(
                'Book a Bus',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingsList() {
    return RefreshIndicator(
      onRefresh: _loadTrackableBookings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _trackableBookings.length,
        itemBuilder: (context, index) {
          final booking = _trackableBookings[index];
          return _buildBookingCard(booking);
        },
      ),
    );
  }

  Widget _buildBookingCard(BookingListItem booking) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToTracking(booking),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.directions_bus,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.routeName ?? 'Bus Booking',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            booking.bookingReference,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.chevron_right,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  height: 1,
                  color: AppColors.primary.withOpacity(0.1),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildChip(
                      icon: Icons.calendar_today,
                      label: booking.formattedDeparture,
                    ),
                    const SizedBox(width: 12),
                    _buildChip(
                      icon: Icons.event_seat,
                      label:
                          '${booking.numberOfSeats ?? 0} seat${booking.numberOfSeats == 1 ? '' : 's'}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF374151),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

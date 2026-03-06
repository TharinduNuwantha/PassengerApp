import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/lounge_booking_models.dart';
import '../../services/lounge_booking_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_style.dart';
import '../../widgets/blue_header.dart';
import 'lounge_booking_detail_screen.dart';

/// Screen showing all lounge bookings for the current user
class MyLoungeBookingsScreen extends StatefulWidget {
  final bool embedded;

  const MyLoungeBookingsScreen({super.key, this.embedded = false});

  @override
  State<MyLoungeBookingsScreen> createState() => _MyLoungeBookingsScreenState();
}

class _MyLoungeBookingsScreenState extends State<MyLoungeBookingsScreen>
    with SingleTickerProviderStateMixin {
  final LoungeBookingService _loungeService = LoungeBookingService();
  late TabController _tabController;

  List<LoungeBooking> _upcomingBookings = [];
  List<LoungeBooking> _allBookings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _loungeService.getUpcomingBookings(),
        _loungeService.getMyBookings(),
      ]);

      setState(() {
        _upcomingBookings = results[0];
        _allBookings = results[1];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    
    // For embedded mode (inside tabs), just show the content
    if (widget.embedded) {
      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7FA),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: false,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                indicator: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(4),
                labelColor: AppColors.primary,
                unselectedLabelColor: Colors.grey.shade600,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.upcoming, size: 16),
                        const SizedBox(width: 6),
                        const Text('Upcoming'),
                        if (_upcomingBookings.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_upcomingBookings.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 16),
                        SizedBox(width: 6),
                        Text('All'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadBookings,
                color: AppColors.primary,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBookingsList(_upcomingBookings, isUpcoming: true),
                    _buildBookingsList(_allBookings, isUpcoming: false),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    // For standalone mode (with its own header)
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BlueHeader(
              padding: EdgeInsets.fromLTRB(20, topInset + 18, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Lounge Bookings',
                    style: AppTextStyles.h2.copyWith(
                      color: AppColors.textLight,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Track your lounge reservations',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textLight.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: false,
                      padding: EdgeInsets.zero,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                      indicator: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorPadding: const EdgeInsets.all(4),
                      labelColor: AppColors.primary,
                      unselectedLabelColor:
                          AppColors.textLight.withOpacity(0.85),
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                      dividerColor: Colors.transparent,
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.upcoming, size: 16),
                              const SizedBox(width: 6),
                              const Text('Upcoming'),
                              if (_upcomingBookings.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${_upcomingBookings.length}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history, size: 16),
                              SizedBox(width: 6),
                              Text('All'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: RefreshIndicator(
                  onRefresh: _loadBookings,
                  color: AppColors.primary,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBookingsList(_upcomingBookings, isUpcoming: true),
                      _buildBookingsList(_allBookings, isUpcoming: false),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingsList(List<LoungeBooking> bookings,
      {required bool isUpcoming}) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading bookings...',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red.shade400,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Failed to load bookings',
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadBookings,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
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

    if (bookings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isUpcoming ? Icons.weekend : Icons.history,
                  size: 56,
                  color: const Color(0xFF7C3AED).withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isUpcoming ? 'No upcoming bookings' : 'No booking history',
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isUpcoming
                    ? 'Book a lounge and it will appear here'
                    : 'Your past bookings will appear here',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        return _BookingCard(
          booking: bookings[index],
          onTap: () => _navigateToDetail(bookings[index]),
          showQR: isUpcoming,
        );
      },
    );
  }

  void _navigateToDetail(LoungeBooking booking) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoungeBookingDetailScreen(booking: booking),
      ),
    ).then((_) => _loadBookings()); // Refresh on return
  }
}

class _BookingCard extends StatelessWidget {
  final LoungeBooking booking;
  final VoidCallback onTap;
  final bool showQR;

  const _BookingCard({
    required this.booking,
    required this.onTap,
    this.showQR = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.1),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // QR Code preview (only for upcoming)
                if (showQR) ...[
                  Container(
                    width: 80,
                    height: 80,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF7C3AED).withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: QrImageView(
                      data: booking.qrCodeData,
                      version: QrVersions.auto,
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF7C3AED),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status badge
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(booking.status)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getStatusIcon(booking.status),
                                  size: 14,
                                  color: _getStatusColor(booking.status),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  booking.status.displayName,
                                  style: TextStyle(
                                    color: _getStatusColor(booking.status),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.chevron_right,
                              color: Colors.grey.shade400),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Lounge name
                      Text(
                        booking.loungeName ?? 'Lounge',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Reference
                      Row(
                        children: [
                          Icon(
                            Icons.confirmation_number,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            booking.bookingReference,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Date/time and price
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            // Date
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          booking.formattedScheduledArrival,
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.timer,
                                        size: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        booking.pricingType.displayName,
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            
                            // Price
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'LKR',
                                    style: TextStyle(
                                      color: const Color(0xFF7C3AED),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    booking.totalAmount.toStringAsFixed(0),
                                    style: const TextStyle(
                                      color: Color(0xFF7C3AED),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(LoungeBookingStatus status) {
    switch (status) {
      case LoungeBookingStatus.pending:
        return Colors.orange;
      case LoungeBookingStatus.confirmed:
        return Colors.blue;
      case LoungeBookingStatus.checkedIn:
        return Colors.green;
      case LoungeBookingStatus.completed:
        return Colors.grey;
      case LoungeBookingStatus.cancelled:
        return Colors.red;
      case LoungeBookingStatus.noShow:
        return Colors.red.shade300;
    }
  }

  IconData _getStatusIcon(LoungeBookingStatus status) {
    switch (status) {
      case LoungeBookingStatus.pending:
        return Icons.schedule;
      case LoungeBookingStatus.confirmed:
        return Icons.check_circle_outline;
      case LoungeBookingStatus.checkedIn:
        return Icons.login;
      case LoungeBookingStatus.completed:
        return Icons.done_all;
      case LoungeBookingStatus.cancelled:
        return Icons.cancel_outlined;
      case LoungeBookingStatus.noShow:
        return Icons.person_off;
    }
  }
}

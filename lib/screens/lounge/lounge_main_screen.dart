import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_style.dart';
import '../../widgets/blue_header.dart';
import 'lounge_list_content.dart';
import 'my_lounge_bookings_screen.dart';

/// Main lounge screen with tabs for browsing and bookings
class LoungeMainScreen extends StatefulWidget {
  const LoungeMainScreen({super.key});

  @override
  State<LoungeMainScreen> createState() => _LoungeMainScreenState();
}

class _LoungeMainScreenState extends State<LoungeMainScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
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
                    'Lounges',
                    style: AppTextStyles.h2.copyWith(
                      color: AppColors.textLight,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Browse and manage your lounge bookings',
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
                      tabs: const [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.explore, size: 16),
                              SizedBox(width: 6),
                              Text('Browse'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.book_online, size: 16),
                              SizedBox(width: 6),
                              Text('My Bookings'),
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
              child: TabBarView(
                controller: _tabController,
                children: const [
                  LoungeListContent(),
                  MyLoungeBookingsScreen(embedded: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

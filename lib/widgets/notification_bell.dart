import 'package:flutter/material.dart';
import 'dart:async';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';

class NotificationBell extends StatefulWidget {
  final String userId;
  final VoidCallback onTap;
  final int? initialCount;

  const NotificationBell({
    Key? key,
    required this.userId,
    required this.onTap,
    this.initialCount,
  }) : super(key: key);

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> with TickerProviderStateMixin {
  late NotificationService _notificationService;
  int _unreadCount = 0;
  Timer? _refreshTimer;
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rippleAnimation;
  bool _hasNewNotification = false;

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService();
    _unreadCount = widget.initialCount ?? 0;
    
    // Setup animation controller for badge pulse effect (one-time)
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Setup continuous pulse animation (WhatsApp-style breathing)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Setup ripple animation
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _rippleController,
        curve: Curves.easeOut,
      ),
    );
    
    if (widget.initialCount == null) {
      _loadUnreadCount();
    }
    
    // Start continuous pulse if there are unread notifications
    if (_unreadCount > 0) {
      _startContinuousPulse();
    }
    
    // Auto-refresh count every 15 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        _loadUnreadCount();
      }
    });
  }

  @override
  void didUpdateWidget(NotificationBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCount != oldWidget.initialCount && widget.initialCount != null) {
      final hadNewNotification = widget.initialCount! > _unreadCount;
      setState(() {
        _unreadCount = widget.initialCount!;
      });
      
      // Trigger animation if count increased
      if (hadNewNotification && _unreadCount > 0) {
        _triggerNewNotificationAnimation();
        _startContinuousPulse();
      } else if (_unreadCount == 0) {
        _stopContinuousPulse();
      }
    }
  }

  Future<void> _loadUnreadCount() async {
    if (widget.userId.isEmpty) return;
    try {
      final count = await _notificationService.getUnreadCount(widget.userId);
      if (mounted && count != _unreadCount) {
        final hadNewNotification = count > _unreadCount;
        setState(() {
          _unreadCount = count;
        });
        
        // Trigger animation if count increased
        if (hadNewNotification && count > 0) {
          _triggerNewNotificationAnimation();
          _startContinuousPulse();
        } else if (count == 0) {
          _stopContinuousPulse();
        }
      }
    } catch (e) {
      // Silently fail - don't break UI for notification count errors
    }
  }

  void _startContinuousPulse() {
    if (!_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }

  void _stopContinuousPulse() {
    if (_pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  void _triggerNewNotificationAnimation() {
    _hasNewNotification = true;
    
    // Bounce animation
    _animationController.forward().then((_) {
      _animationController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _hasNewNotification = false;
          });
        }
      });
    });
    
    // Ripple effect
    _rippleController.reset();
    _rippleController.forward();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _animationController.dispose();
    _pulseController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_scaleAnimation, _pulseAnimation, _rippleAnimation]),
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Ripple effect when new notification arrives
              if (_rippleAnimation.value > 0)
                Container(
                  width: 60 + (40 * _rippleAnimation.value),
                  height: 60 + (40 * _rippleAnimation.value),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFF4B4B).withOpacity(0.6 * (1 - _rippleAnimation.value)),
                      width: 2,
                    ),
                  ),
                ),
              
              // Main notification bell with continuous pulse
              Transform.scale(
                scale: (_hasNewNotification ? _scaleAnimation.value : 1.0) * 
                       (_unreadCount > 0 ? _pulseAnimation.value : 1.0),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _unreadCount > 0 
                            ? const Color(0xFFFF4B4B).withOpacity(0.3)
                            : Colors.black.withOpacity(0.08),
                        blurRadius: _unreadCount > 0 ? 20 : 12,
                        offset: const Offset(0, 4),
                        spreadRadius: _unreadCount > 0 ? 2 : 0,
                      ),
                    ],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Badge(
                        isLabelVisible: _unreadCount > 0,
                        label: Text(
                          _unreadCount > 99 ? '99+' : '$_unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: const Color(0xFFFF4B4B),
                        largeSize: 18,
                        child: Icon(
                          _unreadCount > 0 
                              ? Icons.notifications_active_rounded 
                              : Icons.notifications_none_rounded,
                          color: _unreadCount > 0 
                              ? const Color(0xFFFF4B4B) 
                              : AppColors.primary,
                          size: 24,
                        ),
                      ),
                      
                      // WhatsApp-style green status dot for new notifications
                      if (_hasNewNotification)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFF25D366), // WhatsApp green
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF25D366).withOpacity(0.5),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

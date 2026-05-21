import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../controllers/notification_controller.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
  }

  void _markAllAsRead() {
    _notificationService.markAllAsRead();
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = AuthService().isLoggedIn.value;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Text(
                      'notification_title'.tr(),
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.black,
                        ),
                      ),
                      if (isLoggedIn)
                        GestureDetector(
                          onTap: _markAllAsRead,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 6.0,
                            ),
                            decoration: const ShapeDecoration(
                              shape: StadiumBorder(),
                              color: Color(0xFFF3F4F6),
                            ),
                            child: Text(
                              'read_all'.tr(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Body: Guest Empty State or Notification List
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF304423),
                onRefresh: () async {
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: !isLoggedIn
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.7,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 88,
                                      height: 88,
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFC9E88A,
                                        ).withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.notifications_none_rounded,
                                        size: 44,
                                        color: Color(0xFF304423),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      'no_notifications'.tr(),
                                      style: GoogleFonts.bricolageGrotesque(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'notification_guest_desc'.tr(),
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        color: const Color(0xFF64748B),
                                        height: 1.6,
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          try {
                                            await AuthService()
                                                .nativeGoogleSignIn();
                                            if (context.mounted &&
                                                AuthService()
                                                    .isLoggedIn
                                                    .value) {
                                              Navigator.pop(context);
                                            }
                                          } catch (error) {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(error.toString()),
                                              ),
                                            );
                                          }
                                        },
                                        icon: Image.asset(
                                          'assets/images/google_logo.png',
                                          height: 24,
                                        ),
                                        label: Text(
                                          'login_with_google'.tr(),
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF304423,
                                          ),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Consumer(
                        builder: (context, ref, child) {
                          final asyncNotifications = ref.watch(
                            notificationControllerProvider,
                          );

                          return asyncNotifications.when(
                            loading: () => const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF304423),
                              ),
                            ),
                            error: (err, stack) =>
                                Center(child: Text('Error: $err')),
                            data: (notifications) {
                              if (notifications.isEmpty) {
                                return ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    SizedBox(
                                      height:
                                          MediaQuery.of(context).size.height *
                                          0.7,
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 40,
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons
                                                    .notifications_none_rounded,
                                                size: 64,
                                                color: Color(0xFF94A3B8),
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                'no_notifications'.tr(),
                                                textAlign: TextAlign.center,
                                                style:
                                                    GoogleFonts.bricolageGrotesque(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: const Color(
                                                        0xFF1E293B,
                                                      ),
                                                    ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'notification_empty_desc'.tr(),
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 14,
                                                  color: const Color(
                                                    0xFF64748B,
                                                  ),
                                                  height: 1.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: notifications.length,
                                itemBuilder: (context, index) {
                                  final item = notifications[index];
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: item.isUnread
                                          ? const Color(0xFFE8F5E9)
                                          : Colors.transparent,
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.grey.withValues(
                                            alpha: 0.2,
                                          ),
                                          width: 1.0,
                                        ),
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24.0,
                                      vertical: 10.0,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.dateTime,
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 4.0),
                                        Row(
                                          children: [
                                            Icon(
                                              item.icon,
                                              size: 20,
                                              color: const Color(0xFF304423),
                                            ),
                                            const SizedBox(width: 8.0),
                                            Expanded(
                                              child: Text(
                                                item.title.tr(
                                                  namedArgs: item.titleArgs,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style:
                                                    GoogleFonts.bricolageGrotesque(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black87,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4.0),
                                        Text(
                                          item.message.tr(
                                            namedArgs: item.messageArgs,
                                          ),
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            color: Colors.black54,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

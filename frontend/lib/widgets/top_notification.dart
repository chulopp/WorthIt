import 'package:flutter/material.dart';

class TopNotification {
  static void show({required BuildContext context, required Widget child}) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _TopNotificationWidget(
        content: child,
        onDismiss: () {
          if (overlayEntry.mounted) {
            overlayEntry.remove();
          }
        },
      ),
    );

    overlay.insert(overlayEntry);
  }
}

class _TopNotificationWidget extends StatefulWidget {
  final Widget content;
  final VoidCallback onDismiss;

  const _TopNotificationWidget({
    Key? key,
    required this.content,
    required this.onDismiss,
  }) : super(key: key);

  @override
  State<_TopNotificationWidget> createState() => _TopNotificationWidgetState();
}

class _TopNotificationWidgetState extends State<_TopNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: Dismissible(
          key: const ValueKey('top-notification'),
          direction: DismissDirection.up,
          onDismissed: (_) => widget.onDismiss(),
          child: SlideTransition(
            position: _offsetAnimation,
            child: widget.content,
          ),
        ),
      ),
    );
  }
}

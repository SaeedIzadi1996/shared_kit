import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Resolves the [OverlayState] the toasts should be inserted into.
///
/// The shared package must not know how each app manages navigation
/// (gold-trade uses a global `navigatorKey`; trust-chain uses go_router's
/// `appRouter`), so each app injects the lookup once at startup:
///
/// ```dart
/// // gold-trade main.dart
/// AppToast.overlayResolver = () => navigatorKey.currentState?.overlay;
///
/// // trust-chain main.dart
/// AppToast.overlayResolver =
///     () => appRouter.routerDelegate.navigatorKey.currentState?.overlay;
/// ```
typedef OverlayResolver = OverlayState? Function();

class AppToast {
  AppToast._();

  /// Must be set once during app startup. Until it is set, toasts no-op.
  static OverlayResolver? overlayResolver;

  static OverlayState? _resolveOverlay() => overlayResolver?.call();

  static OverlayEntry? _current;
  static OverlayEntry? _notificationEntry;

  static void _show({
    required String message,
    Duration duration = const Duration(seconds: 3),
    ToastType type = ToastType.info,
  }) {
    final overlay = _resolveOverlay();
    if (overlay == null) return;

    _current?.remove();
    _current = null;

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: message,
        duration: duration,
        type: type,
        onDismissed: () {
          entry.remove();
          if (_current == entry) _current = null;
        },
      ),
    );

    _current = entry;
    overlay.insert(entry);
  }

  static void error(String message, {Duration duration = const Duration(seconds: 5)}) {
    _show(message: message, duration: duration, type: ToastType.error);
  }

  static void success(String message, {Duration duration = const Duration(seconds: 3)}) {
    _show(message: message, duration: duration, type: ToastType.success);
  }

  static void info(String message, {Duration duration = const Duration(seconds: 3)}) {
    _show(message: message, duration: duration, type: ToastType.info);
  }

  static void warning(String message, {Duration duration = const Duration(seconds: 3)}) {
    _show(message: message, duration: duration, type: ToastType.warning);
  }

  static void show(String message, bool isSuccess, {Duration duration = const Duration(seconds: 3)}) {
    _show(message: message, duration: duration, type: isSuccess ? ToastType.success : ToastType.info);
  }

  static void notification({
    required String title,
    required String message,
    IconData icon = Icons.notifications_rounded,
    Color color = Colors.indigo,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 6),
  }) {
    final overlay = _resolveOverlay();
    if (overlay == null) return;

    _notificationEntry?.remove();
    _notificationEntry = null;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _NotificationToastWidget(
        title: title,
        message: message,
        icon: icon,
        color: color,
        duration: duration,
        onTap: onTap,
        onDismissed: () {
          entry.remove();
          if (_notificationEntry == entry) _notificationEntry = null;
        },
      ),
    );

    _notificationEntry = entry;
    overlay.insert(entry);
  }
}

enum ToastType { success, error, info, warning }

class _ToastWidget extends StatefulWidget {
  final String message;
  final Duration duration;
  final ToastType type;
  final VoidCallback onDismissed;

  const _ToastWidget({
    required this.message,
    required this.duration,
    required this.type,
    required this.onDismissed,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  Color get color {
    switch (widget.type) {
      case ToastType.success:
        return Colors.green;
      case ToastType.error:
        return Colors.red;
      case ToastType.warning:
        return Colors.orange;
      case ToastType.info:
        return Colors.black87;
    }
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      reverseDuration: const Duration(milliseconds: 200),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();

    Future.delayed(widget.duration, () async {
      if (!mounted) return;
      await _controller.reverse();
      widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    if (widget.type == ToastType.error) {
      Clipboard.setData(ClipboardData(text: widget.message));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 60,
      left: 16,
      right: 16,
      child: SafeArea(
        child: FadeTransition(
          opacity: _animation,
          child: GestureDetector(
            onTap: _onTap,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 10,
                      color: Colors.black26,
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                child: Text(
                  widget.message,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationToastWidget extends StatefulWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final Duration duration;
  final VoidCallback? onTap;
  final VoidCallback onDismissed;

  const _NotificationToastWidget({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    required this.duration,
    required this.onDismissed,
    this.onTap,
  });

  @override
  State<_NotificationToastWidget> createState() => _NotificationToastWidgetState();
}

class _NotificationToastWidgetState extends State<_NotificationToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
    Future.delayed(widget.duration, () async {
      if (!mounted) return;
      await _controller.reverse();
      widget.onDismissed();
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
      top: 8,
      left: 12,
      right: 12,
      child: SafeArea(
        child: FadeTransition(
          opacity: _opacity,
          child: SlideTransition(
            position: _slide,
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: () {
                  widget.onTap?.call();
                  _controller.reverse().then((_) => widget.onDismissed());
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border(left: BorderSide(color: widget.color, width: 4)),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 20,
                        color: Colors.black.withValues(alpha: 0.15),
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(widget.icon, color: widget.color, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          textDirection: TextDirection.rtl,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B2559),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.message,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

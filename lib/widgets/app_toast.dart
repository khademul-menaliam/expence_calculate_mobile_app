import 'dart:async';
import 'package:flutter/material.dart';

class AppToast {
  static OverlayEntry? _currentEntry;
  static Timer? _timer;

  static void showUndo({
    required BuildContext context,
    required String message,
    required VoidCallback onUndo,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    _timer?.cancel();
    _currentEntry?.remove();
    _currentEntry = null;

    final overlayState = Overlay.maybeOf(context);
    if (overlayState == null) return;

    final key = GlobalKey<_ToastWidgetState>();
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) {
        return _ToastWidget(
          key: key,
          message: message,
          onUndo: () {
            _timer?.cancel();
            if (_currentEntry == entry) {
              entry.remove();
              _currentEntry = null;
            }
            onUndo();
          },
          onDismiss: () {
            _timer?.cancel();
            if (_currentEntry == entry) {
              entry.remove();
              _currentEntry = null;
            }
          },
        );
      },
    );

    _currentEntry = entry;
    overlayState.insert(entry);

    _timer = Timer(duration, () {
      if (_currentEntry == entry) {
        key.currentState?.dismiss();
      }
    });
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final VoidCallback onUndo;
  final VoidCallback onDismiss;

  const _ToastWidget({
    super.key,
    required this.message,
    required this.onUndo,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  Future<void> dismiss([VoidCallback? action]) async {
    if (!mounted) return;
    if (_controller.status == AnimationStatus.reverse || _controller.status == AnimationStatus.dismissed) {
      return;
    }
    await _controller.reverse();
    if (action != null) {
      action();
    } else {
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 70;

    return Positioned(
      bottom: bottomPadding,
      left: 16,
      right: 16,
      child: Material(
        type: MaterialType.transparency,
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.amber,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => dismiss(widget.onUndo),
                    child: const Text(
                      'UNDO',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

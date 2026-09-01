import 'package:flutter/material.dart';

/// Single snackbar entry point (F1 feedback, 2026-08-31).
///
/// Material's `ScaffoldMessenger.showSnackBar` QUEUES snackbars: rapid actions
/// (deleting several slides, inserting media…) pile up 4 s per snackbar and the
/// last one appears to stay forever. This helper always replaces the current
/// snackbar instead of queueing, and makes the duration explicit.
///
/// Flutter 3.44 made a new default: `SnackBar.persist ?? action != null` — a
/// snackbar WITH an action stays visible forever until the action (or close
/// icon) is tapped. That is exactly the "mãi không tự tắt" bug reported for the
/// delete + Undo snackbar. We force `persist: false` so every notification
/// auto-dismisses after its duration, action still tappable while visible.
void showAppSnackBar(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(message),
      duration: duration,
      persist: false,
      action: actionLabel != null && onAction != null
          ? SnackBarAction(label: actionLabel, onPressed: onAction)
          : null,
    ));
}

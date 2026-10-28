import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const privacyChannel = MethodChannel('shannon/privacy');
bool get nativePrivacy =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// One observer per Navigator. Opaque cover routes can release underlying
/// protection only after their transition finishes. Dialogs keep it active.
class ScreenPrivacyObserver extends NavigatorObserver {
  final _routes = <Route<dynamic>>[];
  final _hosts = <Route<dynamic>, _SensitiveScreenState>{};
  int _revision = 0;
  void _changed({Route<dynamic>? entering}) {
    final revision = ++_revision;
    final visible = <Route<dynamic>>{};
    for (final route in _routes.reversed) {
      visible.add(route);
      if (route is ModalRoute && route.opaque) break;
    }
    void reconcile(bool settled) {
      if (revision != _revision) return;
      for (final entry in _hosts.entries.toList()) {
        if (visible.contains(entry.key)) {
          entry.value._visibility(true);
        } else if (settled && _routes.contains(entry.key)) {
          entry.value._visibility(false);
        }
      }
    }

    // Reveal waits for native acquire; never paint a previously covered secret.
    WidgetsBinding.instance.addPostFrameCallback((_) => reconcile(false));
    final animation = entering is TransitionRoute ? entering.animation : null;
    if (animation == null || animation.status == AnimationStatus.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => reconcile(true));
    } else {
      void done(AnimationStatus status) {
        if (status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed) {
          animation.removeStatusListener(done);
          WidgetsBinding.instance.addPostFrameCallback((_) => reconcile(true));
        }
      }

      animation.addStatusListener(done);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _changed(entering: route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    }
    _changed(entering: newRoute);
  }
}

/// Every real conversation, media, active-call or private-secret route must use
/// this gate. Opaque screens may cover it; overlays inherit its protection.
class SensitiveScreen extends StatefulWidget {
  const SensitiveScreen({required this.child, this.observer, super.key});
  final Widget child;
  final ScreenPrivacyObserver? observer;
  @override
  State<SensitiveScreen> createState() => _SensitiveScreenState();
}

class _SensitiveScreenState extends State<SensitiveScreen> {
  static int _serial = 0;
  String? _lease;
  Route<dynamic>? _route;
  bool _ready = false, _failed = false, _visible = true;
  @override
  void initState() {
    super.initState();
    _protect();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      widget.observer?._hosts.remove(_route);
      _route = route;
      if (route != null) widget.observer?._hosts[route] = this;
    }
  }

  void _visibility(bool visible) {
    if (!mounted || visible == _visible) return;
    setState(() {
      _visible = visible;
      _ready = false;
      _failed = false;
    });
    if (visible) {
      _protect();
    } else {
      _release();
    }
  }

  Future<void> _protect() async {
    final lease = 'route-${++_serial}';
    _lease = lease;
    try {
      if (nativePrivacy) {
        await privacyChannel.invokeMethod<void>('acquire', lease);
      }
      if (mounted && _lease == lease && _visible) setState(() => _ready = true);
    } catch (_) {
      if (mounted && _lease == lease) setState(() => _failed = true);
    }
  }

  void _release() {
    final lease = _lease;
    _lease = null;
    if (nativePrivacy && lease != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          privacyChannel
              .invokeMethod<void>('release', lease)
              .catchError((_) {}),
        );
      });
      // Ensure release runs even when the retired route schedules no new frame.
      WidgetsBinding.instance.scheduleFrame();
    }
  }

  @override
  void dispose() {
    widget.observer?._hosts.remove(_route);
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ready && _visible
      ? widget.child
      : Scaffold(
          body: Center(
            child: _failed
                ? const Text(
                    'Screen protection unavailable. Sensitive content is hidden.',
                  )
                : _visible
                ? const CircularProgressIndicator()
                : const SizedBox.shrink(),
          ),
        );
}

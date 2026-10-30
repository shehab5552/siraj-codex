import 'dart:async';
import 'package:flutter/material.dart';
import '../core/design/siraj_navigation.dart';
import '../features/auth/auth_models.dart';
import 'app_session_controller.dart';

/// Keeps one private Navigator and one navigation bar in the same session scope.
/// Authorization remains in AppSessionController; this host owns only routes.
class AuthenticatedNavigation extends StatefulWidget {
  const AuthenticatedNavigation({
    super.key,
    required this.session,
    required this.identity,
    required this.home,
  });
  final AppSessionController session;
  final AuthSession identity;
  final WidgetBuilder home;
  @override
  State<AuthenticatedNavigation> createState() =>
      _AuthenticatedNavigationState();
}

class _AuthenticatedNavigationState extends State<AuthenticatedNavigation> {
  final _navigator = GlobalKey<NavigatorState>();
  int _index = 0, _selection = 0;
  bool _modal = false, _desiredModal = false, _modalScheduled = false;
  late final _observer = _ModalObserver((value) {
    _desiredModal = value;
    if (!mounted || _modalScheduled) return;
    _modalScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _modalScheduled = false;
      if (mounted && _modal != _desiredModal) {
        setState(() => _modal = _desiredModal);
      }
    });
  });
  Future<void> _select(int value) async {
    if (value < 0 || value > 3 || _modal) return;
    final selection = ++_selection;
    if (!await widget.session.authorizeNavigation(widget.identity) ||
        !mounted ||
        selection != _selection) {
      return;
    }
    _navigator.currentState?.popUntil((route) => route.isFirst);
    setState(() => _index = value);
  }

  @override
  Widget build(BuildContext context) => SirajTabScope(
    index: _index,
    select: (value) => unawaited(_select(value)),
    setContext: (value) {
      if (mounted && _index != value) setState(() => _index = value);
    },
    child: SirajAdaptiveNavigation(
      index: _index,
      onSelect: (value) => unawaited(_select(value)),
      suspended: _modal,
      body: Navigator(
        key: _navigator,
        observers: [_observer],
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: widget.home),
      ),
    ),
  );
}

class _ModalObserver extends NavigatorObserver {
  _ModalObserver(this.changed);
  final ValueChanged<bool> changed;
  final _routes = <Route<dynamic>>[];
  void _changed() => changed(_routes.isNotEmpty && _routes.last is PopupRoute);
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _changed();
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
    _changed();
  }
}

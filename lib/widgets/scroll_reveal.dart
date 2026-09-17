import 'dart:async';

import 'package:flutter/material.dart';

/// Scope to share the root ScrollController across all descendant sections.
class HomeScrollScope extends InheritedWidget {
  final ScrollController scrollController;

  const HomeScrollScope({
    super.key,
    required this.scrollController,
    required super.child,
  });

  static ScrollController? of(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<HomeScrollScope>()
        ?.scrollController;
  }

  @override
  bool updateShouldNotify(HomeScrollScope oldWidget) =>
      scrollController != oldWidget.scrollController;
}

/// A high-performance scroll reveal widget inspired by the web's
/// IntersectionObserver `.home-reveal.is-visible` effect.
///
/// As the user scrolls down, sections fade in and slide up smoothly into view.
/// Includes an automatic 500ms safety timer so content can NEVER stay blank.
class ScrollReveal extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double offsetY;
  final Curve curve;
  final double threshold;

  const ScrollReveal({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 380),
    this.delay = Duration.zero,
    this.offsetY = 22.0,
    this.curve = Curves.easeOutCubic,
    this.threshold = 0.94,
  });

  @override
  State<ScrollReveal> createState() => _ScrollRevealState();
}

class _ScrollRevealState extends State<ScrollReveal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _curveAnim;

  Listenable? _scrollListenable;
  bool _isRevealed = false;
  Timer? _delayTimer;
  Timer? _safetyTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _curveAnim = CurvedAnimation(parent: _controller, curve: widget.curve);

    _controller.addStatusListener(_onAnimStatus);

    // Reveal off-screen content only when no scrollable can be observed.
    _safetyTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted && !_isRevealed) {
        _attachListenerIfNeeded();
        _checkVisibility();
        if (_scrollListenable == null && !_isRevealed) _triggerReveal();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _attachListenerIfNeeded();
        _checkVisibility();
      }
    });
  }

  void _onAnimStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isRevealed) {
      _attachListenerIfNeeded();
    }
  }

  void _attachListenerIfNeeded() {
    if (_isRevealed) return;
    try {
      // Prioritize root HomeScrollScope controller
      final rootController = HomeScrollScope.of(context);
      final listenable =
          rootController ?? Scrollable.maybeOf(context)?.position;

      if (listenable != null && _scrollListenable != listenable) {
        _cleanupListener();
        _scrollListenable = listenable;
        _scrollListenable!.addListener(_checkVisibility);
      }
    } catch (_) {}
  }

  void _triggerReveal() {
    if (_isRevealed) return;
    _isRevealed = true;
    _cleanupListener();
    _safetyTimer?.cancel();

    if (widget.delay > Duration.zero) {
      _delayTimer = Timer(widget.delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    } else {
      _controller.forward();
    }
  }

  void _checkVisibility() {
    if (!mounted || _isRevealed) return;

    _attachListenerIfNeeded();

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize || !renderBox.attached) {
      return;
    }

    final mediaQuery = MediaQuery.maybeOf(context);
    final screenHeight = mediaQuery?.size.height ?? 800.0;

    final Offset globalPos;
    try {
      globalPos = renderBox.localToGlobal(Offset.zero);
    } catch (_) {
      return;
    }

    final top = globalPos.dy;
    final height = renderBox.size.height;

    // Scrolled past top of screen
    if (top + height < 0) {
      _isRevealed = true;
      _cleanupListener();
      _safetyTimer?.cancel();
      _controller.value = 1.0;
      if (mounted) setState(() {});
      return;
    }

    // Entering viewport from bottom
    if (top < screenHeight * widget.threshold) {
      _triggerReveal();
    }
  }

  void _cleanupListener() {
    try {
      _scrollListenable?.removeListener(_checkVisibility);
    } catch (_) {}
    _scrollListenable = null;
  }

  @override
  void dispose() {
    _cleanupListener();
    _delayTimer?.cancel();
    _safetyTimer?.cancel();
    _controller.removeStatusListener(_onAnimStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isRevealed && _controller.isCompleted) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _curveAnim.value;
        return Opacity(
          opacity: progress.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1.0 - progress) * widget.offsetY),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

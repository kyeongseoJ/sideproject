import 'dart:async';

import 'package:flutter/material.dart';
import 'package:novelty_app/novelty_theme.dart';

class NoveltySplashGate extends StatefulWidget {
  const NoveltySplashGate({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1600),
  });

  final Widget child;
  final Duration duration;

  @override
  State<NoveltySplashGate> createState() => _NoveltySplashGateState();
}

class _NoveltySplashGateState extends State<NoveltySplashGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  Timer? _timer;
  bool _showSplash = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 1;
    } else if (_showSplash && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _scale = Tween<double>(
      begin: 0.94,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _timer = Timer(widget.duration, () {
      if (mounted) {
        _controller.stop();
        setState(() => _showSplash = false);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: NoveltyMotion.slow,
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    child: _showSplash
        ? ColoredBox(
            key: const Key('novelty-splash'),
            color: NoveltyColors.primary,
            child: Center(
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.72, end: 1).animate(_fade),
                child: ScaleTransition(
                  scale: _scale,
                  child: Semantics(
                    label: 'Novelty 로딩 중',
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/ui/Novelty_logo_white.png',
                          width: 112,
                          height: 112,
                          filterQuality: FilterQuality.high,
                        ),
                        const SizedBox(height: 24),
                        Image.asset(
                          'assets/ui/Novelty_logo_letter_white.png',
                          width: 190,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
        : KeyedSubtree(
            key: const Key('novelty-app-content'),
            child: widget.child,
          ),
  );
}

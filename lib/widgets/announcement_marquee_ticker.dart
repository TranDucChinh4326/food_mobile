import 'dart:async';

import 'package:flutter/material.dart';

import '../models/home_content.dart';

/// Horizontal scrolling marquee ticker for announcements.
/// Text continuously glides from right to left across the screen.
class AnnouncementMarqueeTicker extends StatefulWidget {
  const AnnouncementMarqueeTicker({
    super.key,
    required this.announcements,
    required this.onTap,
  });

  final List<HomeAnnouncement> announcements;
  final VoidCallback onTap;

  @override
  State<AnnouncementMarqueeTicker> createState() =>
      _AnnouncementMarqueeTickerState();
}

class _AnnouncementMarqueeTickerState extends State<AnnouncementMarqueeTicker> {
  late final ScrollController _scrollController;
  Timer? _tickerTimer;
  bool _isDisposed = false;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startContinuousScroll();
    });
  }

  @override
  void didUpdateWidget(AnnouncementMarqueeTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.announcements != widget.announcements) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startContinuousScroll();
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _tickerTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startContinuousScroll() {
    _tickerTimer?.cancel();
    if (_isDisposed || !mounted) return;
    if (!_scrollController.hasClients) {
      _tickerTimer = Timer(
        const Duration(milliseconds: 300),
        _startContinuousScroll,
      );
      return;
    }
    _runScrollLoop();
  }

  Future<void> _runScrollLoop() async {
    if (_isScrolling || _isDisposed || !mounted) return;
    _isScrolling = true;

    while (!_isDisposed && mounted && _scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) {
        await Future.delayed(const Duration(milliseconds: 500));
        continue;
      }

      final current = _scrollController.offset;
      final remaining = maxScroll - current;
      // Scroll speed ~ 7.7 pixels per second (halved again from previous 15.4 px/s)
      final durationMs = (remaining * 130).toInt().clamp(6000, 720000);

      try {
        await _scrollController.animateTo(
          maxScroll,
          duration: Duration(milliseconds: durationMs),
          curve: Curves.linear,
        );
        if (_isDisposed || !mounted || !_scrollController.hasClients) break;
        _scrollController.jumpTo(0.0);
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (_) {
        break;
      }
    }
    _isScrolling = false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.announcements.isEmpty) return const SizedBox.shrink();

    return InkWell(
      onTap: widget.onTap,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 150,
        itemBuilder: (context, index) {
          final item =
              widget.announcements[index % widget.announcements.length];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!item.isRead)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF3D00),
                      shape: BoxShape.circle,
                    ),
                  ),
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Color(0xFFFFEDE3),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 14),
                const Text(
                  '✦',
                  style: TextStyle(color: Color(0xFFFF8A1D), fontSize: 10),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/config/remote_config.dart';
import '../core/l10n/ltext.dart';
import 'tr.dart';

/// The owner's announcements (up to 3) as one bright, animated card:
/// a glowing gradient, a ringing megaphone with ripples and a light that
/// sweeps across. With several announcements the card changes by itself
/// every few seconds (swipe or tap a dot to move earlier). Animations are
/// switched off when the phone asks for reduced motion.
class AnnouncementCard extends StatefulWidget {
  final List<Announcement> items;
  final void Function(Announcement item) onOpen;
  const AnnouncementCard({super.key, required this.items, required this.onOpen});

  @override
  State<AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends State<AnnouncementCard> with SingleTickerProviderStateMixin {
  static const _colors = [Color(0xFFFF7A18), Color(0xFFE91E63), Color(0xFF7B2FF7)];

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );
  Timer? _rotate;
  int _index = 0;
  bool _forward = true;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _startRotation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.of(context).disableAnimations;
    _reduced = reduced;
    if (reduced) {
      _anim.stop();
    } else if (!_anim.isAnimating) {
      _anim.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnnouncementCard old) {
    super.didUpdateWidget(old);
    if (_index >= widget.items.length) _index = 0;
    _startRotation();
  }

  @override
  void dispose() {
    _rotate?.cancel();
    _anim.dispose();
    super.dispose();
  }

  void _startRotation() {
    _rotate?.cancel();
    if (widget.items.length < 2) return;
    _rotate = Timer.periodic(const Duration(seconds: 6), (_) => _step(1));
  }

  void _step(int by) {
    final n = widget.items.length;
    if (!mounted || n < 2) return;
    setState(() {
      _forward = by > 0;
      _index = (_index + by) % n;
      if (_index < 0) _index += n;
    });
  }

  void _goTo(int i) {
    if (i == _index) return;
    setState(() {
      _forward = i > _index;
      _index = i;
    });
    _startRotation(); // a fresh 6 seconds after the person's own choice
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();
    final index = _index < items.length ? _index : 0;
    final item = items[index];
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.94, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Opacity(
        opacity: scale.clamp(0.0, 1.0).toDouble(),
        child: Transform.scale(scale: scale, child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GestureDetector(
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -200) {
              _step(1);
              _startRotation();
            } else if (v > 200) {
              _step(-1);
              _startRotation();
            }
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _colors[1].withAlpha(90),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _colors,
                  ),
                ),
                child: Stack(
                  children: [
                    // light sweeping across the card
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _anim,
                          builder: (context, _) => LayoutBuilder(
                            builder: (context, box) {
                              final t = _reduced ? 0.0 : _anim.value;
                              // the light travels during the last 45% of each round
                              final p = ((t - 0.55) / 0.45).clamp(0.0, 1.0).toDouble();
                              final w = box.maxWidth;
                              return Transform.translate(
                                offset: Offset(-w * 0.4 + p * w * 1.6, 0),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Transform(
                                    transform: Matrix4.skewX(-0.35),
                                    child: Container(
                                      width: w * 0.28,
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Color(0x00FFFFFF), Color(0x55FFFFFF), Color(0x00FFFFFF)],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: () => widget.onOpen(item),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _Megaphone(animation: _anim, reduced: _reduced),
                              const SizedBox(width: 14),
                              Expanded(
                                child: AnimatedSize(
                                  duration: const Duration(milliseconds: 250),
                                  alignment: Alignment.topLeft,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 380),
                                    transitionBuilder: (child, a) => FadeTransition(
                                      opacity: a,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: Offset(_forward ? 0.15 : -0.15, 0),
                                          end: Offset.zero,
                                        ).animate(a),
                                        child: child,
                                      ),
                                    ),
                                    child: _Text(key: ValueKey('${item.id}_$index'), item: item, anim: _anim, reduced: _reduced),
                                  ),
                                ),
                              ),
                              if (item.url != null)
                                const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (items.length > 1)
                      Positioned(
                        right: 12,
                        bottom: 6,
                        child: Row(
                          children: [
                            for (var i = 0; i < items.length; i++)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _goTo(i),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    width: i == index ? 18 : 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: i == index ? Colors.white : Colors.white54,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
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
    );
  }
}

class _Text extends StatelessWidget {
  final Announcement item;
  final Animation<double> anim;
  final bool reduced;
  const _Text({super.key, required this.item, required this.anim, required this.reduced});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // a small dot that blinks next to the label
            AnimatedBuilder(
              animation: anim,
              builder: (context, _) {
                final blink = reduced ? 1.0 : 0.45 + 0.55 * (0.5 + 0.5 * math.sin(anim.value * 2 * math.pi * 2));
                return Opacity(
                  opacity: blink,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: SizedBox(width: 8, height: 8),
                  ),
                );
              },
            ),
            const SizedBox(width: 6),
            Text(
              tr(context, t('ANNOUNCEMENT', 'घोषणा')),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        if (item.title.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            item.title,
            style: text.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.2),
          ),
        ],
        if (item.message.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            item.message,
            style: const TextStyle(color: Color(0xF2FFFFFF), height: 1.3),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

/// The megaphone: ripples spread from a white disc and the icon "rings".
class _Megaphone extends StatelessWidget {
  final Animation<double> animation;
  final bool reduced;
  const _Megaphone({required this.animation, required this.reduced});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = reduced ? 0.0 : animation.value;
          final rings = <Widget>[];
          if (!reduced) {
            for (final shift in const [0.0, 0.5]) {
              final p = (t + shift) % 1.0;
              rings.add(Opacity(
                opacity: (0.5 * (1 - p)).clamp(0.0, 1.0).toDouble(),
                child: Transform.scale(
                  scale: 0.8 + 0.75 * p,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
                    ),
                    child: SizedBox(width: 52, height: 52),
                  ),
                ),
              ));
            }
          }
          // rings (wiggles) during the first 30% of each round, then rests
          final wiggle = (!reduced && t < 0.3) ? math.sin(t / 0.3 * math.pi * 6) * 0.22 * (1 - t / 0.3) : 0.0;
          final pulse = reduced ? 1.0 : 1.0 + 0.06 * math.sin(t * 2 * math.pi);
          return Stack(
            alignment: Alignment.center,
            children: [
              ...rings,
              Transform.scale(
                scale: pulse,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(color: Color(0x33FFFFFF), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Transform.rotate(
                    angle: wiggle,
                    child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 30),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

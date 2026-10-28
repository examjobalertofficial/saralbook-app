import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/config/remote_config.dart';
import '../core/l10n/ltext.dart';
import 'tr.dart';

/// The owner's announcements (up to 3) as one compact, animated card.
/// With several announcements the card slides from right to left every few
/// seconds and each announcement has its own colour, so all of them share one
/// small place on Home (a thin line shows the time left; swipe or tap a dot to
/// move). A ringing megaphone with ripples, a sweeping light and a blinking
/// dot keep it lively. Animations are off when the phone asks for reduced motion.
class AnnouncementCard extends StatefulWidget {
  final List<Announcement> items;
  final void Function(Announcement item) onOpen;
  const AnnouncementCard({super.key, required this.items, required this.onOpen});

  @override
  State<AnnouncementCard> createState() => _AnnouncementCardState();
}

/// One colour set for each announcement (they repeat if there are more).
const List<List<Color>> _palettes = [
  [Color(0xFFFF7A18), Color(0xFFE91E63), Color(0xFF7B2FF7)], // warm
  [Color(0xFF00A86B), Color(0xFF00897B), Color(0xFF1565C0)], // green to blue
  [Color(0xFF1E88E5), Color(0xFF3949AB), Color(0xFF00ACC1)], // cool blue
  [Color(0xFFD81B60), Color(0xFF8E24AA), Color(0xFF3949AB)], // rose to indigo
  [Color(0xFFF57C00), Color(0xFFE53935), Color(0xFFAD1457)], // sunset
  [Color(0xFF00897B), Color(0xFF43A047), Color(0xFF9E9D24)], // forest
  [Color(0xFF5E35B1), Color(0xFF1E88E5), Color(0xFF00ACC1)], // violet to cyan
  [Color(0xFFC62828), Color(0xFFEF6C00), Color(0xFFF9A825)], // fire
  [Color(0xFF00838F), Color(0xFF1565C0), Color(0xFF4527A0)], // ocean
  [Color(0xFF6D4C41), Color(0xFFD84315), Color(0xFFFF8F00)], // earth
  [Color(0xFF283593), Color(0xFF6A1B9A), Color(0xFFD81B60)], // night
];

List<Color> _paletteOf(int index) => _palettes[index % _palettes.length];

class _AnnouncementCardState extends State<AnnouncementCard> with SingleTickerProviderStateMixin {
  static const _every = Duration(seconds: 6);

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );
  Timer? _rotate;
  int _index = 0;
  int _epoch = 0; // restarts the "time left" line
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
    _reduced = MediaQuery.of(context).disableAnimations;
    if (_reduced) {
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
    _rotate = Timer.periodic(_every, (_) => _step(1));
  }

  void _step(int by) {
    final n = widget.items.length;
    if (!mounted || n < 2) return;
    setState(() {
      _forward = by > 0;
      _index = (_index + by) % n;
      if (_index < 0) _index += n;
      _epoch++;
    });
  }

  void _byPerson(int by) {
    _step(by);
    _startRotation(); // a fresh 6 seconds after the person's own choice
  }

  void _goTo(int i) {
    if (i == _index) return;
    setState(() {
      _forward = i > _index;
      _index = i;
      _epoch++;
    });
    _startRotation();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();
    final index = _index < items.length ? _index : 0;
    final palette = _paletteOf(index);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.95, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Opacity(
        opacity: scale.clamp(0.0, 1.0).toDouble(),
        child: Transform.scale(scale: scale, child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -200) {
              _byPerson(1);
            } else if (v > 200) {
              _byPerson(-1);
            }
          },
          // the glow stays in place and changes colour; only the card slides
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 450),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: palette[1].withAlpha(70),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 250),
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: _reduced ? Duration.zero : const Duration(milliseconds: 480),
                  switchInCurve: Curves.easeInOutCubic,
                  switchOutCurve: Curves.easeInOutCubic,
                  transitionBuilder: (child, animation) {
                    // the new card comes in from the right, the old one leaves to the left
                    final incoming = child.key == ValueKey<int>(index);
                    final side = _forward ? 1.0 : -1.0;
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(incoming ? side : -side, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    );
                  },
                  child: _Face(
                    key: ValueKey<int>(index),
                    item: items[index],
                    palette: palette,
                    animation: _anim,
                    reduced: _reduced,
                    count: items.length,
                    index: index,
                    epoch: _epoch,
                    every: _every,
                    onOpen: widget.onOpen,
                    onDot: _goTo,
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

/// One announcement drawn on its own colour.
class _Face extends StatelessWidget {
  final Announcement item;
  final List<Color> palette;
  final Animation<double> animation;
  final bool reduced;
  final int count;
  final int index;
  final int epoch;
  final Duration every;
  final void Function(Announcement item) onOpen;
  final ValueChanged<int> onDot;
  const _Face({
    super.key,
    required this.item,
    required this.palette,
    required this.animation,
    required this.reduced,
    required this.count,
    required this.index,
    required this.epoch,
    required this.every,
    required this.onOpen,
    required this.onDot,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x30FFFFFF)),
      ),
      child: Stack(
        children: [
          // light sweeping across the card
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, _) => LayoutBuilder(
                  builder: (context, box) {
                    final t = reduced ? 0.0 : animation.value;
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
                            width: w * 0.26,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0x00FFFFFF), Color(0x4DFFFFFF), Color(0x00FFFFFF)],
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
              onTap: () => onOpen(item),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _Megaphone(animation: animation, reduced: reduced),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _LabelRow(
                            animation: animation,
                            reduced: reduced,
                            count: count,
                            index: index,
                            onDot: onDot,
                          ),
                          const SizedBox(height: 2),
                          _Body(item: item),
                        ],
                      ),
                    ),
                    if (item.url != null)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 15),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // time left before the next announcement
          if (count > 1 && !reduced)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 2.5,
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey<int>(epoch),
                  tween: Tween(begin: 0, end: 1),
                  duration: every,
                  builder: (context, v, _) => Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: v,
                      child: const ColoredBox(color: Color(0x66FFFFFF), child: SizedBox(height: 2.5)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The small "ANNOUNCEMENT" label with a blinking dot, and the dots that pick an announcement.
class _LabelRow extends StatelessWidget {
  final Animation<double> animation;
  final bool reduced;
  final int count;
  final int index;
  final ValueChanged<int> onDot;
  const _LabelRow({
    required this.animation,
    required this.reduced,
    required this.count,
    required this.index,
    required this.onDot,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final blink = reduced ? 1.0 : 0.45 + 0.55 * (0.5 + 0.5 * math.sin(animation.value * 2 * math.pi * 2));
            return Opacity(
              opacity: blink,
              child: const DecoratedBox(
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: SizedBox(width: 7, height: 7),
              ),
            );
          },
        ),
        const SizedBox(width: 6),
        Text(
          tr(context, t('ANNOUNCEMENT', 'घोषणा')),
          style: const TextStyle(
            color: Color(0xE6FFFFFF),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
          ),
        ),
        const Spacer(),
        if (count > 1)
          for (var i = 0; i < count; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onDot(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: i == index ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == index ? Colors.white : Colors.white54,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  final Announcement item;
  const _Body({required this.item});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.title.isNotEmpty)
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.5, height: 1.2),
          ),
        if (item.message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              item.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xF2FFFFFF), fontSize: 13, height: 1.25),
            ),
          ),
      ],
    );
  }
}

/// The megaphone: ripples spread from a soft disc and the icon "rings".
class _Megaphone extends StatelessWidget {
  final Animation<double> animation;
  final bool reduced;
  const _Megaphone({required this.animation, required this.reduced});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46,
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
                  scale: 0.8 + 0.7 * p,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 1.6)),
                    ),
                    child: SizedBox(width: 42, height: 42),
                  ),
                ),
              ));
            }
          }
          // rings (wiggles) during the first 30% of each round, then rests
          final wiggle = (!reduced && t < 0.3) ? math.sin(t / 0.3 * math.pi * 6) * 0.22 * (1 - t / 0.3) : 0.0;
          final pulse = reduced ? 1.0 : 1.0 + 0.05 * math.sin(t * 2 * math.pi);
          return Stack(
            alignment: Alignment.center,
            children: [
              ...rings,
              Transform.scale(
                scale: pulse,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(color: Color(0x33FFFFFF), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Transform.rotate(
                    angle: wiggle,
                    child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 25),
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

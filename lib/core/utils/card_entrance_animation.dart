import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Shared timing for the staggered "card sits empty, then its content pops
/// in" entrance used across installment and dashboard cards. The outer
/// card container is never wrapped — only its internal children.
const Duration kCardAnimDuration = Duration(milliseconds: 500);
const Curve kCardAnimCurve = Curves.easeOutCubic;
const Curve kCardPopCurve = Curves.easeOutBack;
const double kCardSlideOffset = 0.35;
const Offset kCardScaleBegin = Offset(0.85, 0.85);

/// Beat before any content starts appearing, so the card is visibly empty
/// for a moment before its data pops in.
const Duration kCardInitialDelay = Duration(milliseconds: 180);
const Duration kCardStaggerStep = Duration(milliseconds: 140);

/// [tier] is the stagger step (0, 1, 2, ...) — each tier starts one
/// [kCardStaggerStep] after the previous one, following [kCardInitialDelay].
Duration cardStaggerDelay(int tier) =>
    kCardInitialDelay + kCardStaggerStep * tier;

extension CardEntranceAnimation on Widget {
  /// Fades, slides up, and pops (scales) this widget into place as tier
  /// [tier] of a staggered card entrance.
  Widget popIn(int tier) {
    return animate(delay: cardStaggerDelay(tier))
        .fadeIn(duration: kCardAnimDuration, curve: kCardAnimCurve)
        .slideY(
          begin: kCardSlideOffset,
          end: 0,
          duration: kCardAnimDuration,
          curve: kCardAnimCurve,
        )
        .scale(
          begin: kCardScaleBegin,
          end: const Offset(1, 1),
          duration: kCardAnimDuration,
          curve: kCardPopCurve,
        );
  }

  /// Same as [popIn], but only applies the effect when [shouldAnimate] is
  /// true — otherwise returns the widget unchanged. Used inside
  /// [CardPopIn.builder] so a card's tiers only animate once it has
  /// actually scrolled into view.
  Widget popInIf(bool shouldAnimate, int tier) =>
      shouldAnimate ? popIn(tier) : this;
}

/// Wraps a card so its entrance animation only plays the first time it
/// scrolls into the viewport — not the moment it's built. This matters for
/// any list where items below the fold get built eagerly (e.g. a
/// `ListView` with `shrinkWrap: true`, or content further down a
/// `SingleChildScrollView`): without this, a card's `.popIn()` timers would
/// already have finished by the time the user scrolls down to see it.
///
/// [id] must be stable and unique across the whole app (it becomes the
/// underlying `VisibilityDetector` key) — e.g. an installment's id, or a
/// fixed string for a one-off dashboard card.
///
/// [builder] receives `animate: true` exactly once, the first time the
/// card becomes >5% visible; before that it's called with `animate: false`
/// so the (invisible) placeholder still reserves the card's real layout
/// height for accurate visibility detection.
class CardPopIn extends StatefulWidget {
  final String id;
  final Widget Function(BuildContext context, bool animate) builder;

  const CardPopIn({super.key, required this.id, required this.builder});

  @override
  State<CardPopIn> createState() => _CardPopInState();
}

class _CardPopInState extends State<CardPopIn> {
  bool _hasAppeared = false;

  @override
  Widget build(BuildContext context) {
    if (_hasAppeared) {
      return widget.builder(context, true);
    }
    return VisibilityDetector(
      key: Key('card-pop-in-${widget.id}'),
      onVisibilityChanged: (info) {
        if (!_hasAppeared && info.visibleFraction > 0.05 && mounted) {
          setState(() => _hasAppeared = true);
        }
      },
      child: IgnorePointer(
        child: Opacity(opacity: 0, child: widget.builder(context, false)),
      ),
    );
  }
}

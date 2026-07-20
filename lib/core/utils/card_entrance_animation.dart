import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
}

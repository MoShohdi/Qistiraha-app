import 'package:flutter/material.dart';

/// Width (in logical pixels) at which the app switches from its mobile
/// layout to a dedicated desktop/web layout.
const double kDesktopBreakpoint = 850;

/// Max width the main content area is allowed to stretch to on desktop —
/// keeps things readable on ultrawide monitors instead of spanning
/// edge-to-edge.
const double kDesktopMaxContentWidth = 1200;

/// Renders [desktopWidget] once the available width reaches
/// [kDesktopBreakpoint], [mobileWidget] otherwise. Uses [LayoutBuilder] (not
/// `MediaQuery` alone) so a live window resize on desktop/web is picked up
/// immediately without needing a hot restart.
///
/// On Flutter web, the browser's real viewport size sometimes isn't measured
/// yet by the time the very first frame builds — [LayoutBuilder] evaluates
/// against a stale/default constraint that frame, and nothing then tells this
/// widget to re-check until something else (like a hot reload) forces a
/// rebuild. [WidgetsBindingObserver.didChangeMetrics] fires as soon as the
/// engine reports the real size, and the post-frame callback forces one extra
/// check right after mount — either is enough to correct course immediately
/// instead of leaving the mobile layout stretched across the desktop window.
class ResponsiveLayout extends StatefulWidget {
  final Widget mobileWidget;
  final Widget desktopWidget;

  const ResponsiveLayout({
    super.key,
    required this.mobileWidget,
    required this.desktopWidget,
  });

  @override
  State<ResponsiveLayout> createState() => _ResponsiveLayoutState();
}

class _ResponsiveLayoutState extends State<ResponsiveLayout>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return constraints.maxWidth >= kDesktopBreakpoint
            ? widget.desktopWidget
            : widget.mobileWidget;
      },
    );
  }
}

/// Centers [child] and caps its width at [maxWidth] — the standard
/// "don't stretch forever on a 32-inch monitor" wrapper for desktop content
/// areas.
class DesktopCenteredContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const DesktopCenteredContent({
    super.key,
    required this.child,
    this.maxWidth = kDesktopMaxContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Embeds a full "screen" widget — one written to be pushed via `Navigator`,
/// complete with its own `AppBar`/back button — as a non-navigable panel
/// (e.g. the detail pane of a desktop master-detail layout).
///
/// Wrapping [child] in its own single-route [Navigator] keeps any
/// `Navigator.pop()` calls it makes internally scoped to that private stack
/// instead of popping the real, enclosing desktop shell. Give this a `key`
/// derived from whatever identifies the selected record (e.g.
/// `ValueKey(installment.id)`) so switching the selection mounts a fresh
/// instance rather than reusing stale state from the previous one.
class EmbeddedScreen extends StatelessWidget {
  final Widget child;
  const EmbeddedScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (settings) =>
          MaterialPageRoute(builder: (_) => child, settings: settings),
    );
  }
}

/// A "select something on the left" placeholder for the empty state of a
/// desktop master-detail detail pane.
class DesktopEmptyDetail extends StatelessWidget {
  final IconData icon;
  final String message;

  const DesktopEmptyDetail({
    super.key,
    this.icon = Icons.touch_app_outlined,
    this.message = 'Select a record to view details',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey[500], fontSize: 15),
          ),
        ],
      ),
    );
  }
}

/// Standard desktop interactive-card chrome: click cursor, a subtle border
/// that appears on hover (or when [selected]), and a soft lift shadow while
/// hovered. Purely presentational — wrap any card/list-tile/nav-item that
/// needs proper desktop affordances in this instead of a bare
/// `GestureDetector`.
class DesktopHoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final Color selectedColor;
  final bool selected;
  final Color? backgroundColor;

  const DesktopHoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.selectedColor = const Color(0xFF99AFD7),
    this.selected = false,
    this.backgroundColor,
  });

  @override
  State<DesktopHoverCard> createState() => _DesktopHoverCardState();
}

class _DesktopHoverCardState extends State<DesktopHoverCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = widget.selected
        ? widget.selectedColor
        : (_hovering ? Colors.grey[400]! : Colors.grey[200]!);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: widget.backgroundColor ?? Colors.white,
          borderRadius: widget.borderRadius,
          border: Border.all(
            color: borderColor,
            width: widget.selected ? 1.5 : 1,
          ),
          boxShadow: _hovering || widget.selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: widget.borderRadius,
          child: InkWell(
            borderRadius: widget.borderRadius,
            onTap: widget.onTap,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

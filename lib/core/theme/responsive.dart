import 'package:flutter/widgets.dart';

// Material Design 3 adaptive layout breakpoints
const double kCompactBreak = 600.0;   // phone → tablet boundary
const double kExpandedBreak = 840.0;  // tablet → large-tablet boundary

extension ResponsiveContext on BuildContext {
  double get _w => MediaQuery.sizeOf(this).width;

  bool get isCompact  => _w < kCompactBreak;
  bool get isMedium   => _w >= kCompactBreak && _w < kExpandedBreak;
  bool get isExpanded => _w >= kExpandedBreak;
  bool get isTablet   => _w >= kCompactBreak;

  /// Horizontal padding for full-bleed content sections.
  double get hPad => isTablet ? 36.0 : 24.0;

  /// Number of columns for the categories bento grid.
  int get gridColumns {
    if (isExpanded) return 4;
    if (isMedium)   return 3;
    return 2;
  }

  /// Max width for the scrollable content area; infinity on phones.
  double get contentMaxWidth => isExpanded ? 840.0 : double.infinity;
}

/// Wraps [child] in a centered, max-width container on wide screens.
/// On compact/medium it is a no-op.
Widget responsiveCenter({required BuildContext context, required Widget child}) {
  final maxW = context.contentMaxWidth;
  if (maxW == double.infinity) return child;
  return Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxW), child: child));
}

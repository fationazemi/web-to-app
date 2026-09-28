import 'package:flutter/material.dart';

/// Responsive breakpoints shared by every screen.
///
/// * phone:  shortest side < 600dp (bottom bar, single column)
/// * tablet: shortest side >= 600dp (wider cards, more grid columns, all
///   orientations allowed)
/// * wide:   width >= 900dp (navigation rail, side toolbar on the canvas)
class Layout {
  Layout._();

  static const double tabletShortestSide = 600;
  static const double wideWidth = 900;
  static const double contentMaxWidth = 760;
  static const double narrowContentMaxWidth = 640;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= tabletShortestSide;

  static bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= wideWidth;

  /// Horizontal page padding that keeps content centered at [maxWidth] on
  /// large screens and 20dp from the edge on phones.
  static EdgeInsets pagePadding(BuildContext context, {double maxWidth = contentMaxWidth}) {
    final width = MediaQuery.sizeOf(context).width;
    final side = width > maxWidth ? (width - maxWidth) / 2 : 20.0;
    return EdgeInsets.symmetric(horizontal: side);
  }

  /// Number of grid columns for cards roughly [itemWidth] wide.
  static int columns(double width, {double itemWidth = 190, int min = 2, int max = 6}) =>
      (width / itemWidth).floor().clamp(min, max);
}

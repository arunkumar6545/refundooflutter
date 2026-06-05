import 'package:flutter/material.dart';
import '../../models/refund_item.dart';

/// Single source of truth for category icons used both in the dashboard
/// bento cards and in the refund list tiles.
IconData iconForCategory(RefundCategory? c) {
  switch (c) {
    case RefundCategory.travel:        return Icons.flight_takeoff;
    case RefundCategory.retail:        return Icons.shopping_bag_outlined;
    case RefundCategory.services:      return Icons.account_tree_outlined;
    case RefundCategory.foodDining:    return Icons.restaurant_outlined;
    case RefundCategory.electronics:   return Icons.devices_outlined;
    case RefundCategory.entertainment: return Icons.movie_outlined;
    default:                           return Icons.receipt_long_outlined;
  }
}

/// Gradient per category used in the bento cards and the category screen header.
LinearGradient gradientForCategory(RefundCategory? c) {
  switch (c) {
    case RefundCategory.travel:
      return const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
      );
    case RefundCategory.retail:
      return const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
      );
    case RefundCategory.services:
      return const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
      );
    case RefundCategory.foodDining:
      return const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFFE65100), Color(0xFFBF360C)],
      );
    case RefundCategory.electronics:
      return const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF263238), Color(0xFF37474F)],
      );
    case RefundCategory.entertainment:
      return const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFFAD1457), Color(0xFF880E4F)],
      );
    default:
      return const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF004D40), Color(0xFF00695C)],
      );
  }
}

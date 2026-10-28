import 'package:flutter/material.dart';

/// Icons a category can use. The database stores `codePoint`; the UI resolves
/// it back through this const list (never `IconData(codePoint)`), so release
/// builds can still tree-shake the Material icon font.
abstract final class CategoryIcons {
  static const List<IconData> all = <IconData>[
    Icons.restaurant,
    Icons.local_cafe,
    Icons.shopping_cart,
    Icons.shopping_bag,
    Icons.directions_bus,
    Icons.directions_car,
    Icons.local_gas_station,
    Icons.flight,
    Icons.bolt,
    Icons.water_drop,
    Icons.home,
    Icons.phone_android,
    Icons.wifi,
    Icons.local_hospital,
    Icons.medication,
    Icons.fitness_center,
    Icons.movie,
    Icons.sports_esports,
    Icons.school,
    Icons.menu_book,
    Icons.checkroom,
    Icons.child_care,
    Icons.pets,
    Icons.build,
    Icons.payments,
    Icons.work,
    Icons.star,
    Icons.redeem,
    Icons.card_giftcard,
    Icons.trending_up,
    Icons.attach_money,
    Icons.savings,
    Icons.more_horiz,
  ];

  static const IconData fallback = Icons.category;

  static IconData byCodePoint(int codePoint) {
    for (final IconData i in all) {
      if (i.codePoint == codePoint) return i;
    }
    return fallback;
  }
}

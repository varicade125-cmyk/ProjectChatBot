import 'package:flutter/material.dart';

/// Fixed built-in avatar set (no image assets, no network).
/// Keys are stored in `companion_profile.avatarRef`.
const Map<String, IconData> companionAvatars = {
  'robot': Icons.smart_toy_outlined,
  'pet': Icons.pets_outlined,
  'leaf': Icons.spa_outlined,
  'star': Icons.star_outline,
  'sail': Icons.sailing_outlined,
  'cup': Icons.coffee_outlined,
};

IconData avatarIconFor(String? ref) =>
    companionAvatars[ref] ?? Icons.smart_toy_outlined;

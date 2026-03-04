import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the app locale. null means system default.
final localeProvider = StateProvider<Locale?>((ref) => null);

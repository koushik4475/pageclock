import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Selected tab in the main PageClock navigation shell.
final mainTabNavigationIndexProvider = StateProvider<int>((ref) => 0);

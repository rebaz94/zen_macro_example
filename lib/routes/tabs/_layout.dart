import 'package:flutter/material.dart';
import 'package:macro_kit/macro_kit.dart';
import 'package:zen_macro/layout_macro.dart';
import 'package:zen_macro/route_macro.dart';
import 'package:zen_macro/routes/routes.zen.dart';
import 'package:zen_macro/routes/tabs/feed/_layout.dart';
import 'package:zen_macro/routes/tabs/profile.dart';
import 'package:zen_macro/routes/tabs/settings.dart';

part '../../.gen/routes/tabs/_layout.g.dart';

@Macro(
  ZenLayoutMacro(
    layoutType: LayoutType.indexed,
    routes: [FeedIndexedTab, ProfileTab, SettingsTab],
  ),
)
class Tabs extends TabsLayout {
  @override
  Widget build(covariant Coordinator<RouteUnique> coordinator, BuildContext context) {
    throw UnimplementedError();
  }
}

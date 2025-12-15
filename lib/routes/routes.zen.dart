import 'dart:async';

import 'package:zen_macro/routes/tabs/feed/_layout.dart';
import 'package:zen_macro/routes/tabs/feed/for-you/_layout.dart';
import 'package:zen_macro/routes/tabs/profile.dart';
import 'package:zen_macro/routes/tabs/settings.dart';
import 'package:zenrouter/zenrouter.dart';

abstract class AppRoute extends RouteTarget with RouteUnique {}

class AppCoordinator extends Coordinator<AppRoute> {
  final IndexedStackPath<AppRoute> tabsPath = IndexedStackPath([
    FeedIndexedTab(),
    ProfileTab(),
    SettingsTab(),
  ], 'Tabs');

  final IndexedStackPath<AppRoute> tabsFeedPath = IndexedStackPath([
    ForYouStacked(),
  ], 'FeedTab');

  final NavigationPath<AppRoute> tabsFeedForYouPath = NavigationPath('ForYou');

  @override
  FutureOr<AppRoute> parseRouteFromUri(Uri uri) {
    // TODO: implement parseRouteFromUri
    throw UnimplementedError();
  }
}

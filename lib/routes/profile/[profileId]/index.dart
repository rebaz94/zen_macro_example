import 'package:flutter/material.dart';
import 'package:zen_macro/route_macro.dart';
import 'package:zen_macro/routes/routes.zen.dart';

part '../../../.gen/routes/profile/[profileId]/index.g.dart';

@zenRouteMacro
class ProfilePage extends ProfilePageRoute {
  ProfilePage({required super.profileId});

  @override
  Widget build(covariant Coordinator<RouteUnique> coordinator, BuildContext context) {
    throw UnimplementedError();
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sidesail/app.dart';
import 'package:sidesail/config/dependencies.dart';

const appName = 'SideSail';

Future<void> start() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initGetitDependencies();

  runApp(
    SailApp(
      // the initial route is defined in routing/router.dart
      builder: (context, router) => MaterialApp.router(
        routerDelegate: router.delegate(),
        routeInformationParser: router.defaultRouteParser(),
        title: appName,
        theme: ThemeData(
          fontFamily: 'SourceCodePro',
          colorScheme: ColorScheme.fromSwatch().copyWith(secondary: const Color(0xffFF8000)),
        ),
      ),
    ),
  );
}

void main() {
  // the application is launched function because some startup things
  // are async
  start();
}
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zenverse/app/bindings/app_binding.dart';
import 'package:zenverse/app/routes/app_pages.dart';
import 'package:zenverse/app/routes/app_routes.dart';
import 'package:zenverse/app/theme/app_theme.dart';

class AppBootstrap {
  static Future<void> initialize() async {
    await Hive.initFlutter();
    await Hive.openBox('zenverse_box');
    await Supabase.initialize(
      url: 'https://payosmfzwiqlggldkwtb.supabase.co',
      anonKey: 'sb_publishable_2UItcPm1YFodRgRuR0_xGw_5y7iJwjo',
    );
  }
}

class ZenverseApp extends StatelessWidget {
  const ZenverseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Zenverse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialBinding: AppBinding(),
      initialRoute: AppRoutes.splash,
      getPages: AppPages.pages,
    );
  }
}

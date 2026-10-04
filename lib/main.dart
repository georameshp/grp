import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grp/app/router.dart';
import 'package:grp/app/theme.dart';
import 'package:grp/core/firebase/firebase_bootstrap.dart';
import 'package:grp/core/notifications/reminder_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.init();
  await ReminderService.instance.init();
  runApp(const GrpApp());
}

class GrpApp extends StatelessWidget {
  const GrpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp.router(
        title: 'GRP',
        debugShowCheckedModeBanner: false,
        theme: GrpTheme.light(),
        routerConfig: grpRouter,
      ),
    );
  }
}

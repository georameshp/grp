import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:grp/features/auth/auth_gate.dart';
import 'package:grp/features/auth/sign_in_screen.dart';
import 'package:grp/features/children/children_screen.dart';
import 'package:grp/features/dashboard/dashboard_screen.dart';
import 'package:grp/features/family/family_screen.dart';
import 'package:grp/features/finance/finance_screen.dart';
import 'package:grp/features/profile/profile_screen.dart';
import 'package:grp/features/todos/todos_screen.dart';
import 'package:grp/features/tuition/tuition_screen.dart';
import 'package:grp/screens/entryPoint/entry_point.dart';
import 'package:grp/screens/onboding/onboding_screen.dart';

/// Phase 1 routes. `/` hosts the Rive shell with GRP tabs; each tab is also
/// deep-linkable for notifications (reminders land on `/todos`, etc.).
final grpRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AuthGate(
        signedOutChild: OnbodingScreen(),
        signedInChild: EntryPoint(),
      ),
    ),
    GoRoute(
      path: '/sign-in',
      builder: (context, state) => const SignInScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/todos',
      builder: (context, state) => const TodosScreen(),
    ),
    GoRoute(
      path: '/finance',
      builder: (context, state) => const FinanceScreen(),
    ),
    GoRoute(
      path: '/family',
      builder: (context, state) => const FamilyScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/children',
      builder: (context, state) => const ChildrenScreen(),
    ),
    GoRoute(
      path: '/children/:childId',
      builder: (context, state) => ChildDetailScreen(
        childId: state.pathParameters['childId']!,
      ),
    ),
    GoRoute(
      path: '/tuition',
      builder: (context, state) => const TuitionScreen(),
    ),
  ],
);

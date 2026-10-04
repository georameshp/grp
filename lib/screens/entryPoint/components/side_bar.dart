import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/auth_providers.dart';
import '../../../model/menu.dart';
import '../../../utils/rive_utils.dart';
import 'info_card.dart';
import 'side_menu.dart';

/// GRP drawer: signed-in user header + navigation to each section.
class SideBar extends ConsumerStatefulWidget {
  const SideBar({super.key});

  @override
  ConsumerState<SideBar> createState() => _SideBarState();
}

String _routeFor(String title) {
  switch (title) {
    case 'Children':
      return '/children';
    case 'Tuition':
      return '/tuition';
    case 'Family':
      return '/family';
    case 'Todos':
      return '/todos';
    case 'Finance':
      return '/finance';
    case 'Dashboard':
    default:
      return '/dashboard';
  }
}

class _SideBarState extends ConsumerState<SideBar> {
  Menu selectedSideMenu = sidebarMenus.first;

  void _go(Menu menu) {
    RiveUtils.chnageSMIBoolState(menu.rive.status!);
    setState(() {
      selectedSideMenu = menu;
    });
    context.push(_routeFor(menu.title));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    return SafeArea(
      child: Container(
        width: 288,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF17203A),
          borderRadius: BorderRadius.all(
            Radius.circular(30),
          ),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoCard(
                name: user?.displayName ?? 'GRP member',
                bio: user?.email ?? 'Welcome to GRP',
              ),
              Padding(
                padding: const EdgeInsets.only(left: 24, top: 32, bottom: 16),
                child: Text(
                  "Browse".toUpperCase(),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium!
                      .copyWith(color: Colors.white70),
                ),
              ),
              ...sidebarMenus.map((menu) => SideMenu(
                    menu: menu,
                    selectedMenu: selectedSideMenu,
                    press: () => _go(menu),
                    riveOnInit: (artboard) {
                      menu.rive.status = RiveUtils.getRiveInput(artboard,
                          stateMachineName: menu.rive.stateMachineName);
                    },
                  )),
              Padding(
                padding: const EdgeInsets.only(left: 24, top: 40, bottom: 16),
                child: Text(
                  "Track".toUpperCase(),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium!
                      .copyWith(color: Colors.white70),
                ),
              ),
              ...sidebarMenus2.map((menu) => SideMenu(
                    menu: menu,
                    selectedMenu: selectedSideMenu,
                    press: () => _go(menu),
                    riveOnInit: (artboard) {
                      menu.rive.status = RiveUtils.getRiveInput(artboard,
                          stateMachineName: menu.rive.stateMachineName);
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

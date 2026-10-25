import 'package:flutter/material.dart';

import '../../../../app/icons.dart';

import '../../../../app/design_system.dart';

/// Lightweight floating navigation for Shannon's four primary tabs.
/// Uses built-in Flutter animations; no additional packages are required.
class ShannonFloatingNav extends StatelessWidget {
  const ShannonFloatingNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.chatCount = 0,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int chatCount;

  static const _labels = ['Chats', 'Calls', 'Contacts', 'Settings'];
  static const _icons = [
    ShannonIconsRegular.chatsCircle,
    ShannonIconsRegular.phone,
    ShannonIconsRegular.users,
    ShannonIconsRegular.gearSix,
  ];
  static const _selectedIcons = [
    ShannonIconsFill.chatsCircle,
    ShannonIconsFill.phone,
    ShannonIconsFill.users,
    ShannonIconsFill.gearSix,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final duration = ShannonMotion.duration(context, ShannonMotion.standard);
    final selected = selectedIndex.clamp(0, 3);
    final surface = dark ? const Color(0xFF1B2433) : const Color(0xFFF4F7FC);
    final selection = dark ? const Color(0xFF2B3A54) : const Color(0xFFDCE9FF);
    final foreground = dark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);
    final accent = dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.23 : 0.07),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SizedBox(
            height: 78,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final cellWidth = width / 4;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: AnimatedAlign(
                          duration: duration,
                          curve: Curves.easeInOutCubic,
                          alignment: Alignment(-1 + selected * 2 / 3, 0),
                          child: Container(
                            width: cellWidth - 10,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: selection,
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: List.generate(4, (i) {
                        final active = i == selected;
                        return Expanded(
                          child: Semantics(
                            button: true,
                            selected: active,
                            label: _labels[i],
                            child: InkWell(
                              borderRadius: BorderRadius.circular(26),
                              onTap: () {
                                if (i != selected) onSelected(i);
                              },
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedScale(
                                    scale: active ? 1.1 : 1.0,
                                    duration: duration,
                                    curve: Curves.easeOutCubic,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Icon(
                                          active
                                              ? _selectedIcons[i]
                                              : _icons[i],
                                          color: active ? accent : foreground,
                                          size: 25,
                                        ),
                                        if (i == 0 && chatCount > 0)
                                          Positioned(
                                            top: -9,
                                            right: -15,
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF3B82F6),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 2,
                                                    ),
                                                child: Text(
                                                  chatCount > 99
                                                      ? '99+'
                                                      : '$chatCount',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  AnimatedDefaultTextStyle(
                                    duration: duration,
                                    style: TextStyle(
                                      color: active ? accent : foreground,
                                      fontSize: 11,
                                      fontWeight: active
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                    child: Text(
                                      _labels[i],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

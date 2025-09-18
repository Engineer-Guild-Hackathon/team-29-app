import 'package:flutter/material.dart';
import '../widgets/illustrated_action_button.dart';
import 'solve_screen.dart';
import 'solve_picker_screen.dart';
import '../widgets/app_icon.dart';

class SolveHubScreen extends StatelessWidget {
  const SolveHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const IconAppBarTitle(title: '問題を解く')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IllustratedActionButton(
                  label: '問題をランダムに解く',
                  icon: Icons.casino,
                  color: Colors.indigo,
                  illustrationHeight: 120,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SolveScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                IllustratedActionButton(
                  label: '問題を選んで解く',
                  icon: Icons.view_list,
                  color: Colors.deepOrange,
                  illustrationHeight: 120,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SolvePickerScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

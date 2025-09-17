import 'package:flutter/material.dart';
import 'solve_screen.dart';
import 'solve_picker_screen.dart';

class SolveHubScreen extends StatelessWidget {
  const SolveHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('問題を解く')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SolveScreen())),
                    child: const Text('問題をランダムに解く'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SolvePickerScreen())),
                    child: const Text('問題を選んで解く'),
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


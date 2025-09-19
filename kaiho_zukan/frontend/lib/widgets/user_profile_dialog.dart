import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/api.dart';
import 'app_icon.dart';

class UserProfileDialog extends StatefulWidget {
  const UserProfileDialog({super.key, required this.userId});

  final int userId;

  @override
  State<UserProfileDialog> createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends State<UserProfileDialog> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.users.fetchProfile(userId: widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      title: const Text('ユーザープロフィール'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return SizedBox(
                height: 160,
                child: Center(
                  child: Text(
                    'プロフィール情報の取得に失敗しました',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final data = snapshot.data ?? <String, dynamic>{};
            final username = (data['username'] ?? '').toString();
            final nickname = (data['nickname'] ?? '').toString();
            final iconUrl = data['icon_url']?.toString();
            final rank = (data['rank'] ?? '').toString();

            final stats = <MapEntry<String, String>>[
              MapEntry('ユーザー名', username),
              if (nickname.isNotEmpty && nickname != username)
                MapEntry('ニックネーム', nickname),
              MapEntry('作問数', (data['question_count'] ?? 0).toString()),
              MapEntry('解説作成数', (data['answer_creation_count'] ?? 0).toString()),
              MapEntry('問題のいいね', (data['question_likes'] ?? 0).toString()),
              MapEntry('解説のいいね', (data['explanation_likes'] ?? 0).toString()),
              if (rank.isNotEmpty) MapEntry('現在のランク', rank),
            ];

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    AppIcon(
                      size: 64,
                      borderRadius: BorderRadius.circular(20),
                      backgroundColor: AppColors.background,
                      imageUrl: iconUrl,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username.isNotEmpty ? username : 'ユーザー',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (rank.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'ランク: $rank',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...stats.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key),
                        Text(
                          entry.value,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}

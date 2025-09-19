import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/api.dart';
import '../widgets/app_icon.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_breadcrumbs.dart';
import 'home.dart';

class UserInfoScreen extends StatefulWidget {
  const UserInfoScreen({super.key});
  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  bool loading = true;
  String? username;
  String? iconUrl;
  Uint8List? _iconPreview;
  PlatformFile? _pendingIcon;
  String? _pendingIconContentType;
  bool _uploadingIcon = false;
  final TextEditingController nicknameCtrl = TextEditingController();
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    nicknameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final me = await Api.users.fetchMe();
      nicknameCtrl.text = (me['nickname'] ?? '').toString();
      if (!mounted) return;
      setState(() {
        username = me['username']?.toString();
        iconUrl = me['icon_url']?.toString();
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  String? _detectContentType(PlatformFile file) {
    final ext = file.extension?.toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return null;
    }
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : null,
      ),
    );
  }

  Future<void> _pickIcon() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        _showSnack('画像の読み込みに失敗しました', error: true);
        return;
      }
      final contentType = _detectContentType(file);
      if (contentType == null) {
        _showSnack('対応していない画像形式です', error: true);
        return;
      }
      setState(() {
        _pendingIcon = file;
        _pendingIconContentType = contentType;
        _iconPreview = Uint8List.fromList(bytes);
      });
    } catch (_) {
      _showSnack('画像の選択に失敗しました', error: true);
    }
  }

  Future<void> _uploadIcon() async {
    final file = _pendingIcon;
    final bytes = _iconPreview;
    final contentType = _pendingIconContentType;
    if (file == null || bytes == null || contentType == null) {
      _showSnack('画像を選択してください', error: true);
      return;
    }
    setState(() => _uploadingIcon = true);
    try {
      final newUrl = await Api.profile.uploadIcon(
        bytes: bytes,
        filename: file.name,
        contentType: contentType,
      );
      if (!mounted) return;
      setState(() {
        iconUrl = newUrl ?? iconUrl;
        _pendingIcon = null;
        _pendingIconContentType = null;
        _iconPreview = null;
      });
      _showSnack('プロフィール画像を更新しました');
    } catch (_) {
      _showSnack('プロフィール画像の更新に失敗しました', error: true);
    } finally {
      if (mounted) {
        setState(() => _uploadingIcon = false);
      }
    }
  }

  void _clearPendingIcon() {
    setState(() {
      _pendingIcon = null;
      _pendingIconContentType = null;
      _iconPreview = null;
    });
  }

  Widget _buildAvatar() {
    const double radius = 48;
    ImageProvider<Object>? image;
    if (_iconPreview != null) {
      image = MemoryImage(_iconPreview!);
    } else if (iconUrl != null && iconUrl!.trim().isNotEmpty) {
      final resolved = AppIcon.resolveImageUrl(iconUrl);
      if (resolved != null && resolved.isNotEmpty) {
        image = NetworkImage(resolved);
      }
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.border,
      backgroundImage: image,
      child: image == null
          ? const Icon(Icons.person, size: 48, color: Colors.white)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'ユーザー情報',
      subHeader: AppBreadcrumbs(
        items: [
          BreadcrumbItem(
            label: 'ホーム',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            ),
          ),
          const BreadcrumbItem(label: 'ユーザー情報'),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('プロフィール画像', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAvatar(),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _uploadingIcon ? null : _pickIcon,
                                icon: const Icon(Icons.photo_library_outlined),
                                label: const Text('画像を選択'),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'PNG / JPG / GIF / WEBP に対応しています',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                              if (_pendingIcon != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _pendingIcon!.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'サイズ: ' + (_pendingIcon!.size / 1024).toStringAsFixed(1) + ' KB',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    FilledButton(
                                      onPressed: _uploadingIcon ? null : _uploadIcon,
                                      child: _uploadingIcon
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Text('アップロード'),
                                    ),
                                    const SizedBox(width: 12),
                                    TextButton(
                                      onPressed: _uploadingIcon ? null : _clearPendingIcon,
                                      child: const Text('キャンセル'),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('ユーザーID: ${username ?? ''}'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nicknameCtrl,
                      decoration: const InputDecoration(labelText: 'ニックネーム'),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          final ok = await Api.users.updateNickname(nicknameCtrl.text.trim());
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok ? '更新しました' : '更新に失敗しました'),
                              backgroundColor: ok ? null : AppColors.danger,
                            ),
                          );
                        },
                        child: const Text('保存'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}


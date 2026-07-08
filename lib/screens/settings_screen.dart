import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/app_state.dart';
import '../sync/backup_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final backup = context.watch<BackupService>();
    final remote = backup.remote;

    Future<void> guarded(Future<void> Function() action) async {
      try {
        await action();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(children: [
        ListTile(
          leading: const Icon(Icons.account_circle),
          title: Text(remote.signedIn ? remote.accountEmail! : '구글 로그인'),
          subtitle: Text(remote.signedIn ? '로그인됨' : '드라이브 백업에 필요합니다'),
          trailing: TextButton(
            child: Text(remote.signedIn ? '로그아웃' : '로그인'),
            onPressed: () => guarded(() async {
              if (remote.signedIn) {
                await backup.signOut();
              } else {
                await backup.signIn();
              }
            }),
          ),
        ),
        SwitchListTile(
          title: const Text('드라이브 자동 백업'),
          subtitle: const Text('거래를 저장할 때마다 내 드라이브에 백업'),
          value: backup.autoBackup,
          onChanged: remote.signedIn
              ? (v) => backup.setAutoBackup(v)
              : null,
        ),
        ListTile(
          title: const Text('지금 백업'),
          enabled: remote.signedIn && !backup.busy,
          trailing: backup.busy
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.backup),
          onTap: () => guarded(() async {
            final ok = await backup.backupNow();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok ? '백업 완료' : '백업 실패: ${backup.lastError}')));
            }
          }),
        ),
        ListTile(
          title: const Text('드라이브에서 복원'),
          subtitle: const Text('현재 폰의 데이터를 백업 내용으로 덮어씁니다'),
          enabled: remote.signedIn && !backup.busy,
          trailing: const Icon(Icons.restore),
          onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                content: const Text('현재 폰의 모든 데이터를 드라이브 백업으로 덮어씁니다. 계속할까요?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('취소')),
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('확인')),
                ],
              ),
            );
            if (ok != true || !context.mounted) return;
            final restored = await backup.restore();
            if (restored && context.mounted) {
              await context.read<AppState>().reloadAll();
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(restored
                      ? '복원 완료'
                      : '복원 실패: ${backup.lastError ?? "드라이브에 백업이 없습니다"}')));
            }
          },
        ),
        if (backup.lastBackupAt != null)
          ListTile(
            title: const Text('마지막 백업'),
            subtitle: Text('${backup.lastBackupAt}'),
          ),
        if (backup.lastError != null)
          ListTile(
            title: const Text('백업 안 됨'),
            subtitle: Text(backup.lastError!,
                style: const TextStyle(color: Colors.red)),
          ),
      ]),
    );
  }
}

import 'dart:convert';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

abstract class RemoteStore {
  bool get signedIn;
  String? get accountEmail;
  Future<bool> signIn();
  Future<void> signOut();
  Future<void> upload(String json);
  Future<String?> download();
}

const _backupFileName = 'mobile_money_backup.json';

class DriveSync implements RemoteStore {
  final _google = GoogleSignIn(scopes: [drive.DriveApi.driveAppdataScope]);
  GoogleSignInAccount? _account;

  @override
  bool get signedIn => _account != null;

  @override
  String? get accountEmail => _account?.email;

  @override
  Future<bool> signIn() async {
    _account = await _google.signInSilently() ?? await _google.signIn();
    return _account != null;
  }

  @override
  Future<void> signOut() async {
    await _google.signOut();
    _account = null;
  }

  Future<drive.DriveApi> _api() async {
    final client = await _google.authenticatedClient();
    if (client == null) throw Exception('구글 인증이 만료되었습니다. 다시 로그인하세요.');
    return drive.DriveApi(client);
  }

  Future<String?> _findFileId(drive.DriveApi api) async {
    final list = await api.files.list(
        spaces: 'appDataFolder', q: "name = '$_backupFileName'");
    final files = list.files ?? [];
    return files.isEmpty ? null : files.first.id;
  }

  @override
  Future<void> upload(String json) async {
    final api = await _api();
    final bytes = utf8.encode(json);
    final media = drive.Media(Stream.value(bytes), bytes.length);
    final existingId = await _findFileId(api);
    if (existingId == null) {
      await api.files.create(
        drive.File()
          ..name = _backupFileName
          ..parents = ['appDataFolder'],
        uploadMedia: media,
      );
    } else {
      await api.files.update(drive.File(), existingId, uploadMedia: media);
    }
  }

  @override
  Future<String?> download() async {
    final api = await _api();
    final id = await _findFileId(api);
    if (id == null) return null;
    final media = await api.files.get(id,
        downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    final bytes = await media.stream.expand((c) => c).toList();
    return utf8.decode(bytes);
  }
}

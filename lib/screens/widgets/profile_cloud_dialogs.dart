import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../l10n/l10n.dart';
import '../../models/user_profile.dart';
import '../../services/cloud_sync_service.dart';
import '../../utils/snackbar_helper.dart';

/// Local profile editor (Track 49, FEAT 84): name + avatar color/emoji.
class ProfileDialog extends StatefulWidget {
  const ProfileDialog({super.key, required this.initial});

  final UserProfile initial;

  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _emojiController;
  String _color = '#FF9800';
  static const _colors = [
    '#FF9800',
    '#E91E63',
    '#9C27B0',
    '#3F51B5',
    '#2196F3',
    '#009688',
    '#4CAF50',
    '#FF5722',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial.name);
    _emojiController = TextEditingController(text: widget.initial.avatarEmoji);
    _color = widget.initial.color;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final profile = UserProfile(
      name: _nameController.text.trim().isEmpty
          ? 'User'
          : _nameController.text.trim(),
      avatarEmoji: _emojiController.text.trim().isEmpty
          ? '👤'
          : _emojiController.text.trim(),
      color: _color,
      cloudAccountName: widget.initial.cloudAccountName,
    );
    await profile.save();
    if (!mounted) return;
    Navigator.pop(context, profile);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.profileTitle),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: _parseColor(_color),
                  child: Text(
                      _emojiController.text.isEmpty
                          ? '👤'
                          : _emojiController.text,
                      style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _emojiController,
                    decoration: InputDecoration(
                      labelText: l.profileAvatar,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l.profileName,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(l.profileAuthorHint,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final color in _colors)
                  InkWell(
                    onTap: () => setState(() => _color = color),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _parseColor(color),
                        shape: BoxShape.circle,
                        border: _color == color
                            ? Border.all(color: Colors.black, width: 2)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.close),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: Text(l.profileSave),
        ),
      ],
    );
  }

  Color _parseColor(String hex) {
    final clean = hex.replaceAll('#', '');
    final v = int.tryParse(clean.length >= 6 ? clean.substring(0, 6) : 'FF9800',
            radix: 16) ??
        0xFF9800;
    return Color(0xFF000000 | v);
  }
}

/// Cloud sync + version history (Track 50, FEAT 82/83).
///
/// Configure a WebDAV (Nextcloud) account, upload the current deck, list
/// remote versions and restore/delete them.
class CloudSyncDialog extends StatefulWidget {
  const CloudSyncDialog({
    super.key,
    required this.projectName,
    required this.deckBytes,
  });

  final String projectName;
  final List<int> deckBytes;

  @override
  State<CloudSyncDialog> createState() => _CloudSyncDialogState();
}

class _CloudSyncDialogState extends State<CloudSyncDialog> {
  CloudCredentials? _creds;
  List<RemoteVersion> _versions = const [];
  bool _busy = false;
  String? _message;
  final _urlController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final creds = await CloudSyncService.loadCredentials();
    if (!mounted) return;
    setState(() {
      _creds = creds;
      if (creds != null) {
        _urlController.text = creds.baseUrl;
        _userController.text = creds.username;
      }
    });
    if (creds != null) await _refreshVersions();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _refreshVersions() async {
    final creds = _creds;
    if (creds == null) return;
    setState(() => _busy = true);
    final versions =
        await CloudSyncService.listVersions(creds, widget.projectName);
    if (!mounted) return;
    setState(() {
      _versions = versions;
      _busy = false;
    });
  }

  Future<void> _saveAccount() async {
    if (_urlController.text.trim().isEmpty ||
        _userController.text.trim().isEmpty) {
      setState(() => _message = 'URL + username required');
      return;
    }
    late final CloudCredentials creds;
    try {
      creds = CloudCredentials(
        baseUrl: CloudSyncService.normalizedBaseUrl(
          _urlController.text.trim(),
        ),
        username: _userController.text.trim(),
        password: _passController.text,
        projectName: widget.projectName,
      );
    } on FormatException catch (error) {
      setState(() => _message = error.message);
      return;
    }
    await CloudSyncService.saveCredentials(
      baseUrl: creds.baseUrl,
      username: creds.username,
      password: creds.password,
    );
    if (!mounted) return;
    setState(() {
      _creds = creds;
      _message = context.l10n.cloudSaved;
    });
    await _refreshVersions();
  }

  Future<void> _upload() async {
    final creds = _creds;
    if (creds == null) return;
    setState(() {
      _busy = true;
      _message = context.l10n.cloudSyncing;
    });
    final version = await CloudSyncService.uploadVersion(
        creds, widget.projectName, widget.deckBytes);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = version != null
          ? '${context.l10n.cloudSynced} v$version'
          : 'Upload failed';
    });
    await _refreshVersions();
  }

  Future<void> _restore(RemoteVersion v) async {
    final creds = _creds;
    if (creds == null) return;
    setState(() => _busy = true);
    final bytes = await CloudSyncService.downloadVersion(
        creds, widget.projectName,
        version: v.version);
    if (!mounted) return;
    setState(() => _busy = false);
    if (bytes == null) return;
    final dir = await FilePicker.platform
        .getDirectoryPath(dialogTitle: 'Restore v${v.version}');
    if (dir == null) return;
    final path = '$dir${Platform.pathSeparator}'
        '${widget.projectName}_v${v.version}.ghita';
    await File(path).writeAsBytes(bytes, flush: true);
    if (mounted) {
      showAppSnackBar(context, context.l10n.versionsRestored);
    }
  }

  Future<void> _delete(RemoteVersion v) async {
    final creds = _creds;
    if (creds == null) return;
    await CloudSyncService.deleteVersion(creds, widget.projectName, v.version);
    await _refreshVersions();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.cloudTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: l.cloudUrl,
                  hintText: 'https://nextcloud.example.com/remote.php/dav/'
                      'files/USER',
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _userController,
                      decoration: InputDecoration(
                        labelText: l.cloudUsername,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _passController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: l.cloudPassword,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : _saveAccount,
                    icon: const Icon(Icons.cloud_queue),
                    label: Text(l.cloudSave),
                  ),
                  const SizedBox(width: 8),
                  if (_creds != null)
                    FilledButton.icon(
                      onPressed: _busy ? null : _upload,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: Text(l.cloudSyncNow),
                    ),
                ],
              ),
              if (_creds == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(l.cloudNoAccount,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_message!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary)),
                ),
              const Divider(height: 24),
              Text('${l.versions} — ${l.versionsMax}',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_versions.isEmpty)
                Text(l.versionsEmpty,
                    style: Theme.of(context).textTheme.bodySmall)
              else
                for (final v in _versions)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history),
                    title: Text('v${v.version}'
                        '${v.modifiedAt != null ? ' · ${v.modifiedAt!.toLocal()}' : ''}'),
                    subtitle:
                        Text('${(v.sizeBytes / 1024).toStringAsFixed(1)} KB'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: l.versionsRestore,
                          icon: const Icon(Icons.restore),
                          onPressed: _busy ? null : () => _restore(v),
                        ),
                        IconButton(
                          tooltip: l.versionsDelete,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _busy ? null : () => _delete(v),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.close),
        ),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/l10n.dart';
import '../../services/collaboration_service.dart';

/// Host/join panel for authenticated, revisioned local collaboration.
class CollaborationPanel extends StatefulWidget {
  const CollaborationPanel({super.key});

  @override
  State<CollaborationPanel> createState() => _CollaborationPanelState();
}

class _CollaborationPanelState extends State<CollaborationPanel> {
  CollaborationService? _service;
  StreamSubscription<CollaborationEvent>? _eventSubscription;
  bool _isLoading = false;
  String? _errorMessage;

  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '8080');
  final _tokenController = TextEditingController();
  final _nameController = TextEditingController(text: 'User');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = context.read<CollaborationService>();
    if (identical(service, _service)) return;
    _eventSubscription?.cancel();
    _service = service;
    _eventSubscription = service.eventStream.listen(_onEvent);
  }

  void _onEvent(CollaborationEvent event) {
    if (!mounted) return;
    setState(() {});
    final l = context.l10n;
    if (event.type == CollaborationEventType.syncConflict) {
      final data = (event.data as Map?)?.cast<String, dynamic>() ?? const {};
      final owner = data['lockOwner']?.toString();
      final message = owner != null && owner.isNotEmpty
          ? l.collabLockedBy(owner)
          : l.collaborationConflict;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } else if (event.type == CollaborationEventType.authenticationFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.collaborationAuthFailed)),
      );
    } else if (event.type == CollaborationEventType.readOnlyRejected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.collabViewModeNotice)),
      );
    } else if (event.type == CollaborationEventType.connectionLost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.collabConnectionLost)),
      );
    } else if (event.type == CollaborationEventType.reconnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.collabReconnected)),
      );
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _hostController.dispose();
    _portController.dispose();
    _tokenController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _startHosting() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final success = await _service!.startHosting();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (!success) _errorMessage = context.l10n.collaborationStartFailed;
    });
  }

  Future<void> _stopOrLeave() async {
    setState(() => _isLoading = true);
    await _service!.stop();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
    }
  }

  Future<void> _joinSession() async {
    var host = _hostController.text.trim();
    var port = int.tryParse(_portController.text.trim()) ?? 8080;
    var token = _tokenController.text.trim();

    final pastedUri = Uri.tryParse(host);
    if (pastedUri != null && pastedUri.hasScheme && pastedUri.host.isNotEmpty) {
      host = pastedUri.host;
      if (pastedUri.hasPort) port = pastedUri.port;
      token = pastedUri.queryParameters['token'] ?? token;
      _hostController.text = host;
      _portController.text = port.toString();
      _tokenController.text = token;
    }

    if (host.isEmpty || token.isEmpty) {
      setState(() => _errorMessage = context.l10n.collaborationJoinFields);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final success = await _service!.joinSession(
      hostIp: host,
      port: port,
      sessionToken: token,
      name: _nameController.text.trim().isEmpty
          ? 'User'
          : _nameController.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (!success) _errorMessage = context.l10n.collaborationJoinFailed;
    });
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.collaborationJoined),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = _service!;
    final shareUrl = service.getShareUrl();

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.people, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(context.l10n.collaboration,
                        style: theme.textTheme.titleLarge),
                    const Spacer(),
                    IconButton(
                      tooltip: context.l10n.close,
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    if (_errorMessage != null) _errorBanner(theme),
                    if (service.isActive)
                      _activeSessionCard(theme, service, shareUrl)
                    else ...[
                      _hostCard(theme),
                      const SizedBox(height: 12),
                      _joinCard(theme),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.lock_outline, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.l10n.collaborationSecurityNotice,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(_errorMessage!)),
        ],
      ),
    );
  }

  Widget _activeSessionCard(
    ThemeData theme,
    CollaborationService service,
    String? shareUrl,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              service.isHosting ? Icons.broadcast_on_personal : Icons.sync,
              size: 36,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              service.isHosting
                  ? context.l10n.collaborationHosting
                  : context.l10n.collaborationConnected,
              style: theme.textTheme.titleMedium,
            ),
            Text(context.l10n.collaborationRevision(service.revision)),
            if (service.isViewer)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(context.l10n.collabViewModeNotice,
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
            if (service.isHosting) ...[
              Text(context.l10n
                  .collaborationParticipants(service.collaborators.length)),
              if (shareUrl != null) ...[
                const SizedBox(height: 12),
                QrImageView(data: shareUrl, size: 150),
                const SizedBox(height: 8),
                _copyableValue(theme, shareUrl),
                const SizedBox(height: 8),
                Text(context.l10n.collabViewLink,
                    style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                _copyableValue(theme, service.getShareViewUrl() ?? ''),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() =>
                        service.setSessionLocked(!service.sessionLocked)),
                    icon: Icon(service.sessionLocked
                        ? Icons.lock_open
                        : Icons.lock_outline),
                    label: Text(service.sessionLocked
                        ? context.l10n.collabUnlockSession
                        : context.l10n.collabLockSession),
                  ),
                ],
              ),
            ],
            if (service.collaborators.isNotEmpty) ...[
              const Divider(height: 16),
              Text(context.l10n.collaborationParticipants(
                  service.collaborators.length)),
              const SizedBox(height: 4),
              for (final c in service.collaborators)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: _parseColor(c.color),
                    child: Text(c.name.isNotEmpty
                        ? c.name[0].toUpperCase()
                        : '?'),
                  ),
                  title: Text(c.name),
                  subtitle: Text(
                      '${_roleLabel(context, c.role.name)}'
                      '${_presenceSlideLabel(service, c)}',
                      style: theme.textTheme.bodySmall),
                  trailing: service.isHosting && c.role != CollaborationRole.host
                      ? IconButton(
                          tooltip: context.l10n.collabKick,
                          icon: const Icon(Icons.person_remove_outlined),
                          onPressed: () async {
                            await service.kickCollaborator(c.id);
                            if (mounted) setState(() {});
                          },
                        )
                      : null,
                ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _stopOrLeave,
                icon: const Icon(Icons.stop_circle_outlined),
                label: Text(service.isHosting
                    ? context.l10n.stopCollaboration
                    : context.l10n.leaveCollaboration),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    final clean = hex.replaceAll('#', '');
    final v = int.tryParse(
            clean.length >= 6 ? clean.substring(0, 6) : 'FF9800',
            radix: 16) ??
        0xFF9800;
    return Color(0xFF000000 | v);
  }

  String _roleLabel(BuildContext context, String role) => switch (role) {
        'host' => context.l10n.collabRoleHost,
        'viewer' => context.l10n.collabRoleViewer,
        _ => context.l10n.collabRoleEditor,
      };

  /// T47 P3: "editing slide X" presence hint from the live cursor feed.
  String _presenceSlideLabel(CollaborationService service, CollaboratorInfo c) {
    if (service.isHosting) {
      for (final entry in service.presence) {
        if (entry['name'] == c.name && entry['slideIndex'] is int) {
          return ' · ${context.l10n.collabLockSlide} ${(entry['slideIndex'] as int) + 1}';
        }
      }
      return '';
    }
    // Clients can't see the presence map directly; fetch it lazily.
    _fetchPresenceOnce(service);
    return '';
  }

  Future<void> _fetchPresenceOnce(CollaborationService service) async {
    if (_presenceFetched) return;
    _presenceFetched = true;
    final data = await service.fetchPresence();
    if (!mounted || data.isEmpty) return;
    setState(() {});
  }

  bool _presenceFetched = false;

  Widget _copyableValue(ThemeData theme, String value) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'Consolas', fontSize: 11),
            ),
          ),
          IconButton(
            tooltip: context.l10n.copy,
            icon: const Icon(Icons.copy, size: 16),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.l10n.collaborationLinkCopied)),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _hostCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.hostCollaboration,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(context.l10n.hostCollaborationDescription,
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _startHosting,
                icon: const Icon(Icons.broadcast_on_personal),
                label: Text(context.l10n.startCollaboration),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _joinCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.joinCollaboration,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _hostController,
              decoration: InputDecoration(
                labelText: context.l10n.hostOrShareLink,
                hintText: '192.168.1.100',
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _portController,
                    decoration: InputDecoration(
                      labelText: context.l10n.port,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: context.l10n.displayName,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tokenController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: context.l10n.sessionToken,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _joinSession,
                icon: const Icon(Icons.login),
                label: Text(context.l10n.connect),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

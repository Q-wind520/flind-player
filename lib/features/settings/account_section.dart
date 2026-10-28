// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:flind_player/app/theme/app_icons.dart';
import 'package:flind_player/app/theme/app_tokens.dart';
import 'package:flind_player/core/auth/auth_driver.dart';
import 'package:flind_player/core/auth/auth_exception.dart';
import 'package:flind_player/core/auth/auth_session.dart';
import 'package:flind_player/core/auth/auth_state.dart';
import 'package:flind_player/data/providers/auth_providers.dart';
import 'package:flind_player/l10n/app_localizations.dart';

/// Opens the account sheet for [sourceId].
Future<void> showAccountLoginSheet(
  BuildContext context, {
  required String sourceId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 480),
    builder: (context) => AccountLoginSheet(sourceId: sourceId),
  );
}

/// One row per registered login driver.
class AccountSection extends ConsumerWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final drivers = ref.watch(authDriversProvider);
    final auth = ref.watch(authControllerProvider);

    return auth.when(
      loading: () => ListTile(
        leading: const Icon(AppIcons.accountCircle),
        title: Text(l10n.loading),
      ),
      error: (_, _) => ListTile(
        leading: const Icon(AppIcons.accountCircle),
        title: Text(l10n.accountNotSignedIn),
      ),
      data: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final driver in drivers)
            _AccountRow(driver: driver, state: state),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.driver, required this.state});

  final AuthDriver driver;
  final AuthState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final account = state.accountFor(driver.sourceId);
    final session = state.sessionFor(driver.sourceId);
    final expired = state.isExpired(driver.sourceId);
    final status = session != null
        ? (account?.displayName ?? l10n.accountNotSignedIn)
        : expired
        ? l10n.accountExpired
        : l10n.accountNotSignedIn;

    return ListTile(
      leading: _AccountAvatar(account: account),
      title: Text(driver.displayName),
      subtitle: Row(
        children: [
          Flexible(
            child: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (session != null && account?.isVip == true) ...[
            const SizedBox(width: AppSpacing.xs),
            _VipBadge(label: l10n.accountVip),
          ],
        ],
      ),
      trailing: const Icon(AppIcons.chevronRight),
      onTap: () => showAccountLoginSheet(context, sourceId: driver.sourceId),
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({this.account});

  final AuthAccount? account;

  @override
  Widget build(BuildContext context) {
    final url = account?.avatarUrl;
    if (url == null || url.isEmpty) {
      return const CircleAvatar(child: Icon(AppIcons.accountCircle));
    }
    return CircleAvatar(
      backgroundImage: NetworkImage(url),
      onBackgroundImageError: (_, _) {},
    );
  }
}

class _VipBadge extends StatelessWidget {
  const _VipBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// QR/auth sheet for one source.
class AccountLoginSheet extends ConsumerStatefulWidget {
  const AccountLoginSheet({super.key, required this.sourceId});

  final String sourceId;

  @override
  ConsumerState<AccountLoginSheet> createState() => _AccountLoginSheetState();
}

class _AccountLoginSheetState extends ConsumerState<AccountLoginSheet> {
  late final AuthController _authController;
  Timer? _ticker;
  int _ticks = 0;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    // Capture the notifier while the element is alive: `ref` is unusable in
    // dispose(), but cancelling the flow there is still required.
    _authController = ref.read(authControllerProvider.notifier);
    // The first frame may already have a session; only start a flow for a
    // signed-out source.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Wait for the keychain restore before deciding this source is signed
      // out; otherwise a stored session would start a redundant QR flow.
      try {
        await ref.read(authControllerProvider.future);
      } catch (_) {
        // A storage failure is surfaced by the flow's own error state.
      }
      if (!mounted) return;
      if (ref.read(authSessionProvider(widget.sourceId)) == null) {
        unawaited(_start());
        return;
      }
      // Opening the account card is a good moment to check an old session; a
      // rejected credential moves it to the "expired" state.
      try {
        await _authController.validate(widget.sourceId);
      } on AuthException {
        // Network/risk failures leave the cached session alone.
      }
      if (!mounted) return;
      if (ref.read(authSessionProvider(widget.sourceId)) == null) {
        unawaited(_start());
      }
    });
  }

  @override
  void dispose() {
    _stopTicker();
    unawaited(_authController.cancelLogin(widget.sourceId));
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting) return;
    _starting = true;
    try {
      await _authController.startLogin(widget.sourceId);
      _startTicker();
    } on AuthException {
      // The controller exposes the error through [authFlowProvider].
    } finally {
      _starting = false;
    }
  }

  Future<void> _restart() async {
    _stopTicker();
    await _authController.cancelLogin(widget.sourceId);
    await _start();
  }

  void _startTicker() {
    _stopTicker();
    _ticks = 0;
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      _ticks++;
      // Poll every two seconds; the one-second tick also refreshes the
      // countdown without a second timer.
      if (_ticks.isEven) {
        final flow = ref.read(authFlowProvider(widget.sourceId));
        if (flow?.error != null || flow?.status == AuthPollStatus.expired) {
          _stopTicker();
        } else {
          unawaited(_authController.poll(widget.sourceId));
        }
      }
      if (mounted) setState(() {});
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final session = ref.watch(authSessionProvider(widget.sourceId));
    final flow = ref.watch(authFlowProvider(widget.sourceId));
    final sourceName = _sourceName(ref);

    ref.listen<AuthSession?>(authSessionProvider(widget.sourceId), (_, next) {
      if (next != null) _stopTicker();
    });

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              session == null ? l10n.accountLoginTitle(sourceName) : sourceName,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (session != null)
              _SignedInCard(
                session: session,
                onSignOut: () => _signOut(session),
              )
            else
              _LoginBody(flow: flow, onRestart: _restart),
          ],
        ),
      ),
    );
  }

  String _sourceName(WidgetRef ref) {
    for (final driver in ref.read(authDriversProvider)) {
      if (driver.sourceId == widget.sourceId) return driver.displayName;
    }
    return widget.sourceId;
  }

  Future<void> _signOut(AuthSession session) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.accountLogoutConfirmTitle),
        content: Text(l10n.accountLogoutConfirmBody(_sourceName(ref))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.accountLogout),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _authController.signOut(widget.sourceId);
    if (mounted) Navigator.of(context).pop();
  }
}

class _SignedInCard extends StatelessWidget {
  const _SignedInCard({required this.session, required this.onSignOut});

  final AuthSession session;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final account = session.account;
    return Column(
      children: [
        _AccountAvatar(account: account),
        const SizedBox(height: AppSpacing.sm),
        Text(
          account.displayName,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.accountUid(account.userId),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (account.isVip) ...[
          const SizedBox(height: AppSpacing.xs),
          _VipBadge(label: l10n.accountVip),
        ],
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: onSignOut,
          icon: const Icon(AppIcons.close),
          label: Text(l10n.accountLogout),
        ),
      ],
    );
  }
}

class _LoginBody extends StatelessWidget {
  const _LoginBody({required this.flow, required this.onRestart});

  final AuthFlowState? flow;
  final Future<void> Function() onRestart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final challenge = flow?.challenge;
    final error = flow?.error;

    if (challenge == null && error == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final expired =
        flow?.status == AuthPollStatus.expired ||
        (challenge != null && DateTime.now().isAfter(challenge.expiresAt));
    final scanned = flow?.status == AuthPollStatus.scanned;

    return Column(
      children: [
        if (challenge?.qrContent != null && !expired)
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.sm),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: QrImageView(
                data: challenge!.qrContent!,
                size: 210,
                padding: EdgeInsets.zero,
              ),
            ),
          )
        else
          const SizedBox(height: 210, child: Icon(AppIcons.qrCode, size: 72)),
        const SizedBox(height: AppSpacing.md),
        Text(
          expired
              ? l10n.accountQrExpired
              : scanned
              ? l10n.accountScanned
              : l10n.accountWaitingScan,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        if (challenge != null && !expired) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.accountQrExpiresIn(_formatCountdown(challenge.expiresAt)),
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.accountLoginFailed(_authErrorText(l10n, error)),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (expired || error != null)
          FilledButton.icon(
            onPressed: onRestart,
            icon: const Icon(AppIcons.refresh),
            label: Text(l10n.accountRefreshQr),
          ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.accountScanHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

String _authErrorText(AppLocalizations l10n, AuthException error) {
  return switch (error.kind) {
    AuthFailure.network => l10n.errNetwork,
    AuthFailure.riskControl => l10n.errRiskControl,
    AuthFailure.expired => l10n.accountExpired,
    AuthFailure.storage => l10n.accountSecureStorageUnavailable,
    _ => error.message,
  };
}

String _formatCountdown(DateTime deadline) {
  final remaining = deadline.difference(DateTime.now());
  final seconds = remaining.isNegative ? 0 : remaining.inSeconds;
  final minutes = seconds ~/ 60;
  return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
}

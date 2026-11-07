import 'package:flutter/material.dart';
import '../services/app_lock_service.dart';
import '../services/biometric_service.dart';
import '../services/session.dart';
import '../services/theme_service.dart';
import '../ui/nv.dart';
import 'account_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _themes = ThemeService();
  final _lock = AppLockService();
  bool _phoneOn = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final on = await BiometricService.isEnabled();
    if (mounted) setState(() => _phoneOn = on);
  }

  Future<void> _signOut() async {
    final ok = await showNvConfirm(
      context,
      title: 'Sign out?',
      message: 'You’ll need your email, password and PIN to sign back in. Phone unlock will be turned off.',
      confirmLabel: 'Sign out',
    );
    if (ok && mounted) Session.signOut(Navigator.of(context));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    final lockSummary = [
      AppLockService.labelFor(_lock.preference),
      if (_phoneOn) 'phone unlock on',
    ].join(', ');

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), shape: Border(bottom: BorderSide(color: c.lineMuted))),
      body: ListenableBuilder(
        listenable: Listenable.merge([_themes, _lock]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(NvSpace.gutter, NvSpace.xs, NvSpace.gutter, NvSpace.xxl),
          children: [
            const NvSectionHeader('Appearance'),
            NvBox(
              children: [
                for (final (mode, label) in [
                  (ThemeMode.system, 'Match phone'),
                  (ThemeMode.dark, 'Dark'),
                  (ThemeMode.light, 'Light'),
                ])
                  NvRadioRow<ThemeMode>(
                    title: label,
                    value: mode,
                    selected: _themes.themeMode == mode,
                    onSelected: _themes.setMode,
                  ),
              ],
            ),
            const NvSectionHeader('Privacy'),
            NvBox(
              children: [
                NvRow(
                  title: 'App lock',
                  subtitle: lockSummary.isEmpty ? null : lockSummary[0].toUpperCase() + lockSummary.substring(1),
                  leading: Icons.lock_outline,
                  showChevron: true,
                  onTap: () async {
                    await Navigator.of(context).pushNamed('/app-lock-preferences');
                    _refresh();
                  },
                ),
                NvRow(
                  title: 'Change PIN',
                  leading: Icons.pin_outlined,
                  showChevron: true,
                  onTap: () => Navigator.of(context).pushNamed('/change-pin'),
                ),
              ],
            ),
            const NvSectionHeader('Account'),
            NvBox(
              children: [
                NvRow(
                  title: 'Profile',
                  leading: Icons.person_outline,
                  showChevron: true,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountPage())),
                ),
                NvRow(title: 'Sign out', leading: Icons.logout, destructive: true, onTap: _signOut),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

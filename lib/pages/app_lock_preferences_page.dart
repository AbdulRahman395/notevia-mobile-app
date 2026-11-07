import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/app_lock_service.dart';
import '../services/biometric_service.dart';
import '../services/session.dart';
import '../services/token_service.dart';
import '../services/toaster_service.dart';
import '../ui/nv.dart';

/// App lock settings, laid out like WhatsApp's: phone unlock on top,
/// then how soon Notevia locks itself. Changes save as you tap.
class AppLockPreferencesPage extends StatefulWidget {
  const AppLockPreferencesPage({super.key});

  @override
  State<AppLockPreferencesPage> createState() => _AppLockPreferencesPageState();
}

class _AppLockPreferencesPageState extends State<AppLockPreferencesPage> {
  final _lock = AppLockService();
  PhoneUnlockInfo _phone = PhoneUnlockInfo.none;
  bool _phoneOn = false;
  bool _phoneBusy = false;
  late String _preference = _lock.preference;
  String? _savingPreference;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([BiometricService.info(), BiometricService.isEnabled()]);
    if (!mounted) return;
    setState(() {
      _phone = results[0] as PhoneUnlockInfo;
      _phoneOn = results[1] as bool;
    });
    final token = await TokenService.getAccessToken();
    if (token != null) {
      await _lock.refreshPreference(token);
      if (mounted) setState(() => _preference = _lock.preference);
    }
  }

  Future<void> _setPreference(String value) async {
    if (value == _preference || _savingPreference != null) return;
    final previous = _preference;
    setState(() {
      _preference = value;
      _savingPreference = value;
    });
    final token = await TokenService.getAccessToken();
    final result = token == null
        ? {'success': false}
        : await ApiService.updateLockPreferences(token, value);
    if (!mounted) return;
    if (result['success'] == true) {
      await _lock.updateLockPreferences(value);
      setState(() => _savingPreference = null);
    } else {
      setState(() {
        _preference = previous;
        _savingPreference = null;
      });
      ToasterService.showError(context, 'Couldn’t save. Check your connection and try again.');
    }
  }

  Future<void> _togglePhone(bool on) async {
    if (!on) {
      await BiometricService.disable();
      if (!mounted) return;
      setState(() => _phoneOn = false);
      ToasterService.showInfo(context, 'Phone unlock turned off');
      return;
    }
    // The PIN is needed once, to keep it behind the phone's lock
    final pin = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => _ConfirmPinSheet(label: _phone.label),
    );
    if (pin == null || !mounted) return;
    setState(() => _phoneBusy = true);
    try {
      final ok = await BiometricService.enable(pin);
      if (!mounted) return;
      setState(() => _phoneOn = ok);
      if (ok) ToasterService.showSuccess(context, 'You can now unlock with your ${_phone.label}');
    } catch (_) {
      if (mounted) ToasterService.showError(context, 'Couldn’t turn on phone unlock. Try again.');
    } finally {
      if (mounted) setState(() => _phoneBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    return Scaffold(
      appBar: AppBar(title: const Text('App lock'), shape: Border(bottom: BorderSide(color: c.lineMuted))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(NvSpace.gutter, NvSpace.xs, NvSpace.gutter, NvSpace.xxl),
        children: [
          const NvSectionHeader('Phone unlock'),
          NvBox(
            children: [
              _phone.available
                  ? NvSwitchRow(
                      title: 'Unlock with ${_phone.label}',
                      subtitle: 'Open Notevia with your fingerprint, face or phone screen lock instead of typing your PIN.',
                      value: _phoneOn,
                      busy: _phoneBusy,
                      onChanged: _togglePhone,
                    )
                  : const NvRow(
                      title: 'Phone unlock isn’t available',
                      subtitle: 'Set up a screen lock or fingerprint on your phone to use it here.',
                      leading: Icons.lock_outline,
                    ),
            ],
          ),
          const NvSectionHeader('Automatically lock'),
          NvBox(
            children: [
              for (final option in AppLockService.options)
                NvRadioRow<String>(
                  title: AppLockService.labelFor(option),
                  value: option,
                  selected: _preference == option,
                  onSelected: _setPreference,
                ),
            ],
          ),
          const SizedBox(height: NvSpace.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              _preference == 'off'
                  ? 'Notevia stays open until you lock it from the top bar.'
                  : 'Notevia locks after it has been in the background for this long. This setting is saved to your account.',
              style: NvText.meta.copyWith(color: c.muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks for the Notevia PIN, checks it with the server, then returns it.
class _ConfirmPinSheet extends StatelessWidget {
  const _ConfirmPinSheet({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    return Padding(
      padding: const EdgeInsets.fromLTRB(NvSpace.lg, 0, NvSpace.lg, NvSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Enter your PIN', style: NvText.title.copyWith(color: c.fg)),
          const SizedBox(height: NvSpace.xxs),
          Text(
            'It stays encrypted on this phone and is only unlocked by your $label.',
            textAlign: TextAlign.center,
            style: NvText.small.copyWith(color: c.muted),
          ),
          const SizedBox(height: NvSpace.lg),
          NvPinPad(
            onSubmit: (pin) async {
              final error = await Session.verifyPin(pin);
              if (error == null && context.mounted) Navigator.of(context).pop(pin);
              return error;
            },
          ),
        ],
      ),
    );
  }
}

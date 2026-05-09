import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../services/app_lock_service.dart';
import '../services/toaster_service.dart';

enum AppLockOption {
  immediately,
  oneMinute,
  fiveMinutes,
  tenMinutes,
  thirtyMinutes,
  off,
}

class AppLockPreferencesPage extends StatefulWidget {
  const AppLockPreferencesPage({super.key});

  @override
  State<AppLockPreferencesPage> createState() => _AppLockPreferencesPageState();
}

class _AppLockPreferencesPageState extends State<AppLockPreferencesPage> {
  AppLockOption _selectedOption = AppLockOption.immediately;
  AppLockOption _tempSelectedOption = AppLockOption.immediately;
  bool _hasChanges = false;
  final AppLockService _appLockService = AppLockService();

  @override
  void initState() {
    super.initState();
    _loadCurrentPreferences();
  }

  Future<void> _loadCurrentPreferences() async {
    try {
      // Get token
      final token = await TokenService.getAccessToken();
      if (token == null) {
        print('No token available for API call');
        return;
      }

      // Get current preferences
      final result = await ApiService.getLockPreferences(token);

      if (result['success'] == true && result['data'] != null) {
        final preferenceValue = result['data']['preferences'] ?? 'immediately';
        AppLockOption currentOption = _getAppLockOptionFromApiValue(
          preferenceValue,
        );

        setState(() {
          _selectedOption = currentOption;
          _tempSelectedOption = currentOption;
          _hasChanges = false;
        });
      }
    } catch (e) {
      print('Error loading lock preferences: $e');
    }
  }

  AppLockOption _getAppLockOptionFromApiValue(String apiValue) {
    switch (apiValue) {
      case 'immediately':
        return AppLockOption.immediately;
      case '1 min':
        return AppLockOption.oneMinute;
      case '5 min':
        return AppLockOption.fiveMinutes;
      case '10 min':
        return AppLockOption.tenMinutes;
      case '30 min':
        return AppLockOption.thirtyMinutes;
      case 'off':
        return AppLockOption.off;
      default:
        return AppLockOption.immediately;
    }
  }

  String _getOptionLabel(AppLockOption option) {
    switch (option) {
      case AppLockOption.immediately:
        return 'Immediately';
      case AppLockOption.oneMinute:
        return 'After 1 minute';
      case AppLockOption.fiveMinutes:
        return 'After 5 minutes';
      case AppLockOption.tenMinutes:
        return 'After 10 minutes';
      case AppLockOption.thirtyMinutes:
        return 'After 30 minutes';
      case AppLockOption.off:
        return 'Off';
    }
  }

  String _getApiPreferenceValue(AppLockOption option) {
    switch (option) {
      case AppLockOption.immediately:
        return 'immediately';
      case AppLockOption.oneMinute:
        return '1 min';
      case AppLockOption.fiveMinutes:
        return '5 min';
      case AppLockOption.tenMinutes:
        return '10 min';
      case AppLockOption.thirtyMinutes:
        return '30 min';
      case AppLockOption.off:
        return 'off';
    }
  }

  void _selectOption(AppLockOption option) {
    setState(() {
      _tempSelectedOption = option;
      _hasChanges = _tempSelectedOption != _selectedOption;
    });
  }

  Future<void> _savePreferences() async {
    if (!_hasChanges) return;

    try {
      // Get token
      final token = await TokenService.getAccessToken();
      if (token == null) {
        print('No token available for API call');
        return;
      }

      // Call API
      final apiValue = _getApiPreferenceValue(_tempSelectedOption);
      final result = await ApiService.updateLockPreferences(token, apiValue);

      if (result['success'] == true) {
        // Update AppLockService with new preferences
        await _appLockService.updateLockPreferences(apiValue);

        // Only update state if API call was successful
        setState(() {
          _selectedOption = _tempSelectedOption;
          _hasChanges = false;
        });
        print('Lock preferences updated successfully');
        _showSuccessMessage();
      } else {
        print('Failed to update lock preferences: ${result['message']}');
        _showErrorMessage('Failed to save preferences');
      }
    } catch (e) {
      print('Error updating lock preferences: $e');
      _showErrorMessage('Error saving preferences');
    }
  }

  void _showSuccessMessage() {
    ToasterService.showSuccess(context, 'Preferences saved successfully');
  }

  void _showErrorMessage(String message) {
    ToasterService.showError(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'App Lock Preferences',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Automatically lock',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: AppLockOption.values.length,
                separatorBuilder: (context, index) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final option = AppLockOption.values[index];
                  return InkWell(
                    onTap: () {
                      _selectOption(option);
                    },
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Radio<AppLockOption>(
                            value: option,
                            groupValue: _tempSelectedOption,
                            onChanged: (AppLockOption? value) {
                              if (value != null) {
                                _selectOption(value);
                              }
                            },
                            activeColor: Theme.of(context).primaryColor,
                            overlayColor: WidgetStateProperty.all(
                              Colors.transparent,
                            ),
                            splashRadius: 0,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _getOptionLabel(option),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _hasChanges ? _savePreferences : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Save Changes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _hasChanges ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

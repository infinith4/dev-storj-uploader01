import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiUrlController = TextEditingController();
  bool _isLoading = false;
  bool _isTesting = false;
  String? _connectionStatus;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(StorageKeys.apiBaseUrl);

      // Use saved URL or default from environment
      _apiUrlController.text = savedUrl ?? ApiConstants.defaultBaseUrl;
    } catch (e) {
      debugPrint('Error loading settings: $e');
      _apiUrlController.text = ApiConstants.defaultBaseUrl;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final newUrl = _apiUrlController.text.trim();

      // Save to SharedPreferences
      await prefs.setString(StorageKeys.apiBaseUrl, newUrl);

      // Reinitialize API service with new URL
      ApiService().initialize(baseUrl: newUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Settings saved successfully!'),
            backgroundColor: Color(UIConstants.successColorValue),
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate settings changed
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error saving settings: $e'),
            backgroundColor: const Color(UIConstants.errorColorValue),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTesting = true;
      _connectionStatus = null;
    });

    try {
      final testUrl = _apiUrlController.text.trim();

      // Temporarily initialize API service with test URL
      ApiService().initialize(baseUrl: testUrl);

      // Test connection
      final isConnected = await ApiService().testConnection();

      setState(() {
        _connectionStatus = isConnected
            ? '✅ Connection successful!'
            : '❌ Connection failed';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_connectionStatus!),
            backgroundColor: isConnected
                ? const Color(UIConstants.successColorValue)
                : const Color(UIConstants.errorColorValue),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _connectionStatus = '❌ Error: ${e.toString()}';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_connectionStatus!),
            backgroundColor: const Color(UIConstants.errorColorValue),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTesting = false);
      }
    }
  }

  Future<void> _resetToDefault() async {
    setState(() {
      _apiUrlController.text = ApiConstants.defaultBaseUrl;
      _connectionStatus = null;
    });
  }

  Future<void> _setAzureUrl() async {
    const azureUrl = 'https://stjup2-backend-udm3tutq7eb7i.yellowplant-e4c48860.japaneast.azurecontainerapps.io';
    setState(() {
      _apiUrlController.text = azureUrl;
      _connectionStatus = null;
    });
  }

  Future<void> _setLocalhostUrl() async {
    setState(() {
      _apiUrlController.text = 'http://localhost:8010';
      _connectionStatus = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSettings,
              tooltip: 'Save Settings',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(UIConstants.defaultPadding),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // API URL Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(UIConstants.defaultPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.cloud, size: UIConstants.defaultIconSize),
                                const SizedBox(width: UIConstants.smallPadding),
                                Text(
                                  'API Configuration',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ],
                            ),
                            const SizedBox(height: UIConstants.defaultPadding),
                            TextFormField(
                              controller: _apiUrlController,
                              decoration: const InputDecoration(
                                labelText: 'API Base URL',
                                hintText: 'https://example.com or http://localhost:8010',
                                helperText: 'Enter the backend API URL',
                                prefixIcon: Icon(Icons.link),
                              ),
                              keyboardType: TextInputType.url,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter API URL';
                                }
                                if (!value.startsWith('http://') &&
                                    !value.startsWith('https://')) {
                                  return 'URL must start with http:// or https://';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: UIConstants.defaultPadding),
                            if (_connectionStatus != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: UIConstants.smallPadding),
                                child: Text(
                                  _connectionStatus!,
                                  style: TextStyle(
                                    color: _connectionStatus!.startsWith('✅')
                                        ? const Color(UIConstants.successColorValue)
                                        : const Color(UIConstants.errorColorValue),
                                  ),
                                ),
                              ),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isTesting ? null : _testConnection,
                                    icon: _isTesting
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(Icons.wifi_find),
                                    label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: UIConstants.defaultPadding),

                    // Quick Presets Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(UIConstants.defaultPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.bookmark, size: UIConstants.defaultIconSize),
                                const SizedBox(width: UIConstants.smallPadding),
                                Text(
                                  'Quick Presets',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ],
                            ),
                            const SizedBox(height: UIConstants.defaultPadding),
                            ListTile(
                              leading: const Icon(Icons.cloud_circle),
                              title: const Text('Azure Production'),
                              subtitle: const Text('Azure Container Apps'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _setAzureUrl,
                            ),
                            const Divider(),
                            ListTile(
                              leading: const Icon(Icons.computer),
                              title: const Text('Local Development'),
                              subtitle: const Text('http://localhost:8010'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _setLocalhostUrl,
                            ),
                            const Divider(),
                            ListTile(
                              leading: const Icon(Icons.refresh),
                              title: const Text('Reset to Default'),
                              subtitle: const Text('Use environment default'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _resetToDefault,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: UIConstants.defaultPadding),

                    // App Info Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(UIConstants.defaultPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info, size: UIConstants.defaultIconSize),
                                const SizedBox(width: UIConstants.smallPadding),
                                Text(
                                  'App Information',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ],
                            ),
                            const SizedBox(height: UIConstants.defaultPadding),
                            ListTile(
                              title: const Text('App Name'),
                              subtitle: Text(AppConstants.appName),
                            ),
                            ListTile(
                              title: const Text('Version'),
                              subtitle: Text(AppConstants.appVersion),
                            ),
                            ListTile(
                              title: const Text('Description'),
                              subtitle: Text(AppConstants.appDescription),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

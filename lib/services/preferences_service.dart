import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  static const String _telegramChatIdKey = 'telegram_chat_id';
  static const String _telegramEnabledKey = 'telegram_enabled';
  static const String _serverRunningKey = 'server_running';

  Future<void> saveTelegramChatId(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_telegramChatIdKey, chatId);
  }

  Future<String> getTelegramChatId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_telegramChatIdKey) ?? '';
  }

  Future<void> clearTelegramChatId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_telegramChatIdKey);
  }

  Future<void> saveTelegramEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_telegramEnabledKey, enabled);
  }

  Future<bool> getTelegramEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_telegramEnabledKey) ?? true; // Default: enabled
  }

  Future<void> saveServerRunning(bool isRunning) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_serverRunningKey, isRunning);
  }

  Future<bool> getServerRunning() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_serverRunningKey) ?? false; // Default: not running
  }
}

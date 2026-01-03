import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  static const String _telegramChatIdKey = 'telegram_chat_id';

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
}

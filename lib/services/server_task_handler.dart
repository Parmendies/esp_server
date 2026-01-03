import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:vibration/vibration.dart';
import 'package:http/http.dart' as http;
import '../config/telegram_config.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(ServerTaskHandler());
}

class ServerTaskHandler extends TaskHandler {
  HttpServer? _server;
  final Map<String, Map<int, List<int>>> _chunksBuffer = {};
  final Map<String, DateTime> _sessionTimestamps = {};

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _startServer();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _cleanOldSessions();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _server?.close();
    _chunksBuffer.clear();
    _sessionTimestamps.clear();
  }

  void _cleanOldSessions() {
    final now = DateTime.now();
    final toRemove = <String>[];

    _sessionTimestamps.forEach((sessionId, timestamp) {
      if (now.difference(timestamp).inMinutes > 5) {
        toRemove.add(sessionId);
      }
    });

    for (var sessionId in toRemove) {
      _chunksBuffer.remove(sessionId);
      _sessionTimestamps.remove(sessionId);
    }
  }

  Future<void> _startServer() async {
    final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(_handleRequest);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);
  }

  Future<shelf.Response> _handleRequest(shelf.Request request) async {
    if (request.method == 'POST' && request.url.path == 'upload') {
      try {
        final params = request.url.queryParameters;
        final chunkNum = int.parse(params['chunk'] ?? '0');
        final totalChunks = int.parse(params['total'] ?? '1');
        final sessionId =
            params['session'] ??
            DateTime.now().millisecondsSinceEpoch.toString();

        final chunkData = await request.read().expand((x) => x).toList();

        if (!_chunksBuffer.containsKey(sessionId)) {
          _chunksBuffer[sessionId] = {};
          _sessionTimestamps[sessionId] = DateTime.now();
        }

        _chunksBuffer[sessionId]![chunkNum] = chunkData;

        // Progress göster
        final progress = (_chunksBuffer[sessionId]!.length / totalChunks * 100)
            .toInt();
        FlutterForegroundTask.sendDataToMain({
          'event': 'chunk_received',
          'progress': progress,
          'chunk': chunkNum + 1,
          'total': totalChunks,
        });

        if (_chunksBuffer[sessionId]!.length == totalChunks) {
          final completeImage = <int>[];
          for (int i = 0; i < totalChunks; i++) {
            if (!_chunksBuffer[sessionId]!.containsKey(i)) {
              return shelf.Response.badRequest(body: 'Missing chunk $i');
            }
            completeImage.addAll(_chunksBuffer[sessionId]![i]!);
          }

          final filePath = await _saveImage(completeImage);
          _chunksBuffer.remove(sessionId);
          _sessionTimestamps.remove(sessionId);

          if (await Vibration.hasVibrator()) {
            Vibration.vibrate(duration: 500);
          }

          FlutterForegroundTask.sendDataToMain({
            'event': 'image_received',
            'path': filePath,
            'size': completeImage.length,
          });

          // ✅ Telegram'a gönder
          await _sendToTelegram(filePath, completeImage.length);
        }

        return shelf.Response.ok('OK');
      } catch (e) {
        return shelf.Response.internalServerError(body: 'Error: $e');
      }
    }

    return shelf.Response.notFound('Not Found');
  }

  Future<String> _saveImage(List<int> imageData) async {
    final directory = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${directory.path}/esp32_images');

    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final filePath = '${imagesDir.path}/image_$timestamp.jpg';
    final file = File(filePath);
    await file.writeAsBytes(imageData);

    return filePath;
  }

  // ✅ Telegram'a resim gönderme fonksiyonu
  Future<void> _sendToTelegram(String filePath, int fileSize) async {
    // Chat ID kontrolü
    if (TELEGRAM_CHAT_ID.isEmpty) {
      print('❌ Telegram Chat ID boş! Ayarlardan giriniz.');
      return;
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('❌ Dosya bulunamadı: $filePath');
        return;
      }

      final url = Uri.parse(
        'https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendPhoto',
      );

      final request = http.MultipartRequest('POST', url)
        ..fields['chat_id'] = TELEGRAM_CHAT_ID
        ..fields['caption'] =
            '📸 ESP32 Kamera\n⏰ ${DateTime.now()}\n📦 ${(fileSize / 1024).toStringAsFixed(1)} KB'
        ..files.add(await http.MultipartFile.fromPath('photo', filePath));

      final response = await request.send();

      if (response.statusCode == 200) {
        print('✅ Telegram\'a gönderildi!');
      } else {
        final responseBody = await response.stream.bytesToString();
        print('❌ Telegram hatası (${response.statusCode}): $responseBody');
      }
    } catch (e) {
      print('❌ Telegram gönderim hatası: $e');
    }
  }
}

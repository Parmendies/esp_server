import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../services/preferences_service.dart';
import '../services/server_task_handler.dart';
import '../widgets/info_card.dart';
import 'images_page.dart';

class ServerPage extends StatefulWidget {
  const ServerPage({super.key});

  @override
  ServerPageState createState() => ServerPageState();
}

class ServerPageState extends State<ServerPage> with TickerProviderStateMixin {
  bool _isServerRunning = false;
  String _ipAddress = 'Alınıyor...';
  int _receivedImages = 0;
  int _currentProgress = 0;
  String _lastImagePath = '';
  Timer? _refreshTimer;
  late AnimationController _pulseController;
  final TextEditingController _chatIdController = TextEditingController();
  String _telegramChatId = ''; // State variable for Telegram Chat ID
  final PreferencesService _prefs = PreferencesService();

  @override
  void initState() {
    super.initState();
    _initForegroundTask();
    _getIpAddress();
    _requestPermissions();
    _checkServiceStatus();
    _loadImageCount();
    _loadLatestImage();
    _loadTelegramChatId();

    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat(reverse: true);

    _refreshTimer = Timer.periodic(Duration(seconds: 2), (_) {
      if (mounted) _loadImageCount();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    _chatIdController.dispose();
    super.dispose();
  }

  Future<void> _loadTelegramChatId() async {
    final chatId = await _prefs.getTelegramChatId();
    if (mounted) {
      setState(() {
        _telegramChatId = chatId;
        _chatIdController.text = chatId;
      });
    }
  }

  Future<void> _saveTelegramChatId() async {
    final chatId = _chatIdController.text.trim();
    await _prefs.saveTelegramChatId(chatId);
    if (mounted) {
      setState(() {
        _telegramChatId = chatId;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Telegram Chat ID kaydedildi')));
    }
  }

  Future<void> _loadImageCount() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${directory.path}/esp32_images');

      if (await imagesDir.exists()) {
        final files = imagesDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.jpg'))
            .toList();

        if (mounted) {
          setState(() {
            _receivedImages = files.length;
            if (files.isNotEmpty) {
              files.sort((a, b) => b.path.compareTo(a.path));
              _lastImagePath = files.first.path;
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadLatestImage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${directory.path}/esp32_images');

      if (await imagesDir.exists()) {
        final files = imagesDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.jpg'))
            .toList();

        if (files.isNotEmpty) {
          files.sort((a, b) => b.path.compareTo(a.path));
          if (mounted) {
            setState(() {
              _lastImagePath = files.first.path;
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _checkServiceStatus() async {
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (mounted) {
      setState(() {
        _isServerRunning = isRunning;
      });
    }
  }

  Future<void> _initForegroundTask() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'esp32_server',
        channelName: 'ESP32 Kamera Sunucusu',
        channelDescription: 'ESP32\'den resimler alınıyor',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
  }

  void _onReceiveTaskData(dynamic data) {
    if (!mounted) return;

    if (data['event'] == 'chunk_received') {
      setState(() {
        _currentProgress = data['progress'] ?? 0;
      });
    } else if (data['event'] == 'image_received') {
      setState(() {
        _currentProgress = 0;
        _lastImagePath = data['path'] ?? '';
      });
      _loadImageCount();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Yeni resim kaydedildi ve Telegram\'a gönderildi!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _requestPermissions() async {
    await Permission.notification.request();
    await Permission.storage.request();

    if (Platform.isAndroid && await Permission.storage.isDenied) {
      await Permission.manageExternalStorage.request();
    }
  }

  Future<void> _getIpAddress() async {
    try {
      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();
      if (mounted) {
        setState(() {
          _ipAddress = wifiIP ?? 'IP alınamadı';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ipAddress = 'Hata';
        });
      }
    }
  }

  Future<void> _startServer() async {
    if (_telegramChatId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Telegram Chat ID girilmedi!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) return;

    final serviceStarted = await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'ESP32 Sunucu Aktif',
      notificationText: 'Resimler alınıyor - $_ipAddress:8080',
      notificationIcon: null,
      callback: startCallback,
    );

    if (serviceStarted is ServiceRequestSuccess) {
      setState(() {
        _isServerRunning = true;
      });
    }
  }

  Future<void> _stopServer() async {
    await FlutterForegroundTask.stopService();
    setState(() {
      _isServerRunning = false;
      _currentProgress = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text('ESP32 Kamera'),
            actions: [
              IconButton(
                icon: Icon(Icons.settings),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Row(
                        children: [
                          Icon(Icons.telegram, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Telegram Ayarları'),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chat ID\'nizi öğrenmek için:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text('1. @userinfobot\'a mesaj gönderin'),
                          Text('2. Gelen ID\'yi buraya girin'),
                          SizedBox(height: 16),
                          TextField(
                            controller: _chatIdController,
                            decoration: InputDecoration(
                              labelText: 'Telegram Chat ID',
                              hintText: '123456789',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.tag),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('İptal'),
                        ),
                        FilledButton(
                          onPressed: () {
                            _saveTelegramChatId();
                            Navigator.pop(context);
                          },
                          child: Text('Kaydet'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              IconButton(
                icon: Icon(Icons.photo_library_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ImagesPage()),
                  ).then((_) => _loadImageCount());
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  // Telegram Status Card
                  Card(
                    elevation: 0,
                    color: _telegramChatId.isNotEmpty
                        ? Colors.blue.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.telegram,
                            color: _telegramChatId.isNotEmpty
                                ? Colors.blue
                                : Colors.orange,
                            size: 32,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _telegramChatId.isNotEmpty
                                      ? 'Telegram Bağlı'
                                      : 'Telegram Bağlı Değil',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  _telegramChatId.isNotEmpty
                                      ? 'Chat ID: $_telegramChatId'
                                      : 'Ayarlardan Chat ID girin',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Status Card
                  Card(
                    elevation: 0,
                    color: _isServerRunning
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Container(
                                padding: EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isServerRunning
                                      ? Colors.green.withOpacity(
                                          0.2 + _pulseController.value * 0.1,
                                        )
                                      : Colors.grey.withOpacity(0.2),
                                ),
                                child: Icon(
                                  _isServerRunning
                                      ? Icons.wifi
                                      : Icons.wifi_off,
                                  size: 64,
                                  color: _isServerRunning
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              );
                            },
                          ),
                          SizedBox(height: 16),
                          Text(
                            _isServerRunning ? 'SUNUCU AKTİF' : 'SUNUCU KAPALI',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _isServerRunning
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                          ),
                          if (_currentProgress > 0) ...[
                            SizedBox(height: 16),
                            LinearProgressIndicator(
                              value: _currentProgress / 100,
                              backgroundColor: Colors.grey.withOpacity(0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.green,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text('Alınıyor... %$_currentProgress'),
                          ],
                          if (_lastImagePath.isNotEmpty) ...[
                            SizedBox(height: 16),
                            Divider(),
                            SizedBox(height: 8),
                            Text(
                              'Son Alınan Resim',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FullImagePage(
                                        file: File(_lastImagePath),
                                      ),
                                    ),
                                  );
                                },
                                child: Image.file(
                                  File(_lastImagePath),
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 200,
                                      color: Colors.grey.withOpacity(0.2),
                                      child: Icon(
                                        Icons.broken_image,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Info Cards
                  Row(
                    children: [
                      Expanded(
                        child: InfoCard(
                          icon: Icons.devices,
                          title: 'IP Adresi',
                          value: _ipAddress,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: InfoCard(
                          icon: Icons.photo_camera,
                          title: 'Resimler',
                          value: '$_receivedImages',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // ESP32 Connection Info
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'ESP32 Bağlantı Adresi',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outline.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'http://$_ipAddress:8080/upload',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.copy, size: 20),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Adres kopyalandı'),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),

                  // Control Button
                  FilledButton.icon(
                    onPressed: _isServerRunning ? _stopServer : _startServer,
                    icon: Icon(
                      _isServerRunning ? Icons.stop : Icons.play_arrow,
                    ),
                    label: Text(
                      _isServerRunning ? 'Sunucuyu Durdur' : 'Sunucuyu Başlat',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _isServerRunning
                          ? Colors.red
                          : Colors.green,
                      padding: EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      minimumSize: Size(double.infinity, 56),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

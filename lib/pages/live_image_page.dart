import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class LiveImagePage extends StatefulWidget {
  const LiveImagePage({super.key});

  @override
  LiveImagePageState createState() => LiveImagePageState();
}

class LiveImagePageState extends State<LiveImagePage> {
  File? _latestImage;
  bool _isServerRunning = false;
  int _currentProgress = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadLatestImage();
    _checkServerStatus();

    // Listen for task data updates
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);

    // Auto-refresh latest image every 2 seconds
    _refreshTimer = Timer.periodic(Duration(seconds: 2), (_) {
      if (mounted) {
        _loadLatestImage();
        _checkServerStatus();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    super.dispose();
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
      });
      _loadLatestImage();
    }
  }

  Future<void> _checkServerStatus() async {
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (mounted && _isServerRunning != isRunning) {
      setState(() {
        _isServerRunning = isRunning;
      });
    }
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
          if (mounted &&
              (_latestImage == null ||
                  _latestImage!.path != files.first.path)) {
            setState(() {
              _latestImage = files.first;
            });
          }
        }
      }
    } catch (e) {
      // Ignore errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Canlı Görüntü'),
        actions: [
          // Server status indicator
          Container(
            margin: EdgeInsets.only(right: 16),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isServerRunning
                  ? Colors.green.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isServerRunning ? Colors.green : Colors.grey,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isServerRunning ? Colors.green : Colors.grey,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  _isServerRunning ? 'Aktif' : 'Kapalı',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _isServerRunning ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _latestImage == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_camera_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Henüz resim yok',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  if (!_isServerRunning) ...[
                    SizedBox(height: 8),
                    Text(
                      'Sunucuyu başlatın',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            )
          : Column(
              children: [
                // Progress indicator
                if (_currentProgress > 0)
                  LinearProgressIndicator(
                    value: _currentProgress / 100,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),

                // Image preview
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _latestImage!,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey.withOpacity(0.2),
                                    child: Icon(
                                      Icons.broken_image,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          SizedBox(height: 24),

                          // Full screen button
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LiveFullImagePage(
                                    initialImage: _latestImage!,
                                  ),
                                ),
                              );
                            },
                            icon: Icon(Icons.fullscreen),
                            label: Text('Tam Ekran Görüntüle'),
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class LiveFullImagePage extends StatefulWidget {
  final File initialImage;

  const LiveFullImagePage({super.key, required this.initialImage});

  @override
  LiveFullImagePageState createState() => LiveFullImagePageState();
}

class LiveFullImagePageState extends State<LiveFullImagePage> {
  late File _currentImage;
  Timer? _refreshTimer;
  int _currentProgress = 0;

  @override
  void initState() {
    super.initState();
    _currentImage = widget.initialImage;

    // Listen for task data updates
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);

    // Auto-refresh latest image every 2 seconds
    _refreshTimer = Timer.periodic(Duration(seconds: 2), (_) {
      if (mounted) {
        _loadLatestImage();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    super.dispose();
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
      });
      _loadLatestImage();
    }
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
          if (mounted && _currentImage.path != files.first.path) {
            setState(() {
              _currentImage = files.first;
            });
          }
        }
      }
    } catch (e) {
      // Ignore errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Text('Canlı Görüntü'),
            SizedBox(width: 8),
            Icon(Icons.live_tv, size: 20, color: Colors.red),
          ],
        ),
      ),
      body: Column(
        children: [
          // Progress indicator
          if (_currentProgress > 0)
            LinearProgressIndicator(
              value: _currentProgress / 100,
              backgroundColor: Colors.grey.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),

          // Image
          Expanded(
            child: Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.file(
                  _currentImage,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.withOpacity(0.2),
                      child: Icon(
                        Icons.broken_image,
                        size: 64,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

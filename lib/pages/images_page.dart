import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../utils/date_formatter.dart';

class ImagesPage extends StatefulWidget {
  const ImagesPage({super.key});

  @override
  ImagesPageState createState() => ImagesPageState();
}

class ImagesPageState extends State<ImagesPage> {
  List<File> _images = [];
  bool _loading = true;
  File? _latestImage;
  bool _isServerRunning = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadImages();
    _checkServerStatus();

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
    super.dispose();
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

  Future<void> _loadImages() async {
    setState(() => _loading = true);

    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${directory.path}/esp32_images');

      if (await imagesDir.exists()) {
        final files = imagesDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.jpg'))
            .toList();

        files.sort((a, b) => b.path.compareTo(a.path));

        setState(() {
          _images = files;
          _latestImage = files.isNotEmpty ? files.first : null;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteImage(File file) async {
    await file.delete();
    _loadImages();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Resim silindi')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Compact header with status and thumbnail
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  // Back button
                  IconButton(
                    icon: Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  SizedBox(width: 8),

                  // Server status chip
                  Container(
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
                            color: _isServerRunning
                                ? Colors.green
                                : Colors.grey,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          _isServerRunning ? 'Açık' : 'Kapalı',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isServerRunning
                                ? Colors.green
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(width: 8),

                  // Image count
                  Text(
                    '${_images.length} resim',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),

                  Spacer(),

                  // Delete all button
                  if (_images.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.delete_sweep, size: 20),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Tüm Resimleri Sil'),
                            content: Text(
                              '${_images.length} resim silinecek. Emin misiniz?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text('İptal'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: Text('Sil'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          for (var file in _images) {
                            await file.delete();
                          }
                          _loadImages();
                        }
                      },
                    ),

                  SizedBox(width: 4),

                  // Latest image thumbnail
                  if (_latestImage != null)
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                FullImagePage(file: _latestImage!),
                          ),
                        );
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(
                            _latestImage!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey.withOpacity(0.2),
                                child: Icon(Icons.broken_image, size: 20),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          Divider(height: 1),

          // Grid view
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator())
                : _images.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Henüz resim yok',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: EdgeInsets.all(8),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _images.length,
                    itemBuilder: (context, index) {
                      final file = _images[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FullImagePage(file: file),
                            ),
                          );
                        },
                        onLongPress: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('Resmi Sil'),
                              content: Text(
                                'Bu resmi silmek istediğinize emin misiniz?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text('İptal'),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _deleteImage(file);
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  child: Text('Sil'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Image.file(file, fit: BoxFit.cover),
                              ),
                              Container(
                                padding: EdgeInsets.all(4),
                                color: Colors.black.withOpacity(0.7),
                                child: Text(
                                  formatImageDate(file),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class FullImagePage extends StatelessWidget {
  final File file;

  const FullImagePage({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resim', style: TextStyle(fontSize: 16)),
            Text(
              formatImageDate(file),
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.file(file),
        ),
      ),
    );
  }
}

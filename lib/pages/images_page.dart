import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/date_formatter.dart';

class ImagesPage extends StatefulWidget {
  const ImagesPage({super.key});

  @override
  ImagesPageState createState() => ImagesPageState();
}

class ImagesPageState extends State<ImagesPage> {
  List<File> _images = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadImages();
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
      appBar: AppBar(
        title: Text('Kaydedilen Resimler (${_images.length})'),
        actions: [
          if (_images.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep),
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
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _images.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text('Henüz resim yok', style: TextStyle(fontSize: 18)),
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
                        Expanded(child: Image.file(file, fit: BoxFit.cover)),
                        Container(
                          padding: EdgeInsets.all(4),
                          color: Colors.black.withOpacity(0.7),
                          child: Text(
                            formatImageDate(file),
                            style: TextStyle(color: Colors.white, fontSize: 10),
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

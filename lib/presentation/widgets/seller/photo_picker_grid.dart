import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';

/// Photo picker grid with camera/gallery upload and drag reorder
class PhotoPickerGrid extends StatefulWidget {
  final List<String> initialUrls;
  final List<File> newFiles;
  final ValueChanged<List<File>> onFilesChanged;
  final ValueChanged<List<String>> onUrlsChanged;
  final int maxPhotos;

  const PhotoPickerGrid({
    super.key,
    this.initialUrls = const [],
    this.newFiles = const [],
    required this.onFilesChanged,
    required this.onUrlsChanged,
    this.maxPhotos = 5,
  });

  @override
  State<PhotoPickerGrid> createState() => _PhotoPickerGridState();
}

class _PhotoPickerGridState extends State<PhotoPickerGrid> {
  final ImagePicker _picker = ImagePicker();
  late List<String> _urls;
  late List<File> _files;

  @override
  void initState() {
    super.initState();
    _urls = List.from(widget.initialUrls);
    _files = List.from(widget.newFiles);
  }

  @override
  void didUpdateWidget(covariant PhotoPickerGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialUrls != oldWidget.initialUrls) {
      _urls = List.from(widget.initialUrls);
    }
    if (widget.newFiles != oldWidget.newFiles) {
      _files = List.from(widget.newFiles);
    }
  }

  int get _totalCount => _urls.length + _files.length;
  bool get _canAddMore => _totalCount < widget.maxPhotos;
  bool get _isEmpty => _totalCount == 0;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image != null) {
        if (!_validateFormat(image.path)) return;

        setState(() {
          _files.add(File(image.path));
        });
        widget.onFilesChanged(_files);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _pickMultiImage() async {
    try {
      final remaining = widget.maxPhotos - _totalCount;
      if (remaining <= 0) return;

      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        final validFiles = <File>[];
        for (final image in images) {
          if (validFiles.length >= remaining) break;
          if (_validateFormat(image.path)) {
            validFiles.add(File(image.path));
          }
        }

        if (validFiles.isNotEmpty) {
          setState(() {
            _files.addAll(validFiles);
          });
          widget.onFilesChanged(_files);
        }
      }
    } catch (e) {
      debugPrint('Error picking multiple images: $e');
    }
  }

  bool _validateFormat(String path) {
    final ext = path.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png'].contains(ext)) {
      if (mounted) {
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
          const SnackBar(
            content: Text('Formato não suportado. Use JPG ou PNG.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return false;
    }
    return true;
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Adicionar foto',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.sellerAccent.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: AppColors.sellerAccent,
                ),
              ),
              title: const Text('Tirar foto'),
              subtitle: const Text('Use a câmera do dispositivo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.sellerAccent.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.photo_library,
                  color: AppColors.sellerAccent,
                ),
              ),
              title: const Text('Escolher da galeria'),
              subtitle: const Text('Selecione uma ou mais imagens'),
              onTap: () {
                Navigator.pop(context);
                _pickMultiImage();
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  void _removeUrl(int index) {
    setState(() {
      _urls.removeAt(index);
    });
    widget.onUrlsChanged(_urls);
  }

  void _removeFile(int index) {
    setState(() {
      _files.removeAt(index);
    });
    widget.onFilesChanged(_files);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Row(
          children: [
            Text(
              'Fotos do produto',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              '$_totalCount/${widget.maxPhotos}',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Empty state or photo grid
        if (_isEmpty)
          _EmptyPhotoArea(onTap: _showPickerOptions)
        else ...[
          SizedBox(
            height: 130,
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              itemCount: _totalCount + (_canAddMore ? 1 : 0),
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex--;
                setState(() {
                  final isOldUrl = oldIndex < _urls.length;
                  final isNewUrl = newIndex < _urls.length;

                  if (isOldUrl && isNewUrl) {
                    // URL → URL: reorder within URLs
                    final item = _urls.removeAt(oldIndex);
                    _urls.insert(newIndex, item);
                    widget.onUrlsChanged(_urls);
                  } else if (!isOldUrl && !isNewUrl) {
                    // File → File: reorder within files
                    final oldFileIdx = oldIndex - _urls.length;
                    final newFileIdx = newIndex - _urls.length;
                    final item = _files.removeAt(oldFileIdx);
                    _files.insert(newFileIdx.clamp(0, _files.length), item);
                    widget.onFilesChanged(_files);
                  } else if (isOldUrl && !isNewUrl) {
                    // URL → File zone: move URL to end of URLs list
                    final item = _urls.removeAt(oldIndex);
                    _urls.add(item);
                    widget.onUrlsChanged(_urls);
                  } else {
                    // File → URL zone: move File to beginning of files list
                    final oldFileIdx = oldIndex - _urls.length;
                    final item = _files.removeAt(oldFileIdx);
                    _files.insert(0, item);
                    widget.onFilesChanged(_files);
                  }
                });
              },
              itemBuilder: (context, index) {
                // Add button
                if (index == _totalCount) {
                  return _AddPhotoButton(
                    key: const ValueKey('add_button'),
                    onTap: _showPickerOptions,
                  );
                }

                // Existing URL
                if (index < _urls.length) {
                  return ReorderableDragStartListener(
                    key: ValueKey('url_$index'),
                    index: index,
                    child: _PhotoTile(
                      imageProvider: NetworkImage(_urls[index]),
                      onRemove: () => _removeUrl(index),
                      isFirst: index == 0,
                    ),
                  );
                }

                // New file
                final fileIndex = index - _urls.length;
                return ReorderableDragStartListener(
                  key: ValueKey('file_$fileIndex'),
                  index: index,
                  child: _PhotoTile(
                    imageProvider: FileImage(_files[fileIndex]),
                    onRemove: () => _removeFile(fileIndex),
                    isFirst: index == 0,
                  ),
                );
              },
            ),
          ),

          // Hint
          const SizedBox(height: 8),
          Text(
            'Arraste para reordenar. A primeira foto será a principal.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textHint,
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyPhotoArea extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptyPhotoArea({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: AppColors.sellerAccent.withAlpha(100),
          borderRadius: 16,
        ),
        child: Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.sellerAccent.withAlpha(10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                color: AppColors.sellerAccent,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                'Adicionar fotos do produto',
                style: TextStyle(
                  color: AppColors.sellerAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tire uma foto ou escolha da galeria',
                style: TextStyle(
                  color: AppColors.textHint,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double borderRadius;
  static const double strokeWidth = 2;
  static const double dashWidth = 8;
  static const double dashSpace = 5;

  _DashedBorderPainter({
    required this.color,
    this.borderRadius = 16,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        dashPath.addPath(metric.extractPath(distance, end), Offset.zero);
        distance += dashWidth + dashSpace;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color;
}

class _PhotoTile extends StatelessWidget {
  final ImageProvider imageProvider;
  final VoidCallback onRemove;
  final bool isFirst;

  const _PhotoTile({
    required this.imageProvider,
    required this.onRemove,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      margin: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isFirst ? AppColors.sellerAccent : AppColors.border,
                  width: isFirst ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image(
                  image: imageProvider,
                  fit: BoxFit.cover,
                  width: 120,
                  height: 120,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.surfaceVariant,
                    child: const Icon(Icons.error),
                  ),
                ),
              ),
            ),
          ),

          // Main badge
          if (isFirst)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.sellerAccent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Principal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          // Remove button
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(150),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPhotoButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddPhotoButton({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        height: 120,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: AppColors.sellerAccent.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.sellerAccent.withAlpha(40),
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              color: AppColors.sellerAccent,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              'Adicionar',
              style: TextStyle(
                color: AppColors.sellerAccent,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

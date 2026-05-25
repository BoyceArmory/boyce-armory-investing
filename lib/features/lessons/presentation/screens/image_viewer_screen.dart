import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';

import '../../../../core/theme/app_colors.dart';

/// Fullscreen pinch-to-zoom image viewer with a Save button.
///
/// Used by lesson detail screens — user taps the lesson hero image and lands
/// here. Two main actions:
///   - Pinch / double-tap to zoom (via [InteractiveViewer]).
///   - Save the image to the device's photo library.
///
/// Save behavior:
///   - On iOS, requires NSPhotoLibraryAddUsageDescription in Info.plist
///     (already declared) and uses `gal` to write the bytes.
///   - On Android, `gal` handles the WRITE_EXTERNAL_STORAGE / MediaStore
///     permission flow automatically.
///   - First save attempt may show the system permission prompt. If the user
///     denies, we surface a clear "open settings" snackbar.
class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({
    super.key,
    required this.assetPath,
    required this.heroTitle,
  });

  /// Flutter asset path (e.g. 'assets/learn/the_greeks_delta_theta_gamma.png').
  final String assetPath;

  /// Used both as the AppBar title and (slugified) as the saved file's name.
  final String heroTitle;

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  bool _saving = false;

  Future<void> _saveToPhotos() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      // Ensure we have photo-library add permission. `requestAccess` shows
      // the OS prompt if not yet granted; subsequent calls return immediately.
      final bool granted = await Gal.requestAccess(toAlbum: true);
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Photo library access denied. Enable in Settings to save.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Pull the asset bytes (no network — bundled with the app).
      final ByteData data = await rootBundle.load(widget.assetPath);
      final Uint8List bytes = data.buffer.asUint8List();

      // Slug the title for a clean filename; gal will append the right extension.
      final String safeName = widget.heroTitle
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');

      await Gal.putImageBytes(
        bytes,
        name: safeName.isEmpty ? 'boyce_armory_lesson' : safeName,
        album: 'Boyce Armory',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved to Photos'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on GalException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: ${e.type.message}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.heroTitle,
          style: const TextStyle(fontSize: 16),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Save to Photos',
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.gold,
                    ),
                  )
                : const Icon(Icons.download_rounded),
            onPressed: _saving ? null : _saveToPhotos,
          ),
        ],
      ),
      body: GestureDetector(
        // Tap anywhere outside the image to close.
        onTap: () => Navigator.of(context).maybePop(),
        child: Center(
          child: Hero(
            tag: 'lesson_image_${widget.assetPath}',
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 5.0,
              clipBehavior: Clip.none,
              child: Image.asset(
                widget.assetPath,
                fit: BoxFit.contain,
                errorBuilder: (BuildContext c, _, __) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Image not available.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

class AppVideoPlayerModal extends StatefulWidget {
  final String videoUrl;
  final String title;

  const AppVideoPlayerModal({
    super.key,
    required this.videoUrl,
    this.title = 'Trip Video Clip',
  });

  static void show(BuildContext context, String videoUrl, {String title = 'Trip Video Clip'}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      builder: (_) => AppVideoPlayerModal(videoUrl: videoUrl, title: title),
    );
  }

  @override
  State<AppVideoPlayerModal> createState() => _AppVideoPlayerModalState();
}

class _AppVideoPlayerModalState extends State<AppVideoPlayerModal> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMsg = '';
  File? _tempFile;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final raw = widget.videoUrl.trim();
      if (raw.isEmpty) {
        throw Exception('Video URL is empty');
      }

      if (raw.startsWith('data:')) {
        // Base64 Data URL — decode and write to temporary file
        final commaIdx = raw.indexOf(',');
        if (commaIdx == -1) {
          throw Exception('Invalid base64 video data URL');
        }
        final base64Str = raw.substring(commaIdx + 1);
        final bytes = base64Decode(base64Str);
        final tempDir = await getTemporaryDirectory();
        _tempFile = File('${tempDir.path}/temp_vid_${DateTime.now().millisecondsSinceEpoch}.mp4');
        await _tempFile!.writeAsBytes(bytes);
        _controller = VideoPlayerController.file(_tempFile!);
      } else if (raw.startsWith('http://') || raw.startsWith('https://')) {
        // Network URL
        _controller = VideoPlayerController.networkUrl(Uri.parse(raw));
      } else if (raw.startsWith('file://')) {
        // File URI
        final filePath = raw.replaceFirst('file://', '');
        _controller = VideoPlayerController.file(File(filePath));
      } else {
        // Plain local file path
        final localFile = File(raw);
        if (await localFile.exists()) {
          _controller = VideoPlayerController.file(localFile);
        } else {
          _controller = VideoPlayerController.networkUrl(Uri.parse(raw));
        }
      }

      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.play();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('AppVideoPlayerModal init error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMsg = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    if (_controller != null) {
      _controller!.dispose();
    }
    if (_tempFile != null && _tempFile!.existsSync()) {
      try {
        _tempFile!.deleteSync();
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: Colors.black,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: const Color(0xFF1E293B),
                child: Row(
                  children: [
                    const Icon(Icons.movie_rounded, color: Color(0xFFFF7300), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Video Container
              Flexible(
                child: AspectRatio(
                  aspectRatio: (_isInitialized && _controller != null) ? _controller!.value.aspectRatio : 16 / 9,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_isInitialized && _controller != null) ...[
                        VideoPlayer(_controller!),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_controller!.value.isPlaying) {
                                _controller!.pause();
                              } else {
                                _controller!.play();
                              }
                            });
                          },
                          child: Container(
                            color: Colors.transparent,
                            child: AnimatedOpacity(
                              opacity: _controller!.value.isPlaying ? 0.0 : 0.9,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _controller!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 44,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: VideoProgressIndicator(
                            _controller!,
                            allowScrubbing: true,
                            colors: const VideoProgressColors(
                              playedColor: Color(0xFFFF7300),
                              bufferedColor: Colors.white30,
                              backgroundColor: Colors.white10,
                            ),
                          ),
                        ),
                      ] else if (_hasError) ...[
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
                              const SizedBox(height: 12),
                              Text(
                                'Could not play video clip.',
                                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _errorMsg,
                                style: const TextStyle(color: Colors.white60, fontSize: 11),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Color(0xFFFF7300), strokeWidth: 3),
                            SizedBox(height: 12),
                            Text('Loading trip video...', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ],
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

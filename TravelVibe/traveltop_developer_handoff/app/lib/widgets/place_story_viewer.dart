import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_network_image.dart';

class PlaceStoryItem {
  final String id;
  final String name;
  final String category;
  final String? description;
  final String? idealDuration;
  final String? bestTimeOfDay;
  final List<String> images;

  PlaceStoryItem({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    this.idealDuration,
    this.bestTimeOfDay,
    required this.images,
  });
}

class PlaceStoryViewer extends StatefulWidget {
  final List<PlaceStoryItem> places;
  final int initialPlaceIndex;

  const PlaceStoryViewer({
    super.key,
    required this.places,
    this.initialPlaceIndex = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required List<PlaceStoryItem> places,
    int initialIndex = 0,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Story',
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return PlaceStoryViewer(
          places: places,
          initialPlaceIndex: initialIndex,
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  @override
  State<PlaceStoryViewer> createState() => _PlaceStoryViewerState();
}

class _PlaceStoryViewerState extends State<PlaceStoryViewer> with SingleTickerProviderStateMixin {
  late int _currentPlaceIndex;
  late int _currentImageIndex;

  late AnimationController _animController;
  bool _isPaused = false;

  PlaceStoryItem get _currentPlace => widget.places[_currentPlaceIndex];
  List<String> get _currentImages =>
      _currentPlace.images.isNotEmpty ? _currentPlace.images : ['https://images.unsplash.com/photo-1506929562872-bb421503ef21?w=600&q=80'];

  @override
  void initState() {
    super.initState();
    _currentPlaceIndex = widget.initialPlaceIndex.clamp(0, widget.places.length - 1);
    _currentImageIndex = 0;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

    _startStory();
  }

  void _startStory() {
    _animController.stop();
    _animController.reset();
    _animController.forward();
  }

  void _nextStory() {
    if (_currentImageIndex < _currentImages.length - 1) {
      setState(() => _currentImageIndex++);
      _startStory();
    } else if (_currentPlaceIndex < widget.places.length - 1) {
      setState(() {
        _currentPlaceIndex++;
        _currentImageIndex = 0;
      });
      _startStory();
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentImageIndex > 0) {
      setState(() => _currentImageIndex--);
      _startStory();
    } else if (_currentPlaceIndex > 0) {
      setState(() {
        _currentPlaceIndex--;
        _currentImageIndex = widget.places[_currentPlaceIndex].images.isEmpty
            ? 0
            : widget.places[_currentPlaceIndex].images.length - 1;
      });
      _startStory();
    } else {
      _startStory();
    }
  }

  void _onTapDown(TapDownDetails details, Size size) {
    final dx = details.globalPosition.dx;
    if (dx < size.width * 0.35) {
      _previousStory();
    } else {
      _nextStory();
    }
  }

  void _onLongPressStart() {
    setState(() => _isPaused = true);
    _animController.stop();
  }

  void _onLongPressEnd() {
    setState(() => _isPaused = false);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) => _onTapDown(details, size),
        onLongPressStart: (_) => _onLongPressStart(),
        onLongPressEnd: (_) => _onLongPressEnd(),
        onLongPressCancel: () => _onLongPressEnd(),
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
            Navigator.pop(context);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Current Story Image Background
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: AppNetworkImage(
                key: ValueKey('${_currentPlace.id}_$_currentImageIndex'),
                imageUrl: _currentImages[_currentImageIndex],
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),

            // Top Gradient Scrim
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 180,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
              ),
            ),

            // Bottom Gradient Scrim
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 280,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
              ),
            ),

            // Overlay Controls & Info (Hidden when user long-presses to pause)
            if (!_isPaused)
              SafeArea(
                child: Column(
                  children: [
                    // Segmented Progress Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: List.generate(_currentImages.length, (idx) {
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              height: 3,
                              decoration: BoxDecoration(
                                color: AppTheme.textMuted,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: AnimatedBuilder(
                                animation: _animController,
                                builder: (context, child) {
                                  double fillPercent = 0.0;
                                  if (idx < _currentImageIndex) {
                                    fillPercent = 1.0;
                                  } else if (idx == _currentImageIndex) {
                                    fillPercent = _animController.value;
                                  }
                                  return FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: fillPercent,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppTheme.coral,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    // Top Header Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: AppNetworkImage(
                              imageUrl: _currentImages.first,
                              width: 38,
                              height: 38,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentPlace.name,
                                  style: const TextStyle(
                                    color: AppTheme.textDark,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.teal.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _currentPlace.category.toUpperCase(),
                                    style: const TextStyle(
                                      color: AppTheme.textDark,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: AppTheme.textDark, size: 28),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Bottom Details Scrim Container
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentPlace.name,
                            style: const TextStyle(
                              color: AppTheme.textDark,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (_currentPlace.idealDuration != null &&
                                  _currentPlace.idealDuration!.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.sunshineYellow,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.access_time, size: 14, color: AppTheme.inkNavy),
                                      const SizedBox(width: 4),
                                      Text(
                                        _currentPlace.idealDuration!,
                                        style: const TextStyle(
                                          color: AppTheme.inkNavy,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (_currentPlace.bestTimeOfDay != null &&
                                  _currentPlace.bestTimeOfDay!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.mintGreen,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.wb_sunny_outlined, size: 14, color: AppTheme.inkNavy),
                                      const SizedBox(width: 4),
                                      Text(
                                        _currentPlace.bestTimeOfDay!,
                                        style: const TextStyle(
                                          color: AppTheme.inkNavy,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          if (_currentPlace.description != null &&
                              _currentPlace.description!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              _currentPlace.description!,
                              style: const TextStyle(
                                color: AppTheme.textDark,
                                fontSize: 14,
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

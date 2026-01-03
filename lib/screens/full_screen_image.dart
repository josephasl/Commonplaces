import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class FullScreenImageScreen extends StatefulWidget {
  final String imageUrl;

  const FullScreenImageScreen({super.key, required this.imageUrl});

  @override
  State<FullScreenImageScreen> createState() => _FullScreenImageScreenState();
}

class _FullScreenImageScreenState extends State<FullScreenImageScreen>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;
  int _quarterTurns = 0;
  bool _isZoomed = false;
  bool _isTransitioning = false;
  Animation<double>? _routeAnimation;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onTransformationChange);
    _animationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 200),
        )..addListener(() {
          _transformationController.value = _animation!.value;
        });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && _routeAnimation == null) {
      _routeAnimation = route.animation;
      _routeAnimation?.addStatusListener(_onRouteAnimationStatus);
      final status = _routeAnimation?.status;
      _isTransitioning =
          status == AnimationStatus.forward ||
          status == AnimationStatus.reverse;
    }
  }

  void _onRouteAnimationStatus(AnimationStatus status) {
    final isTrans =
        status == AnimationStatus.forward || status == AnimationStatus.reverse;
    if (isTrans != _isTransitioning) {
      setState(() => _isTransitioning = isTrans);
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
    _transformationController.removeListener(_onTransformationChange);
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onTransformationChange() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final isZoomed = scale != 1.0;
    if (_isZoomed != isZoomed) {
      setState(() => _isZoomed = isZoomed);
    }
  }

  void _handleDoubleTap() {
    if (_animationController.isAnimating) return;

    Matrix4 currentMatrix = _transformationController.value;
    double currentScale = currentMatrix.getMaxScaleOnAxis();

    Matrix4 targetMatrix = Matrix4.identity();

    if ((currentScale - 1.0).abs() > 0.05) {
      // Reset to default if not at 1.0 (zoomed in or out)
      targetMatrix = Matrix4.identity();
    } else {
      // Zoom in
      final position = _doubleTapDetails!.localPosition;
      const double targetScale = 3.0;
      final double dx = position.dx * (1 - targetScale);
      final double dy = position.dy * (1 - targetScale);

      targetMatrix = Matrix4.identity()
        ..translate(dx, dy)
        ..scale(targetScale);
    }

    _animation = Matrix4Tween(begin: currentMatrix, end: targetMatrix).animate(
      CurveTween(curve: Curves.easeInOut).animate(_animationController),
    );

    _animationController.forward(from: 0);
  }

  void _rotateImage() {
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLocal = !widget.imageUrl.startsWith('http');

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (!_isZoomed &&
            details.primaryVelocity != null &&
            details.primaryVelocity! > 200) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: GestureDetector(
                  onDoubleTapDown: (d) => _doubleTapDetails = d,
                  onDoubleTap: _handleDoubleTap,
                  child: Builder(
                    builder: (context) {
                      final viewer = InteractiveViewer(
                        transformationController: _transformationController,
                        minScale: 0.5,
                        maxScale: 4.0,
                        clipBehavior: Clip.none,
                        panEnabled: _isZoomed,
                        boundaryMargin: _isZoomed
                            ? const EdgeInsets.all(50)
                            : EdgeInsets.zero,
                        child: RotatedBox(
                          quarterTurns: _quarterTurns,
                          child: isLocal
                              ? Image.file(
                                  File(widget.imageUrl),
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildError();
                                  },
                                )
                              : Image.network(
                                  widget.imageUrl,
                                  fit: BoxFit.contain,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return const Center(
                                          child: CupertinoActivityIndicator(
                                            color: Colors.white,
                                          ),
                                        );
                                      },
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildError();
                                  },
                                ),
                        ),
                      );

                      if (_isTransitioning) {
                        return ClipRect(
                          clipper: _HorizontalClipper(),
                          child: viewer,
                        );
                      }
                      return viewer;
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildCircleButton(
                        icon: CupertinoIcons.back,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      _buildCircleButton(
                        icon: CupertinoIcons.rotate_right,
                        onTap: _rotateImage,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildError() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image, color: Colors.white54, size: 48),
          SizedBox(height: 16),
          Text("Could not load image", style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}

class _HorizontalClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, -100000, size.width, 100000);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}

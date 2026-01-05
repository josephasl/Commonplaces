import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../models.dart';
import '../../storage_service.dart';
import '../../attributes.dart';
import '../cards.dart';
import '../ui/app_styles.dart';

class FolderBoardView extends StatefulWidget {
  final AppFolder folder;
  final StorageService storage;
  final List<AppEntry> entries;
  final List<String> visibleAttributes;
  final Map<String, AttributeDefinition> registry;
  final Function(List<AppEntry> entries, int index) onEntryTap;
  final ValueChanged<bool>? onBoardStatusChanged;
  final bool isSelectionMode;
  final Set<String> selectedEntryIds;
  final Function(String) onToggleSelection;

  const FolderBoardView({
    super.key,
    required this.folder,
    required this.storage,
    required this.entries,
    required this.visibleAttributes,
    required this.registry,
    required this.onEntryTap,
    this.onBoardStatusChanged,
    required this.isSelectionMode,
    required this.selectedEntryIds,
    required this.onToggleSelection,
  });

  @override
  State<FolderBoardView> createState() => FolderBoardViewState();
}

class FolderBoardViewState extends State<FolderBoardView> {
  final TransformationController _boardTransformController =
      TransformationController();
  bool _hasCenteredBoard = false;
  Size? _boardViewportSize;

  @override
  void dispose() {
    _boardTransformController.dispose();
    super.dispose();
  }

  void resetView() {
    if (_boardViewportSize == null && mounted) {
      _boardViewportSize = MediaQuery.of(context).size;
    }
    if (_boardViewportSize != null) {
      final x = (_boardViewportSize!.width / 2) - 2500.0;
      final y = (_boardViewportSize!.height / 2) - 2500.0;
      _boardTransformController.value = Matrix4.identity()..translate(x, y);
    }
  }

  @override
  Widget build(BuildContext context) {
    final placedEntries = widget.entries
        .where((e) => widget.folder.isEntryPlaced(e.id))
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        _boardViewportSize = Size(constraints.maxWidth, constraints.maxHeight);

        // Center on first load
        if (!_hasCenteredBoard) {
          _hasCenteredBoard = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => resetView());
        }

        return DragTarget<AppEntry>(
          onAcceptWithDetails: (details) {
            final renderBox = context.findRenderObject() as RenderBox;
            final localOffset = renderBox.globalToLocal(details.offset);

            try {
              final matrix = _boardTransformController.value;
              final inverseMatrix =
                  Matrix4.tryInvert(matrix) ?? Matrix4.identity();
              final scenePoint = MatrixUtils.transformPoint(
                inverseMatrix,
                localOffset,
              );

              final x = scenePoint.dx - 2500 - 100;
              final y = scenePoint.dy - 2500 - 50;

              if (x.isFinite && y.isFinite) {
                widget.folder.setBoardEntryPosition(details.data.id, x, y, 1.0);
                widget.storage.saveFolder(widget.folder);
                setState(() {});
              }
            } catch (e) {
              debugPrint("Drop failed: $e");
            }
          },
          builder: (context, candidateData, rejectedData) {
            return Listener(
              onPointerDown: (_) => widget.onBoardStatusChanged?.call(true),
              onPointerUp: (_) => widget.onBoardStatusChanged?.call(false),
              onPointerCancel: (_) => widget.onBoardStatusChanged?.call(false),
              child: InteractiveViewer(
                transformationController: _boardTransformController,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                minScale: 0.1,
                maxScale: 5.0,
                constrained: false,
                child: Container(
                  width: 5000,
                  height: 5000,
                  color: Colors.transparent,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: _GridPainter()),
                      ),
                      Positioned(
                        left: 2495,
                        top: 2495,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      ...placedEntries.map((entry) {
                        final pos = widget.folder.getBoardEntryPosition(
                          entry.id,
                        )!;
                        final isSelected = widget.selectedEntryIds.contains(
                          entry.id,
                        );
                        return Positioned(
                          left: pos['x']! + 2500,
                          top: pos['y']! + 2500,
                          child: GestureDetector(
                            onTap: () {
                              if (widget.isSelectionMode) {
                                widget.onToggleSelection(entry.id);
                              } else {
                                widget.onEntryTap(
                                  widget.entries,
                                  widget.entries.indexOf(entry),
                                );
                              }
                            },
                            onPanUpdate: widget.isSelectionMode
                                ? null
                                : (details) {
                                    final currentScale =
                                        _boardTransformController.value
                                            .getMaxScaleOnAxis();
                                    final newX =
                                        pos['x']! +
                                        (details.delta.dx / currentScale);
                                    final newY =
                                        pos['y']! +
                                        (details.delta.dy / currentScale);

                                    if (newX.isFinite && newY.isFinite) {
                                      widget.folder.setBoardEntryPosition(
                                        entry.id,
                                        newX,
                                        newY,
                                        pos['scale']!,
                                      );
                                      setState(() {});
                                    }
                                  },
                            onPanEnd: widget.isSelectionMode
                                ? null
                                : (_) {
                                    widget.storage.saveFolder(widget.folder);
                                  },
                            child: SizedBox(
                              width: 200,
                              child: EntryCard(
                                entry: entry,
                                isSelected: isSelected,
                                visibleAttributes: widget.visibleAttributes,
                                tagColorResolver: widget.storage.getTagColor,
                                registry: widget.registry,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class UnplacedItemsMenu extends StatelessWidget {
  final List<AppEntry> entries;
  final AppFolder folder;
  final StorageService storage;
  final List<String> visibleAttributes;
  final Map<String, AttributeDefinition> registry;
  final VoidCallback onDragStarted;

  const UnplacedItemsMenu({
    super.key,
    required this.entries,
    required this.folder,
    required this.storage,
    required this.visibleAttributes,
    required this.registry,
    required this.onDragStarted,
  });

  @override
  Widget build(BuildContext context) {
    final unplacedEntries = entries
        .where((e) => !folder.isEntryPlaced(e.id))
        .toList();

    return MasonryGridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      itemCount: unplacedEntries.length,
      itemBuilder: (context, index) {
        final entry = unplacedEntries[index];
        return LongPressDraggable<AppEntry>(
          data: entry,
          delay: const Duration(milliseconds: 150),
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: 150,
              child: EntryCard(
                entry: entry,
                visibleAttributes: visibleAttributes,
                tagColorResolver: storage.getTagColor,
                registry: registry,
              ),
            ),
          ),
          onDragStarted: onDragStarted,
          child: EntryCard(
            entry: entry,
            visibleAttributes: visibleAttributes,
            tagColorResolver: storage.getTagColor,
            registry: registry,
          ),
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1;

    const step = 100.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

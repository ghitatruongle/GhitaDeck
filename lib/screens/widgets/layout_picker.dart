import 'package:flutter/material.dart';
import '../../models/slide_layout.dart';

/// Layout Picker — grid of slide layout options similar to PowerPoint's
/// "New Slide" layout picker.
class LayoutPicker extends StatelessWidget {
  final ValueChanged<SlideLayoutType> onLayoutSelected;

  /// Optional localizer for layout names (Track 05, P9); defaults to the
  /// built-in English names.
  final String Function(SlideLayoutType type)? nameOf;

  const LayoutPicker({
    super.key,
    required this.onLayoutSelected,
    this.nameOf,
  });

  String _name(SlideLayoutType type) =>
      (nameOf ?? (t) => SlideLayout.getByType(t).name)(type);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Choose Layout',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 120,
                childAspectRatio: 0.85,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: SlideLayout.layouts.length,
              itemBuilder: (context, index) {
                final layout = SlideLayout.layouts[index];
                return _LayoutCard(
                  layout: layout,
                  name: _name(layout.type),
                  onTap: () {
                    onLayoutSelected(layout.type);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  /// Show the layout picker as a popup menu anchored to a widget.
  static Future<void> show(
    BuildContext context,
    Offset position,
    ValueChanged<SlideLayoutType> onLayoutSelected, {
    String Function(SlideLayoutType type)? nameOf,
  }) async {
    final localName = nameOf ?? (type) => SlideLayout.getByType(type).name;
    final result = await showMenu<SlideLayoutType>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 400,
        position.dy + 500,
      ),
      items: SlideLayout.layouts.map((layout) {
        return PopupMenuItem<SlideLayoutType>(
          value: layout.type,
          child: SizedBox(
            width: 200,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Icon(layout.icon, size: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        localName(layout.type),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        layout.description,
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );

    if (result != null) {
      onLayoutSelected(result);
    }
  }

  /// Show as a dialog.
  static Future<void> showAsDialog(
    BuildContext context,
    ValueChanged<SlideLayoutType> onLayoutSelected, {
    String Function(SlideLayoutType type)? nameOf,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: LayoutPicker(
          onLayoutSelected: onLayoutSelected,
          nameOf: nameOf,
        ),
      ),
    );
  }
}

class _LayoutCard extends StatelessWidget {
  final SlideLayout layout;
  final String name;
  final VoidCallback onTap;

  const _LayoutCard({
    required this.layout,
    required this.name,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Layout thumbnail
            Container(
              width: 50,
              height: 38,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: _buildMiniLayout(layout.type, theme),
            ),
            // Layout name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                name,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniLayout(SlideLayoutType type, ThemeData theme) {
    final color = theme.colorScheme.primary.withValues(alpha: 0.5);
    final secondary = theme.colorScheme.onSurface.withValues(alpha: 0.2);

    return Padding(
      padding: const EdgeInsets.all(4),
      child: CustomPaint(
        painter: _LayoutPainter(type: type, primaryColor: color, secondaryColor: secondary),
        size: Size.infinite,
      ),
    );
  }
}

class _LayoutPainter extends CustomPainter {
  final SlideLayoutType type;
  final Color primaryColor;
  final Color secondaryColor;

  _LayoutPainter({
    required this.type,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    switch (type) {
      case SlideLayoutType.blank:
        // Empty
        break;
      case SlideLayoutType.titleSlide:
        // Title bar in center
        paint.color = primaryColor;
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height * 0.4),
            width: size.width * 0.7,
            height: size.height * 0.18,
          ),
          paint,
        );
        // Subtitle below
        paint.color = secondaryColor;
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height * 0.65),
            width: size.width * 0.5,
            height: size.height * 0.12,
          ),
          paint,
        );
        break;
      case SlideLayoutType.titleAndContent:
        // Title at top
        paint.color = primaryColor;
        canvas.drawRect(
          Rect.fromLTWH(size.width * 0.08, size.height * 0.08, size.width * 0.84, size.height * 0.18),
          paint,
        );
        // Content area
        paint.color = secondaryColor;
        canvas.drawRect(
          Rect.fromLTWH(size.width * 0.08, size.height * 0.35, size.width * 0.84, size.height * 0.55),
          paint,
        );
        break;
      case SlideLayoutType.sectionHeader:
        // Large center title
        paint.color = primaryColor;
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height * 0.45),
            width: size.width * 0.8,
            height: size.height * 0.22,
          ),
          paint,
        );
        paint.color = secondaryColor;
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height * 0.72),
            width: size.width * 0.5,
            height: size.height * 0.1,
          ),
          paint,
        );
        break;
      case SlideLayoutType.twoContent:
      case SlideLayoutType.comparison:
        // Title
        paint.color = primaryColor;
        canvas.drawRect(
          Rect.fromLTWH(size.width * 0.08, size.height * 0.08, size.width * 0.84, size.height * 0.15),
          paint,
        );
        // Left content
        paint.color = secondaryColor;
        canvas.drawRect(
          Rect.fromLTWH(size.width * 0.08, size.height * 0.32, size.width * 0.4, size.height * 0.55),
          paint,
        );
        // Right content
        canvas.drawRect(
          Rect.fromLTWH(size.width * 0.52, size.height * 0.32, size.width * 0.4, size.height * 0.55),
          paint,
        );
        break;
      case SlideLayoutType.titleOnly:
        // Title only
        paint.color = primaryColor;
        canvas.drawRect(
          Rect.fromLTWH(size.width * 0.08, size.height * 0.08, size.width * 0.84, size.height * 0.18),
          paint,
        );
        break;
      case SlideLayoutType.contentAndCaption:
        // Title
        paint.color = primaryColor;
        canvas.drawRect(
          Rect.fromLTWH(size.width * 0.08, size.height * 0.08, size.width * 0.84, size.height * 0.15),
          paint,
        );
        // Content (left, larger)
        paint.color = secondaryColor;
        canvas.drawRect(
          Rect.fromLTWH(size.width * 0.08, size.height * 0.32, size.width * 0.55, size.height * 0.55),
          paint,
        );
        // Caption (right, smaller)
        paint.color = secondaryColor.withValues(alpha: 0.5);
        canvas.drawRect(
          Rect.fromLTWH(size.width * 0.68, size.height * 0.32, size.width * 0.24, size.height * 0.55),
          paint,
        );
        break;
      case SlideLayoutType.pictureAndCaption:
        // Title
        paint.color = primaryColor;
        canvas.drawRect(
          Rect.fromLTWH(size.width * 0.08, size.height * 0.08, size.width * 0.84, size.height * 0.15),
          paint,
        );
        // Picture (large center)
        paint.color = secondaryColor;
        canvas.drawRect(
          Rect.fromLTWH(size.width * 0.08, size.height * 0.32, size.width * 0.84, size.height * 0.45),
          paint,
        );
        // Caption (small, bottom)
        paint.color = secondaryColor.withValues(alpha: 0.5);
        canvas.drawRect(
          Rect.fromLTWH(size.width * 0.08, size.height * 0.82, size.width * 0.84, size.height * 0.1),
          paint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _LayoutPainter oldDelegate) {
    return oldDelegate.type != type;
  }
}

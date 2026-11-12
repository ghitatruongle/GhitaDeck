import 'package:flutter/material.dart';
import '../../theme/office_colors.dart';

/// Office 365 style sidebar navigation item (icon + label).
class OfficeSidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? tooltip;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const OfficeSidebarItem({
    super.key,
    required this.icon,
    required this.label,
    this.tooltip,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<OfficeSidebarItem> createState() => _OfficeSidebarItemState();
}

class _OfficeSidebarItemState extends State<OfficeSidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color? bgColor;
    Color iconColor;
    Color labelColor;

    if (widget.isSelected) {
      bgColor = widget.isDark
          ? OfficeColors.blueBadgeBgDark
          : OfficeColors.officeBlueLight;
      iconColor =
          widget.isDark ? OfficeColors.blueBadgeFgDark : OfficeColors.officeBlue;
      labelColor =
          widget.isDark ? OfficeColors.blueBadgeFgDark : OfficeColors.officeBlue;
    } else if (_isHovered) {
      bgColor = widget.isDark ? OfficeColors.gray30 : OfficeColors.gray90;
      iconColor = widget.isDark ? OfficeColors.gray90 : OfficeColors.gray20;
      labelColor = widget.isDark ? OfficeColors.gray90 : OfficeColors.gray30;
    } else {
      bgColor = Colors.transparent;
      iconColor = widget.isDark ? OfficeColors.gray60 : OfficeColors.gray40;
      labelColor = widget.isDark ? OfficeColors.gray60 : OfficeColors.gray40;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        child: Tooltip(
          message: widget.tooltip ?? widget.label,
          waitDuration: const Duration(milliseconds: 600),
          preferBelow: false,
          child: Semantics(
            label: widget.tooltip ?? widget.label,
            button: true,
            selected: widget.isSelected,
            onTap: widget.onTap,
            child: ExcludeSemantics(
              child: InkWell(
                onTap: widget.onTap,
                onHover: (hovered) => setState(() => _isHovered = hovered),
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      // Left accent bar for selected item
                      if (widget.isSelected)
                        Container(
                          width: 3,
                          height: 24,
                          margin: const EdgeInsets.only(left: 2, right: 2),
                          decoration: BoxDecoration(
                            color: widget.isDark
                                ? OfficeColors.blueBadgeFgDark
                                : OfficeColors.officeBlue,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        )
                      else
                        const SizedBox(width: 7),
                      // Icon and label
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(widget.icon, size: 20, color: iconColor),
                            const SizedBox(height: 2),
                            Text(
                              widget.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: widget.isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: labelColor,
                                fontFamily: 'Segoe UI',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

/// Office 365 style icon-only sidebar button.
class OfficeSidebarButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isDark;

  const OfficeSidebarButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<OfficeSidebarButton> createState() => _OfficeSidebarButtonState();
}

class _OfficeSidebarButtonState extends State<OfficeSidebarButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color iconColor;

    if (_isHovered) {
      bgColor = widget.isDark ? OfficeColors.gray30 : OfficeColors.gray90;
      iconColor = widget.isDark ? OfficeColors.gray90 : OfficeColors.gray20;
    } else {
      bgColor = Colors.transparent;
      iconColor = widget.isDark ? OfficeColors.gray60 : OfficeColors.gray40;
    }

    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        label: widget.tooltip,
        button: true,
        onTap: widget.onTap,
        child: ExcludeSemantics(
          child: Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: IconButton(
              icon: Icon(widget.icon, size: 18, color: iconColor),
              onPressed: widget.onTap,
              onHover: (hovered) => setState(() => _isHovered = hovered),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              tooltip: widget.tooltip,
            ),
          ),
        ),
      ),
    );
  }
}

/// Office 365 style small header button (used in title bar).
class OfficeHeaderButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isDark;

  const OfficeHeaderButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<OfficeHeaderButton> createState() => _OfficeHeaderButtonState();
}

class _OfficeHeaderButtonState extends State<OfficeHeaderButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color? bgColor;
    Color iconColor;

    if (_isHovered) {
      bgColor = widget.isDark ? OfficeColors.gray30 : OfficeColors.gray90;
      iconColor = widget.isDark ? OfficeColors.gray90 : OfficeColors.gray20;
    } else {
      bgColor = Colors.transparent;
      iconColor = widget.isDark ? OfficeColors.gray60 : OfficeColors.gray40;
    }

    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        label: widget.tooltip,
        button: true,
        onTap: widget.onTap,
        child: ExcludeSemantics(
          child: Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(2),
            ),
            child: IconButton(
              icon: Icon(widget.icon, size: 16, color: iconColor),
              onPressed: widget.onTap,
              onHover: (hovered) => setState(() => _isHovered = hovered),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              tooltip: widget.tooltip,
            ),
          ),
        ),
      ),
    );
  }
}

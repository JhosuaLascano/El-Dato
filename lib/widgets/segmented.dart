import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

/// Control segmentado con indicador que se desliza.
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.values, required this.labels, required this.value, required this.onChanged, this.activeColor = AppColors.gold});
  final List<T> values;
  final List<String> labels;
  final T value;
  final ValueChanged<T> onChanged;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final idx = values.indexOf(value);
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth / values.length;
        return Stack(children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            left: w * idx,
            top: 0,
            bottom: 0,
            width: w,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              decoration: BoxDecoration(color: activeColor, borderRadius: BorderRadius.circular(26)),
            ),
          ),
          Row(
            children: List.generate(values.length, (i) {
              final sel = i == idx;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (!sel) {
                      HapticFeedback.selectionClick();
                      onChanged(values[i]);
                    }
                  },
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: sel ? Colors.black : AppColors.muted,
                      ),
                      child: Text(labels[i]),
                    ),
                  ),
                ),
              );
            }),
          ),
        ]);
      }),
    );
  }
}

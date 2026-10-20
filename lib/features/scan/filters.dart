import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/k_icons.dart';
import '../../core/widgets/micrograph.dart';

/// Image filter definitions. The editor, Live Scan quick toggle and the
/// Workspace "Adjust" tab are all built from this list, so the final filter
/// set can change after testing without touching the screens.
@immutable
class FilterDef {
  const FilterDef.slider(this.id, this.label, this.icon, this.help, {this.min = 0, this.max = 1})
      : isToggle = false;
  const FilterDef.toggle(this.id, this.label, this.icon, this.help)
      : isToggle = true,
        min = 0,
        max = 1;

  final String id;
  final String label;
  final IconData icon;
  final String help;
  final bool isToggle;
  final double min;
  final double max;
}

const filterConfig = <FilterDef>[
  FilterDef.slider('brightness', 'Brightness', KIcons.sun, 'Lift a dim field without changing focus.', min: -1),
  FilterDef.slider('contrast', 'Contrast', KIcons.contrast, 'Separates pale bodies from the background.', min: -1),
  FilterDef.slider('clahe', 'Local contrast (CLAHE)', KIcons.aperture, 'Evens out uneven lighting across the field.'),
  FilterDef.slider('sharpen', 'Sharpen', KIcons.crosshair, 'Crisps outlines of the stylet and tail.'),
  FilterDef.slider('edge', 'Edge enhance', KIcons.frame, 'Outlines bodies so they stand out from debris.'),
  FilterDef.toggle('grayscale', 'Grayscale', KIcons.drop, 'Removes stain colour casts.'),
  FilterDef.toggle('invert', 'Invert', KIcons.contrast, 'Dark-field look; can help with thin juveniles.'),
];

double filterValue(ImageAdjustments a, String id) => switch (id) {
      'brightness' => a.brightness,
      'contrast' => a.contrast,
      'clahe' => a.clahe,
      'sharpen' => a.sharpen,
      'edge' => a.edge,
      'grayscale' => a.grayscale ? 1 : 0,
      'invert' => a.invert ? 1 : 0,
      _ => 0,
    };

ImageAdjustments withFilter(ImageAdjustments a, String id, double v) => switch (id) {
      'brightness' => a.copyWith(brightness: v),
      'contrast' => a.copyWith(contrast: v),
      'clahe' => a.copyWith(clahe: v),
      'sharpen' => a.copyWith(sharpen: v),
      'edge' => a.copyWith(edge: v),
      'grayscale' => a.copyWith(grayscale: v > 0.5),
      'invert' => a.copyWith(invert: v > 0.5),
      _ => a,
    };

/// Adjustments applied to each specimen (editor → identification canvas).
class AdjustmentsController extends Notifier<Map<String, ImageAdjustments>> {
  @override
  Map<String, ImageAdjustments> build() => const {};

  void set(String specimenId, ImageAdjustments a) => state = {...state, specimenId: a};
}

final adjustmentsProvider =
    NotifierProvider<AdjustmentsController, Map<String, ImageAdjustments>>(AdjustmentsController.new);

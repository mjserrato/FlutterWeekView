import 'dart:math' as Math;
import 'dart:collection';

import 'package:flutter/material.dart';

/// An abstract zoom controller.
abstract class ZoomController {
  /// The scroll controller.
  final ScrollController verticalScrollController;

  /// The zoom coefficient (<= 0 to disable).
  final double zoomCoefficient;

  /// The minimum zoom factor.
  final double minZoom;

  /// The maximum zoom factor.
  final double maxZoom;

  /// Whether this controller is disposable.
  final bool disposable;

  /// All controller listeners.
  final Set<ZoomControllerListener> _listeners = HashSet();

  /// Creates a zoom controller instance.
  ZoomController({
    ScrollController verticalScrollController,
    double zoomCoefficient = 0.8,
    double minZoom,
    double maxZoom,
    this.disposable = true,
  })  : this.verticalScrollController = verticalScrollController ?? ScrollController(),
        this.zoomCoefficient = Math.max(0, zoomCoefficient ?? 0),
        this.minZoom = Math.max(0, minZoom ?? 0.4),
        this.maxZoom = Math.max(0, minZoom ?? 1.6),
        assert(disposable != null) {
    assert(this.minZoom <= this.maxZoom);
  }

  /// Adds a listener.
  void addListener(ZoomControllerListener listener) => _listeners.add(listener);

  /// Removes a listener.
  void removeListener(ZoomControllerListener listener) => _listeners.remove(listener);

  /// Calculates a zoom factor according to the specified scale.
  double calculateZoomFactor(double scale);

  /// Should be called when the scale operation start.
  void scaleStart();

  /// Should be called when the scale operation has an update.
  void scaleUpdate(ScaleUpdateDetails details);

  /// Returns the current scale.
  double get scale;

  /// Returns the current zoom factor.
  double get zoomFactor;

  /// Disposes this controller if enabled.
  /// You should not use it anymore after having called this method.
  @mustCallSuper
  void dispose() {
    if (disposable) {
      _listeners.clear();
      verticalScrollController.dispose();
    }
  }
}

/// A day view controller listener.
mixin ZoomControllerListener {
  /// Triggered when the day view zoom factor has changed.
  void onZoomFactorChanged(ZoomController controller, ScaleUpdateDetails details);
}

/// Allows to control some parameters of a day view.
class DayViewController extends ZoomController {
  /// The previous zoom factor.
  double _previousZoomFactor = 1;

  /// The current zoom factor.
  double _zoomFactor = 1;

  /// Creates a new day view controller instance.
  DayViewController({
    ScrollController verticalScrollController,
    double zoomCoefficient = 0.8,
    double minZoom,
    double maxZoom,
    bool disposable = true,
  }) : super(
          verticalScrollController: verticalScrollController,
          zoomCoefficient: zoomCoefficient,
          minZoom: minZoom,
          maxZoom: maxZoom,
          disposable: disposable,
        );

  @override
  double calculateZoomFactor(double scale) {
    double zoomFactor = _previousZoomFactor * scale * zoomCoefficient;
    if (zoomFactor < minZoom) {
      zoomFactor = minZoom;
    }

    if (zoomFactor > maxZoom) {
      zoomFactor = maxZoom;
    }

    return zoomFactor;
  }

  @override
  void scaleStart() => _previousZoomFactor = _zoomFactor;

  @override
  void scaleUpdate(ScaleUpdateDetails details) {
    double zoomFactor = calculateZoomFactor(details.scale);
    bool hasChanged = _zoomFactor != zoomFactor;
    if (hasChanged) {
      _zoomFactor = zoomFactor;
      _listeners.forEach((listener) => listener.onZoomFactorChanged(this, details));
    }
  }

  @override
  double get scale => _zoomFactor / (_previousZoomFactor * zoomCoefficient);

  @override
  double get zoomFactor => _zoomFactor;
}

/// Allows to control some parameters of a week view.
class WeekViewController extends ZoomController {
  /// All day view controllers.
  final List<DayViewController> dayViewControllers;

  /// The horizontal scroll controller.
  final ScrollController horizontalScrollController;

  /// Creates a new week view controller.
  WeekViewController({
    @required int dayViewsCount,
    ScrollController horizontalScrollController,
    ScrollController verticalScrollController,
    double zoomCoefficient = 0.8,
    double minZoom,
    double maxZoom,
    bool disposable = true,
  })  : this.horizontalScrollController = horizontalScrollController ?? ScrollController(),
        assert(dayViewsCount != null && dayViewsCount > 0),
        assert(disposable != null),
        this.dayViewControllers = List.generate(
          dayViewsCount,
          (_) => DayViewController(
            zoomCoefficient: zoomCoefficient,
            minZoom: minZoom,
            maxZoom: maxZoom,
            disposable: false,
          ),
        ),
        super(
          verticalScrollController: verticalScrollController,
          zoomCoefficient: zoomCoefficient,
          minZoom: minZoom,
          maxZoom: maxZoom,
          disposable: disposable,
        );

  @override
  double calculateZoomFactor(double scale) => dayViewControllers.first.calculateZoomFactor(scale);

  @override
  void scaleStart() => dayViewControllers.forEach((controller) => controller.scaleStart());

  @override
  void scaleUpdate(ScaleUpdateDetails details) {
    double zoomFactor = calculateZoomFactor(details.scale);
    bool hasChanged = this.zoomFactor != zoomFactor;
    if (hasChanged) {
      dayViewControllers.forEach((controller) => controller.scaleUpdate(details));
      _listeners.forEach((listener) => listener.onZoomFactorChanged(this, details));
    }
  }

  @override
  double get scale => dayViewControllers.first.scale;

  @override
  double get zoomFactor => dayViewControllers.first.zoomFactor;

  /// Disposes this controller.
  /// You should not use it anymore after having called this method.
  void dispose() {
    super.dispose();
    if (disposable) {
      dayViewControllers.forEach((controller) => controller.dispose());
      horizontalScrollController.dispose();
    }
  }
}

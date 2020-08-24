// Copyright 2019 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

// A tween that starts from 1.0 and ends at 0.0.
final Tween<double> _flippedTween = Tween<double>(
  begin: 1.0,
  end: 0.0,
);

/// Enables creating a flipped [CurveTween].
///
/// This creates a [CurveTween] that evaluates to a result that flips the
/// tween vertically.
///
/// This tween sequence assumes that the evaluated result has to be a double
/// between 0.0 and 1.0.
class FlippedCurveTween extends CurveTween {
  /// Creates a vertically flipped [CurveTween].
  FlippedCurveTween({
    @required Curve curve,
  })  : assert(curve != null),
        super(curve: curve);

  @override
  double transform(double t) => 1.0 - super.transform(t);
}

/// Flips the incoming passed in [Animation] to start from 1.0 and end at 0.0.
Animation<double> flipTween(Animation<double> animation) {
  return _flippedTween.animate(animation);
}

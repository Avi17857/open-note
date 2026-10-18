import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A wrapper widget whose [RenderBox] permits hit-testing children positioned
/// outside its own layout bounds (such as pasteboard content).
class UnboundedHitTest extends SingleChildRenderObjectWidget {
  const UnboundedHitTest({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderUnboundedHitTest();
}

class RenderUnboundedHitTest extends RenderProxyBox {
  RenderUnboundedHitTest([super.child]);

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (hitTestChildren(result, position: position) || hitTestSelf(position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}

/// A [Stack] whose [RenderStack] permits hit-testing children positioned outside
/// the stack's own layout bounds (for instance, strokes and text boxes in the pasteboard).
class UnboundedHitTestStack extends Stack {
  const UnboundedHitTestStack({
    super.key,
    super.alignment = Alignment.topLeft,
    super.textDirection,
    super.fit,
    super.clipBehavior = Clip.none,
    super.children,
  });

  @override
  RenderStack createRenderObject(BuildContext context) {
    return RenderUnboundedHitTestStack(
      alignment: alignment,
      textDirection: textDirection ?? Directionality.maybeOf(context),
      fit: fit,
      clipBehavior: clipBehavior,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderStack renderObject) {
    renderObject
      ..alignment = alignment
      ..textDirection = textDirection ?? Directionality.maybeOf(context)
      ..fit = fit
      ..clipBehavior = clipBehavior;
  }
}

class RenderUnboundedHitTestStack extends RenderStack {
  RenderUnboundedHitTestStack({
    super.children,
    super.alignment,
    super.textDirection,
    super.fit,
    super.clipBehavior,
  });

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (hitTestChildren(result, position: position) || hitTestSelf(position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}

// Copyright 2019 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

typedef PageTransitionIndexedStackBuilder = Widget Function(Widget child,
    Animation<double> animation, Animation<double> secondaryAnimation);

///
// TODO(grinder): much better if don't build transition at the creation of
//  _ChildEntry, instead just build the transition at build() method to reflect
//  any changes in transitionBuilder, duration, and children parameters.
class PageTransitionIndexedStack extends StatefulWidget {
  ///
  const PageTransitionIndexedStack({
    Key key,
    @required this.index,
    @required this.children,
    @required this.transitionBuilder,
    this.duration = const Duration(milliseconds: 300),
    this.lazy = false,
    this.reverse = false,
  })  : assert(index != null),
        assert(children != null),
        assert(transitionBuilder != null),
        assert(duration != null),
        super(key: key);

  /// Active index will be shown in stack. Changing this will trigger the
  /// animations.
  final int index;

  ///
  // TODO(grinder15): If children changes, what will happen?
  // not sure, I think if we check all widgets against the previous and re-wrap
  // them with transitionBuilder
  // possible checks: by children.length and [Widget.canUpdate]
  final List<Widget> children;

  ///
  // TODO(grinder15): If duration changes, what will happen?
  // possible: flush all _ChildEntry and recreate thus destroying the state of
  // widgets? or re wrap again?
  final Duration duration;

  ///
  // TODO(grinder15): If transitionBuilder changes, what will happen?
  // current scenario: it will reset all children, re-wraps all children with new
  // transitionBuilder and animate-in the child with the supplied index.
  final PageTransitionIndexedStackBuilder transitionBuilder;

  ///
  // TODO(grinder15): If lazy changes, what will happen?
  // current scenario: the widget will not allow changes in lazy thus assertion
  // check will trigger.
  final bool lazy;

  ///
  final bool reverse;

  @override
  _PageTransitionIndexedStackState createState() =>
      _PageTransitionIndexedStackState();
}

class _PageTransitionIndexedStackState extends State<PageTransitionIndexedStack>
    with TickerProviderStateMixin {
  // caching children
  List<_ChildEntry> _children;

  // this is used for lazy property of the widget, save the index of child here
  // to initialize the widget
  final Set<int> _setIndexes = <int>{};

  // this is used in checking if the child will be off-staged.
  // possible scenario, 2 active child in transitioning and the outgoing child
  // will be off-staged
  final Set<int> _activeIndexes = <int>{};

  @override
  void initState() {
    super.initState();
    _setNewChildrenList();
    assert(_children.isNotEmpty);
    // initial complete the animation.
    if (widget.index != null) {
      if (widget.lazy) {
        _addIndexToSet(widget.index);
      }
      _activeIndexes.add(widget.index);
      _children[widget.index].primaryController.value = 1.0;
    }
  }

  void _addIndexToSet(int index) {
    _setIndexes.add(index);
  }

  void _setNewChildrenList() {
    _children = widget.children
        .asMap()
        .map(
          (int index, Widget child) {
            // create animation controller
            final AnimationController _primaryController = AnimationController(
              vsync: this,
              duration: widget.duration,
            );

            final AnimationController _secondaryController =
                AnimationController(
              vsync: this,
              duration: widget.duration,
            );

            _primaryController.addStatusListener((AnimationStatus status) {
              if (status == AnimationStatus.dismissed) {
                setState(() {
                  _activeIndexes.remove(index);
                });
              }
            });

            _secondaryController.addStatusListener((AnimationStatus status) {
              if (status == AnimationStatus.completed) {
                setState(() {
                  _activeIndexes.remove(index);
                });
              }
            });

            final Widget _transition = widget.transitionBuilder(
              child,
              _primaryController,
              _secondaryController,
            );

            assert(
              _transition != null,
              'AnimatedIndexedStack.transitionBuilder must not return null.',
            );

            return MapEntry<int, _ChildEntry>(
              index,
              _ChildEntry(
                index: index,
                primaryController: _primaryController,
                secondaryController: _secondaryController,
                //widgetChild: child,
                transition: _transition,
              ),
            );
          },
        )
        .values
        .toList();
  }

  void _animateChild(_ChildEntry _childEntry,
      {bool exit = false, bool reverse = false}) {
    // animate the child
    if (reverse) {
      if (exit) {
        // play reversed exit animation
        _childEntry.secondaryController.value = 0.0;
        _childEntry.primaryController.reverse(from: 1.0);
      } else {
        // play reversed enter animation
        _childEntry.primaryController.value = 1.0;
        _childEntry.secondaryController.reverse(from: 1.0);
      }
    } else {
      if (exit) {
        // play exit animation
        _childEntry.primaryController.value = 1.0;
        _childEntry.secondaryController.forward(from: 0.0);
      } else {
        // play enter animation
        _childEntry.secondaryController.value = 0.0;
        _childEntry.primaryController.forward(from: 0.0);
      }
    }
  }

  @override
  void didUpdateWidget(PageTransitionIndexedStack oldWidget) {
    assert(widget.lazy == oldWidget.lazy,
        "You can't change lazy parameter in rebuild.");
    super.didUpdateWidget(oldWidget);

    // recreate all children entries whenever the list length is different or
    // duration is different
    if (widget.children.length != _children.length ||
        widget.duration != oldWidget.duration) {
      // if lazy and there is a change, reset all indexes.
      if (widget.lazy) {
        _setIndexes.clear();
      }
      _activeIndexes.clear();

      // dispose children first.
      _disposeChildren();
      // update all children entries
      _setNewChildrenList();
      // play animation
      if (widget.index != null) {
        _activeIndexes.add(widget.index);
        _animateChild(_children[widget.index], reverse: widget.reverse);
      }
      // Note: we don't need to setState here cuz we will not perform exit animation
      // for the previous active index. save build cost.
      return;
    }

    assert(widget.children.length == oldWidget.children.length,
        "You changed the children but isn't refreshed");

    // update children.
    // TODO(grinder15): Do we need to update children?
    //_updateChildren(widget.children);

    if (widget.index != oldWidget.index) {
      // animate!
      // if the new index is null don't animate in!
      if (widget.index != null) {
        // if lazy, cache that index
        if (widget.lazy) {
          _addIndexToSet(widget.index);
        }
        _activeIndexes.add(widget.index);
        _animateChild(_children[widget.index], reverse: widget.reverse);
      }
      if (oldWidget.index != null) {
        _activeIndexes.add(widget.index);
        _animateChild(_children[oldWidget.index],
            exit: true, reverse: widget.reverse);
      }
    }
  }

  void _disposeChildren() {
    for (final _ChildEntry _child in _children) {
      _child.dispose();
    }
  }

  /*void _updateChildren(List<Widget> newChildren) {
    for (int i = 0; i < newChildren.length; i++) {
      _children[i].widgetChild = newChildren[i];
    }
  }*/

  @override
  void dispose() {
    _disposeChildren();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: _children.map(
        (_ChildEntry child) {
          if (widget.lazy) {
            return Offstage(
              offstage: !_activeIndexes.contains(child.index),
              child: _setIndexes.contains(child.index)
                  ? child.transition
                  : Container(),
            );
          }
          return Offstage(
            offstage: !_activeIndexes.contains(child.index),
            child: child.transition,
          );
        },
      ).toList(),
    );
  }
}

class _ChildEntry {
  _ChildEntry({
    @required this.index,
    @required this.primaryController,
    @required this.secondaryController,
    //@required this.widgetChild,
    @required this.transition,
  })  : assert(index != null),
        assert(primaryController != null),
        assert(secondaryController != null),
        //assert(widgetChild != null),
        assert(transition != null);

  final int index;

  final AnimationController primaryController;

  final AnimationController secondaryController;

  Widget transition;

  //Widget widgetChild;

  void dispose() {
    primaryController.dispose();
    secondaryController.dispose();
  }
}

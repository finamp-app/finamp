import 'dart:async';

import 'package:finamp/main.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/feedback_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_on_it/focus_on_it.dart';

enum Drag { start, update, end }

class AlphabetList extends ConsumerStatefulWidget {
  final Function(String) callback;

  final SortOrder sortOrder;

  final Widget child;
  final ScrollController scrollController;
  final bool inGridMode;

  const AlphabetList({
    super.key,
    required this.callback,
    required this.sortOrder,
    required this.child,
    required this.scrollController,
    required this.inGridMode,
  });

  @override
  ConsumerState<AlphabetList> createState() => _AlphabetListState();
}

class _AlphabetListState extends ConsumerState<AlphabetList> {
  List<String> alphabet =
      ['#'] +
      List.generate(26, (int index) {
        return String.fromCharCode('A'.codeUnitAt(0) + index);
      });

  List<String> get getAlphabet => alphabet;

  @override
  void initState() {
    orderTheList(alphabet);
    super.initState();
  }

  String? _currentSelected;
  String? _toBeSelected;
  bool _displayPreview = false;
  double _letterHeight = 20;
  final double _bottomPadding = 20;

  @override
  void didUpdateWidget(AlphabetList oldWidget) {
    orderTheList(alphabet);
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final alphabetList = Container(
      margin: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + _bottomPadding / 2),
      decoration: widget.inGridMode
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(12.0),
              color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.75),
            )
          : null,
      padding: EdgeInsets.only(top: 10, bottom: _bottomPadding / 2, right: 3 + MediaQuery.paddingOf(context).right),
      child: LayoutBuilder(
        builder: (context, constraints) {
          _letterHeight = constraints.maxHeight / alphabet.length;
          return Listener(
            onPointerDown: (x) => updateSelected(x.localPosition, Drag.start),
            onPointerMove: (x) => updateSelected(x.localPosition, Drag.update),
            onPointerUp: (x) => updateSelected(x.localPosition, Drag.end),
            behavior: HitTestBehavior.opaque,
            child: Semantics(
              excludeSemantics: true, // replace child semantics with custom semantics
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  alphabet.length,
                  (x) => Container(
                    padding: const EdgeInsets.only(right: 6.0),
                    height: _letterHeight,
                    child: FittedBox(child: Text(alphabet[x].toUpperCase())),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    // This gestureDetector blocks the horizontal drag to switch tabs gesture
    // while dragging on alphabet, but still allows all gestures on main content.
    // I don't know why this works, there's weird interactions between the listener,
    // gestureDetecters, and the stack.-

    return GestureDetector(
      onVerticalDragStart: (_) {},
      // Draw scrollbar on top of fast scroller to enable interaction and improve
      // visibility
      child: Scrollbar(
        controller: widget.scrollController,
        child: Stack(
          children: [
            // Disable default scrollbar
            ScrollConfiguration(
              behavior: const FinampScrollBehavior(scrollbars: false),
              child: Padding(padding: const EdgeInsets.only(right: 22.0), child: widget.child),
            ),
            if (_currentSelected != null && _displayPreview)
              Positioned(
                left: 20,
                top: 20,
                child: FocusOnIt(
                  onUnfocus: () {
                    setState(() {
                      _currentSelected = null;
                      _displayPreview = false;
                    });
                  },
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentSelected = null;
                        _displayPreview = false;
                      });
                    },
                    child: Container(
                      width: MediaQuery.widthOf(context) / 3,
                      height: MediaQuery.widthOf(context) / 3,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: FittedBox(child: Text(_currentSelected!, style: const TextStyle(fontSize: 120))),
                    ),
                  ),
                ),
              ),
            Directionality.of(context) == TextDirection.rtl
                ? Positioned(left: 0, top: -10, bottom: -10, child: alphabetList)
                : Positioned(right: 0, top: -10, bottom: -10, child: alphabetList),
          ],
        ),
      ),
    );
  }

  void updateSelected(Offset position, Drag state) {
    String previousToBeSelected = _toBeSelected ?? '';
    if (position.dx > -20) {
      _toBeSelected = alphabet[(position.dy / _letterHeight).floor().clamp(0, alphabet.length - 1)];
      if (previousToBeSelected != _toBeSelected) {
        FeedbackHelper.feedback(FeedbackType.light);
      }
    }

    if (state == Drag.start) {
      setState(() {
        _displayPreview = true;
      });
    }
    if (state == Drag.end && _toBeSelected != null) {
      FeedbackHelper.feedback(FeedbackType.selection);
      widget.callback(_toBeSelected ?? _currentSelected ?? '');
    }

    if (state == Drag.end) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          setState(() {
            _displayPreview = false;
            _currentSelected = null;
          });
        } else {
          _displayPreview = false;
          _currentSelected = null;
        }
      });
    } else if (_currentSelected != _toBeSelected) {
      setState(() {
        if (_currentSelected != null) {
          _displayPreview = true;
        }
        _currentSelected = _toBeSelected;
      });
    }
  }

  void orderTheList(List<String> list) {
    widget.sortOrder == SortOrder.ascending ? list.sort() : list.sort((a, b) => b.compareTo(a));
  }
}

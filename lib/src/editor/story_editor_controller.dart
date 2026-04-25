import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'models/story_element.dart';

class StoryEditorController extends ChangeNotifier {
  static const _maxHistory = 30;

  final List<StoryElement> _elements = [];
  final List<List<StoryElement>> _history = [];
  String? _selectedId;

  List<StoryElement> get elements => List.unmodifiable(_elements);
  String? get selectedId => _selectedId;
  bool get canUndo => _history.isNotEmpty;

  StoryElement? get selectedElement =>
      _selectedId == null
          ? null
          : _elements.where((e) => e.id == _selectedId).firstOrNull;

  // ---------------------------------------------------------------------------
  // History

  void pushHistory() {
    _history.add(List.of(_elements));
    if (_history.length > _maxHistory) _history.removeAt(0);
  }

  void undo() {
    if (_history.isEmpty) return;
    final prev = _history.removeLast();
    _elements
      ..clear()
      ..addAll(prev);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Element CRUD

  void addText(TextElement element) {
    pushHistory();
    _elements.add(element);
    notifyListeners();
  }

  void addSticker(StickerElement element) {
    pushHistory();
    _elements.add(element);
    notifyListeners();
  }

  void addDrawingStroke(DrawingElement element) {
    pushHistory();
    _elements.add(element);
    notifyListeners();
  }

  void updateElement(String id, StoryElement updated) {
    final idx = _elements.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    _elements[idx] = updated;
    notifyListeners();
  }

  void removeElement(String id) {
    pushHistory();
    _elements.removeWhere((e) => e.id == id);
    if (_selectedId == id) _selectedId = null;
    notifyListeners();
  }

  void selectElement(String? id) {
    if (_selectedId == id) return;
    _selectedId = id;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Transforms — callers must pass fractional deltas (0.0–1.0 coordinate space)

  void moveElement(String id, Offset fractionalDelta) {
    final el = _elements.where((e) => e.id == id).firstOrNull;
    if (el == null) return;
    updateElement(id, el.copyWith(position: el.position + fractionalDelta));
  }

  void scaleElement(String id, double scaleFactor) {
    final el = _elements.where((e) => e.id == id).firstOrNull;
    if (el == null) return;
    updateElement(
      id,
      el.copyWith(scale: (el.scale * scaleFactor).clamp(0.1, 10.0)),
    );
  }

  void rotateElement(String id, double rotationDelta) {
    final el = _elements.where((e) => e.id == id).firstOrNull;
    if (el == null) return;
    updateElement(id, el.copyWith(rotation: el.rotation + rotationDelta));
  }

  // ---------------------------------------------------------------------------
  // Serialization

  List<Map<String, dynamic>> toJsonList() =>
      _elements.map((e) => e.toJson()).toList();

  static List<StoryElement> fromJsonList(List<Map<String, dynamic>> list) =>
      list.map((e) => StoryElement.fromJson(e)).toList();
}

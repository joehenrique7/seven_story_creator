import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/story_element.dart';

class TextEditor extends StatefulWidget {
  const TextEditor({
    super.key,
    this.initial,
    required this.onConfirm,
    required this.onCancel,
  });

  final TextElement? initial;
  final void Function(TextElement) onConfirm;
  final VoidCallback onCancel;

  @override
  State<TextEditor> createState() => _TextEditorState();
}

class _TextEditorState extends State<TextEditor> {
  static const _uuid = Uuid();

  late final TextEditingController _textCtrl;
  Color _color = Colors.white;
  double _fontSize = 28.0;
  String? _fontFamily;
  bool _hasShadow = false;
  TextAlign _align = TextAlign.center;

  static const _colors = [
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.pink,
    Colors.orange,
  ];

  static const _fonts = [null, 'Serif', 'Monospace', 'SansSerif'];

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _textCtrl = TextEditingController(text: init?.text ?? '');
    if (init != null) {
      _color = init.color;
      _fontSize = init.fontSize;
      _fontFamily = init.fontFamily;
      _hasShadow = init.hasShadow;
      _align = init.align;
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Center(
                child: TextField(
                  controller: _textCtrl,
                  autofocus: true,
                  maxLines: null,
                  textAlign: _align,
                  style: TextStyle(
                    color: _color,
                    fontSize: _fontSize,
                    fontFamily: _fontFamily,
                    shadows: _hasShadow
                        ? const [
                            Shadow(blurRadius: 4, color: Colors.black54),
                          ]
                        : null,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Type something...',
                    hintStyle: TextStyle(color: Colors.white54),
                    contentPadding: EdgeInsets.symmetric(horizontal: 24),
                  ),
                ),
              ),
            ),
            _buildToolbar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: widget.onCancel,
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: _confirm,
            child: const Text('Done',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      color: Colors.black45,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Color row
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _colors.map((c) {
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 30,
                    height: 30,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color == c ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Font size slider
          Row(
            children: [
              const Icon(Icons.text_fields, color: Colors.white, size: 16),
              Expanded(
                child: Slider(
                  value: _fontSize,
                  min: 14,
                  max: 80,
                  onChanged: (v) => setState(() => _fontSize = v),
                ),
              ),
            ],
          ),
          // Font + align + shadow row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Font cycle
              TextButton(
                onPressed: () {
                  final idx = _fonts.indexOf(_fontFamily);
                  setState(() {
                    _fontFamily = _fonts[(idx + 1) % _fonts.length];
                  });
                },
                child: Text(
                  _fontFamily ?? 'Default',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              // Align
              IconButton(
                icon: Icon(_alignIcon(), color: Colors.white),
                onPressed: () {
                  setState(() {
                    _align = TextAlign.values[
                        (_align.index + 1) % TextAlign.values.length];
                  });
                },
              ),
              // Shadow
              IconButton(
                icon: Icon(
                  _hasShadow ? Icons.wb_shade : Icons.wb_shade_outlined,
                  color: Colors.white,
                ),
                onPressed: () => setState(() => _hasShadow = !_hasShadow),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _alignIcon() {
    return switch (_align) {
      TextAlign.left || TextAlign.start => Icons.format_align_left,
      TextAlign.right || TextAlign.end => Icons.format_align_right,
      TextAlign.justify => Icons.format_align_justify,
      _ => Icons.format_align_center,
    };
  }

  void _confirm() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      widget.onCancel();
      return;
    }
    final el = widget.initial?.copyWith(
          text: text,
          color: _color,
          fontSize: _fontSize,
          fontFamily: _fontFamily,
          hasShadow: _hasShadow,
          align: _align,
        ) ??
        TextElement(
          id: _uuid.v4(),
          position: const Offset(0.5, 0.5),
          text: text,
          color: _color,
          fontSize: _fontSize,
          fontFamily: _fontFamily,
          hasShadow: _hasShadow,
          align: _align,
        );
    widget.onConfirm(el);
  }
}

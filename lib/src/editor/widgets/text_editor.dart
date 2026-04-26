import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  static const _fontOptions = [
    _FontOption(label: 'Padrão', family: null),
    _FontOption(label: 'Roboto', family: 'Roboto'),
    _FontOption(label: 'Playfair', family: 'Playfair Display'),
    _FontOption(label: 'Mono', family: 'Roboto Mono'),
    _FontOption(label: 'Oswald', family: 'Oswald'),
    _FontOption(label: 'Pacifico', family: 'Pacifico'),
    _FontOption(label: 'Dancing', family: 'Dancing Script'),
    _FontOption(label: 'Bebas', family: 'Bebas Neue'),
  ];

  static const _alignCycle = [
    TextAlign.left,
    TextAlign.center,
    TextAlign.right,
    TextAlign.justify,
  ];

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
              child: GestureDetector(
                onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
                child: Center(
                  child: TextField(
                    controller: _textCtrl,
                    autofocus: true,
                    maxLines: null,
                    textAlign: _align,
                    style: _applyFont(
                      _fontFamily,
                      TextStyle(
                        color: _color,
                        fontSize: _fontSize,
                        shadows: _hasShadow
                            ? const [Shadow(blurRadius: 4, color: Colors.black54)]
                            : null,
                      ),
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Digite algo...',
                      hintStyle: TextStyle(color: Colors.white54),
                      contentPadding: EdgeInsets.symmetric(horizontal: 24),
                    ),
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
            child: const Text('Cancelar', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: _confirm,
            child: const Text(
              'Concluir',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black54,
        border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFontFamilyRow(),
          const SizedBox(height: 12),
          _buildActionsRow(),
        ],
      ),
    );
  }

  Widget _buildFontFamilyRow() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: _fontOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final opt = _fontOptions[i];
          final selected = _fontFamily == opt.family;
          return GestureDetector(
            onTap: () => setState(() => _fontFamily = opt.family),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.white10,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? Colors.white : Colors.white30,
                  width: 1.5,
                ),
              ),
              child: Text(
                opt.label,
                style: _applyFont(
                  opt.family,
                  TextStyle(
                    fontSize: 14,
                    color: selected ? Colors.black : Colors.white,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionsRow() {
    return Row(
      children: [
        // Color circles
        Expanded(
          child: SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _colors.map((c) {
                final selected = _color == c;
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: selected ? 34 : 28,
                    height: selected ? 34 : 28,
                    margin: EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: selected ? 0 : 3,
                    ),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Colors.white : Colors.white38,
                        width: selected ? 2.5 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Font size -
        _ActionButton(
          icon: Icons.remove,
          onTap: () => setState(
            () => _fontSize = (_fontSize - 2).clamp(10.0, 80.0),
          ),
        ),
        const SizedBox(width: 2),
        SizedBox(
          width: 32,
          child: Text(
            _fontSize.round().toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 2),
        // Font size +
        _ActionButton(
          icon: Icons.add,
          onTap: () => setState(
            () => _fontSize = (_fontSize + 2).clamp(10.0, 80.0),
          ),
        ),
        const SizedBox(width: 6),
        // Align
        _ActionButton(
          icon: _alignIcon(),
          active: true,
          onTap: () {
            setState(() {
              final idx = _alignCycle.indexOf(_align);
              _align = _alignCycle[(idx + 1) % _alignCycle.length];
            });
          },
        ),
        const SizedBox(width: 6),
        // Shadow
        _ActionButton(
          icon: Icons.auto_awesome,
          active: _hasShadow,
          onTap: () => setState(() => _hasShadow = !_hasShadow),
        ),
      ],
    );
  }

  static TextStyle _applyFont(String? family, TextStyle base) {
    if (family == null) return base;
    try {
      return GoogleFonts.getFont(family, textStyle: base);
    } catch (_) {
      return base;
    }
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

class _FontOption {
  const _FontOption({required this.label, required this.family});
  final String label;
  final String? family;
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white10,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? Colors.white : Colors.white30,
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          color: active ? Colors.black : Colors.white,
          size: 18,
        ),
      ),
    );
  }
}

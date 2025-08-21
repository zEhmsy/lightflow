import 'dart:ui' show Color, FontFeature;
import 'package:flutter/material.dart';
import '../../../core/models/strip_state.dart';
import '../../../core/utils/color_hex.dart';

class StripCard extends StatefulWidget {
  final int index;
  final String name;                         // NEW
  final StripState state;
  final int maxN;
  final ValueChanged<StripState> onChanged;
  final ValueChanged<String> onRename;       // NEW
  final VoidCallback onApply;
  final VoidCallback onPickColor;

  const StripCard({
    super.key,
    required this.index,
    required this.name,
    required this.state,
    required this.maxN,
    required this.onChanged,
    required this.onRename,
    required this.onApply,
    required this.onPickColor,
  });

  @override
  State<StripCard> createState() => _StripCardState();
}

class _StripCardState extends State<StripCard> {
  bool _expanded = false;

  late final TextEditingController _nameCtrl = TextEditingController(text: widget.name);
  final FocusNode _nameFocus = FocusNode();

  // Preset per carosello colori in espansione
  final List<Color> _swatches = const [
    Color(0xFFFFFFFF), Color(0xFFFF0000), Color(0xFF00FF00),
    Color(0xFF2B60FF), Color(0xFFFFA000), Color(0xFF8A2BE2),
    Color(0xFF00FFFF), Color(0xFFFF00FF), Color(0xFFFF7F50),
  ];

  StripState get state => widget.state;

  void _setN(int v) => widget.onChanged(state.copyWith(n: v.clamp(1, widget.maxN)));
  void _setB(int v) => widget.onChanged(state.copyWith(b: v.clamp(0, 255)));
  void _setS(int v) => widget.onChanged(state.copyWith(s: v.clamp(1, 1000)));
  void _setC(Color c) => widget.onChanged(state.copyWith(c: c));

  @override
  Widget build(BuildContext context) {
    final previewColor = Color.lerp(Colors.black, state.c, (state.b.clamp(0, 255)) / 255.0)!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: state.c.withOpacity(0.22)),
        boxShadow: [BoxShadow(color: state.c.withOpacity(0.08), blurRadius: 14, offset: const Offset(0, 8))],
      ),
      padding: const EdgeInsets.all(12),
      clipBehavior: Clip.hardEdge,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // HEADER COMPATTO: SOLO NOME + COLORE + CHEVRON
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.name,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // dot colore (sempre visibile)
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: state.c,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        duration: const Duration(milliseconds: 200),
                        turns: _expanded ? 0.5 : 0.0,
                        child: const Icon(Icons.keyboard_arrow_down, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          // PREVIEW barra
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(height: 8, child: DecoratedBox(decoration: BoxDecoration(color: previewColor))),
          ),

          // CONTENUTO ESPANDIBILE (rename + sliders + carosello + apply)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // RENAME
                        Row(
                          children: [
                            const _Label('Nome'),
                            Expanded(
                              child: TextField(
                                controller: _nameCtrl,
                                focusNode: _nameFocus,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  suffixIcon: IconButton(
                                    tooltip: 'Salva nome',
                                    icon: const Icon(Icons.check),
                                    onPressed: _commitName, // <-- salva anche senza invio
                                  ),
                                ),
                                onEditingComplete: _commitName, // invio/done
                                onSubmitted: (_) => _commitName(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // LED
                        Row(
                          children: [
                            const _Label('LED'),
                            IconButton(
                              onPressed: () => _setN(state.n - 1),
                              icon: const Icon(Icons.remove),
                              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                            ),
                            SizedBox(
                              width: 72,
                              child: TextFormField(
                                initialValue: state.n.toString(),
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  isDense: true, border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                                onChanged: (v) { final n = int.tryParse(v); if (n != null) _setN(n); },
                              ),
                            ),
                            IconButton(
                              onPressed: () => _setN(state.n + 1),
                              icon: const Icon(Icons.add),
                              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                            ),
                            const Spacer(),
                            Text('${state.n}/${widget.maxN}', style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
                          ],
                        ),

                        // Brightness
                        Row(
                          children: [
                            const Icon(Icons.wb_sunny_outlined, size: 18),
                            const SizedBox(width: 6),
                            const _Label('Bright'),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(trackHeight: 3),
                                child: Slider(
                                  value: state.b.toDouble(), min: 0, max: 255, divisions: 255,
                                  label: state.b.toString(), onChanged: (v) => _setB(v.round()),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 44,
                              child: Text(state.b.toString().padLeft(3, ' '),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
                            ),
                          ],
                        ),

                        // Speed
                        Row(
                          children: [
                            const Icon(Icons.timer_outlined, size: 18),
                            const SizedBox(width: 6),
                            const _Label('Velocità'),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(trackHeight: 3),
                                child: Slider(
                                  value: state.s.toDouble(), min: 1, max: 1000, divisions: 999,
                                  label: '${state.s} ms', onChanged: (v) => _setS(v.round()),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 64,
                              child: Text('${state.s} ms',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
                            ),
                          ],
                        ),

                        // Colore: carosello compatto + HEX + picker
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const _Label('Colore'),
                            Expanded(
                              child: _MiniCarousel(
                                colors: _swatches,
                                selected: state.c,
                                onSelected: _setC,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 96,
                              child: TextFormField(
                                initialValue: '#${hex6(state.c)}',
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  isDense: true, border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                                onFieldSubmitted: (v) {
                                  final clean = v.replaceAll('#', '').trim().toUpperCase();
                                  if (RegExp(r'^[0-9A-F]{6}$').hasMatch(clean)) _setC(colorFromHex6(clean));
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: widget.onPickColor,
                              icon: const Icon(Icons.palette_outlined),
                              label: const Text('Scegli'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: widget.onApply,
                            icon: const Icon(Icons.check),
                            label: const Text('Applica'),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  @override
  void didUpdateWidget(covariant StripCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se il nome cambia “da fuori” (es. dopo persistenza) e non stai editando, sincronizza il campo
    if (!_nameFocus.hasFocus && widget.name != _nameCtrl.text) {
      _nameCtrl.text = widget.name;
    }
  }

  void _commitName() {
    final n = _nameCtrl.text.trim();
    widget.onRename(n);         // salva su VM + SharedPreferences
    _nameFocus.unfocus();
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Colors.white70),
      ),
    );
  }
}

/// Carosello compatto: centro più grande, lati più piccoli (snap)
class _MiniCarousel extends StatefulWidget {
  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onSelected;
  const _MiniCarousel({required this.colors, required this.selected, required this.onSelected});
  @override
  State<_MiniCarousel> createState() => _MiniCarouselState();
}

class _MiniCarouselState extends State<_MiniCarousel> {
  late final PageController _ctrl;
  late int _index;

  int _indexFor(Color c) {
    final v = (c.value & 0xFFFFFF);
    final i = widget.colors.indexWhere((x) => (x.value & 0xFFFFFF) == v);
    return i < 0 ? 0 : i;
  }

  @override
  void initState() {
    super.initState();
    _index = _indexFor(widget.selected);
    _ctrl = PageController(viewportFraction: 0.35, initialPage: _index);
  }

  @override
  void didUpdateWidget(covariant _MiniCarousel old) {
    super.didUpdateWidget(old);
    final ni = _indexFor(widget.selected);
    if (ni != _index && _ctrl.hasClients) {
      _index = ni;
      _ctrl.animateToPage(_index, duration: const Duration(milliseconds: 160), curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: PageView.builder(
        controller: _ctrl,
        itemCount: widget.colors.length,
        onPageChanged: (i) {
          setState(() => _index = i);
          widget.onSelected(widget.colors[i]);
        },
        itemBuilder: (ctx, i) {
          return AnimatedBuilder(
            animation: _ctrl,
            builder: (ctx, child) {
              double page = _ctrl.positions.isNotEmpty ? (_ctrl.page ?? _index.toDouble()) : _index.toDouble();
              double delta = (i - page).abs();
              double scale = (1.0 - (delta * 0.30)).clamp(0.70, 1.0);
              double opacity = (1.0 - (delta * 0.6)).clamp(0.4, 1.0);
              final selected = delta < 0.5;
              return Center(
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: GestureDetector(
                      onTap: () {
                        _ctrl.animateToPage(i, duration: const Duration(milliseconds: 160), curve: Curves.easeOutCubic);
                        widget.onSelected(widget.colors[i]);
                      },
                      child: _Dot(color: widget.colors[i], selected: selected),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final bool selected;
  const _Dot({required this.color, required this.selected});
  @override
  Widget build(BuildContext context) {
    final size = selected ? 20.0 : 16.0;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: color, shape: BoxShape.circle,
        border: Border.all(color: selected ? Colors.white : Colors.white24, width: selected ? 2 : 1),
      ),
    );
  }
}
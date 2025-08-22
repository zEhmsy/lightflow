import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import '../../core/repositories/led_repository.dart';
import '../../core/models/strip_state.dart';
import 'controller_vm.dart';
import 'widgets/strip_card.dart';
import '../../core/storage/settings_store.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class ControllerPage extends StatelessWidget {
  final String baseUrl;
  const ControllerPage({super.key, required this.baseUrl});

  void _snack(BuildContext context, String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final repo = Provider.of<LedRepository>(context, listen: false);

    return ChangeNotifierProvider(
      create: (_) => ControllerVm(repo, SettingsStore())..load(),
      child: Builder(
        builder: (context) {
          final vm = context.watch<ControllerVm>();

          return Scaffold(
            appBar: AppBar(
              title: const Text('Sitec LightFlow'),
              actions: [
                IconButton(
                  tooltip: 'Ricarica stato',
                  onPressed: vm.loading ? null : vm.load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: vm.loading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final w = constraints.maxWidth;
                              final cols = w >= 1000 ? 3 : (w >= 650 ? 2 : 1); // responsive
                              return MasonryGridView.count(
                                crossAxisCount: cols,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                itemCount: ControllerVm.nStrips,
                                itemBuilder: (ctx, i) => StripCard(
                                  index: i,
                                  name: vm.names[i],
                                  state: vm.strips[i],
                                  maxN: ControllerVm.maxN,
                                  animated: vm.animated[i], // NEW
                                  onToggleAnimated: (v) => vm.setAnimated(i, v), // NEW
                                  onChanged: (st) => vm.update(i, st),
                                  onRename: (newName) => vm.rename(i, newName),
                                  onApply: () async {
                                    try { await vm.apply(i); }
                                    catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore /set: $e'))); }
                                  },
                                  onPickColor: () async {
                                    Color temp = vm.strips[i].c;
                                    await showDialog<void>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text('Colore ${vm.names[i]}'),
                                        content: SingleChildScrollView(
                                          child: ColorPicker(
                                            pickerColor: temp,
                                            onColorChanged: (c) => temp = c,
                                            enableAlpha: false,
                                            labelTypes: const [],
                                            hexInputBar: true,
                                            displayThumbColor: true,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
                                          FilledButton(
                                            onPressed: () { vm.update(i, vm.strips[i].copyWith(c: temp)); Navigator.pop(ctx); },
                                            child: const Text('Seleziona'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () async {
                                  try {
                                    await vm.sync();
                                    _snack(context, 'Sync inviato');
                                  } catch (e) {
                                    _snack(context, 'Errore /sync: $e');
                                  }
                                },
                                icon: const Icon(Icons.sync),
                                label: const Text('Sincronizza inizio'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}

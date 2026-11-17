import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../widgets/common.dart';

/// Administrar módulos: agregar, editar, reordenar y eliminar.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Módulos')),
      body: SafeArea(
        top: false,
        child: Column(children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Mantén presionado y arrastra para reordenar.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: s.categories.length,
              onReorderItem: s.reorderCategories,
              proxyDecorator: (child, _, _) => Material(color: Colors.transparent, child: child),
              itemBuilder: (context, i) {
                final c = s.categories[i];
                return Padding(
                  key: ValueKey(c.id),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Panel(
                    padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                    radius: 20,
                    child: Row(children: [
                      CatBadge(icon: c.icon, color: c.color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          Text(c.isSavings ? 'En el chanchito: ${money(s.saved)}' : 'Este mes: ${money(s.monthByCat[c.id] ?? 0)}',
                              style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                        ]),
                      ),
                      IconButton(
                        onPressed: () => showCategoryEditor(context, c),
                        icon: const Icon(Icons.edit_rounded, color: AppColors.muted, size: 20),
                      ),
                      if (!c.isSavings)
                        IconButton(
                          onPressed: () => deleteCategoryFlow(context, c),
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red, size: 22),
                        ),
                      ReorderableDragStartListener(
                        index: i,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.drag_indicator_rounded, color: AppColors.muted),
                        ),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: GoldButton(label: 'Nuevo módulo', onTap: () => showCategoryEditor(context, null)),
          ),
        ]),
      ),
    );
  }
}

Future<bool> deleteCategoryFlow(BuildContext context, Category c) async {
  final ok = await confirm(context, 'Eliminar "${c.name}"',
      'El módulo desaparecerá de la lista. Los gastos ya registrados se conservan en el historial.');
  if (!ok || !context.mounted) return false;
  await AppScope.read(context).deleteCategory(c);
  if (context.mounted) toast(context, 'Módulo "${c.name}" eliminado');
  return true;
}

/// Editor de módulo en hoja inferior. Devuelve el id guardado.
Future<int?> showCategoryEditor(BuildContext context, Category? cat) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CategoryEditor(cat: cat),
  );
}

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({this.cat});
  final Category? cat;

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  late final _name = TextEditingController(text: widget.cat?.name ?? '');
  late String _icon = widget.cat?.icon ?? 'shop';
  late int _color = widget.cat?.color ?? AppColors.palette[1];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final n = _name.text.trim();
    if (n.isEmpty) return;
    HapticFeedback.mediumImpact();
    final s = AppScope.read(context);
    final base = widget.cat ?? Category(name: n, icon: _icon, color: _color);
    final id = await s.saveCategory(base.copyWith(name: n, icon: _icon, color: _color));
    if (mounted) Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: CatBadge(key: ValueKey('$_icon$_color'), icon: _icon, color: _color, size: 52),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(widget.cat == null ? 'Nuevo módulo' : 'Editar módulo',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            if (widget.cat != null && !widget.cat!.isSavings)
              IconButton(
                onPressed: () async {
                  final nav = Navigator.of(context);
                  if (await deleteCategoryFlow(context, widget.cat!)) nav.pop();
                },
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
              ),
          ]),
          const SizedBox(height: 18),
          TextField(
            controller: _name,
            autofocus: widget.cat == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Nombre (ej. Mascotas, Salud, Hogar)'),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 18),
          const Text('Color', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final c in AppColors.palette)
              Pressable(
                onTap: () => setState(() => _color = c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: Border.all(color: _color == c ? Colors.white : Colors.transparent, width: 3),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 18),
          const Text('Icono', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final k in kIcons.keys)
              Pressable(
                onTap: () => setState(() => _icon = k),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _icon == k ? Color(_color).withValues(alpha: 0.22) : AppColors.surface2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _icon == k ? Color(_color) : AppColors.border),
                  ),
                  child: Icon(kIcons[k], color: _icon == k ? Color(_color) : AppColors.muted, size: 22),
                ),
              ),
          ]),
          const SizedBox(height: 22),
          GoldButton(
            label: 'Guardar módulo',
            icon: Icons.check_rounded,
            enabled: _name.text.trim().isNotEmpty,
            onTap: _save,
          ),
        ]),
      ),
    );
  }
}

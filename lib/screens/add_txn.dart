import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../widgets/segmented.dart';
import 'categories.dart';

class AddTxnScreen extends StatefulWidget {
  const AddTxnScreen({super.key, this.editing, this.categoryId, this.initialType = TxType.expense, this.initialAmount, this.initialNote});
  final Txn? editing;
  final int? categoryId;
  final int initialType;
  final int? initialAmount;
  final String? initialNote;

  @override
  State<AddTxnScreen> createState() => _AddTxnScreenState();
}

class _AddTxnScreenState extends State<AddTxnScreen> {
  late int _type = widget.editing?.type ?? widget.initialType;
  late int? _cat = widget.editing?.categoryId ?? widget.categoryId;
  late DateTime _date = widget.editing?.date ?? DateTime.now();
  late final _amount = TextEditingController(
      text: widget.editing != null
          ? moneyInput(widget.editing!.amount)
          : (widget.initialAmount != null ? moneyInput(widget.initialAmount!) : ''));
  late final _note = TextEditingController(text: widget.editing?.note ?? widget.initialNote ?? '');
  bool _saving = false;

  bool get _isExpense => _type == TxType.expense;

  bool get _valid {
    final a = parseMoney(_amount.text);
    return a != null && a > 0 && (!_isExpense || _cat != null);
  }

  @override
  void initState() {
    super.initState();
    _amount.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _date = DateTime(d.year, d.month, d.day, _date.hour, _date.minute));
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    final s = AppScope.read(context);
    await s.saveTxn(Txn(
      id: widget.editing?.id,
      type: _type,
      amount: parseMoney(_amount.text)!,
      note: _note.text.trim(),
      // Un retiro del chanchito (ingreso con módulo Ahorro) conserva su módulo al editarse.
      categoryId: _isExpense ? _cat : (widget.editing?.type == TxType.income ? widget.editing?.categoryId : null),
      date: _date,
    ));
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final t = widget.editing!;
    if (!await confirm(context, 'Eliminar movimiento', '¿Seguro que quieres eliminar este movimiento?')) return;
    if (!mounted) return;
    await AppScope.read(context).deleteTxn(t);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final accent = _isExpense ? AppColors.gold : AppColors.green;
    final title = widget.editing != null ? 'Editar movimiento' : (_isExpense ? 'Agregar gasto' : 'Agregar ingreso');
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Pressable(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.black, size: 20),
            ),
          ),
        ),
        title: AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: Text(title, key: ValueKey(title))),
        actions: [
          if (widget.editing != null)
            IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red)),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              physics: const BouncingScrollPhysics(),
              children: [
                Segmented<int>(
                  values: const [TxType.expense, TxType.income],
                  labels: const ['Gasto', 'Ingreso'],
                  value: _type,
                  activeColor: accent,
                  onChanged: (v) => setState(() => _type = v),
                ),
                const SizedBox(height: 14),
                Panel(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_isExpense ? 'Datos del gasto' : 'Datos del ingreso',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    _label('Monto (\$)'),
                    TextField(
                      controller: _amount,
                      autofocus: widget.editing == null,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [moneyFormatter],
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: accent),
                      decoration: InputDecoration(
                        hintText: '0,00',
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 16, right: 6),
                          child: Text('\$', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: accent)),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _label('Descripción'),
                    TextField(
                      controller: _note,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 2,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: _isExpense ? 'Ej. Almuerzo, supermercado, taxi' : 'Ej. Sueldo, pago de cliente, venta',
                      ),
                    ),
                    const SizedBox(height: 14),
                    _label('Fecha'),
                    Pressable(
                      onTap: _pickDate,
                      scale: 0.98,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(children: [
                          Icon(Icons.calendar_today_rounded, color: accent, size: 20),
                          const SizedBox(width: 10),
                          Text('${dayLabel(_date)} · ${shortDate(_date)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                        ]),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      child: _isExpense
                          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const SizedBox(height: 14),
                              _label('Módulo'),
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                for (final c in s.categories) _catChip(c),
                                ActionChip(
                                  avatar: const Icon(Icons.add_rounded, size: 18, color: AppColors.gold),
                                  label: const Text('Nuevo'),
                                  onPressed: () async {
                                    final id = await showCategoryEditor(context, null);
                                    if (id != null) setState(() => _cat = id);
                                  },
                                ),
                              ]),
                            ])
                          : const SizedBox(width: double.infinity),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: GoldButton(
              label: widget.editing != null
                  ? 'Guardar cambios'
                  : (_isExpense
                      ? (s.catById[_cat]?.isSavings == true ? 'Guardar en el chanchito' : 'Guardar gasto')
                      : 'Guardar ingreso'),
              icon: Icons.check_rounded,
              enabled: _valid && !_saving,
              onTap: _save,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(t, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, fontSize: 13)),
      );

  Widget _catChip(Category c) {
    final sel = _cat == c.id;
    final col = Color(c.color);
    return Pressable(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _cat = c.id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: sel ? col.withValues(alpha: 0.2) : AppColors.surface2,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: sel ? col : AppColors.border, width: sel ? 1.5 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(iconFor(c.icon), size: 18, color: col),
          const SizedBox(width: 6),
          Text(c.name, style: TextStyle(fontWeight: FontWeight.w700, color: sel ? AppColors.text : const Color(0xFFCFC8B6))),
        ]),
      ),
    );
  }
}

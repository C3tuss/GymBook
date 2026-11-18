import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/weight_record.dart';
import '../utils/weight_formatters.dart';

class WeightEntryDialog extends StatefulWidget {
  const WeightEntryDialog({super.key, this.initialRecord});

  final WeightRecord? initialRecord;

  @override
  State<WeightEntryDialog> createState() => _WeightEntryDialogState();
}

class _WeightEntryDialogState extends State<WeightEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _weightController;
  late DateTime _selectedDate;
  String? _dateError;

  bool get _isEditing => widget.initialRecord != null;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialRecord?.day ?? dateOnly(DateTime.now());
    _weightController = TextEditingController(
      text: widget.initialRecord == null
          ? ''
          : formatWeight(widget.initialRecord!.weightKg),
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final today = dateOnly(DateTime.now());
    final chosen = await showDatePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      initialDate: _selectedDate.isAfter(today) ? today : _selectedDate,
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: 'Escolha a data da pesagem',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );
    if (chosen != null) {
      setState(() {
        _selectedDate = dateOnly(chosen);
        _dateError = null;
      });
    }
  }

  String? _validateWeight(String? input) {
    final value = input?.trim() ?? '';
    if (value.isEmpty) return 'Informe o peso.';
    if (!RegExp(r'^\d+(?:[,.]\d{1,2})?$').hasMatch(value)) {
      return 'Use um número com até duas casas decimais.';
    }
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null) return 'Informe um peso válido.';
    if (parsed <= 0) return 'O peso precisa ser maior que zero.';
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (isFutureDay(_selectedDate)) {
      setState(() => _dateError = 'A data não pode ser futura.');
      return;
    }

    final parsed = double.parse(_weightController.text.trim().replaceAll(',', '.'));
    Navigator.of(context).pop(
      WeightRecord(
        id: widget.initialRecord?.id,
        date: dateOnly(_selectedDate),
        weightKg: parsed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEEE, dd/MM/yyyy', 'pt_BR')
        .format(_selectedDate);

    return AlertDialog(
      title: Text(_isEditing ? 'Editar pesagem' : 'Adicionar pesagem'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Data', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _chooseDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(dateLabel),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  alignment: Alignment.centerLeft,
                ),
              ),
              if (_dateError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _dateError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              TextFormField(
                controller: _weightController,
                autofocus: !_isEditing,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                ],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                validator: _validateWeight,
                decoration: const InputDecoration(
                  labelText: 'Peso',
                  hintText: 'Ex.: 79,50',
                  suffixText: 'kg',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Salvar')),
      ],
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../services/ocr_service.dart';
import '../utils/formatters.dart';

class ExpenseFormDialog extends StatefulWidget {
  final int reportId;
  final ExpenseCategory initialCategory;
  final Expense? existing;
  final Future<void> Function(String path)? onPhotoCaptured;

  const ExpenseFormDialog({
    super.key,
    required this.reportId,
    required this.initialCategory,
    this.existing,
    this.onPhotoCaptured,
  });

  @override
  State<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<ExpenseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _ocrService = OcrService();
  final _picker = ImagePicker();

  late ExpenseCategory _category;
  late TextEditingController _dateCtrl;
  late TextEditingController _establishmentCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _observationsCtrl;
  late TextEditingController _kmCtrl;
  String _uf = 'PR';
  DateTime _selectedDate = DateTime.now();
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _category = e?.category ?? widget.initialCategory;
    _selectedDate = e?.date ?? DateTime.now();
    _dateCtrl = TextEditingController(text: formatDate(_selectedDate));
    _establishmentCtrl = TextEditingController(text: e?.establishment ?? '');
    _cityCtrl = TextEditingController(text: e?.city ?? '');
    _amountCtrl = TextEditingController(
      text: e != null ? e.amount.toStringAsFixed(2).replaceAll('.', ',') : '',
    );
    _observationsCtrl = TextEditingController(text: e?.observations ?? '');
    _kmCtrl = TextEditingController(text: e?.km ?? '');
    _uf = e?.uf ?? 'PR';
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _establishmentCtrl.dispose();
    _cityCtrl.dispose();
    _amountCtrl.dispose();
    _observationsCtrl.dispose();
    _kmCtrl.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _pickAndScan(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    // Copia para armazenamento permanente e registra nos Anexos
    await widget.onPhotoCaptured?.call(picked.path);
    setState(() => _scanning = true);
    try {
      final result = await _ocrService.recognizeReceipt(File(picked.path));
      if (result.establishment != null && _establishmentCtrl.text.isEmpty) {
        _establishmentCtrl.text = result.establishment!;
      }
      if (result.date != null) {
        _selectedDate = result.date!;
        _dateCtrl.text = formatDate(_selectedDate);
      }
      if (result.amount != null && _amountCtrl.text.isEmpty) {
        _amountCtrl.text =
            result.amount!.toStringAsFixed(2).replaceAll('.', ',');
      }
      if (result.city != null && _cityCtrl.text.isEmpty) {
        _cityCtrl.text = result.city!;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro no OCR: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateCtrl.text = formatDate(picked);
      });
    }
  }

  double _parseAmount(String text) {
    final clean = text.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(clean) ?? 0.0;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final expense = Expense(
      id: widget.existing?.id,
      reportId: widget.reportId,
      category: _category,
      date: _selectedDate,
      establishment: _establishmentCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      uf: _uf,
      amount: _parseAmount(_amountCtrl.text),
      observations: _observationsCtrl.text.trim().isEmpty
          ? null
          : _observationsCtrl.text.trim(),
      km: _kmCtrl.text.trim().isEmpty ? null : _kmCtrl.text.trim(),
    );
    Navigator.of(context).pop(expense);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título
              Text(
                widget.existing == null ? 'Nova Despesa' : 'Editar Despesa',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // OCR buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: _scanning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_alt),
                      label: const Text('Câmera'),
                      onPressed: _scanning
                          ? null
                          : () => _pickAndScan(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Galeria'),
                      onPressed: _scanning
                          ? null
                          : () => _pickAndScan(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
              if (_scanning)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Lendo recibo com OCR…',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              const SizedBox(height: 16),

              // Categoria
              DropdownButtonFormField<ExpenseCategory>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  border: OutlineInputBorder(),
                ),
                items: ExpenseCategory.values
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.label),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 12),

              // Data
              TextFormField(
                controller: _dateCtrl,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Data',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: _selectDate,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Informe a data' : null,
              ),
              const SizedBox(height: 12),

              // Estabelecimento
              TextFormField(
                controller: _establishmentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Estabelecimento',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Informe o estabelecimento' : null,
              ),
              const SizedBox(height: 12),

              // Cidade + UF
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _cityCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Cidade',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Informe a cidade' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _uf,
                      decoration: const InputDecoration(
                        labelText: 'UF',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      ),
                      items: ufs
                          .map((u) => DropdownMenuItem(
                                value: u,
                                child: Text(u),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _uf = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Valor
              TextFormField(
                controller: _amountCtrl,
                decoration: const InputDecoration(
                  labelText: 'Valor (R\$)',
                  border: OutlineInputBorder(),
                  prefixText: 'R\$ ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                ],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Informe o valor';
                  if (_parseAmount(v) <= 0) return 'Valor inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // KM (só para combustível)
              if (_category == ExpenseCategory.combustivel)
                TextFormField(
                  controller: _kmCtrl,
                  decoration: const InputDecoration(
                    labelText: 'KM (opcional)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),

              // Observações (hotel e outros)
              if (_category != ExpenseCategory.combustivel)
                TextFormField(
                  controller: _observationsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Observações (opcional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),

              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _submit,
                    child: Text(widget.existing == null ? 'Adicionar' : 'Salvar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

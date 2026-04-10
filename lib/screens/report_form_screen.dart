import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/rdv_report.dart';
import '../services/report_provider.dart';
import '../utils/formatters.dart';
import 'report_detail_screen.dart';

class ReportFormScreen extends StatefulWidget {
  final RdvReport? existing;
  const ReportFormScreen({super.key, this.existing});

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _employeeCtrl;
  late TextEditingController _roleCtrl;
  late TextEditingController _obraCtrl;
  late TextEditingController _orderCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _periodCtrl;
  late TextEditingController _advanceCtrl;

  ExpenseOrigin _origin = ExpenseOrigin.engenharia;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _employeeCtrl = TextEditingController(text: r?.employee ?? '');
    _roleCtrl = TextEditingController(text: r?.role ?? '');
    _obraCtrl = TextEditingController(text: r?.obra ?? '');
    _orderCtrl = TextEditingController(text: r?.orderNumber ?? '');
    _cityCtrl = TextEditingController(text: r?.city ?? '');
    _periodCtrl = TextEditingController(text: r?.period ?? '');
    _advanceCtrl = TextEditingController(
      text: r?.advance != null && r!.advance > 0
          ? r.advance.toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );
    if (r != null) {
      _origin = r.origin;
      _month = r.month;
      _year = r.year;
    }
  }

  @override
  void dispose() {
    _employeeCtrl.dispose();
    _roleCtrl.dispose();
    _obraCtrl.dispose();
    _orderCtrl.dispose();
    _cityCtrl.dispose();
    _periodCtrl.dispose();
    _advanceCtrl.dispose();
    super.dispose();
  }

  double _parseAdvance() {
    final text = _advanceCtrl.text.trim();
    if (text.isEmpty) return 0.0;
    return double.tryParse(text.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ReportProvider>();

    if (widget.existing == null) {
      final report = RdvReport(
        employee: _employeeCtrl.text.trim(),
        role: _roleCtrl.text.trim(),
        origin: _origin,
        obra: _obraCtrl.text.trim(),
        orderNumber: _orderCtrl.text.trim(),
        month: _month,
        year: _year,
        city: _cityCtrl.text.trim(),
        period: _periodCtrl.text.trim(),
        advance: _parseAdvance(),
      );
      final id = await provider.createReport(report);
      if (mounted) {
        // Navega para o detalhe do novo relatório
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ReportDetailScreen()),
        );
      }
    } else {
      final updated = widget.existing!.copyWith(
        employee: _employeeCtrl.text.trim(),
        role: _roleCtrl.text.trim(),
        origin: _origin,
        obra: _obraCtrl.text.trim(),
        orderNumber: _orderCtrl.text.trim(),
        month: _month,
        year: _year,
        city: _cityCtrl.text.trim(),
        period: _periodCtrl.text.trim(),
        advance: _parseAdvance(),
      );
      await provider.updateReport(updated);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Novo RDV' : 'Editar Cabeçalho'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _section('Identificação'),
            const SizedBox(height: 12),
            _field(_employeeCtrl, 'Funcionário', required: true,
                icon: Icons.person),
            const SizedBox(height: 12),
            _field(_roleCtrl, 'Cargo', required: true, icon: Icons.work),
            const SizedBox(height: 20),

            _section('Origem da Despesa'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: ExpenseOrigin.values
                  .map((o) => ChoiceChip(
                        label: Text(o.label),
                        selected: _origin == o,
                        onSelected: (_) => setState(() => _origin = o),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),

            _section('Obra e Período'),
            const SizedBox(height: 12),
            _field(_obraCtrl, 'Obra / Cliente', required: true,
                icon: Icons.business),
            const SizedBox(height: 12),
            _field(_orderCtrl, 'Nº do Pedido', icon: Icons.tag),
            const SizedBox(height: 12),
            _field(_cityCtrl, 'Cidade', required: true, icon: Icons.location_city),
            const SizedBox(height: 12),
            _field(_periodCtrl, 'Período (ex: 13 a 18/mar)',
                required: true, icon: Icons.date_range),
            const SizedBox(height: 12),

            // Mês/Ano
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _month,
                    decoration: const InputDecoration(
                      labelText: 'Mês',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_month),
                    ),
                    items: List.generate(
                      12,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text(months[i]),
                      ),
                    ),
                    onChanged: (v) => setState(() => _month = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _year,
                    decoration: const InputDecoration(
                      labelText: 'Ano',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.event),
                    ),
                    items: List.generate(
                      5,
                      (i) => DropdownMenuItem(
                        value: DateTime.now().year - 1 + i,
                        child: Text('${DateTime.now().year - 1 + i}'),
                      ),
                    ),
                    onChanged: (v) => setState(() => _year = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _section('Reembolso'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _advanceCtrl,
              decoration: const InputDecoration(
                labelText: 'Adiantamento recebido (R\$)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payments),
                prefixText: 'R\$ ',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 32),

            FilledButton.icon(
              onPressed: _submit,
              icon: Icon(isNew ? Icons.arrow_forward : Icons.save),
              label: Text(isNew ? 'Criar e adicionar despesas' : 'Salvar'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    IconData? icon,
  }) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: icon != null ? Icon(icon) : null,
      ),
      validator: required
          ? (v) => v == null || v.trim().isEmpty ? 'Campo obrigatório' : null
          : null,
    );
  }
}

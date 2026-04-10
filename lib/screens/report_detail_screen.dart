import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../models/expense.dart';
import '../services/report_provider.dart';
import '../services/pdf_service.dart';
import '../utils/formatters.dart';
import '../widgets/expense_category_tile.dart';
import '../widgets/expense_form_dialog.dart';
import 'report_form_screen.dart';

class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportProvider>();
    final report = provider.currentReport;

    if (report == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final saldo = report.advance - provider.totalGeral;
    final isDevolver = saldo < 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('${report.employee} · ${report.monthYearLabel}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar cabeçalho',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReportFormScreen(existing: report),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Gerar PDF',
            onPressed: () => _generatePdf(context),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Cabeçalho resumo
          SliverToBoxAdapter(child: _buildSummaryCard(context, provider, saldo, isDevolver)),

          // Categorias de despesas
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'DESPESAS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.5,
                      color: Colors.grey,
                    ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              children: ExpenseCategory.values.map((cat) {
                final expenses = _expensesByCategory(provider, cat);
                final total = expenses.fold(0.0, (s, e) => s + e.amount);
                return ExpenseCategoryTile(
                  category: cat,
                  expenses: expenses,
                  total: total,
                  onAdd: () => _addExpense(context, cat),
                  onEdit: (e) => _editExpense(context, e),
                  onDelete: (e) => provider.removeExpense(e.id!),
                );
              }).toList(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _generatePdf(context),
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text('Gerar PDF'),
      ),
    );
  }

  List<Expense> _expensesByCategory(ReportProvider p, ExpenseCategory cat) {
    return p.currentExpenses.where((e) => e.category == cat).toList();
  }

  Widget _buildSummaryCard(
    BuildContext context,
    ReportProvider provider,
    double saldo,
    bool isDevolver,
  ) {
    final report = provider.currentReport!;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(report.employee,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(report.role,
                          style: TextStyle(color: theme.colorScheme.secondary)),
                    ],
                  ),
                ),
                Chip(
                  label: Text(report.monthYearLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  backgroundColor: theme.colorScheme.primaryContainer,
                  labelStyle:
                      TextStyle(color: theme.colorScheme.onPrimaryContainer),
                ),
              ],
            ),
            const Divider(height: 20),

            // Totais por categoria
            _summaryRow('Combustível', provider.totalCombustivel,
                Colors.orange, Icons.local_gas_station),
            const SizedBox(height: 4),
            _summaryRow(
                'Hotel', provider.totalHotel, Colors.blue, Icons.hotel),
            const SizedBox(height: 4),
            _summaryRow('Outros', provider.totalOutros, Colors.teal,
                Icons.receipt_long),
            const Divider(height: 16),

            // Total geral
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Despesas',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  formatCurrency(provider.totalGeral),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),

            if (report.advance > 0) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDevolver
                      ? Colors.red.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isDevolver ? 'A Devolver' : 'A Receber',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDevolver ? Colors.red : Colors.green,
                      ),
                    ),
                    Text(
                      formatCurrency(saldo.abs()),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDevolver ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),
            Text(
              '${report.obra} · ${report.city} · ${report.period}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
      String label, double value, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13))),
        Text(formatCurrency(value),
            style: TextStyle(
                color: value > 0 ? color : Colors.grey, fontSize: 13)),
      ],
    );
  }

  Future<void> _addExpense(
      BuildContext context, ExpenseCategory category) async {
    final provider = context.read<ReportProvider>();
    final result = await showDialog<Expense>(
      context: context,
      builder: (_) => ExpenseFormDialog(
        reportId: provider.currentReport!.id!,
        initialCategory: category,
      ),
    );
    if (result != null) await provider.addExpense(result);
  }

  Future<void> _editExpense(BuildContext context, Expense expense) async {
    final provider = context.read<ReportProvider>();
    final result = await showDialog<Expense>(
      context: context,
      builder: (_) => ExpenseFormDialog(
        reportId: expense.reportId,
        initialCategory: expense.category,
        existing: expense,
      ),
    );
    if (result != null) await provider.updateExpense(result);
  }

  Future<void> _generatePdf(BuildContext context) async {
    final provider = context.read<ReportProvider>();
    final report = provider.currentReport!;
    final expenses = provider.currentExpenses;

    try {
      final pdfService = PdfService();
      final file = await pdfService.generateRdvPdf(report, expenses);
      if (!context.mounted) return;
      await Printing.sharePdf(
        bytes: await file.readAsBytes(),
        filename:
            'RDV_${report.year}${report.month.toString().padLeft(2, '0')}_${report.employee.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao gerar PDF: $e')),
      );
    }
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
          SliverToBoxAdapter(
            child: _buildSummaryCard(context, provider, saldo, isDevolver),
          ),

          // Despesas
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
                final expenses = provider.currentExpenses
                    .where((e) => e.category == cat)
                    .toList();
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

          // Anexos (fotos)
          SliverToBoxAdapter(
            child: _buildPhotosSection(context, provider),
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

  // ── Resumo financeiro ────────────────────────────────────────────────────

  Widget _buildSummaryCard(BuildContext context, ReportProvider provider,
      double saldo, bool isDevolver) {
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
                          style: TextStyle(
                              color: theme.colorScheme.secondary)),
                    ],
                  ),
                ),
                Chip(
                  label: Text(report.monthYearLabel,
                      style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                  backgroundColor: theme.colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer),
                ),
              ],
            ),
            const Divider(height: 20),
            _summaryRow('Combustível', provider.totalCombustivel,
                Colors.orange, Icons.local_gas_station),
            const SizedBox(height: 4),
            _summaryRow(
                'Hotel', provider.totalHotel, Colors.blue, Icons.hotel),
            const SizedBox(height: 4),
            _summaryRow('Outros', provider.totalOutros, Colors.teal,
                Icons.receipt_long),
            const Divider(height: 16),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isDevolver ? 'A Devolver' : 'A Receber',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color:
                            isDevolver ? Colors.red : Colors.green,
                      ),
                    ),
                    Text(
                      formatCurrency(saldo.abs()),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color:
                            isDevolver ? Colors.red : Colors.green,
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
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Text(formatCurrency(value),
            style: TextStyle(
                color: value > 0 ? color : Colors.grey, fontSize: 13)),
      ],
    );
  }

  // ── Seção de fotos (Anexos) ──────────────────────────────────────────────

  Widget _buildPhotosSection(BuildContext context, ReportProvider provider) {
    final photos = provider.photoPaths;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                'ANEXOS (${photos.length} foto${photos.length != 1 ? 's' : ''})',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.5,
                      color: Colors.grey,
                    ),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.add_a_photo, size: 18),
                label: const Text('Adicionar foto'),
                onPressed: () => _addPhoto(context),
              ),
            ],
          ),
        ),
        if (photos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Nenhuma foto anexada. As fotos capturadas durante o OCR serão listadas aqui e incluídas no PDF.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.85,
              ),
              itemCount: photos.length,
              itemBuilder: (ctx, i) {
                return Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(photos[i]),
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Foto ${i + 1}',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => provider.removePhoto(i),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Ações ────────────────────────────────────────────────────────────────

  Future<void> _addPhoto(BuildContext context) async {
    final provider = context.read<ReportProvider>();
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Câmera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeria'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked != null) provider.addPhoto(picked.path);
  }

  Future<void> _addExpense(
      BuildContext context, ExpenseCategory category) async {
    final provider = context.read<ReportProvider>();
    final result = await showDialog<Expense>(
      context: context,
      builder: (_) => ExpenseFormDialog(
        reportId: provider.currentReport!.id!,
        initialCategory: category,
        onPhotoCaptured: (path) => provider.addPhoto(path),
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
        onPhotoCaptured: (path) => provider.addPhoto(path),
      ),
    );
    if (result != null) await provider.updateExpense(result);
  }

  Future<void> _generatePdf(BuildContext context) async {
    final provider = context.read<ReportProvider>();
    final report = provider.currentReport!;
    final expenses = provider.currentExpenses;
    final photos = provider.photoPaths;

    try {
      final pdfService = PdfService();
      final file = await pdfService.generateRdvPdf(
        report,
        expenses,
        photoPaths: photos,
      );
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

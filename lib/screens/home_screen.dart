import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/rdv_report.dart';
import '../services/report_provider.dart';
import '../utils/formatters.dart';
import 'report_form_screen.dart';
import 'report_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportProvider>().loadReports();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('RDV'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Novo relatório',
            onPressed: () => _openNewReport(context),
          ),
        ],
      ),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator())
          : provider.reports.isEmpty
              ? _buildEmpty(context)
              : _buildList(context, provider.reports),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNewReport(context),
        icon: const Icon(Icons.add),
        label: const Text('Novo RDV'),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Nenhum relatório ainda.',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Toque em "+ Novo RDV" para começar.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, List<RdvReport> reports) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final r = reports[i];
        return _ReportCard(
          report: r,
          onTap: () => _openReport(context, r),
          onDelete: () => _confirmDelete(context, r),
        );
      },
    );
  }

  Future<void> _openNewReport(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ReportFormScreen()),
    );
    if (mounted) context.read<ReportProvider>().loadReports();
  }

  Future<void> _openReport(BuildContext context, RdvReport report) async {
    await context.read<ReportProvider>().selectReport(report.id!);
    if (mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ReportDetailScreen()),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, RdvReport report) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir RDV?'),
        content: Text(
            'Isso irá excluir o relatório de ${report.employee} (${report.monthYearLabel}) e todas as despesas.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Excluir',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<ReportProvider>().deleteReport(report.id!);
    }
  }
}

class _ReportCard extends StatelessWidget {
  final RdvReport report;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ReportCard({
    required this.report,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.description_outlined,
                    color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.employee,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${report.city} · ${report.monthYearLabel}',
                      style: TextStyle(
                          color: theme.colorScheme.secondary, fontSize: 13),
                    ),
                    Text(
                      report.period,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: onDelete,
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

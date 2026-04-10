import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../utils/formatters.dart';

class ExpenseCategoryTile extends StatelessWidget {
  final ExpenseCategory category;
  final List<Expense> expenses;
  final double total;
  final VoidCallback onAdd;
  final void Function(Expense) onEdit;
  final void Function(Expense) onDelete;

  const ExpenseCategoryTile({
    super.key,
    required this.category,
    required this.expenses,
    required this.total,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  Color get _categoryColor {
    switch (category) {
      case ExpenseCategory.combustivel:
        return Colors.orange;
      case ExpenseCategory.hotel:
        return Colors.blue;
      case ExpenseCategory.outros:
        return Colors.teal;
    }
  }

  IconData get _categoryIcon {
    switch (category) {
      case ExpenseCategory.combustivel:
        return Icons.local_gas_station;
      case ExpenseCategory.hotel:
        return Icons.hotel;
      case ExpenseCategory.outros:
        return Icons.receipt_long;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: _categoryColor.withOpacity(0.15),
            child: Icon(_categoryIcon, color: _categoryColor, size: 20),
          ),
          title: Text(
            category.label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${expenses.length} item${expenses.length != 1 ? 's' : ''} · ${formatCurrency(total)}',
            style: TextStyle(
              color: total > 0 ? _categoryColor : Colors.grey,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: _categoryColor,
                tooltip: 'Adicionar despesa',
                onPressed: onAdd,
              ),
              const Icon(Icons.expand_more),
            ],
          ),
          children: [
            if (expenses.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Text(
                  'Nenhuma despesa registrada.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ...expenses.map((e) => _buildExpenseItem(context, e)),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseItem(BuildContext context, Expense expense) {
    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Remover despesa?'),
            content: Text(
                'Remover "${expense.establishment}" de ${formatCurrency(expense.amount)}?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Remover',
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(expense),
      child: ListTile(
        dense: true,
        onTap: () => onEdit(expense),
        leading: Text(
          formatShortDate(expense.date),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        title: Text(expense.establishment,
            style: const TextStyle(fontSize: 14)),
        subtitle: Text(
          '${expense.city}/${expense.uf}${expense.km != null ? ' · ${expense.km} km' : ''}${expense.observations != null ? ' · ${expense.observations}' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          formatCurrency(expense.amount),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

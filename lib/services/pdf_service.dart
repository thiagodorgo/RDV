import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/expense.dart';
import '../models/rdv_report.dart';

class PdfService {
  static final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _shortDate = DateFormat('dd-MMM', 'pt_BR');

  // Cores do modelo
  static const _headerGray = PdfColor.fromInt(0xFF808080);
  static const _lightGray = PdfColor.fromInt(0xFFD9D9D9);
  static const _darkGray = PdfColor.fromInt(0xFF595959);
  static const _yellowHighlight = PdfColor.fromInt(0xFFFFFF00);
  static const _darkRed = PdfColor.fromInt(0xFF8B0000);
  static const _white = PdfColors.white;
  static const _black = PdfColors.black;
  static const _blue = PdfColor.fromInt(0xFF1F497D);

  Future<File> generateRdvPdf(RdvReport report, List<Expense> expenses) async {
    final pdf = pw.Document();

    final combustivel = expenses.where((e) => e.category == ExpenseCategory.combustivel).toList();
    final hotel = expenses.where((e) => e.category == ExpenseCategory.hotel).toList();
    final outros = expenses.where((e) => e.category == ExpenseCategory.outros).toList();

    final totalCombustivel = combustivel.fold(0.0, (s, e) => s + e.amount);
    final totalHotel = hotel.fold(0.0, (s, e) => s + e.amount);
    final totalOutros = outros.fold(0.0, (s, e) => s + e.amount);
    final totalGeral = totalCombustivel + totalHotel + totalOutros;
    final saldo = report.advance - totalGeral;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildHeader(report),
            pw.SizedBox(height: 8),
            _buildEmployeeRow(report),
            pw.SizedBox(height: 6),
            _buildOriginAndObra(report),
            pw.SizedBox(height: 10),
            _buildSectionTitle('DETALHES DIÁRIOS DAS DESPESAS'),
            pw.SizedBox(height: 6),
            _buildCategoryTable(
              'COMBUSTÍVEL',
              combustivel,
              totalCombustivel,
              hasKm: true,
            ),
            pw.SizedBox(height: 6),
            _buildCategoryTable(
              'HOTEL',
              hotel,
              totalHotel,
              hasObservations: true,
            ),
            pw.SizedBox(height: 6),
            _buildCategoryTable(
              'OUTROS',
              outros,
              totalOutros,
              hasObservations: true,
            ),
            pw.SizedBox(height: 8),
            _buildReimbursementSection(report, totalGeral, saldo),
            pw.SizedBox(height: 8),
            _buildMotivoSection(),
            pw.SizedBox(height: 8),
            _buildSignatureRow(report),
          ],
        ),
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final filename = 'RDV_${report.year}${report.month.toString().padLeft(2, '0')}_${report.employee.replaceAll(' ', '_')}.pdf';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  pw.Widget _buildHeader(RdvReport report) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Logo AMP placeholder
        pw.Container(
          width: 80,
          height: 36,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _headerGray),
          ),
          child: pw.Center(
            child: pw.Text(
              'LOGO',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 14,
                color: _headerGray,
              ),
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Center(
            child: pw.Text(
              'RDV - Relatório de Despesas de Viagens',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(4),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _headerGray),
          ),
          child: pw.Column(
            children: [
              pw.Text('Mês/Ano',
                  style: pw.TextStyle(fontSize: 7, color: _headerGray)),
              pw.Text(
                report.monthYearLabel,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: _blue,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildEmployeeRow(RdvReport report) {
    return pw.Row(
      children: [
        _labelCell('Funcionário', pw.Expanded(
          flex: 3,
          child: _valueCell(report.employee, color: _blue),
        )),
        pw.SizedBox(width: 4),
        _labelCell('Cargo', pw.Expanded(
          child: _valueCell(report.role),
        )),
        pw.SizedBox(width: 4),
        _labelCell('Centro de Custos', pw.Expanded(
          child: _valueCell(''),
        )),
      ],
    );
  }

  pw.Widget _labelCell(String label, pw.Widget child) {
    return pw.Expanded(
      child: pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _lightGray)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: pw.Text(label,
                  style: pw.TextStyle(fontSize: 7, color: _headerGray)),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: pw.Text(
                label == 'Funcionário'
                    ? ''
                    : label == 'Cargo'
                        ? ''
                        : '',
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _valueCell(String value, {PdfColor? color}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _lightGray),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: color ?? _black,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildEmployeeBlock(RdvReport report) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 3,
          child: pw.Container(
            decoration:
                pw.BoxDecoration(border: pw.Border.all(color: _lightGray)),
            padding: const pw.EdgeInsets.all(4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Funcionário',
                    style: pw.TextStyle(fontSize: 7, color: _headerGray)),
                pw.Text(
                  report.employee,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _blue,
                  ),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Expanded(
          child: pw.Container(
            decoration:
                pw.BoxDecoration(border: pw.Border.all(color: _lightGray)),
            padding: const pw.EdgeInsets.all(4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Cargo',
                    style: pw.TextStyle(fontSize: 7, color: _headerGray)),
                pw.Text(report.role,
                    style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Expanded(
          child: pw.Container(
            decoration:
                pw.BoxDecoration(border: pw.Border.all(color: _lightGray)),
            padding: const pw.EdgeInsets.all(4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Centro de Custos',
                    style: pw.TextStyle(fontSize: 7, color: _headerGray)),
                pw.Text('', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildOriginAndObra(RdvReport report) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Origem
        pw.Container(
          width: 180,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _lightGray),
          ),
          padding: const pw.EdgeInsets.all(6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Origem da Despesa',
                  style: pw.TextStyle(fontSize: 7, color: _headerGray)),
              pw.SizedBox(height: 4),
              _radioRow('ENGENHARIA',
                  report.origin == ExpenseOrigin.engenharia),
              _radioRow('SUPERVISÃO OBRAS',
                  report.origin == ExpenseOrigin.supervisaoObras),
              _radioRow('COMERCIAL',
                  report.origin == ExpenseOrigin.comercial),
              _radioRow('ADMINISTRATIVO',
                  report.origin == ExpenseOrigin.administrativo),
            ],
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Column(
            children: [
              pw.Container(
                decoration:
                    pw.BoxDecoration(border: pw.Border.all(color: _lightGray)),
                padding: const pw.EdgeInsets.all(4),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Obra',
                              style:
                                  pw.TextStyle(fontSize: 7, color: _headerGray)),
                          pw.Text(
                            report.obra,
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: _blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Nº do Pedido',
                            style:
                                pw.TextStyle(fontSize: 7, color: _headerGray)),
                        pw.Text(report.orderNumber,
                            style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _radioRow(String label, bool selected) {
    return pw.Row(
      children: [
        pw.Container(
          width: 8,
          height: 8,
          decoration: pw.BoxDecoration(
            shape: pw.BoxShape.circle,
            border: pw.Border.all(color: _darkGray),
            color: selected ? _darkGray : _white,
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      color: _lightGray,
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildCategoryTable(
    String category,
    List<Expense> expenses,
    double total, {
    bool hasKm = false,
    bool hasObservations = false,
  }) {
    final lastCol = hasKm ? 'Registrar KM' : 'Observações';
    return pw.Column(
      children: [
        // Cabeçalho da categoria
        pw.Container(
          color: _lightGray,
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    category,
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 9),
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  'Total ${_titleCase(category)}:',
                  style: pw.TextStyle(fontSize: 9),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                child: pw.Text(
                  _currency.format(total),
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 9),
                ),
              ),
            ],
          ),
        ),
        // Linha de colunas
        pw.Container(
          color: _lightGray,
          child: pw.Row(
            children: [
              _colHeader('Data', flex: 1),
              _colHeader('Detalhes (Nome do Estabelecimento)', flex: 4),
              _colHeader('Cidade', flex: 2),
              _colHeader('UF', flex: 1),
              _colHeader('R\$', flex: 1),
              _colHeader(lastCol, flex: 2),
            ],
          ),
        ),
        // Linhas de despesas
        ...expenses.map((e) => _expenseRow(e, hasKm)),
        // Linhas vazias se não há despesas
        if (expenses.isEmpty) _emptyRow(hasKm),
      ],
    );
  }

  pw.Widget _colHeader(String text, {int flex = 1}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _lightGray, width: 0.5),
        ),
        child: pw.Text(
          text,
          style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: _darkGray),
        ),
      ),
    );
  }

  pw.Widget _expenseRow(Expense expense, bool hasKm) {
    return pw.Row(
      children: [
        _cell(_shortDate.format(expense.date), flex: 1),
        _cell(expense.establishment, flex: 4),
        _cell(expense.city, flex: 2),
        _cell(expense.uf.toUpperCase(), flex: 1),
        _cell(
          NumberFormat('#,##0.00', 'pt_BR').format(expense.amount),
          flex: 1,
        ),
        _cell(hasKm ? (expense.km ?? '') : (expense.observations ?? ''),
            flex: 2),
      ],
    );
  }

  pw.Widget _emptyRow(bool hasKm) {
    return pw.Row(
      children: [
        _cell('', flex: 1),
        _cell('', flex: 4),
        _cell('', flex: 2),
        _cell('', flex: 1),
        _cell('', flex: 1),
        _cell('', flex: 2),
      ],
    );
  }

  pw.Widget _cell(String text, {int flex = 1}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _lightGray, width: 0.3),
        ),
        child: pw.Text(text, style: const pw.TextStyle(fontSize: 8)),
      ),
    );
  }

  pw.Widget _buildReimbursementSection(
      RdvReport report, double totalGeral, double saldo) {
    final isDevolver = saldo < 0;
    final isReceber = saldo > 0;

    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _lightGray)),
      child: pw.Column(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            color: _lightGray,
            child: pw.Row(
              children: [
                pw.Text('REEMBOLSO',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 9)),
              ],
            ),
          ),
          // Adiantamento
          pw.Container(
            color: _yellowHighlight,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'Adiantamento (saldo)${report.advance > 0 ? ': ${_currency.format(report.advance)}' : ''}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          // Total Despesas
          pw.Container(
            color: _lightGray,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total Despesas',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.Text(
                  _currency.format(totalGeral),
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 9),
                ),
              ],
            ),
          ),
          // A receber / A devolver
          pw.Padding(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: pw.Row(
              children: [
                _radioRow('A RECEBER', isReceber),
                pw.SizedBox(width: 16),
                _radioRow('A DEVOLVER', isDevolver),
                pw.Spacer(),
                pw.Text(
                  _currency.format(saldo.abs()),
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                    color:
                        isDevolver ? PdfColors.red : PdfColors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildMotivoSection() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _darkRed),
        color: PdfColor.fromInt(0xFFF2DCDB),
      ),
      child: pw.Text(
        'Motivo da viagem (Preenchimento OBRIGATÓRIO)',
        style: pw.TextStyle(
          color: _darkRed,
          fontWeight: pw.FontWeight.bold,
          fontSize: 9,
        ),
      ),
    );
  }

  pw.Widget _buildSignatureRow(RdvReport report) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Container(
            decoration:
                pw.BoxDecoration(border: pw.Border.all(color: _lightGray)),
            padding: const pw.EdgeInsets.all(6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Funcionário/Emitente:',
                    style: pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 4),
                pw.Text(report.employee,
                    style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 4),
                pw.Text(
                  _dateFormat.format(DateTime.now()),
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Expanded(
          child: pw.Container(
            decoration:
                pw.BoxDecoration(border: pw.Border.all(color: _lightGray)),
            padding: const pw.EdgeInsets.all(6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Diretoria/Gerência:',
                    style: pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 14),
                pw.Text('___/____/___',
                    style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Expanded(
          child: pw.Container(
            decoration:
                pw.BoxDecoration(border: pw.Border.all(color: _lightGray)),
            padding: const pw.EdgeInsets.all(6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Financeiro:',
                    style: pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 14),
                pw.Text('___/___/___',
                    style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _titleCase(String text) {
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}

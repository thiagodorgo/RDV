import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/expense.dart';
import '../models/rdv_report.dart';


class PdfService {
  static final _currency =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final _dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final _shortDate = DateFormat('dd-MMM', 'pt_BR');

  // Cores do modelo RDV
  static const _lightGray = PdfColor.fromInt(0xFFD9D9D9);
  static const _darkGray = PdfColor.fromInt(0xFF595959);
  static const _headerGray = PdfColor.fromInt(0xFF808080);
  static const _yellowHighlight = PdfColor.fromInt(0xFFFFFF00);
  static const _darkRed = PdfColor.fromInt(0xFF8B0000);
  static const _redBg = PdfColor.fromInt(0xFFF2DCDB);
  static const _blue = PdfColor.fromInt(0xFF1F497D);
  static const _white = PdfColors.white;
  static const _black = PdfColors.black;

  Future<File> generateRdvPdf(
    RdvReport report,
    List<Expense> expenses, {
    List<String> photoPaths = const [],
  }) async {
    // Usa fonte padrão do pacote pdf (Helvetica) — sem dependência externa
    final pdf = pw.Document();

    // Carregar logo da AMP dos assets
    final logoBytes = await rootBundle.load('assets/logo_amp.jpg');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    // Carregar imagens dos anexos — só inclui arquivos que existem
    final List<pw.MemoryImage> photoImages = [];
    for (final path in photoPaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          photoImages.add(pw.MemoryImage(bytes));
        }
      } catch (_) {}
    }

    final combustivel = expenses
        .where((e) => e.category == ExpenseCategory.combustivel)
        .toList();
    final hotel =
        expenses.where((e) => e.category == ExpenseCategory.hotel).toList();
    final outros =
        expenses.where((e) => e.category == ExpenseCategory.outros).toList();

    final totalCombustivel =
        combustivel.fold(0.0, (s, e) => s + e.amount);
    final totalHotel = hotel.fold(0.0, (s, e) => s + e.amount);
    final totalOutros = outros.fold(0.0, (s, e) => s + e.amount);
    final totalGeral = totalCombustivel + totalHotel + totalOutros;
    final saldo = report.advance - totalGeral;

    // ── Página principal ────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildHeader(report, logoImage),
            pw.SizedBox(height: 6),
            _buildEmployeeBlock(report),
            pw.SizedBox(height: 6),
            _buildOriginAndObra(report),
            pw.SizedBox(height: 10),
            _buildSectionTitle('DETALHES DIÁRIOS DAS DESPESAS'),
            pw.SizedBox(height: 6),
            _buildCategoryTable('COMBUSTÍVEL', combustivel,
                totalCombustivel, hasKm: true),
            pw.SizedBox(height: 6),
            _buildCategoryTable('HOTEL', hotel, totalHotel,
                hasObservations: true),
            pw.SizedBox(height: 6),
            _buildCategoryTable('OUTROS', outros, totalOutros,
                hasObservations: true),
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

    // ── Página de Anexos (fotos) ─────────────────────────────────────────────
    if (photoImages.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            pw.Text(
              'Anexos',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: _blue,
              ),
            ),
            pw.Divider(color: _lightGray),
            pw.SizedBox(height: 8),
            _buildPhotoGrid(photoImages),
          ],
        ),
      );
    }

    // ── Salvar em local gravável no Android ──────────────────────────────────
    final dir = await getTemporaryDirectory(); // /data/user/0/.../cache — sempre existe
    final filename =
        'RDV_${report.year}${report.month.toString().padLeft(2, '0')}_${report.employee.replaceAll(' ', '_')}.pdf';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // ── Grid de fotos (3 por linha) ──────────────────────────────────────────

  pw.Widget _buildPhotoGrid(List<pw.MemoryImage> images) {
    const photosPerRow = 3;
    final rows = <pw.Widget>[];
    for (var i = 0; i < images.length; i += photosPerRow) {
      final rowImages = images.sublist(
          i, i + photosPerRow > images.length ? images.length : i + photosPerRow);
      // Preenche com espaços vazios para alinhar
      final cells = <pw.Widget>[];
      for (var j = 0; j < rowImages.length; j++) {
        final index = i + j + 1;
        cells.add(
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Column(
                children: [
                  pw.Container(
                    height: 160,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: _lightGray),
                    ),
                    child: pw.Image(rowImages[j], fit: pw.BoxFit.contain),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Foto $index',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: _darkGray,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }
      // Preenche colunas vazias restantes
      for (var k = rowImages.length; k < photosPerRow; k++) {
        cells.add(pw.Expanded(child: pw.SizedBox()));
      }
      rows.add(pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: cells,
      ));
      rows.add(pw.SizedBox(height: 8));
    }
    return pw.Column(children: rows);
  }

  // ── Cabeçalho com logo AMP ───────────────────────────────────────────────

  pw.Widget _buildHeader(RdvReport report, pw.MemoryImage logo) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Image(logo, width: 90, height: 40, fit: pw.BoxFit.contain),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Center(
            child: pw.Text(
              'RDV - Relatório de Despesas de Viagens',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration:
              pw.BoxDecoration(border: pw.Border.all(color: _lightGray)),
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

  // ── Bloco funcionário / cargo / centro de custos ─────────────────────────

  pw.Widget _buildEmployeeBlock(RdvReport report) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _infoBox('Funcionário', report.employee, flex: 3,
            valueColor: _blue, bold: true),
        pw.SizedBox(width: 4),
        _infoBox('Cargo', report.role, flex: 2),
        pw.SizedBox(width: 4),
        _infoBox('Centro de Custos', '', flex: 2),
      ],
    );
  }

  // ── Origem da Despesa + Obra ─────────────────────────────────────────────

  pw.Widget _buildOriginAndObra(RdvReport report) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 160,
          decoration:
              pw.BoxDecoration(border: pw.Border.all(color: _lightGray)),
          padding: const pw.EdgeInsets.all(6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Origem da Despesa',
                  style: pw.TextStyle(fontSize: 7, color: _headerGray)),
              pw.SizedBox(height: 4),
              _radioRow('ENGENHARIA',
                  report.origin == ExpenseOrigin.engenharia),
              pw.SizedBox(height: 2),
              _radioRow('SUPERVISÃO OBRAS',
                  report.origin == ExpenseOrigin.supervisaoObras),
              pw.SizedBox(height: 2),
              _radioRow('COMERCIAL',
                  report.origin == ExpenseOrigin.comercial),
              pw.SizedBox(height: 2),
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
                width: double.infinity,
                decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _lightGray)),
                padding: const pw.EdgeInsets.all(6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Obra / Cliente',
                        style: pw.TextStyle(fontSize: 7, color: _headerGray)),
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
              pw.SizedBox(height: 4),
              pw.Row(
                children: [
                  pw.Expanded(
                      child: _infoBox('Cidade', report.city)),
                  pw.SizedBox(width: 4),
                  pw.Expanded(
                      child: _infoBox('Período', report.period)),
                  pw.SizedBox(width: 4),
                  pw.Expanded(
                      child: _infoBox('Nº do Pedido', report.orderNumber)),
                ],
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
            border: pw.Border.all(color: _darkGray, width: 0.8),
            color: selected ? _darkGray : _white,
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  pw.Widget _infoBox(
    String label,
    String value, {
    int flex = 1,
    PdfColor? valueColor,
    bool bold = false,
  }) {
    return pw.Container(
      decoration:
          pw.BoxDecoration(border: pw.Border.all(color: _lightGray)),
      padding: const pw.EdgeInsets.all(4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(fontSize: 7, color: _headerGray)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: valueColor ?? _black,
            ),
          ),
        ],
      ),
    );
  }

  // ── Título de seção ──────────────────────────────────────────────────────

  pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      color: _lightGray,
      padding:
          const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
      child: pw.Text(
        title,
        style:
            pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // ── Tabela de categoria ──────────────────────────────────────────────────

  pw.Widget _buildCategoryTable(
    String category,
    List<Expense> expenses,
    double total, {
    bool hasKm = false,
    bool hasObservations = false,
  }) {
    final lastColLabel = hasKm ? 'Registrar KM' : 'Observações';
    return pw.Column(
      children: [
        // Barra da categoria com total
        pw.Container(
          color: _lightGray,
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: pw.Row(
            children: [
              pw.Text(category,
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 9)),
              pw.Spacer(),
              pw.Text('Total: ',
                  style: const pw.TextStyle(fontSize: 8)),
              pw.Text(
                _currency.format(total),
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 9),
              ),
            ],
          ),
        ),
        // Cabeçalho das colunas
        pw.Row(
          children: [
            _colHeader('Data', flex: 1),
            _colHeader('Detalhes (Estabelecimento)', flex: 4),
            _colHeader('Cidade', flex: 2),
            _colHeader('UF', flex: 1),
            _colHeader('R\$', flex: 1),
            _colHeader(lastColLabel, flex: 2),
          ],
        ),
        // Linhas de despesas (mínimo 3 linhas)
        ...expenses.map((e) => _expenseRow(e, hasKm)),
        ...List.generate(
          expenses.length < 3 ? 3 - expenses.length : 0,
          (_) => _emptyRow(),
        ),
      ],
    );
  }

  pw.Widget _colHeader(String text, {int flex = 1}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Container(
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        decoration: pw.BoxDecoration(
          color: _lightGray,
          border: pw.Border.all(color: _white, width: 0.5),
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
        _cell(
          hasKm
              ? (expense.km ?? '')
              : (expense.observations ?? ''),
          flex: 2,
        ),
      ],
    );
  }

  pw.Widget _emptyRow() {
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
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _lightGray, width: 0.3),
        ),
        child: pw.Text(text, style: const pw.TextStyle(fontSize: 8)),
      ),
    );
  }

  // ── Reembolso ────────────────────────────────────────────────────────────

  pw.Widget _buildReimbursementSection(
      RdvReport report, double totalGeral, double saldo) {
    final isDevolver = saldo < 0;
    return pw.Container(
      decoration:
          pw.BoxDecoration(border: pw.Border.all(color: _lightGray)),
      child: pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            color: _lightGray,
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 6, vertical: 3),
            child: pw.Text('REEMBOLSO',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 9)),
          ),
          // Adiantamento (destaque amarelo)
          pw.Container(
            width: double.infinity,
            color: _yellowHighlight,
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 8, vertical: 5),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Adiantamento (saldo)',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.Text(
                  report.advance > 0
                      ? _currency.format(report.advance)
                      : '-',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 9),
                ),
              ],
            ),
          ),
          // Total despesas
          pw.Container(
            color: _lightGray,
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total Despesas',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.Text(_currency.format(totalGeral),
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 9)),
              ],
            ),
          ),
          // A receber / A devolver
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 8, vertical: 5),
            child: pw.Row(
              children: [
                _radioRow('A RECEBER', !isDevolver),
                pw.SizedBox(width: 16),
                _radioRow('A DEVOLVER', isDevolver),
                pw.Spacer(),
                pw.Text(
                  _currency.format(saldo.abs()),
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                    color: isDevolver
                        ? PdfColors.red
                        : PdfColors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Motivo da viagem ─────────────────────────────────────────────────────

  pw.Widget _buildMotivoSection() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _darkRed),
        color: _redBg,
      ),
      child: pw.Text(
        'Motivo da viagem (Preenchimento OBRIGATÓRIO)\n\n\n',
        style: pw.TextStyle(
          color: _darkRed,
          fontWeight: pw.FontWeight.bold,
          fontSize: 9,
        ),
      ),
    );
  }

  // ── Assinaturas ──────────────────────────────────────────────────────────

  pw.Widget _buildSignatureRow(RdvReport report) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Container(
            decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _lightGray)),
            padding: const pw.EdgeInsets.all(6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Funcionário / Emitente:',
                    style: pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 4),
                pw.Text(report.employee,
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(_dateFormat.format(DateTime.now()),
                    style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Expanded(
          child: pw.Container(
            decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _lightGray)),
            padding: const pw.EdgeInsets.all(6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Diretoria / Gerência:',
                    style: pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 16),
                pw.Text('___/___/______',
                    style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Expanded(
          child: pw.Container(
            decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _lightGray)),
            padding: const pw.EdgeInsets.all(6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Financeiro:',
                    style: pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 16),
                pw.Text('___/___/______',
                    style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

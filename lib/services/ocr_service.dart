import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  final String? establishment;
  final DateTime? date;
  final double? amount;
  final String? city;
  final String? uf;
  final ExpenseCategoryHint categoryHint;
  final String rawText;

  OcrResult({
    this.establishment,
    this.date,
    this.amount,
    this.city,
    this.uf,
    required this.categoryHint,
    required this.rawText,
  });
}

enum ExpenseCategoryHint { combustivel, hotel, outros }

class OcrService {
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<OcrResult> recognizeReceipt(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognized = await _textRecognizer.processImage(inputImage);
    final raw = recognized.text;
    final lower = raw.toLowerCase();

    return OcrResult(
      establishment: _extractEstablishment(raw),
      date: _extractDate(raw),
      amount: _extractAmount(raw),
      city: _extractCity(raw)?.item1,
      uf: _extractCity(raw)?.item2,
      categoryHint: _inferCategory(lower),
      rawText: raw,
    );
  }

  // ── Categoria inteligente ────────────────────────────────────────────────

  ExpenseCategoryHint _inferCategory(String lower) {
    // Combustível
    if (_matchesAny(lower, [
      'posto', 'combustivel', 'combustível', 'gasolina', 'etanol', 'diesel',
      'abastec', 'shell', 'petrobras', 'ipiranga', 'ale ', 'br distribuidora',
      'raizen', 'litro', 'litros', 'l de ', 'bomba', 'tanque',
    ])) return ExpenseCategoryHint.combustivel;

    // Hotel / hospedagem
    if (_matchesAny(lower, [
      'hotel', 'pousada', 'hostel', 'hospedagem', 'diaria', 'diária',
      'check-in', 'check in', 'checkout', 'check out', 'suite', 'quarto',
      'pernoite', 'acomodacao', 'acomodação', 'inn', 'resort', 'flat',
    ])) return ExpenseCategoryHint.hotel;

    // Outros (alimentação, transporte, pedágio, etc.) → categoria "Outros"
    return ExpenseCategoryHint.outros;
  }

  bool _matchesAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }

  // ── Estabelecimento ──────────────────────────────────────────────────────

  String? _extractEstablishment(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // Descarta linhas que parecem ser endereço, CNPJ ou data
    for (final line in lines) {
      if (line.length < 4 || line.length > 60) continue;
      if (RegExp(r'\d{2}/\d{2}').hasMatch(line)) continue;  // data
      if (RegExp(r'\d{2}\.\d{3}\.\d{3}').hasMatch(line)) continue; // CNPJ
      if (RegExp(r'^(rua|av\.|avenida|r\.)', caseSensitive: false)
          .hasMatch(line)) continue; // endereço
      return line;
    }
    return lines.isNotEmpty ? lines.first : null;
  }

  // ── Data ─────────────────────────────────────────────────────────────────

  DateTime? _extractDate(String text) {
    final patterns = [
      RegExp(r'(\d{2})[\/\-\.](\d{2})[\/\-\.](\d{4})'),
      RegExp(r'(\d{2})[\/\-\.](\d{2})[\/\-\.](\d{2})\b'),
    ];
    for (final pattern in patterns) {
      for (final match in pattern.allMatches(text)) {
        try {
          final day = int.parse(match.group(1)!);
          final month = int.parse(match.group(2)!);
          int year = int.parse(match.group(3)!);
          if (year < 100) year += 2000;
          if (day >= 1 && day <= 31 && month >= 1 && month <= 12) {
            return DateTime(year, month, day);
          }
        } catch (_) {}
      }
    }
    return null;
  }

  // ── Valor ────────────────────────────────────────────────────────────────

  double? _extractAmount(String text) {
    // Busca todos os valores monetários e retorna o maior (total da nota)
    final pattern = RegExp(
      r'(?:R\$\s*|TOTAL[:\s]+)(\d{1,3}(?:[.,]\d{3})*[.,]\d{2})',
      caseSensitive: false,
    );
    final fallback = RegExp(r'(\d{1,3}(?:\.\d{3})*,\d{2})');

    double? maxAmount;

    void tryParse(String raw) {
      final clean = raw.trim().replaceAll('.', '').replaceAll(',', '.');
      final value = double.tryParse(clean);
      if (value != null && value > 0) {
        if (maxAmount == null || value > maxAmount!) maxAmount = value;
      }
    }

    for (final m in pattern.allMatches(text)) {
      tryParse(m.group(1) ?? '');
    }
    if (maxAmount == null) {
      for (final m in fallback.allMatches(text)) {
        tryParse(m.group(1) ?? '');
      }
    }
    return maxAmount;
  }

  // ── Cidade / UF ──────────────────────────────────────────────────────────

  _CityUf? _extractCity(String text) {
    const ufs = [
      'AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS',
      'MG','PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC',
      'SP','SE','TO',
    ];
    for (final uf in ufs) {
      // "Cidade - UF" ou "Cidade/UF" ou "Cidade UF"
      final pattern = RegExp(
        r'([A-ZÀÁÂÃÉÊÍÓÔÕÚÇ][a-záàâãéêíóôõúç]+'
        r'(?:\s[A-ZÀÁÂÃÉÊÍÓÔÕÚÇ][a-záàâãéêíóôõúç]+)*)'
        r'\s*[-\/]\s*' +
            uf,
      );
      final match = pattern.firstMatch(text);
      if (match != null) {
        return _CityUf(match.group(1)!.trim(), uf);
      }
    }
    return null;
  }

  void dispose() => _textRecognizer.close();
}

class _CityUf {
  final String item1;
  final String item2;
  _CityUf(this.item1, this.item2);
}

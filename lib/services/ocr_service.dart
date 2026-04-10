import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';

class OcrResult {
  final String? establishment;
  final DateTime? date;
  final double? amount;
  final String? city;
  final String rawText;

  OcrResult({
    this.establishment,
    this.date,
    this.amount,
    this.city,
    required this.rawText,
  });
}

class OcrService {
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<OcrResult> recognizeReceipt(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    final rawText = recognizedText.text;

    return OcrResult(
      establishment: _extractEstablishment(rawText),
      date: _extractDate(rawText),
      amount: _extractAmount(rawText),
      city: _extractCity(rawText),
      rawText: rawText,
    );
  }

  String? _extractEstablishment(String text) {
    // Primeira linha não vazia costuma ser o nome do estabelecimento
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isNotEmpty) {
      final first = lines.first.trim();
      if (first.length > 3 && first.length < 60) return first;
    }
    return null;
  }

  DateTime? _extractDate(String text) {
    // Padrões: dd/mm/yyyy, dd-mm-yyyy, dd.mm.yyyy
    final patterns = [
      RegExp(r'(\d{2})[\/\-\.](\d{2})[\/\-\.](\d{4})'),
      RegExp(r'(\d{2})[\/\-\.](\d{2})[\/\-\.](\d{2})\b'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
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

  double? _extractAmount(String text) {
    // Busca o maior valor monetário (R$) no texto
    final pattern = RegExp(
      r'R\$\s*(\d{1,3}(?:\.\d{3})*(?:,\d{2})?)|(\d{1,3}(?:\.\d{3})*,\d{2})',
    );
    double? maxAmount;
    for (final match in pattern.allMatches(text)) {
      final raw = (match.group(1) ?? match.group(2) ?? '')
          .replaceAll('.', '')
          .replaceAll(',', '.');
      final value = double.tryParse(raw);
      if (value != null && value > 0) {
        if (maxAmount == null || value > maxAmount) {
          maxAmount = value;
        }
      }
    }
    return maxAmount;
  }

  String? _extractCity(String text) {
    // Lista de UFs para encontrar "CIDADE - UF" ou "CIDADE/UF"
    final ufs = ['AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS',
                  'MG','PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC',
                  'SP','SE','TO'];
    for (final uf in ufs) {
      final pattern = RegExp(r'([A-ZÀ-Ü][a-zà-ü]+(?:\s[A-ZÀ-Ü][a-zà-ü]+)*)\s*[-\/]\s*' + uf);
      final match = pattern.firstMatch(text);
      if (match != null) return match.group(1)?.trim();
    }
    return null;
  }

  void dispose() {
    _textRecognizer.close();
  }
}

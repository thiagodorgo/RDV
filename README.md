# RDV – Relatório de Despesas de Viagens

App Flutter para geração de relatórios de despesas de viagem, fiel ao modelo RDV corporativo.

---

## Funcionalidades

- **Cabeçalho completo**: Funcionário, Cargo, Origem da Despesa (Engenharia / Supervisão Obras / Comercial / Administrativo), Obra, Nº do Pedido, Cidade, Período, Mês/Ano
- **Três categorias de despesas**:
  - Combustível (com campo de KM)
  - Hotel (com observações)
  - Outros (alimentação, transporte, etc.)
- **OCR offline** com Google ML Kit: aponta a câmera para um recibo/nota fiscal e os campos são preenchidos automaticamente (data, estabelecimento, valor, cidade)
- **Totais automáticos** por categoria e total geral
- **Cálculo de reembolso**: A Receber ou A Devolver com base no adiantamento
- **Geração de PDF** fiel ao modelo RDV (compartilhamento via WhatsApp, e-mail, impressão)
- **Persistência local** com SQLite (funciona offline)
- **Suporte a múltiplos relatórios**

---

## Pré-requisitos

- Flutter SDK `>=3.0.0`
- Android SDK (API 21+) ou Xcode (iOS 12+)

---

## Instalação

```bash
git clone https://github.com/thiagodorgo/RDV.git
cd RDV
flutter pub get
flutter run
```

---

## Estrutura do projeto

```
lib/
├── main.dart                          # Entry point, tema, Provider
├── models/
│   ├── expense.dart                   # Modelo de despesa + categorias
│   └── rdv_report.dart                # Modelo do relatório (cabeçalho)
├── services/
│   ├── database_service.dart          # SQLite (sqflite)
│   ├── ocr_service.dart               # Google ML Kit Text Recognition
│   ├── pdf_service.dart               # Geração do PDF fiel ao modelo
│   └── report_provider.dart           # ChangeNotifier (estado global)
├── screens/
│   ├── home_screen.dart               # Lista de relatórios
│   ├── report_form_screen.dart        # Formulário de cabeçalho
│   └── report_detail_screen.dart      # Despesas + gerar PDF
├── widgets/
│   ├── expense_category_tile.dart     # Card expansível por categoria
│   └── expense_form_dialog.dart       # Modal de inserção/edição + OCR
└── utils/
    └── formatters.dart                # Formatadores de data e moeda
```

---

## Dependências principais

| Pacote | Finalidade |
|--------|-----------|
| `provider` | Gerenciamento de estado |
| `sqflite` | Banco de dados local SQLite |
| `google_mlkit_text_recognition` | OCR offline (Google ML Kit) |
| `image_picker` | Câmera e galeria |
| `pdf` | Geração do PDF |
| `printing` | Compartilhamento e impressão do PDF |
| `intl` | Formatação de datas e moeda (pt_BR) |
| `permission_handler` | Permissões de câmera/storage |

---

## Fluxo de uso

1. Abra o app → toque em **"+ Novo RDV"**
2. Preencha o cabeçalho (funcionário, cargo, origem, obra, período)
3. Na tela de despesas, expanda a categoria desejada
4. Toque em **+** para adicionar → use **Câmera** ou **Galeria** para OCR automático
5. Confira e ajuste os dados extraídos pelo OCR
6. Repita para todas as despesas
7. Toque em **"Gerar PDF"** → compartilhe por WhatsApp, e-mail ou imprima

---

## Permissões

| Permissão | Motivo |
|-----------|--------|
| `CAMERA` | Captura de recibos/notas para OCR |
| `READ/WRITE_EXTERNAL_STORAGE` | Salvar o PDF gerado (Android < 10) |

---

## Licença

Uso interno — DHL / GDV.

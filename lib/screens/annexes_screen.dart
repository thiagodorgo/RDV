import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/report_provider.dart';

class AnnexesScreen extends StatelessWidget {
  const AnnexesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportProvider>();
    final photos = provider.photoPaths;

    return Scaffold(
      appBar: AppBar(
        title: Text('Anexos (${photos.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_a_photo_outlined),
            tooltip: 'Adicionar foto',
            onPressed: () => _addPhoto(context),
          ),
        ],
      ),
      body: photos.isEmpty
          ? _buildEmpty(context)
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.80,
              ),
              itemCount: photos.length,
              itemBuilder: (ctx, i) => _PhotoTile(
                path: photos[i],
                index: i + 1,
                onDelete: () => _confirmDelete(context, provider, i),
                onTap: () => _viewPhoto(context, photos, i),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addPhoto(context),
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Adicionar foto'),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined,
              size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Nenhum anexo ainda.',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'As fotos tiradas durante o OCR aparecem aqui\nautomaticamente.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

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
    final picked =
        await picker.pickImage(source: source, imageQuality: 90);
    if (picked != null) await provider.addPhoto(picked.path);
  }

  Future<void> _confirmDelete(
      BuildContext context, ReportProvider provider, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover foto?'),
        content: Text('Remover "Foto ${index + 1}" dos anexos?'),
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
    if (confirm == true) await provider.removePhoto(index);
  }

  void _viewPhoto(
      BuildContext context, List<String> photos, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PhotoViewer(paths: photos, initialIndex: index),
      ),
    );
  }
}

// ── Tile individual de foto ──────────────────────────────────────────────────

class _PhotoTile extends StatelessWidget {
  final String path;
  final int index;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _PhotoTile({
    required this.path,
    required this.index,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(path),
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Foto $index',
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ── Visualizador de foto em tela cheia ───────────────────────────────────────

class _PhotoViewer extends StatefulWidget {
  final List<String> paths;
  final int initialIndex;

  const _PhotoViewer(
      {required this.paths, required this.initialIndex});

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Foto ${_current + 1} de ${widget.paths.length}'),
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        itemCount: widget.paths.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(
            child: Image.file(File(widget.paths[i])),
          ),
        ),
      ),
    );
  }
}

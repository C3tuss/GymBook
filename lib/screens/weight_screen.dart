import 'package:flutter/material.dart';

import '../data/weight_repository.dart';
import '../models/weight_record.dart';
import '../utils/weight_formatters.dart';
import '../widgets/weight_entry_dialog.dart';

enum _DuplicateAction { editExisting, replace, cancel }

class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key});

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  final _repository = WeightRepository.instance;
  late Future<List<WeightRecord>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    _recordsFuture = _repository.getAll();
  }

  Future<void> _reload() async {
    final next = _repository.getAll();
    setState(() => _recordsFuture = next);
    await next;
  }

  Future<void> _openForm({WeightRecord? record}) async {
    final candidate = await showDialog<WeightRecord>(
      context: context,
      builder: (_) => WeightEntryDialog(initialRecord: record),
    );
    if (candidate != null) await _save(candidate);
  }

  Future<void> _save(WeightRecord candidate) async {
    final result = await _repository.save(candidate);
    if (!mounted) return;

    final duplicate = result.conflictingRecord;
    if (duplicate != null) {
      final action = await showDialog<_DuplicateAction>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Já existe uma pesagem nessa data'),
          content: Text(
            'Em ${formatDate(duplicate.date)} há um registro de '
            '${formatWeight(duplicate.weightKg)} kg. O que deseja fazer?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, _DuplicateAction.cancel),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _DuplicateAction.editExisting),
              child: const Text('Editar existente'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _DuplicateAction.replace),
              child: const Text('Substituir peso'),
            ),
          ],
        ),
      );

      if (!mounted || action == null || action == _DuplicateAction.cancel) return;
      if (action == _DuplicateAction.editExisting) {
        await _openForm(record: duplicate);
        return;
      }

      final replacement = WeightRecord(
        id: duplicate.id,
        date: candidate.date,
        weightKg: candidate.weightKg,
      );
      await _repository.save(replacement);
      if (!mounted) return;
      await _reload();
      _showMessage('Pesagem substituída.');
      return;
    }

    await _reload();
    if (!mounted) return;
    _showMessage(candidate.id == null ? 'Pesagem salva.' : 'Pesagem atualizada.');
  }

  Future<void> _openRecordActions(WeightRecord record) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                '${formatWeight(record.weightKg)} kg em ${formatDate(record.date)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar pesagem'),
              onTap: () => Navigator.pop(sheetContext, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Excluir pesagem'),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (action == 'edit') {
      await _openForm(record: record);
    } else if (action == 'delete') {
      await _confirmDelete(record);
    }
  }

  Future<void> _confirmDelete(WeightRecord record) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir pesagem?'),
        content: Text(
          'O registro de ${formatWeight(record.weightKg)} kg em '
          '${formatDate(record.date)} será removido.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || record.id == null) return;
    await _repository.delete(record.id!);
    if (!mounted) return;
    await _reload();
    if (!mounted) return;
    _showMessage('Pesagem excluída.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Peso')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar pesagem'),
      ),
      body: FutureBuilder<List<WeightRecord>>(
        future: _recordsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _LoadError(onRetry: _reload);
          }
          final records = snapshot.data ?? const <WeightRecord>[];
          if (records.isEmpty) {
            return _EmptyWeightState(onAdd: _openForm);
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: records.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final record = records[index];
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  minVerticalPadding: 10,
                  title: Text(
                    formatDate(record.date),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(formatWeekday(record.date)),
                  trailing: Text(
                    '${formatWeight(record.weightKg)} kg',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  onTap: () => _openRecordActions(record),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _EmptyWeightState extends StatelessWidget {
  const _EmptyWeightState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 104),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.monitor_weight_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              'Comece pelo primeiro registro',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Adicione uma pesagem para acompanhar sua evolução ao longo do tempo.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Registrar primeiro peso'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Não foi possível carregar as pesagens.'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

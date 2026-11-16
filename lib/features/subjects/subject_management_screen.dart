import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/subject.dart';
import '../../core/repository/subject_repository.dart';

/// Offline-first management for the subjects used to organise reading sessions.
class SubjectManagementScreen extends ConsumerStatefulWidget {
  const SubjectManagementScreen({super.key});

  @override
  ConsumerState<SubjectManagementScreen> createState() =>
      _SubjectManagementScreenState();
}

class _SubjectManagementScreenState
    extends ConsumerState<SubjectManagementScreen> {
  static const _palette = <String, String>{
    'Orange': '#F97316',
    'Teal': '#0F766E',
    'Indigo': '#4F46E5',
    'Rose': '#DB2777',
    'Gold': '#CA8A04',
    'Slate': '#64748B',
  };

  bool _showArchived = false;

  Future<void> _editSubject({Subject? subject}) async {
    final draft = await showDialog<Subject>(
      context: context,
      builder: (_) => _SubjectEditorDialog(
        existing: subject,
        palette: _palette,
      ),
    );

    if (draft == null || !mounted) return;
    try {
      await ref.read(subjectRepositoryProvider).saveSubject(draft);
      _showMessage(subject == null ? 'Subject created.' : 'Subject updated.');
    } on SubjectNameConflictException catch (error) {
      _showMessage(error.toString());
    } on SubjectStorageCorruptionException catch (error) {
      _showMessage(error.toString());
    } catch (error) {
      _showMessage('Could not save subject: $error');
    }
  }

  Future<void> _setArchived(Subject subject, bool archived) async {
    try {
      await ref.read(subjectRepositoryProvider).setArchived(
            subject.id,
            archived,
          );
      _showMessage(
        archived
            ? 'Archived ${subject.name}. Existing session history is preserved.'
            : 'Restored ${subject.name}.',
      );
    } on SubjectNameConflictException catch (error) {
      _showMessage(error.toString());
    } on SubjectStorageCorruptionException catch (error) {
      _showMessage(error.toString());
    } catch (error) {
      _showMessage('Could not update subject: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Color _parseColor(String value, Color fallback) {
    final normalized = value.replaceFirst('#', '');
    final parsed = int.tryParse(normalized, radix: 16);
    if (parsed == null) return fallback;
    return Color(0xFF000000 | (parsed & 0x00FFFFFF));
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(subjectRepositoryProvider);
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subjects & Projects'),
        actions: [
          IconButton(
            key: const ValueKey('create-subject'),
            tooltip: 'Create subject',
            onPressed: repository.storageIssue == null
                ? () => _editSubject()
                : null,
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<Subject>>(
          stream: repository.watchSubjects(includeArchived: true),
          builder: (context, snapshot) {
            final allSubjects = snapshot.data ?? const <Subject>[];
            final activeCount =
                allSubjects.where((subject) => !subject.archived).length;
            final archivedCount = allSubjects.length - activeCount;
            final visibleSubjects = allSubjects
                .where((subject) => subject.archived == _showArchived)
                .toList();

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Organise your reading',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Create colour-coded subjects and keep your session history organised.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                              height: 1.4,
                            ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _CountPill(
                            label: 'Active',
                            count: activeCount,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 8),
                          _CountPill(
                            label: 'Archived',
                            count: archivedCount,
                            color: colors.onSurfaceVariant,
                          ),
                        ],
                      ),
                      if (repository.storageIssue != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.errorContainer,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: colors.error.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: colors.onErrorContainer,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  repository.storageIssue!,
                                  style: TextStyle(
                                    color: colors.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment<bool>(
                            value: false,
                            label: Text('Active'),
                            icon: Icon(Icons.menu_book_outlined),
                          ),
                          ButtonSegment<bool>(
                            value: true,
                            label: Text('Archived'),
                            icon: Icon(Icons.archive_outlined),
                          ),
                        ],
                        selected: {_showArchived},
                        onSelectionChanged: (selection) {
                          setState(() => _showArchived = selection.first);
                        },
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: snapshot.hasError
                            ? Center(
                                child: Text(
                                  'Subjects could not be loaded: ${snapshot.error}',
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : snapshot.connectionState ==
                                        ConnectionState.waiting &&
                                    !snapshot.hasData
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : visibleSubjects.isEmpty
                                    ? _EmptySubjectsState(
                                        archived: _showArchived,
                                        canCreate:
                                            !_showArchived &&
                                                repository.storageIssue == null,
                                        onCreate: () => _editSubject(),
                                      )
                                    : ListView.separated(
                                        key: const ValueKey('subject-list'),
                                        itemCount: visibleSubjects.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(height: 10),
                                        itemBuilder: (context, index) {
                                          final subject =
                                              visibleSubjects[index];
                                          final subjectColor = _parseColor(
                                            subject.color,
                                            colors.primary,
                                          );
                                          return Container(
                                            decoration: BoxDecoration(
                                              color: colors.surface,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: colors.outlineVariant,
                                              ),
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    backgroundColor:
                                                        subjectColor.withValues(alpha: isDark ? 0.22 : 0.14),
                                                    child: Icon(
                                                      Icons.menu_book_rounded,
                                                      color: subjectColor,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          subject.name,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: Theme.of(context)
                                                              .textTheme
                                                              .titleMedium
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                        ),
                                                        const SizedBox(height: 3),
                                                        Text(
                                                          subject.archived
                                                              ? 'Archived • Session history is preserved'
                                                              : 'Available when starting a session',
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: Theme.of(context)
                                                              .textTheme
                                                              .bodySmall
                                                              ?.copyWith(
                                                                color: colors
                                                                    .onSurfaceVariant,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  IconButton(
                                                    key: ValueKey('edit-subject-${subject.id}'),
                                                    tooltip:
                                                        'Edit ${subject.name}',
                                                    onPressed: repository
                                                                .storageIssue ==
                                                            null
                                                        ? () => _editSubject(
                                                              subject: subject,
                                                            )
                                                        : null,
                                                    icon: const Icon(
                                                      Icons.edit_outlined,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    key: ValueKey(
                                                      subject.archived
                                                          ? 'restore-subject-${subject.id}'
                                                          : 'archive-subject-${subject.id}',
                                                    ),
                                                    tooltip: subject.archived
                                                        ? 'Restore ${subject.name}'
                                                        : 'Archive ${subject.name}',
                                                    onPressed: repository
                                                                .storageIssue ==
                                                            null
                                                        ? () => _setArchived(
                                                              subject,
                                                              !subject.archived,
                                                            )
                                                        : null,
                                                    icon: Icon(
                                                      subject.archived
                                                          ? Icons
                                                              .unarchive_outlined
                                                          : Icons
                                                              .archive_outlined,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SubjectEditorDialog extends StatefulWidget {
  const _SubjectEditorDialog({
    required this.existing,
    required this.palette,
  });

  final Subject? existing;
  final Map<String, String> palette;

  @override
  State<_SubjectEditorDialog> createState() => _SubjectEditorDialogState();
}

class _SubjectEditorDialogState extends State<_SubjectEditorDialog> {
  late final TextEditingController _nameController;
  late String _selectedColor;
  bool _showNameError = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existing?.name ?? '',
    );
    _selectedColor =
        widget.existing?.color ?? widget.palette.values.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _showNameError = true);
      return;
    }

    final existing = widget.existing;
    final draft = existing == null
        ? Subject(
            id: Uuid().v4(),
            name: name,
            color: _selectedColor,
          )
        : existing.copyWith(
            name: name,
            color: _selectedColor,
          );
    Navigator.of(context).pop(draft);
  }

  Color _parseColor(String value, Color fallback) {
    final normalized = value.replaceFirst('#', '');
    final parsed = int.tryParse(normalized, radix: 16);
    if (parsed == null) return fallback;
    return Color(0xFF000000 | (parsed & 0x00FFFFFF));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New subject' : 'Edit subject'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const ValueKey('subject-name-field'),
                controller: _nameController,
                autofocus: true,
                maxLength: 32,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Subject name',
                  hintText: 'e.g. Reading, Mathematics, Research',
                  border: const OutlineInputBorder(),
                  errorText:
                      _showNameError ? 'Enter a subject name.' : null,
                ),
                onChanged: (_) {
                  if (_showNameError) {
                    setState(() => _showNameError = false);
                  }
                },
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 8),
              Text(
                'COLOUR',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.palette.entries.map((entry) {
                  return ChoiceChip(
                    label: Text(entry.key),
                    selected: _selectedColor == entry.value,
                    onSelected: (_) =>
                        setState(() => _selectedColor = entry.value),
                    avatar: CircleAvatar(
                      radius: 7,
                      backgroundColor: _parseColor(
                        entry.value,
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save subject'),
        ),
      ],
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '$label · $count',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptySubjectsState extends StatelessWidget {
  const _EmptySubjectsState({
    required this.archived,
    required this.canCreate,
    required this.onCreate,
  });

  final bool archived;
  final bool canCreate;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              archived
                  ? Icons.archive_outlined
                  : Icons.auto_stories_outlined,
              size: 44,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              archived ? 'Nothing archived yet' : 'No subjects yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              archived
                  ? 'Archived subjects will appear here. Their past sessions remain in your history.'
                  : 'Create your first subject to organise reading sessions by topic or project.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
            if (canCreate) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create your first subject'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const TaskApp());

class TaskApp extends StatelessWidget {
  const TaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tasks Demo',
      theme: ThemeData(useMaterial3: true),
      home: const TaskListPage(),
    );
  }
}

class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  final List<Map<String, dynamic>> _tasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = prefs.getString('tasks');
    if (tasksJson != null) {
      setState(() {
        _tasks.clear();
        _tasks.addAll((jsonDecode(tasksJson) as List).cast<Map<String, dynamic>>());
        _resortTasks();
      });
    } else {
      _saveTasks();
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tasks', jsonEncode(_tasks));
  }

  void _resortTasks() {
    _tasks.sort((a, b) {
      if (a['isImportant'] == b['isImportant']) return 0;
      return a['isImportant'] ? -1 : 1;
    });
  }

  void _addTask(
    String title,
    String description,
    String priority,
    String dueDate,
    String creator,
    List<String> tags,
    bool isImportant,
    bool isRepeating,
  ) {
    setState(() {
      final createdDate = DateTime.now();
      _tasks.add({
        'title': title,
        'description': description,
        'priority': priority,
        'dueDate': dueDate,
        'createdDate':
            "${createdDate.year}-${createdDate.month.toString().padLeft(2, '0')}-${createdDate.day.toString().padLeft(2, '0')}",
        'done': false,
        'creator': creator,
        'tags': tags,
        'isImportant': isImportant,
        'isRepeating': isRepeating,
      });
      _resortTasks();
    });
    _saveTasks();
  }

  void _editTask(int index, Map<String, dynamic> updatedTask) {
    setState(() {
      _tasks[index] = updatedTask;
      _resortTasks();
    });
    _saveTasks();
  }

  void _deleteTask(int index) {
    setState(() {
      _tasks.removeAt(index);
    });
    _saveTasks();
  }

  void _toggleDone(int index) {
    setState(() {
      _tasks[index]['done'] = !_tasks[index]['done'];
    });
    _saveTasks();
  }

  void _openAddModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => AddTaskSheet(
        onCreate: (title, desc, priority, dueDate, creator, tags, isImportant, isRepeating) {
          _addTask(title, desc, priority, dueDate, creator, tags, isImportant, isRepeating);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _openEditModal(int index, Map<String, dynamic> task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => AddTaskSheet(
        existingTask: task,
        onCreate: (title, desc, priority, dueDate, creator, tags, isImportant, isRepeating) {
          _editTask(index, {
            'title': title,
            'description': desc,
            'priority': priority,
            'dueDate': dueDate,
            'createdDate': task['createdDate'],
            'done': task['done'],
            'creator': creator,
            'tags': tags,
            'isImportant': isImportant,
            'isRepeating': isRepeating,
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _resortTasks();

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.all(12),
        itemCount: _tasks.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex -= 1;
            final task = _tasks.removeAt(oldIndex);
            _tasks.insert(newIndex, task);
          });
          _saveTasks();
        },
        itemBuilder: (context, i) {
          final t = _tasks[i];
          return ReorderableDragStartListener(
            key: ValueKey(t['title']),
            index: i,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ExpandableTaskCard(
                title: t['title'],
                description: t['description'],
                priority: t['priority'],
                dueDate: t['dueDate'],
                createdDate: t['createdDate'],
                creator: t['creator'],
                tags: (t['tags'] as List).cast<String>(),
                isImportant: t['isImportant'],
                done: t['done'],
                isRepeating: t['isRepeating'] ?? false,
                onToggleDone: () => _toggleDone(i),
                onEdit: () => _openEditModal(i, t),
                onDelete: () => _deleteTask(i),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        onPressed: _openAddModal,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}

// AddTaskSheet, ExpandableTaskCard, PriorityBadge
// Keep the rest of your code unchanged (as in your original code)


// AddTaskSheet
class AddTaskSheet extends StatefulWidget {
  final void Function(
    String,
    String,
    String,
    String,
    String,
    List<String>,
    bool,
    bool,
  ) onCreate;
  final Map<String, dynamic>? existingTask;

  const AddTaskSheet({super.key, required this.onCreate, this.existingTask});

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _creatorController = TextEditingController();
  String _selectedPriority = 'Low';
  DateTime? _selectedDate;
  bool _isImportant = false;
  bool _isRepeating = false;
  final List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    if (widget.existingTask != null) {
      final task = widget.existingTask!;
      _titleController.text = task['title'];
      _descController.text = task['description'];
      _creatorController.text = task['creator'];
      _selectedPriority = task['priority'];
      _selectedDate = DateTime.tryParse(task['dueDate']);
      _isImportant = task['isImportant'];
      _isRepeating = task['isRepeating'] ?? false;
      _tags.addAll((task['tags'] as List).cast<String>());
    }
  }

  String _formatDate(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _addTag() async {
    final controller = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Tag"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter tag"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text("Add")),
        ],
      ),
    );
    if (tag != null && tag.isNotEmpty) setState(() => _tags.add(tag));
  }

  bool get _canCreate =>
      _titleController.text.trim().isNotEmpty &&
      _descController.text.trim().isNotEmpty &&
      _creatorController.text.trim().isNotEmpty &&
      (_isRepeating || _selectedDate != null);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.existingTask == null ? 'Add Task' : 'Edit Task',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  onChanged: (_) => setState(() {})),
              const SizedBox(height: 8),
              TextField(
                  controller: _descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  onChanged: (_) => setState(() {})),
              const SizedBox(height: 8),
              TextField(
                  controller: _creatorController,
                  decoration: const InputDecoration(labelText: 'Creator'),
                  onChanged: (_) => setState(() {})),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: _selectedPriority,
                items: ['High', 'Medium', 'Low']
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedPriority = v!),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(_isRepeating
                        ? "Repeats Everyday"
                        : (_selectedDate == null ? "No Date Selected" : "Due: ${_formatDate(_selectedDate!)}")),
                  ),
                  if (!_isRepeating)
                    ElevatedButton(
                      onPressed: _pickDate,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                      child: const Text("Pick Date", style: TextStyle(color: Colors.black)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  ..._tags.map((tag) => Chip(
                        label: Text(tag),
                        backgroundColor: PriorityBadge.color(_selectedPriority),
                        labelStyle: const TextStyle(color: Colors.white),
                        onDeleted: () => setState(() => _tags.remove(tag)),
                      )),
                  ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: const Text("Add Tag"),
                      onPressed: _addTag),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(value: _isImportant, onChanged: (v) => setState(() => _isImportant = v!)),
                  const Text("Mark as Important"),
                ],
              ),
              Row(
                children: [
                  Checkbox(value: _isRepeating, onChanged: (v) => setState(() => _isRepeating = v!)),
                  const Text("Repeat Daily"),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                onPressed: _canCreate
                    ? () {
                        final dateStr = _selectedDate != null ? _formatDate(_selectedDate!) : '';
                        widget.onCreate(
                            _titleController.text.trim(),
                            _descController.text.trim(),
                            _selectedPriority,
                            dateStr,
                            _creatorController.text.trim(),
                            _tags,
                            _isImportant,
                            _isRepeating);
                      }
                    : null,
                child: Text(widget.existingTask == null ? 'Create' : 'Save',
                    style: const TextStyle(color: Colors.black)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Expandable Task Card
class ExpandableTaskCard extends StatefulWidget {
  final String title;
  final String description;
  final String priority;
  final String dueDate;
  final String createdDate;
  final String creator;
  final List<String>? tags;
  final bool isImportant;
  final bool done;
  final bool isRepeating;
  final VoidCallback onToggleDone;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ExpandableTaskCard({
    super.key,
    required this.title,
    required this.description,
    required this.priority,
    required this.dueDate,
    required this.createdDate,
    required this.creator,
    this.tags,
    this.isImportant = false,
    required this.done,
    this.isRepeating = false,
    required this.onToggleDone,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<ExpandableTaskCard> createState() => _ExpandableTaskCardState();
}

class _ExpandableTaskCardState extends State<ExpandableTaskCard> {
  bool _expanded = false;

  String _dueLabel() {
    if (widget.isRepeating) return 'Everyday';
    final dueDate = DateTime.tryParse(widget.dueDate);
    if (dueDate == null) return '';
    final now = DateTime.now();
    final diff = dueDate.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (diff < 0) return 'Overdue';
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return '$diff days left';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: widget.isImportant ? 6 : 3,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(value: widget.done, onChanged: (_) => widget.onToggleDone()),
                  PriorityBadge(priority: widget.priority),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: widget.isImportant ? FontWeight.w900 : FontWeight.bold,
                        decoration: widget.done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  if (widget.isImportant) const Icon(Icons.star, color: Colors.amber),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
                    child: Text(_dueLabel(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                  ),
                ],
              ),
              if (_expanded)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.description,
                          style: TextStyle(
                              color: Colors.grey[700],
                              decoration: widget.done ? TextDecoration.lineThrough : null)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.person, size: 16),
                          const SizedBox(width: 4),
                          Text(widget.creator,
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      if (widget.tags != null && widget.tags!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                            spacing: 6,
                            children: widget.tags!
                                .map((tag) => Chip(
                                      label: Text(tag),
                                      backgroundColor: PriorityBadge.color(widget.priority),
                                      labelStyle: const TextStyle(color: Colors.white),
                                    ))
                                .toList()),
                      ],
                      const SizedBox(height: 8),
                      if (!widget.isRepeating)
                        Text("Due: ${widget.dueDate}",
                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                      Text("Created: ${widget.createdDate}",
                          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                              onPressed: widget.onEdit,
                              icon: const Icon(Icons.edit, size: 18, color: Colors.black),
                              label: const Text("Edit", style: TextStyle(color: Colors.black))),
                          const SizedBox(width: 8),
                          TextButton.icon(
                              onPressed: widget.onDelete,
                              icon: const Icon(Icons.delete, size: 18, color: Colors.black),
                              label: const Text("Delete", style: TextStyle(color: Colors.black))),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class PriorityBadge extends StatelessWidget {
  final String priority;
  const PriorityBadge({super.key, required this.priority});

  static Color color(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  Color get _color => color(priority);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: _color, borderRadius: BorderRadius.circular(20)),
      child: Text(priority,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}
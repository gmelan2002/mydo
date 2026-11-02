import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyDoApp());
}

// 1. Task Model with Date
class Task {
  String id;
  String title;
  String description;
  bool isCompleted;
  DateTime dueDate;

  Task({
    required this.id,
    required this.title,
    required this.description,
    this.isCompleted = false,
    required this.dueDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'isCompleted': isCompleted,
        'dueDate': dueDate.toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        isCompleted: json['isCompleted'] ?? false,
        dueDate: json['dueDate'] != null
            ? DateTime.parse(json['dueDate'])
            : DateTime.now(),
      );
}

// 2. Main App Widget
class MyDoApp extends StatefulWidget {
  const MyDoApp({super.key});

  @override
  State<MyDoApp> createState() => _MyDoAppState();
}

class _MyDoAppState extends State<MyDoApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  void _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  void _toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = value;
      prefs.setBool('isDarkMode', _isDarkMode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyDo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: SplashScreen(
        isDarkMode: _isDarkMode,
        onThemeChanged: _toggleTheme,
      ),
    );
  }
}

// 3. Animated Splash Screen
class SplashScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const SplashScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            isDarkMode: widget.isDarkMode,
            onThemeChanged: widget.onThemeChanged,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isDarkMode ? Colors.grey[900] : Colors.indigo.shade50,
      body: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.indigo,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 64,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'MyDo',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your Daily Task Manager',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 4. Home Screen with Custom Calendar Picker & Date Filters
class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const HomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Task> _tasks = [];
  String _searchQuery = '';
  String _filterStatus = 'All'; // All, Today, Tomorrow, Yesterday, Active, Completed, CustomDate
  DateTime? _selectedCustomDate;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tasksString = prefs.getString('tasks_list');
    if (tasksString != null) {
      List<dynamic> decodedData = jsonDecode(tasksString);
      setState(() {
        _tasks = decodedData.map((item) => Task.fromJson(item)).toList();
      });
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    String encodedData = jsonEncode(_tasks.map((task) => task.toJson()).toList());
    await prefs.setString('tasks_list', encodedData);
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  // Add or Edit Task Dialog with Custom Date Picker
  void _showTaskDialog({Task? task}) {
    final titleController = TextEditingController(text: task?.title ?? '');
    final descController = TextEditingController(text: task?.description ?? '');
    DateTime selectedDate = task?.dueDate ?? DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(task == null ? 'Add New Task' : 'Edit Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Task Title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Date: ${selectedDate.toLocal().toString().split(' ')[0]}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Pick Date'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) return;
                setState(() {
                  if (task == null) {
                    _tasks.add(Task(
                      id: DateTime.now().toString(),
                      title: titleController.text,
                      description: descController.text,
                      dueDate: selectedDate,
                    ));
                  } else {
                    task.title = titleController.text;
                    task.description = descController.text;
                    task.dueDate = selectedDate;
                  }
                });
                _saveTasks();
                Navigator.pop(context);
              },
              child: Text(task == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteTask(String id) {
    setState(() {
      _tasks.removeWhere((task) => task.id == id);
    });
    _saveTasks();
  }

  void _toggleTaskStatus(String id) {
    setState(() {
      final task = _tasks.firstWhere((t) => t.id == id);
      task.isCompleted = !task.isCompleted;
    });
    _saveTasks();
  }

  // Open Calendar Dialog to pick any Custom Date to view tasks
  void _pickCalendarFilterDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedCustomDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedCustomDate = picked;
        _filterStatus = 'CustomDate';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime yesterday = today.subtract(const Duration(days: 1));
    DateTime tomorrow = today.add(const Duration(days: 1));

    List<Task> filteredTasks = _tasks.where((task) {
      bool matchesSearch = task.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          task.description.toLowerCase().contains(_searchQuery.toLowerCase());

      DateTime taskDate = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);

      if (_filterStatus == 'Today') {
        return matchesSearch && _isSameDay(taskDate, today);
      } else if (_filterStatus == 'Tomorrow') {
        return matchesSearch && _isSameDay(taskDate, tomorrow);
      } else if (_filterStatus == 'Yesterday') {
        return matchesSearch && _isSameDay(taskDate, yesterday);
      } else if (_filterStatus == 'Active') {
        return matchesSearch && !task.isCompleted;
      } else if (_filterStatus == 'Completed') {
        return matchesSearch && task.isCompleted;
      } else if (_filterStatus == 'CustomDate' && _selectedCustomDate != null) {
        return matchesSearch && _isSameDay(taskDate, _selectedCustomDate!);
      }
      return matchesSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('MyDo'),
        actions: [
          // Calendar Filter Button in AppBar
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Select Custom Date Calendar',
            onPressed: _pickCalendarFilterDate,
          ),
          // Dark Mode Toggle
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.dark_mode : Icons.light_mode),
            onPressed: () => widget.onThemeChanged(!widget.isDarkMode),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search tasks...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 10),
                // If Custom Date is chosen, show a banner to clear or change it
                if (_filterStatus == 'CustomDate' && _selectedCustomDate != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Chip(
                      label: Text(
                          "Calendar Filter: ${_selectedCustomDate!.toLocal().toString().split(' ')[0]}"),
                      deleteIcon: const Icon(Icons.close),
                      onDeleted: () {
                        setState(() {
                          _filterStatus = 'All';
                          _selectedCustomDate = null;
                        });
                      },
                    ),
                  ),
                // Filter Chips (All, Today, Tomorrow, Yesterday, Active, Completed)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Today', 'Tomorrow', 'Yesterday', 'Active', 'Completed'].map((status) {
                      bool isSelected = _filterStatus == status;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ChoiceChip(
                          label: Text(status),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _filterStatus = status;
                              if (status != 'CustomDate') {
                                _selectedCustomDate = null;
                              }
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredTasks.isEmpty
                ? const Center(child: Text('No tasks found for this date/filter!'))
                : ListView.builder(
                    itemCount: filteredTasks.length,
                    itemBuilder: (context, index) {
                      final currentTask = filteredTasks[index];
                      String formattedDate = "${currentTask.dueDate.year}-${currentTask.dueDate.month.toString().padLeft(2, '0')}-${currentTask.dueDate.day.toString().padLeft(2, '0')}";
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: Checkbox(
                            value: currentTask.isCompleted,
                            onChanged: (_) => _toggleTaskStatus(currentTask.id),
                          ),
                          title: Text(
                            currentTask.title,
                            style: TextStyle(
                              decoration: currentTask.isCompleted
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentTask.description,
                                style: TextStyle(
                                  decoration: currentTask.isCompleted
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    formattedDate,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showTaskDialog(task: currentTask),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteTask(currentTask.id),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
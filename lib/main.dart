import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Добавлен импорт для дат
import 'firebase_options.dart';
import 'auth_screen.dart'; 
import 'package:flutter_slidable/flutter_slidable.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const PlannerApp());
}

class PlannerApp extends StatelessWidget {
  const PlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Планер',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            final user = snapshot.data;
            return user == null ? const AuthScreen() : const TaskScreen();
          }
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        },
      ),
    );
  }
}

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final TextEditingController _textController = TextEditingController();
  
  // НОВАЯ ПЕРЕМЕННАЯ: Выбранная дата выполнения
  DateTime? _selectedDueDate;

  // НОВАЯ ФУНКЦИЯ: Выбор даты и времени
  Future<void> _pickDateTime() async {
    // 1. Выбираем дату
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      // 2. Выбираем время
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        setState(() {
          // Соединяем дату и время в одну переменную
          _selectedDueDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _addTask() async {
    if (_textController.text.trim().isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('tasks').add({
      'title': _textController.text.trim(),
      'isDone': false,
      'createdAt': FieldValue.serverTimestamp(),
      'userId': user.uid,
      // НОВОЕ ПОЛЕ: Сохраняем дату выполнения (если не выбрана, будет null)
      'dueDate': _selectedDueDate != null ? Timestamp.fromDate(_selectedDueDate!) : null,
    });

    _textController.clear();
    setState(() {
      _selectedDueDate = null; // Сбрасываем дату после добавления
    });
  }

  Future<void> _deleteTask(String docId) async {
    await FirebaseFirestore.instance.collection('tasks').doc(docId).delete();
  }

  Future<void> _toggleDone(String docId, bool currentValue) async {
    await FirebaseFirestore.instance.collection('tasks').doc(docId).update({
      'isDone': !currentValue,
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мой Планер'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _logout,
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      // Показываем выбранную дату прямо в поле ввода
                      hintText: _selectedDueDate == null 
                          ? 'Введите новую задачу...' 
                          : 'Срок: ${DateFormat('dd.MM.yyyy HH:mm').format(_selectedDueDate!)}',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                // НОВАЯ КНОПКА: Календарик
                IconButton(
                  icon: Icon(
                    Icons.calendar_today,
                    color: _selectedDueDate == null ? Colors.grey : Colors.indigo,
                  ),
                  onPressed: _pickDateTime,
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.indigo, size: 40),
                  onPressed: _addTask,
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tasks')
                  .where('userId', isEqualTo: user?.uid)
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Задач нет. Можно отдохнуть!'));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var taskData = doc.data() as Map<String, dynamic>;
                    String title = taskData['title'] ?? 'Без названия';
                    bool isDone = taskData['isDone'] ?? false;

                    // НОВОЕ: Читаем дату выполнения из базы
                    Timestamp? dueTimestamp = taskData['dueDate'] as Timestamp?;
                    DateTime? dueDate = dueTimestamp?.toDate();
                    
                    // НОВОЕ: Проверяем, просрочена ли задача
                    bool isOverdue = dueDate != null && dueDate.isBefore(DateTime.now()) && !isDone;

                    return Slidable(
                      key: ValueKey(doc.id),
                      startActionPane: ActionPane(
                        motion: const ScrollMotion(),
                        children: [
                          SlidableAction(
                            onPressed: (context) => _toggleDone(doc.id, isDone),
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            icon: isDone ? Icons.undo : Icons.check,
                            label: isDone ? 'Вернуть' : 'Готово',
                          ),
                        ],
                      ),
                      endActionPane: ActionPane(
                        motion: const ScrollMotion(),
                        children: [
                          SlidableAction(
                            onPressed: (context) => _deleteTask(doc.id),
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            icon: Icons.delete,
                            label: 'Удалить',
                          ),
                        ],
                      ),
                      child: Card(
                        child: ListTile(
                          leading: Icon(
                            isDone ? Icons.check_box : Icons.check_box_outline_blank,
                            color: Colors.indigo,
                          ),
                          title: Text(
                            title,
                            style: TextStyle(
                              decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
                              color: isDone ? Colors.grey : Colors.black,
                            ),
                          ),
                          // НОВОЕ: Показываем дату под текстом задачи
                          subtitle: dueDate != null
                              ? Text(
                                  DateFormat('dd.MM.yyyy HH:mm').format(dueDate),
                                  style: TextStyle(
                                    color: isOverdue ? Colors.red : Colors.grey, // Красный, если просрочено
                                    fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                                  ),
                                )
                              : null,
                          onTap: () => _toggleDone(doc.id, isDone),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
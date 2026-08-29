import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("УРА: Firebase подключен!");
  } catch (e) {
    print("ОШИБКА FIREBASE: $e");
  }

  runApp(const PlannerApp());
}

class PlannerApp extends StatelessWidget {
  const PlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Планер',
      theme: ThemeData(primarySwatch: Colors.indigo),
      // Убрали const, так как теперь это StatefulWidget
      home: TaskScreen(),
    );
  }
}

// Изменили на StatefulWidget
class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  // Контроллер теперь здесь, он не требует const
  final TextEditingController _textController = TextEditingController();

  // Функция добавления задачи в Firebase
  Future<void> _addTask() async {
    if (_textController.text.trim().isEmpty) return;

    await FirebaseFirestore.instance.collection('tasks').add({
      'title': _textController.text.trim(),
      'isDone': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    _textController.clear();
  }

  // Функция удаления задачи
  Future<void> _deleteTask(String docId) async {
    await FirebaseFirestore.instance.collection('tasks').doc(docId).delete();
  }

  // Функция отметки "Выполнено"
  Future<void> _toggleDone(String docId, bool currentValue) async {
    await FirebaseFirestore.instance.collection('tasks').doc(docId).update({
      'isDone': !currentValue,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мой Планер')),
      body: Column(
        children: [
          // Поле ввода и кнопка
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Введите новую задачу...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.indigo, size: 40),
                  onPressed: _addTask,
                ),
              ],
            ),
          ),
          // Список задач
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tasks')
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
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

                    return Card(
                      child: ListTile(
                        leading: IconButton(
                          icon: Icon(
                            isDone ? Icons.check_box : Icons.check_box_outline_blank,
                            color: Colors.indigo,
                          ),
                          // При нажатии на галочку меняем статус
                          onPressed: () => _toggleDone(doc.id, isDone),
                        ),
                        title: Text(
                          title,
                          style: TextStyle(
                            decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
                            color: isDone ? Colors.grey : Colors.black,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteTask(doc.id),
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
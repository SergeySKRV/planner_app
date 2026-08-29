import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      // StreamBuilder следит за состоянием авторизации
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Если пользователь есть - показываем задачи, если нет - экран входа
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

  Future<void> _addTask() async {
    if (_textController.text.trim().isEmpty) return;

    // ПОЛУЧАЕМ ID ТЕКУЩЕГО ПОЛЬЗОВАТЕЛЯ
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('tasks').add({
      'title': _textController.text.trim(),
      'isDone': false,
      'createdAt': FieldValue.serverTimestamp(),
      'userId': user.uid, // Привязываем задачу к пользователю!
    });

    _textController.clear();
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

                    // ОБЕРТЫВАЕМ КАРТОЧКУ В SLIDABLE
                    return Slidable(
                      key: ValueKey(doc.id),
                      // Свайп вправо (Отметить выполнение)
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
                      // Свайп влево (Удалить)
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
                      // Сама карточка с задачей
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
                          // При нажатии на саму карточку тоже меняем статус
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
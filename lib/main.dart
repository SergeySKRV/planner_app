import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Пытаемся подключиться к Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase подключен успешно!");
  } catch (e) {
    // Если ошибка — выводим её в терминал красным цветом
    print("ОШИБКА ПОДКЛЮЧЕНИЯ FIREBASE: $e");
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
      home: Scaffold(
        appBar: AppBar(title: const Text('Мой Планер')),
        body: const Center(
          child: Text('Приложение запущено', style: TextStyle(fontSize: 20)),
        ),
      ),
    );
  }
}
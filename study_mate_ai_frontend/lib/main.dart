import 'package:flutter/material.dart';
import 'app.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => const StudyMateApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StudyMateApp());
}

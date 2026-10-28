import 'package:flutter/material.dart';

import 'pages/user_page.dart';
import 'theme/app_theme.dart';

void main() => runApp(const CrudApp());

class CrudApp extends StatelessWidget {
  const CrudApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CRUD REST API',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const UserPage(),
    );
  }
}

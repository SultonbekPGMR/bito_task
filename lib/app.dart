// Created by Sultonbek Tulanov on 12-February 2026
import 'package:flutter/material.dart';

import 'config/app_constants.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: App(),
    );
  }
}



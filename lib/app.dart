import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:unical_task/config/app_constants.dart';
import 'package:unical_task/domain/service/background_simulator.dart';
import 'package:unical_task/domain/service/seat_manager.dart';
import 'package:unical_task/presentation/screen/home_screen.dart';

class App extends StatefulWidget {
  final SeatManager seatManager;

  const App({super.key, required this.seatManager});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final BackgroundSimulator _simulator;

  @override
  void initState() {
    super.initState();
    _simulator = BackgroundSimulator(widget.seatManager);
    _simulator.start();
  }

  @override
  void dispose() {
    _simulator.stop();
    widget.seatManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: widget.seatManager,
      child: MaterialApp(
        title: AppConstants.appName,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

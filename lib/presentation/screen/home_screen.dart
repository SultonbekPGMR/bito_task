import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:unical_task/config/enum.dart';
import 'package:unical_task/domain/model/seat/seat_model.dart';
import 'package:unical_task/domain/service/seat_manager.dart';
import 'package:unical_task/presentation/bloc/home/home_bloc.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          HomeBloc(context.read<SeatManager>())..add(const HomeEvent.init()),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seat Reservation'),
        centerTitle: true,
      ),
      body: BlocConsumer<HomeBloc, HomeState>(
        listener: (context, state) {
          if (state.isError && state.errorMessage?.isNotEmpty == true) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: Colors.red.shade700,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            context
                .read<HomeBloc>()
                .add(const HomeEvent.onErrorMessageConsumed());
          }
        },
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final hasUserLockedSeats = state.seats.any(
            (s) =>
                s.status == SeatStatus.locked &&
                s.lockedBy == HomeBloc.currentUserId,
          );

          return SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      "SULTONBEK'S TASK",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _legendItem(Colors.green, 'Available'),
                      _legendItem(Colors.amber.shade700, 'Locked'),
                      _legendItem(Colors.red, 'Reserved'),
                      _legendItem(Colors.blue, 'Yours'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.builder(
                      padding: const EdgeInsets.only(bottom: 8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 8,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                      itemCount: state.seats.length,
                      itemBuilder: (context, index) {
                        final seat = state.seats[index];
                        return _SeatTile(
                          seat: seat,
                          label: _seatLabel(index),
                          onTap: () {
                            context
                                .read<HomeBloc>()
                                .add(HomeEvent.onSeatTap(seatId: seat.id));
                          },
                        );
                      },
                    ),
                  ),
                ),
                _LogPanel(seatManager: context.read<SeatManager>()),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: hasUserLockedSeats
                          ? () => context
                              .read<HomeBloc>()
                              .add(const HomeEvent.onConfirmTap())
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Confirm Reservation',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _seatLabel(int index) {
    final row = String.fromCharCode('A'.codeUnitAt(0) + index ~/ 8);
    final col = (index % 8) + 1;
    return '$row$col';
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _SeatTile extends StatefulWidget {
  final SeatModel seat;
  final String label;
  final VoidCallback onTap;

  const _SeatTile({
    required this.seat,
    required this.label,
    required this.onTap,
  });

  @override
  State<_SeatTile> createState() => _SeatTileState();
}

class _SeatTileState extends State<_SeatTile> {
  Timer? _countdownTimer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _updateCountdown();
  }

  @override
  void didUpdateWidget(covariant _SeatTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seat.status != widget.seat.status ||
        oldWidget.seat.lockExpirationTime != widget.seat.lockExpirationTime) {
      _updateCountdown();
    }
  }

  void _updateCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;

    if (widget.seat.status == SeatStatus.locked &&
        widget.seat.lockExpirationTime != null) {
      _calculateRemaining();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _calculateRemaining();
      });
    } else {
      if (mounted) setState(() => _remainingSeconds = 0);
    }
  }

  void _calculateRemaining() {
    final expiry = widget.seat.lockExpirationTime;
    if (expiry == null) {
      _countdownTimer?.cancel();
      if (mounted) setState(() => _remainingSeconds = 0);
      return;
    }
    final remaining = expiry.difference(DateTime.now()).inSeconds;
    if (mounted) {
      setState(() => _remainingSeconds = remaining.clamp(0, 999));
    }
    if (remaining <= 0) {
      _countdownTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUserLocked =
        widget.seat.status == SeatStatus.locked &&
        widget.seat.lockedBy == HomeBloc.currentUserId;

    final showCountdown =
        widget.seat.status == SeatStatus.locked && _remainingSeconds > 0;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _getColor(isUserLocked),
          borderRadius: BorderRadius.circular(6),
          border: isUserLocked
              ? Border.all(color: Colors.blue.shade900, width: 2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (showCountdown)
              Text(
                '${_remainingSeconds}s',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getColor(bool isUserLocked) {
    switch (widget.seat.status) {
      case SeatStatus.available:
        return Colors.green;
      case SeatStatus.locked:
        return isUserLocked ? Colors.blue : Colors.amber.shade700;
      case SeatStatus.reserved:
        return Colors.red;
    }
  }
}

class _LogPanel extends StatefulWidget {
  final SeatManager seatManager;

  const _LogPanel({required this.seatManager});

  @override
  State<_LogPanel> createState() => _LogPanelState();
}

class _LogPanelState extends State<_LogPanel> {
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<String>? _logSubscription;

  @override
  void initState() {
    super.initState();
    _logSubscription = widget.seatManager.logStream.listen((message) {
      if (mounted) {
        setState(() {
          _logs.add(message);
          if (_logs.length > 50) _logs.removeAt(0);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
            child: Text(
              'Event Log',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1, color: Colors.grey),
          Expanded(
            child: _logs.isEmpty
                ? Center(
                    child: Text(
                      'No events yet',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      return Text(
                        _logs[index],
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

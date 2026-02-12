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
                      'SULTONBEK\'S TASK',
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
                                .add(HomeEvent.onSeatTap(seat: seat));
                          },
                        );
                      },
                    ),
                  ),
                ),
                // Confirm button
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

class _SeatTile extends StatelessWidget {
  final SeatModel seat;
  final String label;
  final VoidCallback onTap;

  const _SeatTile({
    required this.seat,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUserLocked =
        seat.status == SeatStatus.locked &&
        seat.lockedBy == HomeBloc.currentUserId;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _getColor(isUserLocked),
          borderRadius: BorderRadius.circular(6),
          border: isUserLocked
              ? Border.all(color: Colors.blue.shade900, width: 2)
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Color _getColor(bool isUserLocked) {
    switch (seat.status) {
      case SeatStatus.available:
        return Colors.green;
      case SeatStatus.locked:
        return isUserLocked ? Colors.blue : Colors.amber.shade700;
      case SeatStatus.reserved:
        return Colors.red;
    }
  }
}

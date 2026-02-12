import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:unical_task/config/enum.dart';
import 'package:unical_task/domain/model/seat/seat_model.dart';
import 'package:unical_task/domain/service/seat_manager.dart';

part 'home_event.dart';
part 'home_state.dart';
part 'home_bloc.freezed.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final SeatManager _seatManager;
  StreamSubscription<List<SeatModel>>? _seatSubscription;

  static const String currentUserId = 'current_user';

  HomeBloc(this._seatManager) : super(const HomeState()) {
    on<_Init>(_onInit);
    on<_OnSeatTap>(_onSeatTap);
    on<_OnConfirmTap>(_onConfirmTap);
    on<_OnSeatsUpdated>(_onSeatsUpdated);
    on<_OnErrorMessageConsumed>(_onErrorMessageConsumed);
  }

  void _onInit(_Init event, Emitter<HomeState> emit) {
    _seatSubscription = _seatManager.stream.listen((seats) {
      add(HomeEvent.onSeatsUpdated(seats: seats));
    });
    emit(state.copyWith(seats: _seatManager.seats, isLoading: false));
  }

  void _onSeatTap(_OnSeatTap event, Emitter<HomeState> emit) {
    final result = _seatManager.handleSeatTap(event.seatId, currentUserId);
    if (result != SeatResult.success) {
      emit(state.copyWith(isError: true, errorMessage: result.message));
    }
  }

  void _onConfirmTap(_OnConfirmTap event, Emitter<HomeState> emit) {
    final (:confirmed, :expired) =
        _seatManager.confirmAllUserSeats(currentUserId);

    if (confirmed == 0 && expired == 0) {
      emit(state.copyWith(
        isError: true,
        errorMessage: SeatResult.noLockedSeats.message,
      ));
    } else if (expired > 0 && confirmed == 0) {
      emit(state.copyWith(
        isError: true,
        errorMessage: 'All locks have expired',
      ));
    } else if (expired > 0) {
      emit(state.copyWith(
        isError: true,
        errorMessage: '$expired seat(s) expired, $confirmed confirmed',
      ));
    }
  }

  void _onSeatsUpdated(_OnSeatsUpdated event, Emitter<HomeState> emit) {
    emit(state.copyWith(seats: event.seats));
  }

  void _onErrorMessageConsumed(
    _OnErrorMessageConsumed event,
    Emitter<HomeState> emit,
  ) {
    emit(state.copyWith(isError: false, errorMessage: null));
  }

  @override
  Future<void> close() {
    _seatSubscription?.cancel();
    return super.close();
  }
}

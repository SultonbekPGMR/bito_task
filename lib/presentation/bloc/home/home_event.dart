part of 'home_bloc.dart';

@freezed
class HomeEvent with _$HomeEvent {
  const factory HomeEvent.init() = _Init;
  const factory HomeEvent.onSeatTap({required SeatModel seat}) = _OnSeatTap;
  const factory HomeEvent.onConfirmTap() = _OnConfirmTap;
  const factory HomeEvent.onSeatsUpdated({required List<SeatModel> seats}) =
      _OnSeatsUpdated;
  const factory HomeEvent.onErrorMessageConsumed() = _OnErrorMessageConsumed;
}

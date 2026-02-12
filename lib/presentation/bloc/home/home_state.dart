part of 'home_bloc.dart';

@freezed
sealed class HomeState with _$HomeState {
  const factory HomeState({
    @Default([]) List<SeatModel> seats,
    @Default(true) bool isLoading,
    @Default(false) bool isError,
    String? errorMessage,
  }) = _HomeState;
}

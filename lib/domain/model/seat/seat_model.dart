// Created by Sultonbek Tulanov on 12-February 2026
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../config/enum.dart';

part 'seat_model.freezed.dart';

@freezed
sealed class SeatModel with _$SeatModel {
  const factory SeatModel({
    required String id,
    required SeatStatus status,
    String? lockedBy,
    DateTime? lockExpirationTime,
  }) = _SeatModel;
}

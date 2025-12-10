import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';
import '../../core/models/station.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/epson_service.dart';

/// Station repository interface
abstract class StationRepository {
  /// Get all stations for a society
  Future<Either<Failure, List<Station>>> getStationsBySociety(String societyId);

  /// Get station by ID
  Future<Either<Failure, Station>> getStationById(String stationId);

  /// Get station status (online/offline, ink, paper levels)
  Future<Either<Failure, StationStatus>> getStationStatus(String stationId);

  /// Get available (online) stations for a society
  Future<Either<Failure, List<Station>>> getAvailableStations(String societyId);

  /// Check if station can handle color printing
  Future<Either<Failure, bool>> canPrintColor(String stationId);
}

/// Implementation of StationRepository
class StationRepositoryImpl implements StationRepository {
  final SupabaseService _supabaseService;
  final EpsonService _epsonService;

  StationRepositoryImpl(this._supabaseService, this._epsonService);

  @override
  Future<Either<Failure, List<Station>>> getStationsBySociety(String societyId) async {
    try {
      final stations = await _supabaseService.getStationsBySociety(societyId);
      return Right(stations);
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to fetch stations',
        originalError: e,
      ));
    }
  }

  @override
  Future<Either<Failure, Station>> getStationById(String stationId) async {
    try {
      final station = await _supabaseService.getStationById(stationId);
      if (station == null) {
        return Left(ServerFailure(
          message: 'Station not found',
          code: 'STATION_NOT_FOUND',
        ));
      }
      return Right(station);
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to fetch station',
        originalError: e,
      ));
    }
  }

  @override
  Future<Either<Failure, StationStatus>> getStationStatus(String stationId) async {
    try {
      // Get station details
      final station = await _supabaseService.getStationById(stationId);
      if (station == null) {
        return Left(ServerFailure(
          message: 'Station not found',
          code: 'STATION_NOT_FOUND',
        ));
      }

      // Check printer status via Epson API
      final status = await _epsonService.getPrinterStatus(
        station.epsonPrinterEmail,
      );

      return Right(status);
    } catch (e) {
      // Return offline status if we can't connect
      return Right(StationStatus.offline());
    }
  }

  @override
  Future<Either<Failure, List<Station>>> getAvailableStations(String societyId) async {
    try {
      final allStations = await _supabaseService.getStationsBySociety(societyId);

      // Check each station's status
      final availableStations = <Station>[];
      for (final station in allStations) {
        if (!station.isActive) continue;

        try {
          final status = await _epsonService.getPrinterStatus(
            station.epsonPrinterEmail,
          );

          if (status.isOnline && !status.hasError) {
            availableStations.add(station.copyWith(currentStatus: status));
          }
        } catch (_) {
          // Skip stations we can't reach
          continue;
        }
      }

      return Right(availableStations);
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to fetch available stations',
        originalError: e,
      ));
    }
  }

  @override
  Future<Either<Failure, bool>> canPrintColor(String stationId) async {
    try {
      final station = await _supabaseService.getStationById(stationId);
      if (station == null) {
        return Left(ServerFailure(
          message: 'Station not found',
          code: 'STATION_NOT_FOUND',
        ));
      }
      return Right(station.hasColor);
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to check station capabilities',
        originalError: e,
      ));
    }
  }
}

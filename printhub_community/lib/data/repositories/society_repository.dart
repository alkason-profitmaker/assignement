import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';
import '../../core/models/society.dart';
import '../../core/services/supabase_service.dart';

/// Society repository interface
abstract class SocietyRepository {
  /// Get all active societies
  Future<Either<Failure, List<Society>>> getAllSocieties();

  /// Get society by ID
  Future<Either<Failure, Society>> getSocietyById(String societyId);

  /// Search societies by name or code
  Future<Either<Failure, List<Society>>> searchSocieties(String query);

  /// Get user's society
  Future<Either<Failure, Society?>> getUserSociety();
}

/// Implementation of SocietyRepository
class SocietyRepositoryImpl implements SocietyRepository {
  final SupabaseService _supabaseService;

  SocietyRepositoryImpl(this._supabaseService);

  @override
  Future<Either<Failure, List<Society>>> getAllSocieties() async {
    try {
      final societies = await _supabaseService.getAllSocieties();
      return Right(societies);
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to fetch societies',
        originalError: e,
      ));
    }
  }

  @override
  Future<Either<Failure, Society>> getSocietyById(String societyId) async {
    try {
      final society = await _supabaseService.getSocietyById(societyId);
      if (society == null) {
        return Left(ServerFailure(
          message: 'Society not found',
          code: 'SOCIETY_NOT_FOUND',
        ));
      }
      return Right(society);
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to fetch society',
        originalError: e,
      ));
    }
  }

  @override
  Future<Either<Failure, List<Society>>> searchSocieties(String query) async {
    try {
      if (query.isEmpty) {
        return getAllSocieties();
      }
      final societies = await _supabaseService.searchSocieties(query);
      return Right(societies);
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to search societies',
        originalError: e,
      ));
    }
  }

  @override
  Future<Either<Failure, Society?>> getUserSociety() async {
    try {
      final user = await _supabaseService.getCurrentUser();
      if (user == null) {
        return const Right(null);
      }
      final society = await _supabaseService.getSocietyById(user.societyId);
      return Right(society);
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to fetch user society',
        originalError: e,
      ));
    }
  }
}

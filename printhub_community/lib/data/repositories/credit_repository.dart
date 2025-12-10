import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';
import '../../core/models/credit.dart';
import '../../core/services/supabase_service.dart';

/// Credit repository interface
abstract class CreditRepository {
  /// Get user's available credits
  Future<Either<Failure, CreditSummary>> getUserCredits();

  /// Get credit history
  Future<Either<Failure, List<Credit>>> getCreditHistory({
    int limit = 20,
    int offset = 0,
  });

  /// Apply credits to an order
  Future<Either<Failure, int>> applyCreditsToOrder({
    required String orderId,
    required int bwPagesNeeded,
    required int colorPagesNeeded,
  });
}

/// Implementation of CreditRepository
class CreditRepositoryImpl implements CreditRepository {
  final SupabaseService _supabaseService;

  CreditRepositoryImpl(this._supabaseService);

  @override
  Future<Either<Failure, CreditSummary>> getUserCredits() async {
    try {
      final credits = await _supabaseService.getUserCredits();
      final summary = CreditSummary.fromCredits(credits);
      return Right(summary);
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to fetch credits',
        originalError: e,
      ));
    }
  }

  @override
  Future<Either<Failure, List<Credit>>> getCreditHistory({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final credits = await _supabaseService.getCreditHistory(
        limit: limit,
        offset: offset,
      );
      return Right(credits);
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to fetch credit history',
        originalError: e,
      ));
    }
  }

  @override
  Future<Either<Failure, int>> applyCreditsToOrder({
    required String orderId,
    required int bwPagesNeeded,
    required int colorPagesNeeded,
  }) async {
    try {
      // Get available credits
      final creditsResult = await getUserCredits();

      return creditsResult.fold(
        (failure) => Left(failure),
        (summary) async {
          if (!summary.hasCredits) {
            return const Right(0); // No credits to apply
          }

          // Calculate how many pages can be covered by credits
          final bwPagesToUse = bwPagesNeeded.clamp(0, summary.totalBwPages);
          final colorPagesToUse = colorPagesNeeded.clamp(0, summary.totalColorPages);

          if (bwPagesToUse == 0 && colorPagesToUse == 0) {
            return const Right(0);
          }

          // Apply credits through Supabase
          final savedPaise = await _supabaseService.applyCreditsToOrder(
            orderId: orderId,
            bwPages: bwPagesToUse,
            colorPages: colorPagesToUse,
          );

          return Right(savedPaise);
        },
      );
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to apply credits',
        originalError: e,
      ));
    }
  }
}

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

import '../../domain/entities/print_job_entity.dart';
import '../models/print_job_model.dart';
import '../../../../core/constants/app_constants.dart';

/// Print job repository implementation using Supabase
class PrintJobRepositoryImpl {
  final SupabaseClient supabase;
  final Logger _logger = Logger();

  PrintJobRepositoryImpl({required this.supabase});

  /// Get current user's print jobs
  Future<List<PrintJobEntity>> getUserPrintJobs({
    int limit = 20,
    int offset = 0,
    List<String>? statuses,
  }) async {
    try {
      var query = supabase
          .from('print_jobs')
          .select()
          .eq('user_id', supabase.auth.currentUser?.id ?? '')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if (statuses != null && statuses.isNotEmpty) {
        query = query.inFilter('status', statuses);
      }

      final response = await query;

      return (response as List)
          .map((json) => PrintJobModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logger.e('Error fetching print jobs: $e');
      rethrow;
    }
  }

  /// Get active print jobs (pending, processing, printing, ready)
  Future<List<PrintJobEntity>> getActivePrintJobs() async {
    try {
      final response = await supabase
          .from('print_jobs')
          .select()
          .eq('user_id', supabase.auth.currentUser?.id ?? '')
          .inFilter('status', ['pending', 'processing', 'printing', 'ready'])
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => PrintJobModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logger.e('Error fetching active print jobs: $e');
      rethrow;
    }
  }

  /// Get a single print job by ID
  Future<PrintJobEntity?> getPrintJob(String jobId) async {
    try {
      final response = await supabase
          .from('print_jobs')
          .select()
          .eq('id', jobId)
          .maybeSingle();

      if (response == null) return null;

      return PrintJobModel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      _logger.e('Error fetching print job: $e');
      rethrow;
    }
  }

  /// Subscribe to print job updates (realtime)
  Stream<PrintJobEntity?> watchPrintJob(String jobId) {
    return supabase
        .from('print_jobs')
        .stream(primaryKey: ['id'])
        .eq('id', jobId)
        .map((data) {
          if (data.isEmpty) return null;
          return PrintJobModel.fromJson(data.first);
        });
  }

  /// Subscribe to all user's print jobs (realtime)
  Stream<List<PrintJobEntity>> watchUserPrintJobs() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      return Stream.value([]);
    }

    return supabase
        .from('print_jobs')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((data) => data
            .map((json) => PrintJobModel.fromJson(json))
            .toList());
  }

  /// Mark job as collected
  Future<void> markAsCollected(String jobId) async {
    try {
      await supabase.from('print_jobs').update({
        'status': 'collected',
        'collected_at': DateTime.now().toIso8601String(),
      }).eq('id', jobId);

      _logger.i('Print job marked as collected: $jobId');
    } catch (e) {
      _logger.e('Error marking job as collected: $e');
      rethrow;
    }
  }

  /// Cancel pending print job
  Future<void> cancelPrintJob(String jobId) async {
    try {
      // Only allow cancelling pending jobs
      final job = await getPrintJob(jobId);
      if (job == null) {
        throw Exception('Print job not found');
      }
      if (job.status != PrintJobStatus.pending) {
        throw Exception('Can only cancel pending jobs');
      }

      await supabase.from('print_jobs').update({
        'status': 'failed',
        'error_message': 'Cancelled by user',
      }).eq('id', jobId);

      _logger.i('Print job cancelled: $jobId');
    } catch (e) {
      _logger.e('Error cancelling print job: $e');
      rethrow;
    }
  }

  /// Get print history with pagination
  Future<List<PrintJobEntity>> getPrintHistory({
    int page = 1,
    int pageSize = 15,
  }) async {
    try {
      final offset = (page - 1) * pageSize;

      final response = await supabase
          .from('print_jobs')
          .select()
          .eq('user_id', supabase.auth.currentUser?.id ?? '')
          .inFilter('status', ['collected', 'expired', 'failed', 'refunded'])
          .order('created_at', ascending: false)
          .range(offset, offset + pageSize - 1);

      return (response as List)
          .map((json) => PrintJobModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logger.e('Error fetching print history: $e');
      rethrow;
    }
  }

  /// Get user's print statistics
  Future<Map<String, dynamic>> getUserStats() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        return {
          'totalPrints': 0,
          'totalSpent': 0.0,
          'totalPages': 0,
        };
      }

      final response = await supabase
          .from('users')
          .select('total_prints, total_spent')
          .eq('id', userId)
          .single();

      // Also calculate total pages
      final pagesResponse = await supabase
          .from('print_jobs')
          .select('total_pages, copies')
          .eq('user_id', userId)
          .eq('status', 'collected');

      int totalPages = 0;
      for (final job in pagesResponse as List) {
        totalPages +=
            (job['total_pages'] as int) * (job['copies'] as int? ?? 1);
      }

      return {
        'totalPrints': response['total_prints'] ?? 0,
        'totalSpent': (response['total_spent'] as num?)?.toDouble() ?? 0.0,
        'totalPages': totalPages,
      };
    } catch (e) {
      _logger.e('Error fetching user stats: $e');
      return {
        'totalPrints': 0,
        'totalSpent': 0.0,
        'totalPages': 0,
      };
    }
  }
}

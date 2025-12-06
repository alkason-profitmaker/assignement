import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/repositories/print_job_repository_impl.dart';
import '../../domain/entities/print_job_entity.dart';

// ============ EVENTS ============

abstract class PrintJobEvent extends Equatable {
  const PrintJobEvent();

  @override
  List<Object?> get props => [];
}

class LoadPrintJobsEvent extends PrintJobEvent {}

class LoadActivePrintJobsEvent extends PrintJobEvent {}

class LoadPrintJobEvent extends PrintJobEvent {
  final String jobId;

  const LoadPrintJobEvent(this.jobId);

  @override
  List<Object?> get props => [jobId];
}

class WatchPrintJobEvent extends PrintJobEvent {
  final String jobId;

  const WatchPrintJobEvent(this.jobId);

  @override
  List<Object?> get props => [jobId];
}

class PrintJobUpdatedEvent extends PrintJobEvent {
  final PrintJobEntity? job;

  const PrintJobUpdatedEvent(this.job);

  @override
  List<Object?> get props => [job];
}

class MarkAsCollectedEvent extends PrintJobEvent {
  final String jobId;

  const MarkAsCollectedEvent(this.jobId);

  @override
  List<Object?> get props => [jobId];
}

class CancelPrintJobEvent extends PrintJobEvent {
  final String jobId;

  const CancelPrintJobEvent(this.jobId);

  @override
  List<Object?> get props => [jobId];
}

class LoadPrintHistoryEvent extends PrintJobEvent {
  final int page;

  const LoadPrintHistoryEvent({this.page = 1});

  @override
  List<Object?> get props => [page];
}

class LoadUserStatsEvent extends PrintJobEvent {}

// ============ STATES ============

abstract class PrintJobState extends Equatable {
  const PrintJobState();

  @override
  List<Object?> get props => [];
}

class PrintJobInitial extends PrintJobState {}

class PrintJobLoading extends PrintJobState {}

class PrintJobsLoaded extends PrintJobState {
  final List<PrintJobEntity> jobs;
  final bool hasMore;

  const PrintJobsLoaded({
    required this.jobs,
    this.hasMore = true,
  });

  @override
  List<Object?> get props => [jobs, hasMore];
}

class PrintJobLoaded extends PrintJobState {
  final PrintJobEntity job;

  const PrintJobLoaded(this.job);

  @override
  List<Object?> get props => [job];
}

class PrintJobError extends PrintJobState {
  final String message;

  const PrintJobError(this.message);

  @override
  List<Object?> get props => [message];
}

class PrintJobActionSuccess extends PrintJobState {
  final String message;

  const PrintJobActionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class UserStatsLoaded extends PrintJobState {
  final int totalPrints;
  final double totalSpent;
  final int totalPages;

  const UserStatsLoaded({
    required this.totalPrints,
    required this.totalSpent,
    required this.totalPages,
  });

  @override
  List<Object?> get props => [totalPrints, totalSpent, totalPages];
}

// ============ BLOC ============

class PrintJobBloc extends Bloc<PrintJobEvent, PrintJobState> {
  final PrintJobRepositoryImpl printJobRepository;
  StreamSubscription? _jobSubscription;

  PrintJobBloc({required this.printJobRepository}) : super(PrintJobInitial()) {
    on<LoadPrintJobsEvent>(_onLoadPrintJobs);
    on<LoadActivePrintJobsEvent>(_onLoadActivePrintJobs);
    on<LoadPrintJobEvent>(_onLoadPrintJob);
    on<WatchPrintJobEvent>(_onWatchPrintJob);
    on<PrintJobUpdatedEvent>(_onPrintJobUpdated);
    on<MarkAsCollectedEvent>(_onMarkAsCollected);
    on<CancelPrintJobEvent>(_onCancelPrintJob);
    on<LoadPrintHistoryEvent>(_onLoadPrintHistory);
    on<LoadUserStatsEvent>(_onLoadUserStats);
  }

  Future<void> _onLoadPrintJobs(
    LoadPrintJobsEvent event,
    Emitter<PrintJobState> emit,
  ) async {
    try {
      emit(PrintJobLoading());

      final jobs = await printJobRepository.getUserPrintJobs();

      emit(PrintJobsLoaded(jobs: jobs));
    } catch (e) {
      emit(PrintJobError(e.toString()));
    }
  }

  Future<void> _onLoadActivePrintJobs(
    LoadActivePrintJobsEvent event,
    Emitter<PrintJobState> emit,
  ) async {
    try {
      emit(PrintJobLoading());

      final jobs = await printJobRepository.getActivePrintJobs();

      emit(PrintJobsLoaded(jobs: jobs));
    } catch (e) {
      emit(PrintJobError(e.toString()));
    }
  }

  Future<void> _onLoadPrintJob(
    LoadPrintJobEvent event,
    Emitter<PrintJobState> emit,
  ) async {
    try {
      emit(PrintJobLoading());

      final job = await printJobRepository.getPrintJob(event.jobId);

      if (job != null) {
        emit(PrintJobLoaded(job));
      } else {
        emit(const PrintJobError('Print job not found'));
      }
    } catch (e) {
      emit(PrintJobError(e.toString()));
    }
  }

  Future<void> _onWatchPrintJob(
    WatchPrintJobEvent event,
    Emitter<PrintJobState> emit,
  ) async {
    // Cancel existing subscription
    await _jobSubscription?.cancel();

    // Start watching the job
    _jobSubscription = printJobRepository.watchPrintJob(event.jobId).listen(
      (job) {
        add(PrintJobUpdatedEvent(job));
      },
      onError: (error) {
        add(PrintJobUpdatedEvent(null));
      },
    );
  }

  void _onPrintJobUpdated(
    PrintJobUpdatedEvent event,
    Emitter<PrintJobState> emit,
  ) {
    if (event.job != null) {
      emit(PrintJobLoaded(event.job!));
    } else {
      emit(const PrintJobError('Failed to get job updates'));
    }
  }

  Future<void> _onMarkAsCollected(
    MarkAsCollectedEvent event,
    Emitter<PrintJobState> emit,
  ) async {
    try {
      await printJobRepository.markAsCollected(event.jobId);

      emit(const PrintJobActionSuccess('Print marked as collected'));

      // Reload the job
      add(LoadPrintJobEvent(event.jobId));
    } catch (e) {
      emit(PrintJobError(e.toString()));
    }
  }

  Future<void> _onCancelPrintJob(
    CancelPrintJobEvent event,
    Emitter<PrintJobState> emit,
  ) async {
    try {
      await printJobRepository.cancelPrintJob(event.jobId);

      emit(const PrintJobActionSuccess('Print job cancelled'));
    } catch (e) {
      emit(PrintJobError(e.toString()));
    }
  }

  Future<void> _onLoadPrintHistory(
    LoadPrintHistoryEvent event,
    Emitter<PrintJobState> emit,
  ) async {
    try {
      if (event.page == 1) {
        emit(PrintJobLoading());
      }

      final jobs = await printJobRepository.getPrintHistory(
        page: event.page,
      );

      final currentState = state;
      if (currentState is PrintJobsLoaded && event.page > 1) {
        // Append to existing list
        emit(PrintJobsLoaded(
          jobs: [...currentState.jobs, ...jobs],
          hasMore: jobs.length >= 15,
        ));
      } else {
        emit(PrintJobsLoaded(
          jobs: jobs,
          hasMore: jobs.length >= 15,
        ));
      }
    } catch (e) {
      emit(PrintJobError(e.toString()));
    }
  }

  Future<void> _onLoadUserStats(
    LoadUserStatsEvent event,
    Emitter<PrintJobState> emit,
  ) async {
    try {
      final stats = await printJobRepository.getUserStats();

      emit(UserStatsLoaded(
        totalPrints: stats['totalPrints'] as int,
        totalSpent: stats['totalSpent'] as double,
        totalPages: stats['totalPages'] as int,
      ));
    } catch (e) {
      emit(PrintJobError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _jobSubscription?.cancel();
    return super.close();
  }
}

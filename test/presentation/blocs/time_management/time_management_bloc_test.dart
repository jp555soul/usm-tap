import 'package:flutter_test/flutter_test.dart';
import 'package:usm_tap/presentation/blocs/time_management/time_management_bloc.dart';

void main() {
  group('TimeManagementBloc', () {
    late TimeManagementBloc timeManagementBloc;

    setUp(() {
      timeManagementBloc = TimeManagementBloc();
    });

    tearDown(() {
      timeManagementBloc.close();
    });

    test('initial state has correct dynamic date range (Last 7 Days)', () {
      final state = timeManagementBloc.state as TimeManagementLoadedState;
      final now = DateTime.now().toUtc();
      
      // Allow for small time difference between test execution and bloc initialization
      final difference = now.difference(state.currentEndDate).inSeconds.abs();
      expect(difference, lessThan(5), reason: 'End date should be close to now');

      final expectedStartDate = state.currentEndDate.subtract(const Duration(days: 7));
      final differenceInMs = state.currentDate.difference(expectedStartDate).inMilliseconds.abs();
      expect(differenceInMs, lessThan(100), reason: 'Start date should be approximately 7 days before end date (allowing for execution time)');
    });
  });
}

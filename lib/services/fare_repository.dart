import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/fare_matrix.dart';

class FareMatrixRepository {
  SupabaseClient get _client => Supabase.instance.client;

  /// Fetch the current fare matrix immediately
  Future<List<FareMatrix>> fetchMatrix() async {
    final response =
        await _client.from('fare_matrix').select().eq('is_active', true);

    return (response as List).map((e) => FareMatrix.fromJson(e)).toList();
  }

  /// Listen to realtime changes on the fare_matrix table
  Stream<List<FareMatrix>> streamMatrix() {
    return _client
        .from('fare_matrix')
        .stream(primaryKey: ['id'])
        .eq('is_active', true)
        .map((events) => events.map((e) => FareMatrix.fromJson(e)).toList());
  }

  /// Update a specific vehicle's fare matrix
  Future<void> updateMatrix(FareMatrix matrix) async {
    await _client.from('fare_matrix').update({
      'base_fare': matrix.baseFare,
      'included_base_distance': matrix.includedBaseDistance,
      'per_km_rate': matrix.perKmRate,
      'minimum_fare': matrix.minimumFare,
    }).eq('id', matrix.id);
  }
}

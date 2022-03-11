// dao/person_dao.dart

import 'package:floor/floor.dart';
import 'package:gps_tracker/entitys/user_location.dart';

@dao
abstract class UserLocationDao {
  @Query('SELECT * FROM UserLocation')
  Future<List<UserLocation>> findAllUserLocation();

  @Query('SELECT * FROM UserLocation WHERE id = :id')
  Stream<UserLocation?> findUserLocationById(int id);

  @insert
  Future<void> insertUserLocation(UserLocation UserLocation);
}

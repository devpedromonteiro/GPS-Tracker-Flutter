import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as Geocoding;
import 'package:gps_tracker/entitys/user_location.dart';
import 'package:location/location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:gps_tracker/directions_model.dart';
import 'package:gps_tracker/directions_repository.dart';
import 'package:gps_tracker/db/database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp(
      db: await $FloorAppDatabase.databaseBuilder('app_database.db').build()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key, required this.db}) : super(key: key);
  final AppDatabase db;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: HomePage(
      db: db,
    ));
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key, required this.db}) : super(key: key);
  final AppDatabase db;
  @override
  _HomePageState createState() => _HomePageState(this.db);
}

class _HomePageState extends State<HomePage> {
  late bool _serviceEnabled; //verificar o GPS (on/off)
  late PermissionStatus _permissionGranted; //verificar a permissão de acesso
  LocationData? _userLocation;
  late String? address;
  late double? _latitude;
  late double? _longitude;
  GoogleMapController? _googleMapController;
  Marker? _origin;
  bool? _isTracking = false;
  Marker? _destination;
  Directions? _info;
  final AppDatabase db;
  late Timer _mytimer;
  _HomePageState(this.db);
  late UserLocation userLocation;
  late var result;
  var counter = 10;
  static CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(37.773972, -122.431297),
    zoom: 11.5,
  );

  CameraPosition _getCameraPosition(double latitude, double longitude) {
    return CameraPosition(
      target: LatLng(latitude, longitude),
      zoom: 11.5,
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _googleMapController = controller;
  }

  Future<void> _getUserLocation() async {
    Location location = Location();

    //1. verificar se o serviço de localização está ativado
    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    //2. solicitar a permissão para o app acessar a localização
    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    final _locationData = await location.getLocation();

    Future<List<Geocoding.Placemark>> places;
    double? lat;
    double? lng;
    setState(() {
      _userLocation = _locationData;
      lat = _userLocation!.latitude;
      lng = _userLocation!.longitude;
      _initialCameraPosition = CameraPosition(
        target: LatLng(lat!, lng!),
        zoom: 18,
      );

      places = Geocoding.placemarkFromCoordinates(lat!, lng!,
          localeIdentifier: "pt_BR");
      places.then((value) {
        Geocoding.Placemark place = value[1];
        address = place.street; //nome da rua
        print(_locationData.accuracy); //acurácia da localização
      });
    });
  }

  @override
  void dispose() {
    _googleMapController!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Google Maps'),
        actions: [
          if (_origin != null)
            TextButton(
              onPressed: () => _googleMapController!.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: _origin!.position,
                    zoom: 14.5,
                    tilt: 50.0,
                  ),
                ),
              ),
              style: TextButton.styleFrom(
                primary: Colors.green,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              child: const Text('ORIGIN'),
            ),
          if (_destination != null)
            TextButton(
              onPressed: () => {
                _googleMapController?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: _destination!.position,
                      zoom: 14.5,
                      tilt: 50.0,
                    ),
                  ),
                )
              },
              style: TextButton.styleFrom(
                primary: Colors.blue,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              child: const Text('DEST'),
            )
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          GoogleMap(
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            initialCameraPosition: _userLocation?.latitude != null
                ? _getCameraPosition(_userLocation!.latitude as double,
                    _userLocation!.longitude as double)
                : _initialCameraPosition,
            onMapCreated: (controller) => _googleMapController = controller,
            markers: {
              if (_origin != null) _origin!,
              if (_destination != null) _destination!
            },
            polylines: {
              if (_info != null)
                Polyline(
                  polylineId: const PolylineId('overview_polyline'),
                  color: Colors.red,
                  width: 5,
                  points: _info!.polylinePoints
                      .map((e) => LatLng(e.latitude, e.longitude))
                      .toList(),
                ),
            },
            onLongPress: _addMarker,
          ),
          if (_info != null)
            Positioned(
              top: 20.0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 6.0,
                  horizontal: 12.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.yellowAccent,
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      offset: Offset(0, 2),
                      blurRadius: 6.0,
                    )
                  ],
                ),
                child: Text(
                  '${_info!.totalDistance}, ${_info!.totalDuration}',
                  style: const TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // if (_userLocation != null)
                //   SizedBox(
                //     key: Key('mapa'),
                //     width: 380,
                //     height: 600,
                //     child: GoogleMap(
                //       myLocationButtonEnabled: false,
                //       zoomControlsEnabled: false,
                //       initialCameraPosition: _getCameraPosition(
                //           _userLocation!.latitude as double,
                //           _userLocation!.longitude as double),
                //     ),
                //   ),

                if (_userLocation != null)
                  Text(
                    'LAT: ${_userLocation!.latitude}, LNG: ${_userLocation!.longitude}' +
                        "\n",
                    // + addres pode ser usado aqui
                    textAlign: TextAlign.center,
                  ),
                ElevatedButton(
                    onPressed: () => {
                          _startTracking(),
                          // _mytimer?.cancel(),
                          _mytimer =
                              Timer.periodic(Duration(seconds: 5), (timer) async {
                            // counter--;
                            if (_isTracking!) {
                              // _mytimer?.cancel();
                              _getUserLocation();
                              print('teste');
                              
                              
                              userLocation = UserLocation(
                                  null,
                                  _userLocation!.latitude!,
                                  _userLocation!.longitude!);
                              await db.userLocationDao
                                  .insertUserLocation(userLocation);
                              result = db.userLocationDao
                                  .findUserLocationById(1);
                              print(result.toString());
                              print('snapshot.hasData?' ':' '');
                                      
                                  
                            }
                          })
                        },
                    child: Text(
                        _isTracking! ? 'Stop tracking' : 'Start tracking')),
                if (_userLocation != null)
                  SizedBox(
                    key: Key('mapa'),
                    width: 380,
                    height: 600,
                    child: FutureBuilder<List<UserLocation>>(
                      future: db.userLocationDao.findAllUserLocation(),
                      builder: (context, snapshot) {
                        return snapshot.hasData
                            ? ListView.builder(
                                itemCount: snapshot.data!.length,
                                itemBuilder: (context, index) {
                                  print(snapshot.data!.length);
                                  print(snapshot.data![index].latitude
                                      .toString());
                                  return Text(snapshot.data![index].latitude
                                          .toString() +
                                      " " +
                                      snapshot.data![0].longitude.toString());
                                })
                            : Text('teste');
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.black,
        onPressed: () => _googleMapController!.animateCamera(
          _info != null
              ? CameraUpdate.newLatLngBounds(_info!.bounds, 100.0)
              : CameraUpdate.newCameraPosition(_initialCameraPosition),
        ),
        child: const Icon(Icons.center_focus_strong),
      ),
    );
  }

  void _startTracking() {
    setState(() {
      _isTracking = !_isTracking!;
    });
  }

  void _addMarker(LatLng pos) async {
    if (_origin == null || (_origin != null && _destination != null)) {
      // Origin is not set OR Origin/Destination are both set
      // Set origin
      setState(() {
        _origin = Marker(
          markerId: const MarkerId('origin'),
          infoWindow: const InfoWindow(title: 'Origin'),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          position: pos,
        );
        // Reset destination
        _destination = null;

        // Reset info
        _info = null;
      });
    } else {
      // Origin is already set
      // Set destination
      setState(() {
        _destination = Marker(
          markerId: const MarkerId('destination'),
          infoWindow: const InfoWindow(title: 'Destination'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          position: pos,
        );
      });
    }
  }
}

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as Geocoding;
import 'package:location/location.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: HomePage());
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late bool _serviceEnabled; //verificar o GPS (on/off)
  late PermissionStatus _permissionGranted; //verificar a permissão de acesso
  LocationData? _userLocation;
  late String? address;

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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
                onPressed: _getUserLocation, child: Text('Get location')),
            if (_userLocation != null)
              Text(
                'LAT: ${_userLocation!.latitude}, LNG: ${_userLocation!.longitude}' +
                    "\n" +
                    address!,
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
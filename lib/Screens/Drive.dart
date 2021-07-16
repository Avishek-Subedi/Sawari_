import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uber/model/Highlighter.dart';
import 'package:uber/model/User.dart';
import 'package:uber/util/RequestStatus.dart';
import 'package:uber/util/UserFirebase.dart';

class Drive extends StatefulWidget {
  String idRequest;

  Drive(this.idRequest);

  @override
  _DriveState createState() => _DriveState();
}

class _DriveState extends State<Drive> {
  Completer<GoogleMapController> _controller = Completer();
  CameraPosition _posicaoCamera =
      CameraPosition(target: LatLng(-23.563999, -46.653256));
  Set<Marker> _marcadores = {};
  Map<String, dynamic> _dadosRequest;
  String _idRequest;
  Position _localDriver;
  String _statusRequest = StatusRequest.WAITING;

  //Controles para exibição na tela
  String _textoBotao = "Accept travel";
  Color _corBotao = Color(0xff1ebbd8);
  Function _funcaoBotao;
  String _mensagemStatus = "";

  _alterarBotaoPrincipal(String texto, Color cor, Function funcao) {
    setState(() {
      _textoBotao = texto;
      _corBotao = cor;
      _funcaoBotao = funcao;
    });
  }

  _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  _adicionarListenerLocalizacao() {
    var geolocator = Geolocator();
    var locationOptions =
        LocationOptions(accuracy: LocationAccuracy.high, distanceFilter: 10);

    geolocator.getPositionStream(locationOptions).listen((Position position) {
      if (position != null) {
        if (_idRequest != null && _idRequest.isNotEmpty) {
          if (_statusRequest != StatusRequest.WAITING) {
            //Atualiza local do passenger
            UserFirebase.atualizarDadosLocalizacao(
                _idRequest, position.latitude, position.longitude);
          } else {
            //waiting
            setState(() {
              _localDriver = position;
            });
            _statusAguardando();
          }
        }
      }
    });
  }

  _recuperaUltimaLocalizacaoConhecida() async {
    Position position = await Geolocator()
        .getLastKnownPosition(desiredAccuracy: LocationAccuracy.high);

    if (position != null) {
      //Atualizar localização em tempo real do driver
      if (position != null) {
        // _exibirHighlightPassenger(position);

        _posicaoCamera = CameraPosition(
            target: LatLng(position.latitude, position.longitude), zoom: 19);
        _localDriver = position;
        _movimentarCamera(_posicaoCamera);
      }
    }
  }

  _movimentarCamera(CameraPosition cameraPosition) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  _exibirHighlight(Position local, String icone, String infoWindow) async {
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio), icone)
        .then((BitmapDescriptor bitmapDescriptor) {
      Marker marcador = Marker(
          markerId: MarkerId(icone),
          position: LatLng(local.latitude, local.longitude),
          infoWindow: InfoWindow(title: infoWindow),
          icon: bitmapDescriptor);

      setState(() {
        _marcadores.add(marcador);
      });
    });
  }

  _recuperarRequest() async {
    String idRequest = widget.idRequest;

    Firestore db = Firestore.instance;
    DocumentSnapshot documentSnapshot =
        await db.collection("requests").document(idRequest).get();
  }

  _adicionarListenerRequest() async {
    Firestore db = Firestore.instance;

    await db
        .collection("requests")
        .document(_idRequest)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.data != null) {
        _dadosRequest = snapshot.data;

        Map<String, dynamic> dados = snapshot.data;
        _statusRequest = dados["status"];

        switch (_statusRequest) {
          case StatusRequest.WAITING:
            _statusAguardando();
            break;
          case StatusRequest.ON_MY_WAY:
            _statusACaminho();
            break;
          case StatusRequest.TRAVEL:
            _statusEmTravel();
            break;
          case StatusRequest.FINISHED:
            _statusFinalizada();
            break;
          case StatusRequest.CONFIRMED:
            _statusConfirmada();
            break;
        }
      }
    });
  }

  _aceitarDrive() async {
    //Recuperar dados do driver
    User driver = await UserFirebase.getDadosUserLogado();
    driver.latitude = _localDriver.latitude;
    driver.longitude = _localDriver.longitude;

    Firestore db = Firestore.instance;
    String idRequest = _dadosRequest["id"];

    db.collection("requests").document(idRequest).updateData({
      "driver": driver.toMap(),
      "status": StatusRequest.ON_MY_WAY,
    }).then((_) {
      //atualiza requisicao ativa
      String idPassenger = _dadosRequest["passenger"]["idUser"];
      db.collection("active_request").document(idPassenger).updateData({
        "status": StatusRequest.ON_MY_WAY,
      });

      //Salvar requisicao ativa para driver
      String idDriver = driver.idUser;
      db.collection("active_request_driver").document(idDriver).setData({
        "request_id": idRequest,
        "user_id": idDriver,
        "status": StatusRequest.ON_MY_WAY,
      });
    });
  }

  _statusAguardando() {
    _alterarBotaoPrincipal("Accept travel", Color(0xff1ebbd8), () {
      setState(() {
        _aceitarDrive();
      });
    });

    double latitudeDestination = _dadosRequest["passenger"]["latitude"];
    double longitudeDestination = _dadosRequest["passenger"]["longitude"];

    double latitudeOrigem = _dadosRequest["driver"]["latitude"];
    double longitudeOrigem = _dadosRequest["driver"]["longitude"];

    Highlight marcadorOrigem = Highlight(
        LatLng(latitudeOrigem, longitudeOrigem),
        "assets/images/driver.png",
        "Local driver");

    Highlight marcadorDestination = Highlight(
        LatLng(latitudeDestination, longitudeDestination),
        "assets/images/passenger.png",
        "Local destination");

    _exibirCentralizarDoisHighlightes(marcadorOrigem, marcadorDestination);
  }

  _statusACaminho() {
    _mensagemStatus = "On the way to passenger";
    _alterarBotaoPrincipal("Start travel", Color(0xff1ebbd8), () {
      _iniciarDrive();
    });
    double latitudeDestination = _dadosRequest["passenger"]["latitude"];
    double longitudeDestination = _dadosRequest["passenger"]["longitude"];

    double latitudeOrigem = _dadosRequest["driver"]["latitude"];
    double longitudeOrigem = _dadosRequest["driver"]["longitude"];

    Highlight marcadorOrigem = Highlight(
        LatLng(latitudeOrigem, longitudeOrigem),
        "assets/images/driver.png",
        "Local driver");

    Highlight marcadorDestination = Highlight(
        LatLng(latitudeDestination, longitudeDestination),
        "assets/images/passenger.png",
        "Local destination");

    _exibirCentralizarDoisHighlightes(marcadorOrigem, marcadorDestination);
  }

  _finalizarDrive() {
    Firestore db = Firestore.instance;
    db
        .collection("requests")
        .document(_idRequest)
        .updateData({"status": StatusRequest.FINISHED});

    String idPassenger = _dadosRequest["passenger"]["idUser"];
    db
        .collection("active_request")
        .document(idPassenger)
        .updateData({"status": StatusRequest.FINISHED});

    String idDriver = _dadosRequest["driver"]["idUser"];
    db
        .collection("active_request_driver")
        .document(idDriver)
        .updateData({"status": StatusRequest.FINISHED});
  }

  _statusFinalizada() async {
    //Calcula valor da travel
    double latitudeDestination = _dadosRequest["destination"]["latitude"];
    double longitudeDestination = _dadosRequest["destination"]["longitude"];

    double latitudeOrigem = _dadosRequest["origem"]["latitude"];
    double longitudeOrigem = _dadosRequest["origem"]["longitude"];

    double distanciaEmMetros = await Geolocator().distanceBetween(
        latitudeOrigem,
        longitudeOrigem,
        latitudeDestination,
        longitudeDestination);

    //Convert to Km
    double distanciaKm = distanciaEmMetros / 1000;

    //Rs 5 per Kilometer
    double valorTravel = distanciaKm * 5;

    //Format number
    var f = new NumberFormat("###.0#", "en_US");
    var valorTravelFormatado = f.format(valorTravel);

    _mensagemStatus = "Travel finished";
    _alterarBotaoPrincipal(
        "Confirm - रु $valorTravelFormatado", Color(0xff1ebbd8), () {
      _confirmarDrive();
    });

    _marcadores = {};
    Position position = Position(
        latitude: latitudeDestination, longitude: longitudeDestination);
    _exibirHighlight(position, "assets/images/destination.png", "Destination");

    CameraPosition cameraPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude), zoom: 19);

    _movimentarCamera(cameraPosition);
  }

  _statusConfirmada() {
    Navigator.pushReplacementNamed(context, "/painel-driver");
  }

  _confirmarDrive() {
    Firestore db = Firestore.instance;
    db
        .collection("requests")
        .document(_idRequest)
        .updateData({"status": StatusRequest.CONFIRMED});

    String idPassenger = _dadosRequest["passenger"]["idUser"];
    db.collection("active_request").document(idPassenger).delete();

    String idDriver = _dadosRequest["driver"]["idUser"];
    db.collection("active_request_driver").document(idDriver).delete();
  }

  _statusEmTravel() {
    _mensagemStatus = "In travel";
    _alterarBotaoPrincipal("Finish travel", Color(0xff1ebbd8), () {
      _finalizarDrive();
    });

    double latitudeDestination = _dadosRequest["destination"]["latitude"];
    double longitudeDestination = _dadosRequest["destination"]["longitude"];

    double latitudeOrigem = _dadosRequest["driver"]["latitude"];
    double longitudeOrigem = _dadosRequest["driver"]["longitude"];

    Highlight marcadorOrigem = Highlight(
        LatLng(latitudeOrigem, longitudeOrigem),
        "assets/images/driver.png",
        "Local driver");

    Highlight marcadorDestination = Highlight(
        LatLng(latitudeDestination, longitudeDestination),
        "assets/images/destination.png",
        "Local destination");

    _exibirCentralizarDoisHighlightes(marcadorOrigem, marcadorDestination);
  }

  _exibirCentralizarDoisHighlightes(
      Highlight marcadorOrigem, Highlight marcadorDestination) {
    double latitudeOrigem = marcadorOrigem.local.latitude;
    double longitudeOrigem = marcadorOrigem.local.longitude;

    double latitudeDestination = marcadorDestination.local.latitude;
    double longitudeDestination = marcadorDestination.local.longitude;

    //Exibir dois marcadores
    _exibirDoisHighlightes(marcadorOrigem, marcadorDestination);

    //'southwest.latitude <= northeast.latitude': is not true
    var nLat, nLon, sLat, sLon;

    if (latitudeOrigem <= latitudeDestination) {
      sLat = latitudeOrigem;
      nLat = latitudeDestination;
    } else {
      sLat = latitudeDestination;
      nLat = latitudeOrigem;
    }

    if (longitudeOrigem <= longitudeDestination) {
      sLon = longitudeOrigem;
      nLon = longitudeDestination;
    } else {
      sLon = longitudeDestination;
      nLon = longitudeOrigem;
    }
    //-23.560925, -46.650623
    _movimentarCameraBounds(LatLngBounds(
        northeast: LatLng(nLat, nLon), //nordeste
        southwest: LatLng(sLat, sLon) //sudoeste
        ));
  }

  _iniciarDrive() {
    Firestore db = Firestore.instance;
    db.collection("requests").document(_idRequest).updateData({
      "origem": {
        "latitude": _dadosRequest["driver"]["latitude"],
        "longitude": _dadosRequest["driver"]["longitude"]
      },
      "status": StatusRequest.TRAVEL
    });

    String idPassenger = _dadosRequest["passenger"]["idUser"];
    db
        .collection("active_request")
        .document(idPassenger)
        .updateData({"status": StatusRequest.TRAVEL});

    String idDriver = _dadosRequest["driver"]["idUser"];
    db
        .collection("active_request_driver")
        .document(idDriver)
        .updateData({"status": StatusRequest.TRAVEL});
  }

  _movimentarCameraBounds(LatLngBounds latLngBounds) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newLatLngBounds(latLngBounds, 100));
  }

  _exibirDoisHighlightes(
      Highlight marcadorOrigem, Highlight marcadorDestination) {
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    LatLng latLngOrigem = marcadorOrigem.local;
    LatLng latLngDestination = marcadorDestination.local;

    Set<Marker> _listaHighlightes = {};
    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio),
            marcadorOrigem.caminhoImagem)
        .then((BitmapDescriptor icone) {
      Marker mOrigem = Marker(
          markerId: MarkerId(marcadorOrigem.caminhoImagem),
          position: LatLng(latLngOrigem.latitude, latLngOrigem.longitude),
          infoWindow: InfoWindow(title: marcadorOrigem.titulo),
          icon: icone);
      _listaHighlightes.add(mOrigem);
    });

    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio),
            marcadorDestination.caminhoImagem)
        .then((BitmapDescriptor icone) {
      Marker mDestination = Marker(
          markerId: MarkerId(marcadorDestination.caminhoImagem),
          position:
              LatLng(latLngDestination.latitude, latLngDestination.longitude),
          infoWindow: InfoWindow(title: marcadorDestination.titulo),
          icon: icone);
      _listaHighlightes.add(mDestination);
    });

    setState(() {
      _marcadores = _listaHighlightes;
    });
  }

  @override
  void initState() {
    super.initState();

    _idRequest = widget.idRequest;

    // adicionar listener para mudanças na requisicao
    _adicionarListenerRequest();

    //_recuperaUltimaLocalizacaoConhecida();
    _adicionarListenerLocalizacao();

    //solves the problem?

    _recuperaUltimaLocalizacaoConhecida();
  }

  _escolhaMenuItem(String escolha) {
    switch (escolha) {
      case "Mapa 3D":
        // _deslogarUser();
        break;
    }
  }

  _deslogarUser() async {
    FirebaseAuth auth = FirebaseAuth.instance;

    await auth.signOut();
    Navigator.pushReplacementNamed(context, "/");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _mensagemStatus == ""
            ? Text("Panel travel")
            : Text("Panel travel - " + _mensagemStatus),
      ),
      body: Container(
        child: Stack(
          children: <Widget>[
            GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: _posicaoCamera,
              onMapCreated: _onMapCreated,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              markers: _marcadores,
              zoomControlsEnabled: false,
              //-23,559200, -46,658878
            ),
            Positioned(
              right: 0,
              left: 0,
              bottom: 0,
              child: Padding(
                padding: Platform.isIOS
                    ? EdgeInsets.fromLTRB(20, 10, 20, 25)
                    : EdgeInsets.all(10),
                child: RaisedButton(
                    child: Text(
                      _textoBotao,
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                    color: _corBotao,
                    padding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                    onPressed: _funcaoBotao),
              ),
            )
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:io';

import 'package:uber/model/Destination.dart';
import 'package:uber/model/Highlighter.dart';
import 'package:uber/model/Request.dart';
import 'package:uber/model/User.dart';
import 'package:uber/util/RequestStatus.dart';
import 'package:uber/util/UserFirebase.dart';

class PanelPassenger extends StatefulWidget {
  @override
  _PanelPassengerState createState() => _PanelPassengerState();
}

class _PanelPassengerState extends State<PanelPassenger> {
  TextEditingController _controllerDestination = TextEditingController();
  List<String> itensMenu = ["Logout"];
  Completer<GoogleMapController> _controller = Completer();
  CameraPosition _posicaoCamera =
      CameraPosition(target: LatLng(-23.563999, -46.653256));
  Set<Marker> _marcadores = {};
  String _idRequest;
  Position _localPassenger;
  Map<String, dynamic> _dadosRequest;
  StreamSubscription<DocumentSnapshot> _streamSubscriptionRequisicoes;

  //Controles para exibição na tela
  bool _exibirCaixaEnderecoDestination = true;
  String _textoBotao = "Call sawari";
  Color _corBotao = Color(0xff1ebbd8);
  Function _funcaoBotao;

  _deslogarUser() async {
    FirebaseAuth auth = FirebaseAuth.instance;

    await auth.signOut();
    Navigator.pushReplacementNamed(context, "/");
  }

  _escolhaMenuItem(String escolha) {
    switch (escolha) {
      case "Logout":
        _deslogarUser();
        break;
      case "Configurações":
        break;
    }
  }

  _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  _adicionarListenerLocalizacao() {
    var geolocator = Geolocator();
    var locationOptions =
        LocationOptions(accuracy: LocationAccuracy.high, distanceFilter: 10);

    geolocator.getPositionStream(locationOptions).listen((Position position) {
      if (_idRequest != null && _idRequest.isNotEmpty) {
        //Atualiza local do passenger
        UserFirebase.atualizarDadosLocalizacao(
            _idRequest, position.latitude, position.longitude);
      } else {
        setState(() {
          _localPassenger = position;
        });
        _statusUberNaoChamado();
      }
    });
  }

  _recuperaUltimaLocalizacaoConhecida() async {
    Position position = await Geolocator()
        .getLastKnownPosition(desiredAccuracy: LocationAccuracy.high);

    setState(() {
      if (position != null) {
        _exibirHighlightPassenger(position);

        _posicaoCamera = CameraPosition(
            target: LatLng(position.latitude, position.longitude), zoom: 19);
        _localPassenger = position;
        _movimentarCamera(_posicaoCamera);
      }
    });
  }

  _movimentarCamera(CameraPosition cameraPosition) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  _exibirHighlightPassenger(Position local) async {
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio),
            "assets/images/passenger.png")
        .then((BitmapDescriptor icone) {
      Marker marcadorPassenger = Marker(
          markerId: MarkerId("marcador-passenger"),
          position: LatLng(local.latitude, local.longitude),
          infoWindow: InfoWindow(title: "Meu local"),
          icon: icone);

      setState(() {
        _marcadores.add(marcadorPassenger);
      });
    });
  }

  _chamarUber() async {
    String enderecoDestination = _controllerDestination.text;

    if (enderecoDestination.isNotEmpty) {
      List<Placemark> listaEnderecos =
          await Geolocator().placemarkFromAddress(enderecoDestination);

      if (listaEnderecos != null && listaEnderecos.length > 0) {
        Placemark endereco = listaEnderecos[0];
        Destination destination = Destination();
        destination.cidade = endereco.administrativeArea;
        destination.cep = endereco.postalCode;
        destination.bairro = endereco.subLocality;
        destination.rua = endereco.thoroughfare;
        destination.numero = endereco.subThoroughfare;

        destination.latitude = endereco.position.latitude;
        destination.longitude = endereco.position.longitude;

        String enderecoConfirmacao;
        enderecoConfirmacao = "\n City: " + destination.cidade;
        enderecoConfirmacao +=
            "\n Road: " + destination.rua + ", " + destination.numero;
        enderecoConfirmacao += "\n Neighborhood: " + destination.bairro;
        enderecoConfirmacao += "\n Zip: " + destination.cep;

        showDialog(
            context: context,
            builder: (contex) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    //padding: EdgeInsets.fromLTRB(40, 16, 32, 16),
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          SizedBox(
                            height: 8,
                          ),
                          Center(
                            child: Text(
                              "Confirm",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.black,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(15),
                            child: Text(
                              enderecoConfirmacao,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: <Widget>[
                              FlatButton(
                                child: Text(
                                  "Cancel",
                                  style: TextStyle(
                                    color: Color(0xff1ebbd8),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: () => Navigator.pop(contex),
                              ),
                              FlatButton(
                                child: Text(
                                  "Confirm",
                                  style: TextStyle(
                                    color: Color(0xff1ebbd8),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                onPressed: () {
                                  //salvar requisicao
                                  _salvarRequest(destination);

                                  Navigator.pop(contex);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    decoration: BoxDecoration(
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          offset: Offset(1.0, 6.0),
                          blurRadius: 40.0,
                        ),
                      ],
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white.withOpacity(0.8),
                    ),
                    height: 280,
                    width: 280,
                  ),
                ],
              );
            });
      }
    }
  }

  _salvarRequest(Destination destination) async {
    /*

    + requisicao
      + ID_REQUISICAO
        + destination(rua, endereco, latitude...)
        + passenger (name, email...)
        + driver (name, email..)
        + status (waiting, on_my_way...finished)

    * */

    User passenger = await UserFirebase.getDadosUserLogado();
    passenger.latitude = _localPassenger.latitude;
    passenger.longitude = _localPassenger.longitude;

    Request requisicao = Request();
    requisicao.destination = destination;
    requisicao.passenger = passenger;
    requisicao.status = StatusRequest.WAITING;

    Firestore db = Firestore.instance;

    //salvar requisição
    db
        .collection("requests")
        .document(requisicao.id)
        .setData(requisicao.toMap());

    //Salvar requisição ativa
    Map<String, dynamic> dadosRequestAtiva = {};
    dadosRequestAtiva["request_id"] = requisicao.id;
    dadosRequestAtiva["user_id"] = passenger.idUser;
    dadosRequestAtiva["status"] = StatusRequest.WAITING;

    db
        .collection("active_request")
        .document(passenger.idUser)
        .setData(dadosRequestAtiva);

    //Adicionar listener requisicao
    if (_streamSubscriptionRequisicoes == null) {
      _adicionarListenerRequest(requisicao.id);
    }
  }

  _alterarBotaoPrincipal(String texto, Color cor, Function funcao) {
    setState(() {
      _textoBotao = texto;
      _corBotao = cor;
      _funcaoBotao = funcao;
    });
  }

  _statusUberNaoChamado() {
    _exibirCaixaEnderecoDestination = true;

    _alterarBotaoPrincipal("Call sawari", Color(0xff1ebbd8), () {
      _chamarUber();
    });

    if (_localPassenger != null) {
      Position position = Position(
          latitude: _localPassenger.latitude,
          longitude: _localPassenger.longitude);
      _exibirHighlightPassenger(position);
      CameraPosition cameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude), zoom: 19);
      _movimentarCamera(cameraPosition);
    }
  }

  _statusAguardando() {
    _exibirCaixaEnderecoDestination = false;

    _alterarBotaoPrincipal("Cancel", Colors.red, () {
      _cancelarUber();
    });

    double passengerLat = _dadosRequest["passenger"]["latitude"];
    double passengerLon = _dadosRequest["passenger"]["longitude"];
    Position position =
        Position(latitude: passengerLat, longitude: passengerLon);
    _exibirHighlightPassenger(position);
    CameraPosition cameraPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude), zoom: 19);
    _movimentarCamera(cameraPosition);
  }

  _statusACaminho() {
    _exibirCaixaEnderecoDestination = false;

    _alterarBotaoPrincipal("Driver on the way", Colors.grey, () {});

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

  _statusEmTravel() {
    _exibirCaixaEnderecoDestination = false;
    _alterarBotaoPrincipal("In travel", Colors.grey, null);

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

    //Converte para KM
    double distanciaKm = distanciaEmMetros / 1000;

    //8 é o valor cobrado por KM
    double valorTravel = distanciaKm * 5;

    //Formatar valor travel
    var f = new NumberFormat("###.0#", "en_US");
    var valorTravelFormatado = f.format(valorTravel);

    _alterarBotaoPrincipal(
        "Total - रु $valorTravelFormatado", Colors.green, () {});

    _marcadores = {};
    Position position = Position(
        latitude: latitudeDestination, longitude: longitudeDestination);
    _exibirHighlight(position, "assets/images/destination.png", "Destination");

    CameraPosition cameraPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude), zoom: 19);

    _movimentarCamera(cameraPosition);
  }

  _statusConfirmada() {
    if (_streamSubscriptionRequisicoes != null)
      _streamSubscriptionRequisicoes.cancel();

    Navigator.pushReplacementNamed(context, "/painel-passenger");

    // _exibirCaixaEnderecoDestination = true;
    // _alterarBotaoPrincipal("Call sawari", Color(0xff1ebbd8), () {
    //   _chamarUber();
    // });

    // setState(() {
    //   _dadosRequest = {};
    // });
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

  _cancelarUber() async {
    FirebaseUser firebaseUser = await UserFirebase.getUserAtual();

    Firestore db = Firestore.instance;
    db
        .collection("requests")
        .document(_idRequest)
        .updateData({"status": StatusRequest.CANCELLED}).then((_) {
      db.collection("active_request").document(firebaseUser.uid).delete();
    });
  }

  _recuperaRequestAtiva() async {
    FirebaseUser firebaseUser = await UserFirebase.getUserAtual();

    Firestore db = Firestore.instance;
    DocumentSnapshot documentSnapshot =
        await db.collection("active_request").document(firebaseUser.uid).get();

    if (documentSnapshot.data != null) {
      Map<String, dynamic> dados = documentSnapshot.data;
      _idRequest = dados["request_id"];
      _adicionarListenerRequest(_idRequest);
    } else {
      _statusUberNaoChamado();
    }
  }

  _adicionarListenerRequest(String idRequest) async {
    Firestore db = Firestore.instance;
    _streamSubscriptionRequisicoes = await db
        .collection("requests")
        .document(idRequest)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.data != null) {
        Map<String, dynamic> dados = snapshot.data;
        _dadosRequest = dados;
        String status = dados["status"];
        _idRequest = dados["request_id"];

        switch (status) {
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

  @override
  void initState() {
    super.initState();

    //adicionar listener para requisicao ativa
    _recuperaRequestAtiva();

    //_recuperaUltimaLocalizacaoConhecida();
    _adicionarListenerLocalizacao();

    // solves the problem?
    _recuperaUltimaLocalizacaoConhecida();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Passenger Panel"),
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: _escolhaMenuItem,
            itemBuilder: (context) {
              return itensMenu.map((String item) {
                return PopupMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList();
            },
          )
        ],
      ),
      body: Container(
        child: Stack(
          children: <Widget>[
            GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: _posicaoCamera,
              onMapCreated: _onMapCreated,
              // myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              markers: _marcadores,
              //-23,559200, -46,658878
            ),
            Visibility(
              visible: _exibirCaixaEnderecoDestination,
              child: Stack(
                children: <Widget>[
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Container(
                        height: 50,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(3),
                          color: Colors.white.withOpacity(0.9),
                        ),
                        child: TextField(
                          readOnly: true,
                          decoration: InputDecoration(
                            icon: Container(
                              margin: EdgeInsets.only(left: 20),
                              width: 10,
                              height: 30,
                              child: Icon(
                                Icons.location_on,
                                color: Colors.green,
                              ),
                            ),
                            hintText: "My Location",
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.only(left: 15),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 55,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Container(
                        height: 50,
                        width: double.infinity,
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(3),
                            color: Colors.white.withOpacity(0.9)),
                        child: TextField(
                          controller: _controllerDestination,
                          decoration: InputDecoration(
                            icon: Container(
                              margin: EdgeInsets.only(left: 20),
                              width: 10,
                              height: 30,
                              child: Icon(
                                Icons.local_taxi,
                                color: Colors.black,
                              ),
                            ),
                            hintText: "Enter a destination",
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.only(left: 15),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
                  onPressed: _funcaoBotao,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _streamSubscriptionRequisicoes.cancel();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'Destination.dart';
import 'User.dart';

class Request {
  String _id;
  String _status;
  User _passenger;
  User _driver;
  Destination _destination;

  Request() {
    Firestore db = Firestore.instance;

    DocumentReference ref = db.collection("requests").document();
    this.id = ref.documentID;
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> dadosPassenger = {
      "name": this.passenger.name,
      "email": this.passenger.email,
      "typeUser": this.passenger.typeUser,
      "idUser": this.passenger.idUser,
      "latitude": this.passenger.latitude,
      "longitude": this.passenger.longitude,
    };

    Map<String, dynamic> dadosDestination = {
      "rua": this.destination.rua,
      "numero": this.destination.numero,
      "bairro": this.destination.bairro,
      "cep": this.destination.cep,
      "latitude": this.destination.latitude,
      "longitude": this.destination.longitude,
    };

    Map<String, dynamic> dadosRequest = {
      "id": this.id,
      "status": this.status,
      "passenger": dadosPassenger,
      "driver": null,
      "destination": dadosDestination,
    };

    return dadosRequest;
  }

  Destination get destination => _destination;

  set destination(Destination value) {
    _destination = value;
  }

  User get driver => _driver;

  set driver(User value) {
    _driver = value;
  }

  User get passenger => _passenger;

  set passenger(User value) {
    _passenger = value;
  }

  String get status => _status;

  set status(String value) {
    _status = value;
  }

  String get id => _id;

  set id(String value) {
    _id = value;
  }
}

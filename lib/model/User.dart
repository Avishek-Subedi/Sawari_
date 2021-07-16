class User {
  String _idUser;
  String _name;
  String _email;
  String _senha;
  String _typeUser;

  double _latitude;
  double _longitude;

  User();

  double get latitude => _latitude;

  set latitude(double value) {
    _latitude = value;
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      "idUser": this.idUser,
      "name": this.name,
      "email": this.email,
      "typeUser": this.typeUser,
      "latitude": this.latitude,
      "longitude": this.longitude,
    };

    return map;
  }

  String verificaTipoUser(bool typeUser) {
    return typeUser ? "driver" : "passenger";
  }

  String get typeUser => _typeUser;

  set typeUser(String value) {
    _typeUser = value;
  }

  String get senha => _senha;

  set senha(String value) {
    _senha = value;
  }

  String get email => _email;

  set email(String value) {
    _email = value;
  }

  String get name => _name;

  set name(String value) {
    _name = value;
  }

  String get idUser => _idUser;

  set idUser(String value) {
    _idUser = value;
  }

  double get longitude => _longitude;

  set longitude(double value) {
    _longitude = value;
  }
}

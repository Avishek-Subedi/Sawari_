import 'package:flutter/material.dart';
import 'package:uber/screens/Drive.dart';
import 'package:uber/screens/Register.dart';
import 'package:uber/screens/Home.dart';
import 'package:uber/screens/DriverPanel.dart';
import 'package:uber/screens/PassengerPanel.dart';

class Routes {
  static Route<dynamic> gerarRoutes(RouteSettings settings) {
    final args = settings.arguments;

    switch (settings.name) {
      case "/":
        return MaterialPageRoute(builder: (_) => Home());
      case "/cadastro":
        return MaterialPageRoute(builder: (_) => Register());
      case "/painel-driver":
        return MaterialPageRoute(builder: (_) => PanelDriver());
      case "/painel-passenger":
        return MaterialPageRoute(builder: (_) => PanelPassenger());
      case "/travel":
        return MaterialPageRoute(builder: (_) => Drive(args));
      default:
        _erroRota();
    }
  }

  static Route<dynamic> _erroRota() {
    return MaterialPageRoute(builder: (_) {
      return Scaffold(
        appBar: AppBar(
          title: Text("Tela não encontrada!"),
        ),
        body: Center(
          child: Center(
            child: Text(
              "Tela não encontrada!",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    });
  }
}

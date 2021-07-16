import 'package:flutter/material.dart';
import 'package:uber/screens/Home.dart';
import 'Routes.dart';

final ThemeData temaPadrao = ThemeData(
  primaryColor: Color(0xff37474f),
  accentColor: Color(0xff546e7a),
  fontFamily: 'BunueloCleanPro-Regular',
);

void main() => runApp(
      MaterialApp(
        title: "Sawari",
        home: Home(),
        theme: temaPadrao,
        initialRoute: "/",
        onGenerateRoute: Routes.gerarRoutes,
        debugShowCheckedModeBanner: false,
      ),
    );

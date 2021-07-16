import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uber/model/User.dart';

class UserFirebase {
  static Future<FirebaseUser> getUserAtual() async {
    FirebaseAuth auth = FirebaseAuth.instance;
    return await auth.currentUser();
  }

  static Future<User> getDadosUserLogado() async {
    FirebaseUser firebaseUser = await getUserAtual();
    String idUser = firebaseUser.uid;

    Firestore db = Firestore.instance;

    DocumentSnapshot snapshot =
        await db.collection("users").document(idUser).get();

    Map<String, dynamic> dados = snapshot.data;
    String typeUser = dados["typeUser"];
    String email = dados["email"];
    String name = dados["name"];

    User usuario = User();
    usuario.idUser = idUser;
    usuario.typeUser = typeUser;
    usuario.email = email;
    usuario.name = name;

    return usuario;
  }

  static atualizarDadosLocalizacao(
      String idRequest, double lat, double lon) async {
    Firestore db = Firestore.instance;

    User driver = await getDadosUserLogado();
    driver.latitude = lat;
    driver.longitude = lon;

    db.collection("requests").document(idRequest).updateData(
      {
        "driver": driver.toMap(),
      },
    );
  }
}

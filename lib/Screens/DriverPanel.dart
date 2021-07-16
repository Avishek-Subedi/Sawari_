import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uber/util/RequestStatus.dart';
import 'package:uber/util/UserFirebase.dart';

class PanelDriver extends StatefulWidget {
  @override
  _PanelDriverState createState() => _PanelDriverState();
}

class _PanelDriverState extends State<PanelDriver> {
  List<String> itensMenu = ["Logout"];
  final _controller = StreamController<QuerySnapshot>.broadcast();
  Firestore db = Firestore.instance;

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
      case "Settings":
        break;
    }
  }

  Stream<QuerySnapshot> _adicionarListenerRequisicoes() {
    final stream = db
        .collection("requests")
        .where("status", isEqualTo: StatusRequest.WAITING)
        .snapshots();

    stream.listen((dados) {
      _controller.add(dados);
    });

    return stream;
  }

  _recuperaRequestAtivaDriver() async {
    //Recupera dados do usuario logado
    FirebaseUser firebaseUser = await UserFirebase.getUserAtual();

    //Recupera requisicao ativa
    DocumentSnapshot documentSnapshot = await db
        .collection("active_request_driver")
        .document(firebaseUser.uid)
        .get();

    var dadosRequest = documentSnapshot.data;

    if (dadosRequest == null) {
      _adicionarListenerRequisicoes();
    } else {
      String idRequest = dadosRequest["request_id"];
      Navigator.pushReplacementNamed(context, "/travel", arguments: idRequest);
    }
  }

  @override
  void initState() {
    super.initState();

    /*
    Recupera requisicao ativa para verificar se driver está
    atendendo alguma requisição e envia ele para tela de travel
    */
    _recuperaRequestAtivaDriver();
  }

  @override
  Widget build(BuildContext context) {
    var mensagemCarregando = Container(
      decoration: BoxDecoration(
        image: DecorationImage(
            image: AssetImage("assets/images/fundo.png"), fit: BoxFit.cover),
      ),
      child: Column(
        // crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Center(
            child: Container(
              //padding: EdgeInsets.fromLTRB(40, 16, 32, 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Image.asset(
                        'assets/images/icon.png',
                        width: 50,
                        height: 45,
                      ),
                      Text(
                        "SAWARI",
                        style: TextStyle(
                          fontSize: 30,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 8,
                  ),
                  Text(
                    "Loading Requests",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(
                    height: 8,
                  ),
                  CircularProgressIndicator(),
                ],
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
                color: Colors.white.withOpacity(0.7),
              ),
              height: 200,
              width: 250,
            ),
          ),
        ],
      ),
    );

    var mensagemNaoTemDados = Container(
      decoration: BoxDecoration(
        image: DecorationImage(
            image: AssetImage("assets/images/fundo.png"), fit: BoxFit.cover),
      ),
      child: Column(
        // crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Center(
            child: Container(
              //padding: EdgeInsets.fromLTRB(40, 16, 32, 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Image.asset(
                        'assets/images/icon.png',
                        width: 50,
                        height: 45,
                      ),
                      Text(
                        "SAWARI",
                        style: TextStyle(
                          fontSize: 30,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 8,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(30, 8, 16, 8),
                    child: Text(
                      "You have no requests!",
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
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
                color: Colors.white.withOpacity(0.7),
              ),
              height: 200,
              width: 250,
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text("Driver Panel"),
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
        decoration: BoxDecoration(
          image: DecorationImage(
              image: AssetImage("assets/images/fundo.png"), fit: BoxFit.cover),
        ),
        child: StreamBuilder<QuerySnapshot>(
            stream: _controller.stream,
            builder: (context, snapshot) {
              switch (snapshot.connectionState) {
                case ConnectionState.none:
                case ConnectionState.waiting:
                  return mensagemCarregando;
                  break;
                case ConnectionState.active:
                case ConnectionState.done:
                  if (snapshot.hasError) {
                    return Text("Error Loading Data!");
                  } else {
                    QuerySnapshot querySnapshot = snapshot.data;
                    if (querySnapshot.documents.length == 0) {
                      return mensagemNaoTemDados;
                    } else {
                      return ListView.separated(
                          itemCount: querySnapshot.documents.length,
                          separatorBuilder: (context, indice) => Divider(
                                height: 0,
                                //color: Colors.grey,
                              ),
                          itemBuilder: (context, indice) {
                            List<DocumentSnapshot> requests =
                                querySnapshot.documents.toList();
                            DocumentSnapshot item = requests[indice];

                            String idRequest = item["id"];
                            String namePassenger = item["passenger"]["name"];
                            String rua = item["destination"]["rua"];
                            String numero = item["destination"]["numero"];

                            return Padding(
                              padding: EdgeInsets.fromLTRB(8, 8, 8, 4),
                              child: Container(
                                decoration: BoxDecoration(
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.5),
                                      offset: Offset(1.0, 6.0),
                                      blurRadius: 40.0,
                                    ),
                                  ],
                                  color: Colors.white.withOpacity(0.8),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(10),
                                    topRight: const Radius.circular(10),
                                    bottomLeft: const Radius.circular(10),
                                    bottomRight: const Radius.circular(10),
                                  ),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(8),
                                  child: ListTile(
                                    title: Text(
                                      namePassenger,
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    subtitle: Text(
                                      "destination: $rua, $numero",
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    onTap: () {
                                      Navigator.pushNamed(context, "/travel",
                                          arguments: idRequest);
                                    },
                                  ),
                                ),
                              ),
                            );
                          });
                    }
                  }

                  break;
              }
              return Center(
                child: CircularProgressIndicator(),
              );
            }),
      ),
    );
  }
}

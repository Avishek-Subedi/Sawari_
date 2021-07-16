import 'package:flutter/material.dart';
import 'package:uber/model/User.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  TextEditingController _controllerEmail = TextEditingController();
  TextEditingController _controllerPassword = TextEditingController();
  String _mensagemErro = "";
  bool _carregando = false;

  _validarCampos() {
    //Recuperar dados dos campos
    String email = _controllerEmail.text;
    String senha = _controllerPassword.text;

    //validar campos
    if (email.isNotEmpty && email.contains("@")) {
      if (senha.isNotEmpty && senha.length > 6) {
        User usuario = User();
        usuario.email = email;
        usuario.senha = senha;

        _logarUser(usuario);
      } else {
        setState(() {
          _mensagemErro = "Preencha a senha! digite mais de 6 caracteres";
        });
      }
    } else {
      setState(() {
        _mensagemErro = "Preencha o E-mail válido";
      });
    }
  }

  _logarUser(User usuario) {
    setState(() {
      _carregando = true;
    });

    FirebaseAuth auth = FirebaseAuth.instance;

    auth
        .signInWithEmailAndPassword(
            email: usuario.email, password: usuario.senha)
        .then((firebaseUser) {
      _redirecionaPanelPorTipoUser(firebaseUser.user.uid);
    }).catchError((error) {
      _mensagemErro =
          "Erro ao autenticar usuário, verifique e-mail e senha e tente novamente!";
    });
  }

  _redirecionaPanelPorTipoUser(String idUser) async {
    Firestore db = Firestore.instance;

    DocumentSnapshot snapshot =
        await db.collection("users").document(idUser).get();

    Map<String, dynamic> dados = snapshot.data;
    String typeUser = dados["typeUser"];

    setState(() {
      _carregando = false;
    });

    switch (typeUser) {
      case "driver":
        Navigator.pushReplacementNamed(context, "/painel-driver");
        break;
      case "passenger":
        Navigator.pushReplacementNamed(context, "/painel-passenger");
        break;
    }
  }

  _verificarUserLogado() async {
    FirebaseAuth auth = FirebaseAuth.instance;

    FirebaseUser usuarioLogado = await auth.currentUser();
    if (usuarioLogado != null) {
      String idUser = usuarioLogado.uid;
      _redirecionaPanelPorTipoUser(idUser);
    }
  }

  @override
  void initState() {
    super.initState();
    _verificarUserLogado();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
              image: AssetImage("assets/images/fundo.png"), fit: BoxFit.cover),
        ),
        padding: EdgeInsets.all(16),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(bottom: 32),
                  child: Container(
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 100,
                      height: 100,
                    ),
                    decoration: BoxDecoration(
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withOpacity(0.8),
                          offset: Offset(1.0, 6.0),
                          blurRadius: 40.0,
                        ),
                      ],
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.blueGrey,
                    ),
                    height: 140,
                    width: 130,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Material(
                      borderRadius: BorderRadius.circular(6),
                      elevation: 30.0,
                      shadowColor: Colors.black,
                      child: TextField(
                        controller: _controllerEmail,
                        autofocus: true,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(fontSize: 20),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                          hintText: "E-mail",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 4,
                    ),
                    Material(
                      borderRadius: BorderRadius.circular(6),
                      elevation: 30.0,
                      shadowColor: Colors.black,
                      child: TextField(
                        controller: _controllerPassword,
                        obscureText: true,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(fontSize: 20),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                          hintText: "Password",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 16, bottom: 10),
                      child: Material(
                        borderRadius: BorderRadius.circular(6),
                        elevation: 30.0,
                        shadowColor: Colors.black,
                        child: RaisedButton(
                            child: Text(
                              "Login",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                            color: Color(0xff1ebbd8),
                            padding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                            onPressed: () {
                              _validarCampos();
                            }),
                      ),
                    ),
                    Container(
                      child: Center(
                        child: GestureDetector(
                          child: Column(
                            children: <Widget>[
                              Text(
                                "No Account? Register Now!",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, "/cadastro");
                          },
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 8,
                    ),
                    _carregando
                        ? Center(
                            child: CircularProgressIndicator(
                              backgroundColor: Colors.white,
                            ),
                          )
                        : Container(),
                    Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Center(
                        child: Text(
                          _mensagemErro,
                          style: TextStyle(color: Colors.red, fontSize: 20),
                        ),
                      ),
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

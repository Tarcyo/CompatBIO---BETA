import 'package:flutter/material.dart';

class User {
  final int id;
  final String nome;
  final String email;
  final String? tipoUsuario;
  final String? empresa; // <-- novo campo
  final String token;

  User({
    required this.id,
    required this.nome,
    required this.email,
    this.tipoUsuario,
    this.empresa, // <-- novo campo no construtor
    required this.token,
  });
}

class UserProvider with ChangeNotifier {
  User? _user;

  User? get user => _user;
  bool get isLoggedIn => _user != null;

  void setUser(User user) {
    _user = user;
    notifyListeners();
  }

  void logout() {
    _user = null;
    notifyListeners();
  }
}

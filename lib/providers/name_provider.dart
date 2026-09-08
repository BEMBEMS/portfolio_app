import 'package:flutter/material.dart';

class NameProvider extends ChangeNotifier {
  String _userName = "Student";

  String get userName => _userName;

  void setUserName(String name) {
    _userName = name;
    notifyListeners();
  }
}

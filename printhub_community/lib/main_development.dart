import 'package:flutter/material.dart';
import 'core/config/app_flavor.dart';
import 'main.dart' as app;

void main() {
  AppFlavor.setFlavor('development');
  app.main();
}

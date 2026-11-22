import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'app.dart';

void main() {
  runApp(IWasHereApp(api: ApiClient(baseUrl: ApiClient.apiBaseFromEnvironment)));
}

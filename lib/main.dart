import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:prueba_login2/api.dart';

void main() {
  runApp(const MyApp());
}

class Usuario {
  final String first_name;
  final String last_name;
  final String email;
  final String password;
  final String CED_User;

  Usuario(
      {this.first_name = '',
      this.last_name = '',
      this.email = '',
      this.password = '',
      this.CED_User = ''});
}

Future<void> login(user, password) async {}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'login'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Usuario _usuario = Usuario();
  ApiClient _apiClient = ApiClient();
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenHeight = screenSize.height;
    final double screenWidth = screenSize.width;

    final TextEditingController emailControlador = TextEditingController();
    final TextEditingController passwordControlador = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Container(
          height: screenHeight * 0.5,
          width: screenWidth * 0.4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text('Hola, ${_usuario.email}, ${_usuario.first_name}'),
              Padding(padding: EdgeInsets.only(bottom: 20)),
              TextFormField(
                controller: emailControlador,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Username',
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              TextFormField(
                controller: passwordControlador,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Password',
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              ElevatedButton(
                onPressed: () async {
                  final Map<String, dynamic> datos = {
                    'email': emailControlador.text,
                    'password': passwordControlador.text,
                  };
                  try {
                    final response = await _apiClient.post(
                      Uri.parse('http://54.164.87.195/api/login/'),
                      body: jsonEncode(datos),
                    );

                    if (response.statusCode == 200) {
                      final data = jsonDecode(response.body);
                      final userData = data['user'];
                      print(userData);
                      Usuario usuario = Usuario(
                          email: userData['email'],
                          password: userData['password'],
                          first_name: userData['first_name'],
                          last_name: userData['last_name'],
                          CED_User: userData['CED_User']);
                      setState(() {
                        _usuario = usuario;
                      });
                      //Guarda el token de acceso y el token de actualización en el almacenamiento seguro
                      await _storage.write(
                          key: 'accessToken', value: 'eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJ0b2tlbl90eXBlIjoiYWNjZXNzIiwiZXhwIjoxNzAwMTc5MjkxLCJpYXQiOjE3MDAxNzgzOTEsImp0aSI6ImEyNDg1ODhiYzViYTQ5YWFiOTA2OTMxMjY1MGQ1ZGY2IiwidXNlcl9pZCI6Mn0.T59KqalL7i5iiVU3n-JwzMmgO0qOiXN9jKShNcCJJ8WVL_kk5gtINlYT3YnG0L7jDylSkQfp8Wpf_iuLZEmE8w');
                      await _storage.write(
                          key: 'refreshToken', value: data['refresh_token']);
                    } else {
                      print(
                          'La solicitud falló con el mensaje: ${response.reasonPhrase}.');
                      print(response.body);
                    }
                  } catch (e) {
                    print('Error: $e');
                    //print error details
                    print('Error Details: ${e.runtimeType}');
                  }
                },
                child: const Text('Login'),
              ),
              ElevatedButton(
                  onPressed: () async {
                    final response = await _apiClient.get(
                      Uri.parse(
                          'http://54.164.87.195/api/alumno/?search=${_usuario.CED_User}'),
                    );
                    if (response.statusCode == 200) {
                      final data = jsonDecode(response.body);
                      final alumnoData = data[0];
                      print(alumnoData);
                      setState(() {
                        _usuario = Usuario(
                            first_name: alumnoData['NOM1_ALU'],
                            last_name: _usuario.last_name,
                            email: _usuario.email,
                            password: _usuario.password,
                            CED_User: _usuario.CED_User);
                      });
                    } else {
                      print(
                          'La solicitud falló con el mensaje: ${response.reasonPhrase}.');
                      print(response.body);
                    }
                  },
                  child: Text('Mamachola'))
            ],
          ),
        ),
      ),
    );
  }
}

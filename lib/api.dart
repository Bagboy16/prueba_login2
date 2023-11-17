import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart';

class ApiClient extends http.BaseClient {
  // Cliente HTTP interno para enviar solicitudes
  final http.Client _inner = http.Client();
  // Almacenamiento seguro para leer y escribir tokens de acceso
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    // Leer el token de acceso del almacenamiento seguro
    String? accessToken = await _storage.read(key: 'accessToken');

    // Si el token de acceso existe y la solicitud no es para login o refresh,
    // agregar el token de acceso al encabezado de autorización
    if (accessToken != null &&
        !request.url.path.endsWith('/login/') &&
        !request.url.path.endsWith('/refresh/')) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }

    // Agregar el encabezado de tipo de contenido a la solicitud
    request.headers['Content-Type'] = 'application/json';

    // Enviar la solicitud y recibir la respuesta
    StreamedResponse response = await _inner.send(request);

    // Leer el cuerpo de la respuesta en una lista de bytes
    List<int> responseBodyBytes = await response.stream.toBytes();

    // Crear una nueva respuesta con el cuerpo de la respuesta y otros detalles
    StreamedResponse responseWithBody = http.StreamedResponse(
      Stream.fromIterable([responseBodyBytes]),
      response.statusCode,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
      request: response.request,
    );

    // Decodificar el cuerpo de la respuesta
    String responseBody = utf8.decode(responseBodyBytes);
    // Si el código de estado de la respuesta es 401 y el código es "token_not_valid",
    // entonces el token de acceso ha expirado y se debe solicitar un nuevo token de acceso
    if (response.statusCode == 401 &&
        jsonDecode(responseBody)['code'] == 'token_not_valid') {
      // Leer el token de actualización del almacenamiento seguro
      String? refreshToken = await _storage.read(key: 'refreshToken');

      // Enviar una solicitud POST a la URL de actualización del token
      var refreshResponse = await _inner.post(
        Uri.parse('http://54.164.87.195/api/token/refresh/'),
        body: {'refresh': refreshToken},
      );

      // Si la respuesta a la solicitud de actualización del token tiene un código de estado 200,
      // extraer el nuevo token de acceso y escribirlo en el almacenamiento seguro
      if (refreshResponse.statusCode == 200) {
        String newAccessToken = jsonDecode(refreshResponse.body)['access'];
        await _storage.write(key: 'accessToken', value: newAccessToken);

        // Crear una nueva solicitud con el nuevo token de acceso en el encabezado de autorización
        BaseRequest newRequest = http.Request(request.method, request.url)
          ..headers['Authorization'] = 'Bearer $newAccessToken'
          ..headers['Content-Type'] = 'application/json';

        // Reenviar la solicitud y recibir la nueva respuesta
        response = await _inner.send(newRequest);
        responseBodyBytes = await response.stream.toBytes();
        responseWithBody = http.StreamedResponse(
          Stream.fromIterable([responseBodyBytes]),
          response.statusCode,
          headers: response.headers,
          isRedirect: response.isRedirect,
          persistentConnection: response.persistentConnection,
          reasonPhrase: response.reasonPhrase,
          request: response.request,
        );
      }
    }

    // Devolver la respuesta
    return responseWithBody;
  }
}

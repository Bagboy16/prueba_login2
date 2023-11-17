import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart';

class ApiClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
// Obtén el token de acceso del almacenamiento seguro
    String? accessToken = await _storage.read(key: 'accessToken');

// Si el token de acceso existe y la solicitud no es para el login o el refresh del token,
// agrega el token de acceso al encabezado de autorización
    if (accessToken != null &&
        !request.url.path.endsWith('/login/') &&
        !request.url.path.endsWith('/refresh/')) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }

    //Agrega el encabezado de tipo de contenido a la solicitud
    request.headers['Content-Type'] = 'application/json';

    StreamedResponse response = await _inner.send(request);

    List<int> responseBodyBytes = await response.stream.toBytes();

    StreamedResponse responseWithBody = http.StreamedResponse(
      Stream.fromIterable([responseBodyBytes]),
      response.statusCode,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
      request: response.request,
    );

    String responseBody = utf8.decode(responseBodyBytes);
    // Si el código de estado de la respuesta es 401 y el code es "token_not_valid" entonces el accessToken ha expirado, por lo que se debe solicitar un nuevo accessToken con el refreshToken
    if (response.statusCode == 401 &&
        jsonDecode(responseBody)['code'] == 'token_not_valid') {
      String? refreshToken = await _storage.read(key: 'refreshToken');
      var refreshResponse = await _inner.post(
        Uri.parse('http://54.164.87.195/api/token/refresh/'),
        body: {'refresh': refreshToken},
      );

      if (refreshResponse.statusCode == 200) {
        String newAccessToken = jsonDecode(refreshResponse.body)['access'];
        await _storage.write(key: 'accessToken', value: newAccessToken);

        // Reenvía la solicitud con el nuevo accessToken
        BaseRequest newRequest = http.Request(request.method, request.url)
          ..headers['Authorization'] = 'Bearer $newAccessToken'
          ..headers['Content-Type'] = 'application/json';

        // Resend the request
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
    return responseWithBody;
  }
}

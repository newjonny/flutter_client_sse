library flutter_client_sse;

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
part 'sse_event_model.dart';

class SSEClient {
  static http.Client _client = new http.Client();
  static Stream<SSEModel> subscribeToSSE(String url, Map<String, String> headers) {
    //Regex to be used
    var lineRegex = RegExp(r'^([^:]*)(?::)?(?: )?(.*)?$');
    //Creating a instance of the SSEModel
    var currentSSEModel = SSEModel(data: '', id: '', event: '');
    // ignore: close_sinks
    StreamController<SSEModel> streamController = new StreamController();
    print("--SUBSCRIBING TO SSE---");
    while (true) {
      try {
        _client = http.Client();
        var request = new http.Request("GET", Uri.parse(url));
        //Adding headers to the request
        headers.forEach((k,v) {
          request.headers[k] = v;
        });
        Future<http.StreamedResponse> response = _client.send(request);

        //Listening to the response as a stream
        response.asStream().listen((data) {
          streamController.add(SSEModel(
              data: data.statusCode.toString(), id: '', event: 'data.statusCode'));
          //Applying transforms and listening to it
          data.stream
            ..transform(Utf8Decoder())
                .transform(LineSplitter())
                .listen((dataLine) {
              if (dataLine.isEmpty) {
                //This means that the complete event set has been read.
                //We then add the event to the stream
                streamController.add(currentSSEModel);
                currentSSEModel = SSEModel(data: '', id: '', event: '');
                return;
              }
              //Get the match of each line through the regex
              Match match = lineRegex.firstMatch(dataLine)!;
              var field = match.group(1);
              if (field!.isEmpty) {
                return;
              }
              var value = '';
              if (field == 'data') {
                //If the field is data, we get the data through the substring
                value = dataLine.substring(
                  5,
                );
              } else {
                value = match.group(2) ?? '';
              }
              switch (field) {
                case 'event':
                  currentSSEModel.event = value;
                  break;
                case 'data':
                  currentSSEModel.data =
                      (currentSSEModel.data ?? '') + value + '\n';
                  break;
                case 'id':
                  currentSSEModel.id = value;
                  break;
                case 'retry':
                  break;
              }
            });
        });
      } catch (e) {
        print('---ERROR---');
        print(e);
        streamController.add(SSEModel(data: '', id: '', event: ''));
      }

      Future.delayed(Duration(seconds: 1), () {});
      return streamController.stream;
    }
  }

  static void unsubscribeFromSSE() {
    _client.close();
  }
}

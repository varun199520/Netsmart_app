// import 'package:flutter/material.dart';
// import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';


// class LoginPage extends StatefulWidget {
//   @override
//   _LoginPageState createState() => _LoginPageState();
// }

// class _LoginPageState extends State<LoginPage> {
//   final FlutterWebviewPlugin flutterWebviewPlugin = FlutterWebviewPlugin();
//   String _accessToken='';

//   @override
//   void initState() {
//     super.initState();
//     flutterWebviewPlugin.onUrlChanged.listen((String url) {
//       if (url.startsWith('YOUR_REDIRECT_URI')) {
//         _handleRedirect(url);
//       }
//     });
//   }

//   void _handleRedirect(String url) {
//     final Uri uri = Uri.parse(url);
//     final String code = uri.queryParameters['code']?? 'default_code';
//     _exchangeCodeForToken(code);
//     flutterWebviewPlugin.close();
//   }

//   Future<void> _exchangeCodeForToken(String code) async {
//     final response = await http.post(
//       Uri.parse('https://login.microsoftonline.com/common/oauth2/v2.0/token'),
//       headers: {
//         'Content-Type': 'application/x-www-form-urlencoded',
//       },
//       body: {
//         'grant_type': 'authorization_code',
//         'client_id': 'YOUR_CLIENT_ID', 
//         'client_secret': 'YOUR_CLIENT_SECRET',   
//         'redirect_uri': 'YOUR_REDIRECT_URI',
//         'code': code,
//       },
//     );

//     if (response.statusCode == 200) {
//       final Map<String, dynamic> responseBody = json.decode(response.body);
//       setState(() {
//         _accessToken = responseBody['access_token'];
//       });
//     } else {
//       print('Error exchanging code for token: ${response.statusCode}');
//     }
//   }

//   Future<void> _fetchData() async {
//     if (_accessToken == null) return;

//     final response = await http.get(
//       Uri.parse('https://netsmart.stanfordmed.org/deviceTracker/api/wired-lookup/?address=10.250.79.233'),
//       headers: {
//         'Authorization': 'Bearer $_accessToken',
//       },
//     );

//     if (response.statusCode == 200) {
//       print('Data: ${response.body}');
//     } else {
//       print('Error fetching data: ${response.statusCode}');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Login'),
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: <Widget>[
//             ElevatedButton(
//               onPressed: () {
//                 flutterWebviewPlugin.launch(
//                   'https://login.microsoftonline.com/common/oauth2/v2.0/authorize?client_id=YOUR_CLIENT_ID&response_type=code&redirect_uri=YOUR_REDIRECT_URI&response_mode=query&scope=openid%20profile%20email%20offline_access',
//                 );
//               },
//               child: Text('Login with Microsoft'),
//             ),
//             if (_accessToken != null)
//               ElevatedButton(
//                 onPressed: _fetchData,
//                 child: Text('Fetch Data'),
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     flutterWebviewPlugin.dispose();
//     super.dispose();
//   }
// }

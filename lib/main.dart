import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/didcomm.dart';
import 'package:dart_ssi/wallet.dart';
import 'package:json_schema_form/json_schema_form.dart';
import 'package:json_schema2/json_schema2.dart';

import './schema/email.dart';

void main() async {
  runApp(const MyApp());
}

enum SortingType { dateUp, dateDown, typeUp, typeDown }

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
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
  late WalletStore _wallet;
  bool isInitWallet = false;
  List<VerifiableCredential> credentials = [];

  void listAllCredentials() {
    credentials = [];
    var all = _wallet.getAllCredentials();
    for (var cred in all.values) {
      if (cred.w3cCredential == '') {
        continue;
      }
      if (cred.plaintextCredential == '') {
        credentials.add(VerifiableCredential.fromJson(cred.w3cCredential));
      }
    }
    setState(() {
      isInitWallet = true;
    });
  }

  void openWallet() async {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    _wallet = new WalletStore(appDocumentDir.path);
    await _wallet.openBoxes('password');
    if (!_wallet.isInitialized()) {
      _wallet.initialize();
    }
    listAllCredentials();
    setState(() {
      isInitWallet = true;
    });
  }

  void selfIssue(String type, JsonSchema schema, Map<dynamic, dynamic> result) async {
    var credentialDid = await _wallet.getNextCredentialDID(KeyType.ed25519);
    var credential = VerifiableCredential(
        context: [
          'https://www.w3.org/2018/credentials/v1',
          'https://schema.org'
        ],
        type: [
          'VerifiableCredential',
          type
        ],
        issuer: credentialDid,
        credentialSubject: result,
        issuanceDate: DateTime.now());
    var signed = await signCredential(_wallet, credential.toJson());
    var storageCred = _wallet.getCredential(credentialDid);
    await _wallet.storeCredential(signed, '', storageCred!.hdPath,
        keyType: KeyType.ed25519);
    await _wallet.storeExchangeHistoryEntry(
        credentialDid, DateTime.now(), 'issue', credentialDid);
    listAllCredentials();
  }

   void deleteCredential(String credDid) {
    _wallet.deleteCredential(credDid);
    listAllCredentials();
  }

  Future<void> _dialogBuilder(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Basic dialog title'),
          content: JsonSchemaForm(
              schema: emailSchema,
              controller: SchemaFormController(emailSchema),
              afterValidation: (result) async {
                selfIssue('email', emailSchema, result);
                Navigator.of(context).pop();
              },
              validationButtonText: 'Validate'
            ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if(!isInitWallet)
              TextButton(onPressed: openWallet, child: const Text('Init Wallet'))
            else
              ...credentials.map((e) {
                return Row(children: [
                  Expanded(flex: 1, child: Text("${e.issuer}", overflow: TextOverflow.ellipsis)),
                  Expanded(flex: 1, child: Text(e.credentialSubject.toString(), overflow: TextOverflow.ellipsis)),
                  IconButton(onPressed: () => {
                    deleteCredential(e.issuer)
                  }, icon: const Icon(Icons.remove))
                ]);
              }),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if(isInitWallet)
            FloatingActionButton(
              onPressed: () => _dialogBuilder(context),
              child: const Icon(Icons.add),
            )
        ],
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

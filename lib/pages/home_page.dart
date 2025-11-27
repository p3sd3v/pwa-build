import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  InAppWebViewController? _webViewController;
  String? _userUid;

  /// Extrai o UID do Firebase Auth usando JavaScript Handler
  Future<void> _extractFirebaseUid() async {
    if (_webViewController == null) return;

    // Registra o handler para receber o UID
    _webViewController!.addJavaScriptHandler(
      handlerName: 'uidHandler',
      callback: (args) {
        if (args.isNotEmpty && args[0] != null) {
          final uid = args[0].toString();
          if (uid.isNotEmpty && uid != 'null' && uid != _userUid) {
            setState(() {
              _userUid = uid;
            });
            debugPrint('Firebase UID capturado: $uid');
            // TODO: Salvar no Firebase Realtime Database ou Firestore aqui
          }
        }
        return null;
      },
    );

    // Script que tenta várias formas de pegar o UID (Next.js + Firebase v9)
    const String script = '''
      (function() {
        console.log('[Flutter] Iniciando busca do UID...');
        
        function sendUid(uid) {
          if (uid && window.flutter_inappwebview) {
            console.log('[Flutter] UID encontrado: ' + uid);
            window.flutter_inappwebview.callHandler('uidHandler', uid);
          }
        }
        
        // 0. Lista TODOS os itens do localStorage para debug
        console.log('[Flutter] === localStorage completo ===');
        console.log('[Flutter] Total de itens:', localStorage.length);
        for (var i = 0; i < localStorage.length; i++) {
          var key = localStorage.key(i);
          var value = localStorage.getItem(key);
          console.log('[Flutter] [' + i + '] Key: ' + key);
          console.log('[Flutter] Value: ' + (value ? value.substring(0, 200) : 'null'));
        }
        
        // 1. Tenta do localStorage
        for (var i = 0; i < localStorage.length; i++) {
          var key = localStorage.key(i);
          var value = localStorage.getItem(key);
          if (key && value) {
            try {
              // Tenta parsear como JSON e buscar uid
              var data = JSON.parse(value);
              if (data && data.uid) {
                console.log('[Flutter] UID encontrado em localStorage key:', key);
                sendUid(data.uid);
                return;
              }
              // Busca uid em qualquer lugar do objeto
              var str = JSON.stringify(data);
              var match = str.match(/"uid"\s*:\s*"([^"]+)"/);
              if (match && match[1].length > 10) {
                console.log('[Flutter] UID encontrado via regex em:', key);
                sendUid(match[1]);
                return;
              }
            } catch(e) {}
          }
        }
        
        // 2. Lista TODOS os bancos IndexedDB disponíveis
        console.log('[Flutter] === IndexedDB databases ===');
        if (indexedDB.databases) {
          indexedDB.databases().then(function(dbs) {
            console.log('[Flutter] Bancos disponíveis:', dbs.length);
            dbs.forEach(function(db, idx) {
              console.log('[Flutter] DB[' + idx + ']:', db.name, 'v' + db.version);
            });
            
            // Tenta abrir cada banco
            dbs.forEach(function(dbInfo) {
              if (!dbInfo.name) return;
              
              var request = indexedDB.open(dbInfo.name);
              request.onsuccess = function(event) {
                var db = event.target.result;
                var storeNames = Array.from(db.objectStoreNames);
                console.log('[Flutter] DB ' + dbInfo.name + ' stores:', storeNames.join(', '));
                
                storeNames.forEach(function(storeName) {
                  try {
                    var tx = db.transaction([storeName], 'readonly');
                    var store = tx.objectStore(storeName);
                    var getAll = store.getAll();
                    
                    getAll.onsuccess = function() {
                      var results = getAll.result;
                      console.log('[Flutter] ' + dbInfo.name + '/' + storeName + ': ' + results.length + ' itens');
                      
                      results.forEach(function(item, idx) {
                        var str = JSON.stringify(item);
                        console.log('[Flutter] Item[' + idx + ']:', str.substring(0, 400));
                        
                        // Busca uid
                        var match = str.match(/"uid"\s*:\s*"([^"]+)"/);
                        if (match && match[1].length > 10) {
                          sendUid(match[1]);
                        }
                      });
                    };
                  } catch(e) {
                    console.log('[Flutter] Erro lendo ' + storeName + ':', e.message);
                  }
                });
                
                db.close();
              };
            });
          }).catch(function(e) {
            console.log('[Flutter] indexedDB.databases() não suportado, tentando manualmente...');
            tryManualDbs();
          });
        } else {
          console.log('[Flutter] indexedDB.databases() não disponível');
          tryManualDbs();
        }
        
        function tryManualDbs() {
          var dbNames = [
            'firebaseLocalStorageDb',
            'firebase-heartbeat-database', 
            'firebaseLocalStorage',
            'firebase-installations-database',
            '__sak'
          ];
          
          dbNames.forEach(function(dbName) {
            var request = indexedDB.open(dbName);
            request.onsuccess = function(event) {
              var db = event.target.result;
              var storeNames = Array.from(db.objectStoreNames);
              console.log('[Flutter] Manual DB ' + dbName + ' stores:', storeNames.join(', '));
              
              storeNames.forEach(function(storeName) {
                try {
                  var tx = db.transaction([storeName], 'readonly');
                  var store = tx.objectStore(storeName);
                  var getAll = store.getAll();
                  
                  getAll.onsuccess = function() {
                    var results = getAll.result;
                    console.log('[Flutter] ' + dbName + '/' + storeName + ': ' + results.length + ' itens');
                    
                    results.forEach(function(item) {
                      var str = JSON.stringify(item);
                      console.log('[Flutter] Item:', str.substring(0, 400));
                      
                      var match = str.match(/"uid"\s*:\s*"([^"]+)"/);
                      if (match && match[1].length > 10) {
                        sendUid(match[1]);
                      }
                    });
                  };
                } catch(e) {}
              });
              db.close();
            };
          });
        }
      })();
    ''';

    await _webViewController!.evaluateJavascript(source: script);
  }

  Future<bool> _onWillPop() async {
    if (_webViewController != null) {
      if (await _webViewController!.canGoBack()) {
        _webViewController!.goBack();
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri(dotenv.env['HOST_URL']!),
            ),
            initialSettings: InAppWebViewSettings(
              // Habilita persistência de dados (cookies, localStorage, IndexedDB)
              cacheEnabled: true,
              clearCache: false,
              // iOS
              sharedCookiesEnabled: true,
              // Android
              domStorageEnabled: true,
              databaseEnabled: true,
              // Permite armazenamento de dados
              cacheMode: CacheMode.LOAD_DEFAULT,
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
            },
            onLoadStop: (controller, url) async {
              // Tenta capturar o UID após a página carregar
              await _extractFirebaseUid();
            },
            onUpdateVisitedHistory: (controller, url, androidIsReload) async {
              // Tenta capturar quando o usuário navega (pode ter feito login)
              await _extractFirebaseUid();
            },
            onConsoleMessage: (controller, consoleMessage) {
              // Captura logs do JavaScript para debug
              if (consoleMessage.message.contains('[Flutter]')) {
                debugPrint(consoleMessage.message);
              }
            },
          ),
        ),
      ),
    );
  }
}

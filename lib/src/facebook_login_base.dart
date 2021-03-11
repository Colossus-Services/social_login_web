import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'dart:js';
import 'dart:typed_data';

import 'package:swiss_knife/swiss_knife.dart';

import 'user_login_base.dart';

typedef FacebookStatusListener = void Function(FacebookStatus? status);

abstract class FacebookLoginListener {
  void onFBStatusChange(FacebookStatus? fbStatus);

  void onFBLogout();

  void onFBMe(FacebookMe? fbMe);

  void onFBConnected();
  void onFBDisconnected();
}

typedef FacebookLoginValidator = Future<bool> Function(FBUserLogin user);

class FacebookLogin {
  static final FacebookLogin instance = FacebookLogin._internal();

  static List<FacebookLoginListener> get listeners => instance._listeners;
  static List<FacebookStatusListener> get statusListeners =>
      instance._statusListeners;

  static EventStream<FBUserLogin> get onConnect => instance._onConnect;
  static EventStream<FBUserLogin?> get onDisconnect => instance._onDisconnect;

  static FacebookLoginValidator? get loginValidator => instance._loginValidator;
  static set loginValidator(loginValidator) =>
      instance._loginValidator = loginValidator;

  static void init(String appId, [FacebookLoginValidator? loginValidator]) {
    instance._initialize(appId, loginValidator);
  }

  FacebookLoginValidator? _loginValidator;

  final List<FacebookLoginListener> _listeners = [];
  final List<FacebookStatusListener> _statusListeners = [];

  FacebookLogin._internal();

  final EventStream<FBUserLogin> _onConnect = EventStream();
  final EventStream<FBUserLogin?> _onDisconnect = EventStream();

  String? _appId;
  String? get appId => _appId;

  bool _init = false;

  void _initialize(String appId, [FacebookLoginValidator? loginValidator]) {
    if (appId.isEmpty) throw StateError('FacebookLogin> Invalid appId: $appId');

    if (_init) {
      if (_appId != appId) {
        throw StateError(
            'FacebookLogin already initialized. Trying to change appId: $_appId $appId');
      }
      return;
    }

    if (loginValidator != null) {
      _loginValidator = loginValidator;
    }

    _init = true;
    _appId = appId;

    var fbScriptCode = '''
        
          window.fbAsyncInit = function() {
            FB.init({
              appId      : '137198380292950',
              cookie     : true,
              xfbml      : true,
              version    : 'v2.11'
            });
              
            FB.AppEvents.logPageView();
            
            FB.getLoginStatus(function(response) {
              FacebookLogin_statusChangeCallback(response);
            });   
              
          };
        
          (function(d, s, id){
             var js, fjs = d.getElementsByTagName(s)[0];
             if (d.getElementById(id)) {return;}
             js = d.createElement(s); js.id = id;
             js.src = "https://connect.facebook.net/en_US/sdk.js";
             fjs.parentNode.insertBefore(js, fjs);
           }(document, 'script', 'facebook-jssdk'));
           
           ////////////////
           
           
           FacebookLogin_statusChangeCallback = function(fbStatus) {
              console.log('Default FacebookLogin_statusChangeCallback:') ;
              console.log(fbStatus) ;
           };
           
           FacebookLogin_onLogout = function(fbStatus) {
              console.log('Default FacebookLogin_onLogout:') ;
              console.log(fbStatus) ;
           };
           
           FacebookLogin_onMe = function(fbStatus) {
              console.log('Default FacebookLogin_onMe:') ;
              console.log(fbStatus) ;
           };
           
           ///
           
           function FacebookLogin_set_statusChangeCallback(f) {
              console.log('Setting FacebookLogin_statusChangeCallback:');
              console.log(f);
              FacebookLogin_statusChangeCallback = f ;
           }
           
           function FacebookLogin_set_onLogout(f) {
              console.log('Setting FacebookLogin_onLogout:');
              console.log(f);
              FacebookLogin_onLogout = f ;
           }
           
           function FacebookLogin_set_onMe(f) {
              console.log('Setting FacebookLogin_onMe:');
              console.log(f);
              FacebookLogin_onMe = f ;
           }
           
           //////////////////////
           
           function FacebookLogin_checkLoginState() {
              FB.getLoginStatus(function(response) {
                FacebookLogin_statusChangeCallback(response);
              });
           }
           
           function FacebookLogin_callLogin() {
              FB.login(
                function(response) {
                    if (response.authResponse) {
                      FacebookLogin_statusChangeCallback(response);      
                    }
                    else {
                      FacebookLogin_statusChangeCallback(null);
                    }
                },
                {scope: 'email,public_profile'}
              );
              
           }
           
           function FacebookLogin_callLogout() {
              FB.logout(function(response) {
                FacebookLogin_onLogout(response);
              });
           }
           
           function FacebookLogin_callMe() {
              FB.api('/me?fields=name,email', function(response) {
              console.log('Me:');
                console.log(response);
                FacebookLogin_onMe(response);
              });
           }
           
           
           FacebookLogin_loaded = 1 ;
           
    ''';

    var head = querySelector('head') as HeadElement;

    var fbScript = ScriptElement();
    fbScript.type = 'text/javascript';
    fbScript.text = fbScriptCode;

    head.children.add(fbScript);

    var loaded = context['FacebookLogin_loaded'];

    print('FacebookLogin_loaded: $loaded');

    if (loaded == null) {
      throw StateError('Error loading FacebookLogin component');
    }

    ////////

    var FacebookLogin_set_statusChangeCallback =
        context['FacebookLogin_set_statusChangeCallback'] as JsFunction;
    FacebookLogin_set_statusChangeCallback.apply(
        [(JsObject jsObj) => _statusChangeCallback(jsObj)]);

    var FacebookLogin_set_onMe =
        context['FacebookLogin_set_onMe'] as JsFunction;
    FacebookLogin_set_onMe.apply([(JsObject jsObj) => _onMe(jsObj)]);

    var FacebookLogin_set_onLogout =
        context['FacebookLogin_set_onLogout'] as JsFunction;
    FacebookLogin_set_onLogout.apply([(JsObject jsObj) => _onLogout(jsObj)]);
  }

  //////////////////////

  void _statusChangeCallback(JsObject? jsObj) {
    print('_statusChangeCallback:');
    print(jsObj);

    if (jsObj != null) {
      _setStatus(FacebookStatus(jsObj));
    } else {
      _setStatus(null);
    }
  }

  void _onMe(JsObject? jsObj) {
    if (jsObj != null) {
      _setMe(FacebookMe(jsObj));
    } else {
      _setMe(null);
    }
  }

  void _onLogout(JsObject? jsObj) {
    print('_onLogout:');
    print(jsObj);

    _setStatus(null);
    _setMe(null);

    _listeners.forEach((l) => l.onFBLogout());

    _notifyStatusChange();
  }

  void _notifyStatusChange() {
    _statusListeners.forEach((l) {
      try {
        l(_status);
      } catch (e) {
        print(e);
      }
    });
  }

  //////////////////////

  FacebookStatus? _status;
  static FacebookStatus? get status => instance._status;

  void _setStatus(FacebookStatus? s) async {
    _status = s;

    var connected = _isConnected();

    if (connected) {
      _queryMe();
    }

    var user = await _updateGlobalUser();

    _listeners.forEach((l) => l.onFBStatusChange(_status));

    if (connected) {
      _notifyConnected(user);
    } else {
      _notifyDisconnected();
    }

    _notifyStatusChange();

    print(_status);
  }

  bool _notifyConnectedPending = false;

  void _notifyConnected(FBUserLogin user) {
    if (_isMeLoaded()) {
      _listeners.forEach((l) => l.onFBConnected());
      _onConnect.add(user);
    } else {
      _notifyConnectedPending = true;
    }
  }

  void _notifyDisconnected() {
    _listeners.forEach((l) => l.onFBDisconnected());

    _onDisconnect.add(_lastUser);
  }

  //////////////////////

  FacebookMe? _me;
  static FacebookMe? get me => instance._me;

  String get _pictureURL => pictureURLBuilder(_me!.id);
  static String get pictureURL => instance._pictureURL;

  static String pictureURLBuilder(String? id) {
    return 'https://graph.facebook.com/v3.0/$id/picture';
  }

  void _setMe(FacebookMe? m) async {
    _me = m;

    var user = await _updateGlobalUser();

    _listeners.forEach((l) => l.onFBMe(_me));

    if (_notifyConnectedPending) _notifyConnected(user);

    print(_me);
  }
  //////////////////////

  FBUserLogin? _lastUser;

  Future<FBUserLogin> _updateGlobalUser() async {
    print(
        '_updateGlobalUser> status: $_status ; me: $_me ; loginValidator: $_loginValidator');

    // logout:
    if (_status == null) {
      GlobalUser.loggedOut();
      return Future.value(null);
    }

    FBUserLogin? user;

    if (_me != null) {
      user = FBUserLogin.full(
          _me!.id, _me!.username, _me!.email, _me!.name, _me!.id);
    } else {
      var id = _status!.getUserID();

      if (id != null) {
        user = FBUserLogin.onlyID(id);
      }
    }

    if (user == null) {
      GlobalUser.loggedFail();
      return Future.value(null);
    }

    if (!user.isFullyLoaded()) {
      print('User not fully loaded...');
      return Future.value(null);
    }

    var loginOk = true;

    if (_loginValidator != null) {
      loginOk = await _loginValidator!(user);
    }

    if (loginOk) {
      _lastUser = user;
      GlobalUser.loggedOk(user);
      return Future.value(user);
    } else {
      GlobalUser.loggedFail();
      return Future.value(null);
    }
  }

  //////////////////////

  static bool isConnected() {
    return instance._isConnected();
  }

  bool _isConnected() {
    return _status != null && _status!.isConnected();
  }

  static bool isMeLoaded() {
    return instance._isMeLoaded();
  }

  bool _isMeLoaded() {
    return isConnected() && _me != null && _me!.email != null;
  }

  static String getLoginButton() {
    return '<fb:login-button scope="public_profile,email" onlogin="FacebookLogin_checkLoginState();"></fb:login-button>';
  }

  static void login() {
    instance._login();
  }

  void _login() {
    context.callMethod('FacebookLogin_callLogin');
  }

  static void queryMe() {
    instance._queryMe();
  }

  void _queryMe() {
    context.callMethod('FacebookLogin_callMe');
  }

  static void logout() {
    instance._logout();
  }

  void _logout() {
    context.callMethod('FacebookLogin_callLogout');
  }
}

class FacebookMe {
  final JsObject _jsObj;

  FacebookMe(this._jsObj);

  String? get id => _jsObj['id'];
  String? get email => _jsObj['email'];
  String? get name => _jsObj['name'];
  String get username => 'FB$id';

  @override
  String toString() {
    return 'FacebookMe{ name: $name, id: $id }';
  }
}

class FacebookStatus {
  final JsObject _jsObj;

  FacebookStatus(this._jsObj);

  String? get status => _jsObj['status'];

  FacebookAuthResponse? get authResponse {
    var jsObj = _jsObj['authResponse'];
    return jsObj != null ? FacebookAuthResponse(jsObj) : null;
  }

  bool isConnected() {
    return status != null && status!.toLowerCase() == 'connected';
  }

  String? getUserID() {
    if (authResponse == null) return null;
    return authResponse!.userID;
  }

  @override
  String toString() {
    return 'FacebookStatus{ status: $status, userID: ${getUserID()}, authResponse: $authResponse }';
  }
}

class FacebookAuthResponse {
  final JsObject _jsObj;

  FacebookAuthResponse(this._jsObj);

  String? get userID => _jsObj['userID'];
  int? get expiresIn => _jsObj['expiresIn'];
  String? get accessToken => _jsObj['accessToken'];
  String? get signedRequest => _jsObj['signedRequest'];

  FacebookAuthResponseSignedRequest get signedRequestObject =>
      FacebookAuthResponseSignedRequest(signedRequest);

  @override
  String toString() {
    return 'FacebookAuthResponse{userID: $userID, expiresIn: $expiresIn, accessToken: $accessToken, signedRequest: $signedRequest}';
  }
}

class FacebookAuthResponseSignedRequest {
  final String? signedRequest;

  Uint8List? _encodedSig;
  String? _payload;

  FacebookAuthResponseSignedRequest(this.signedRequest) {
    var parts = signedRequest!.split('.');

    _encodedSig = _base64_url_decode(parts[0]);
    _payload = _base64_url_decode_str(parts[1]);
  }

  Uint8List? get encodedSig => _encodedSig;
  String? get payload => _payload;

  String _base64_url_decode_str(String input) {
    return String.fromCharCodes(_base64_url_decode(input)!);
  }

  Uint8List? _base64_url_decode(String input) {
    try {
      input = input.replaceAll('-', '+');
      input = input.replaceAll('/', '_');

      var padding_factor = (4 - input.length % 4) % 4;

      for (var i = 0; i < padding_factor; i++) {
        input += '=';
      }

      var decode = base64.decode(input);

      return decode;
    } catch (e, s) {
      print(e);
      print(s);
      return null;
    }
  }

  @override
  String toString() {
    return 'FacebookAuthResponseSignedRequest{encodedSig: $_encodedSig, payload: $_payload}';
  }
}

class FBUserLogin extends UserLogin {
  FBUserLogin.onlyID(String externalID)
      : super(false, externalID, externalID, '$externalID@', '#$externalID',
            'user', 'facebook', externalID);

  FBUserLogin.full(String? id, String username, String? email, String? name,
      String? externalID)
      : super(true, id, username, email, name, 'user', 'facebook', externalID);

  FBUserLogin.other(UserLogin other)
      : super(other.isFullyLoaded(), other.id, other.username, other.email,
            other.name, other.userType, other.accountType, other.externalID);

  @override
  void logout() {
    print('FB call logout...');
    FacebookLogin.logout();
  }

  @override
  String get pictureURL {
    if (FacebookLogin.isMeLoaded()) {
      return FacebookLogin.pictureURL;
    } else {
      return FacebookLogin.pictureURLBuilder(externalID);
    }
  }

  @override
  String get loginType => 'Facebook';
}

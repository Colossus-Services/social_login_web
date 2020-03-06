
import 'dart:async';
import 'dart:convert';

import 'package:swiss_knife/swiss_knife.dart';

dynamic _JSONDecode(String json) {
  try {
    return jsonDecode(json);
  }
  catch (e) {
    print(e);
    return null ;
  }
}

typedef Future<UserLogin> ResumeLoginFunction() ;

class GlobalUser {
  static UserLogin user ;

  static void loggedOut() {
    logout() ;
  }

  static void loggedFail() {
    if ( !isLogged() ) {
      logout() ;
    }
  }

  static void loggedOk(UserLogin user) {
    if (user != null) {
      GlobalUser.user = user ;
      notifyLogin();
    }
    else {
      logout() ;
    }
  }

  static bool isLogged() {
    return user != null && user.isFullyLoaded() ;
  }

  static void logout() {
    if (user != null) {
      var u = user ;
      user = null ; // avoid loop
      u.logout();
    }
    notifyLogout();
  }

  static List<GlobalUserListener> listeners = [] ;

  static void notifyLogin() {
    if (listeners != null && listeners.isNotEmpty) {
      List<GlobalUserListener> list = List.from(listeners).cast() ;
      for (var l in list) {
        try {
          l.onGlobalUserLogin(user) ;
        }
        catch (e) {
          print(e);
        }
      }
    }
  }

  static void notifyLogout() {
    if (listeners != null && listeners.isNotEmpty) {
      List<GlobalUserListener> list = List.from(listeners).cast() ;
      for (var l in list) {
        try {
          l.onGlobalUserLogin(null) ;
        }
        catch (e) {
          print(e);
        }
      }
    }
  }

  static ResumeLoginFunction _resumeLoginFunction ;

  static ResumeLoginFunction get resumeLoginFunction => _resumeLoginFunction;

  static set resumeLoginFunction(ResumeLoginFunction value) {
    _resumeLoginFunction = value;
  }

  static bool resumeLogin() {
    if ( _resumeLoginFunction == null ) return false ;

    try {
      Future<UserLogin> futureUser = _resumeLoginFunction();

      if (futureUser != null) {
        futureUser.then((user) {
          if (user != null) {
            loggedOk(user);
          }
          else {
            loggedFail();
          }
        });
      }

      return true ;
    }
    catch (e) {
      print(e);
      return false ;
    }
  }

  static UserLogin processLoginResponse(dynamic response, [ UserLogin userInstantiator(UserLogin user) ]) {
    var user = UserLogin.parse( response , userInstantiator );

    if (user != null) {
      loggedOk(user) ;
      return user ;
    }
    else {
      loggedFail() ;
      return null ;
    }
  }

}

abstract class GlobalUserListener {

  void onGlobalUserLogin(UserLogin user) ;

}

class UserLogin {

  static UserLogin parse(dynamic content, [ UserLogin userInstantiator(UserLogin user) ]) {
    var node ;

    if ( content == null ) {
      node = null ;
    }
    else if ( content is Map ) {
      node = content ;
    }
    else if ( content is UserLogin ) {
      return content ;
    }
    else {
      node = _JSONDecode( "$content" ) ;
    }

    if ( node != null && node is Map ) {
      var username = node['username'] ;

      if (username != null) {
        try {
          String id = getIgnoreCase(node, 'id').toString() ;
          String name = node['name'] ;
          String email = node['email'] ;
          String userType = node['userType'] ;
          String accountType = node['accountType'] ;
          String externalID = node['externalID'] ;

          var user = UserLogin(true, id, username, email, name, userType, accountType, externalID) ;

          if (userInstantiator != null) {
            var user2 = userInstantiator(user) ;
            if (user2 != null) user = user2 ;
          }

          return user ;
        }
        catch (e) {
          print(e);
        }
      }
    }

    return null ;
  }


  bool _fullyLoaded;

  String _id ;
  String get id => _id ;

  String _externalID ;
  String get externalID => _externalID ;

  String _username ;
  String get username => _username ;

  String _name ;
  String get name => _name ?? _extractNameFromEmail( _username ??  _email ) ;

  static String _extractNameFromEmail(String email) {
    if (email == null || email.isEmpty) return null ;
    var name = email.split('@')[0];
    if (name.length < 2) return name ;
    return name.substring(0,1).toUpperCase() + name.substring(1) ;
  }

  String _email ;
  String get email => _email ?? _isEmail(_username) ? _username : null ;

  static bool _isEmail(String s) {
    if (s == null || s.length < 3) return false ;
    int idx = s.indexOf('@') ;
    if (idx <= 0) return false ;

    if ( RegExp(r'^\s').hasMatch(s) || RegExp(r'\s$').hasMatch(s) ) return false ;
    return true ;
  }

  String _userType ;
  String get userType => _userType ;

  String _accountType ;
  String get accountType => _accountType ;

  UserLogin(this._fullyLoaded, this._id, this._username, this._email, this._name, this._userType, this._accountType, this._externalID);

  String get nameLimited => getNameLimited() ;

  String get nameInitial => name.isNotEmpty ? name.substring(0,1).toUpperCase() : "" ;

  static const int NAME_LENGTH_LIMIT = 12 ;

  String getNameLimited() {
    return name.length > NAME_LENGTH_LIMIT ? name.substring(0,NAME_LENGTH_LIMIT)+"..." : name ;
  }

  void logout() {}

  String get pictureURL => null ;

  String get loginType => 'standart' ;

  bool isFullyLoaded() {
    return _fullyLoaded;
  }

  bool isUserTypeOf(String userType) {
    return this._userType != null && this._userType.toLowerCase() == userType.toLowerCase() ;
  }

  bool isAccountTypeOf(String accountType) {
    return this._accountType != null && this._accountType.toLowerCase() == accountType.toLowerCase() ;
  }

  @override
  String toString() {
    return 'UserLogin{externalID: $_externalID, name: $_name, username: $_username, email: $_email, accountType: $_accountType}';
  }


}



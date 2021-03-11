import 'dart:async';
import 'dart:convert';

import 'package:swiss_knife/swiss_knife.dart';

dynamic _JSONDecode(String json) {
  try {
    return jsonDecode(json);
  } catch (e) {
    print(e);
    return null;
  }
}

typedef ResumeLoginFunction = Future<UserLogin?> Function();

class GlobalUser {
  static UserLogin? user;

  static void loggedOut() {
    logout();
  }

  static void loggedFail() {
    if (!isLogged()) {
      logout();
    }
  }

  static void loggedOk(UserLogin? user) {
    if (user != null) {
      GlobalUser.user = user;
      notifyLogin();
    } else {
      logout();
    }
  }

  static bool isLogged() {
    return user != null && user!.isFullyLoaded();
  }

  static void logout() {
    if (user != null) {
      var u = user!;
      user = null; // avoid loop
      u.logout();
    }
    notifyLogout();
  }

  static List<GlobalUserListener> listeners = [];

  static void notifyLogin() {
    if (listeners.isNotEmpty) {
      var list = List.from(listeners).cast();
      for (var l in list) {
        try {
          l.onGlobalUserLogin(user);
        } catch (e) {
          print(e);
        }
      }
    }
  }

  static void notifyLogout() {
    if (listeners.isNotEmpty) {
      var list = List.from(listeners).cast();
      for (var l in list) {
        try {
          l.onGlobalUserLogin(null);
        } catch (e) {
          print(e);
        }
      }
    }
  }

  static ResumeLoginFunction? resumeLoginFunction;

  static bool resumeLogin() {
    if (resumeLoginFunction == null) return false;

    try {
      var futureUser = resumeLoginFunction!();

      futureUser.then((user) {
        if (user != null) {
          loggedOk(user);
        } else {
          loggedFail();
        }
      });

      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  static UserLogin? processLoginResponse(dynamic response,
      [UserLogin Function(UserLogin user)? userInstantiator]) {
    var user = UserLogin.parse(response, userInstantiator);

    if (user != null) {
      loggedOk(user);
      return user;
    } else {
      loggedFail();
      return null;
    }
  }
}

abstract class GlobalUserListener {
  void onGlobalUserLogin(UserLogin? user);
}

class UserLogin {
  static UserLogin? parse(dynamic content,
      [UserLogin Function(UserLogin user)? userInstantiator]) {
    var node;

    if (content == null) {
      node = null;
    } else if (content is Map) {
      node = content;
    } else if (content is UserLogin) {
      return content;
    } else {
      node = _JSONDecode('$content');
    }

    if (node != null && node is Map) {
      var username = node['username'];

      if (username != null) {
        try {
          var map2 = toNonNullMap<String, Object>(node, forceTypeCast: false);

          var id = getIgnoreCase(map2, 'id').toString();
          String? name = node['name'];
          String? email = node['email'];
          String? userType = node['userType'];
          String? accountType = node['accountType'];
          String? externalID = node['externalID'];

          var user = UserLogin(true, id, username, email, name, userType,
              accountType, externalID);

          if (userInstantiator != null) {
            var user2 = userInstantiator(user);
            user = user2;
          }

          return user;
        } catch (e) {
          print(e);
        }
      }
    }

    return null;
  }

  final bool _fullyLoaded;

  final String? _id;
  String? get id => _id;

  final String? _externalID;
  String? get externalID => _externalID;

  final String? _username;
  String? get username => _username ?? _email;

  final String? _name;
  String? get name => _name ?? _extractNameFromEmail(_username ?? _email);

  static String? _extractNameFromEmail(String? email) {
    if (email == null || email.isEmpty) return null;
    var name = email.split('@')[0];
    if (name.length < 2) return name;
    return name.substring(0, 1).toUpperCase() + name.substring(1);
  }

  final String? _email;
  String? get email => _email ?? (_isEmail(_username) ? _username : null);

  static bool _isEmail(String? s) {
    if (s == null || s.length < 3) return false;
    var idx = s.indexOf('@');
    if (idx <= 0) return false;

    if (RegExp(r'^\s').hasMatch(s) || RegExp(r'\s$').hasMatch(s)) return false;
    return true;
  }

  final String? _userType;
  String? get userType => _userType;

  final String? _accountType;
  String? get accountType => _accountType;

  UserLogin(this._fullyLoaded, this._id, this._username, this._email,
      this._name, this._userType, this._accountType, this._externalID);

  String? get nameLimited => getNameLimited();

  String get nameInitial =>
      name!.isNotEmpty ? name!.substring(0, 1).toUpperCase() : '';

  static const int NAME_LENGTH_LIMIT = 12;

  String? getNameLimited() {
    return name!.length > NAME_LENGTH_LIMIT
        ? name!.substring(0, NAME_LENGTH_LIMIT) + '...'
        : name;
  }

  void logout() {}

  String? get pictureURL => null;

  String get loginType => 'standart';

  bool isFullyLoaded() {
    return _fullyLoaded;
  }

  bool isUserTypeOf(String userType) {
    return _userType != null &&
        _userType!.toLowerCase() == userType.toLowerCase();
  }

  bool isAccountTypeOf(String accountType) {
    return _accountType != null &&
        _accountType!.toLowerCase() == accountType.toLowerCase();
  }

  @override
  String toString() {
    return 'UserLogin{externalID: $_externalID, name: $_name, username: $_username, email: $_email, accountType: $_accountType}';
  }
}

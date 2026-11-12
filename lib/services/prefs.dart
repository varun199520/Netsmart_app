import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// Recents, favorites and small UI preferences. Stored per-device, not per-user:
/// they are only search strings and switch names, never tokens.
class Prefs {
  Prefs(this._sp);

  static Future<Prefs> load() async => Prefs(await SharedPreferences.getInstance());

  final SharedPreferences _sp;
  static const _recents = 'recents_v1';
  static const _favorites = 'favorites_v1';
  static const _model = 'chat_model';
  static const _pushAsked = 'push_asked';

  /// Items are `{"kind": "endpoint"|"switch", "value": ..., "label": ..., "id"?: ...}`.
  List<Json> get recents => _read(_recents);
  List<Json> get favorites => _read(_favorites);

  Future<void> addRecent(Json item) async {
    final list = recents..removeWhere((e) => _same(e, item));
    list.insert(0, item);
    await _write(_recents, list.take(15).toList());
  }

  Future<void> clearRecents() => _sp.remove(_recents);

  bool isFavorite(Json item) => favorites.any((e) => _same(e, item));

  Future<void> toggleFavorite(Json item) async {
    final list = favorites;
    if (list.any((e) => _same(e, item))) {
      list.removeWhere((e) => _same(e, item));
    } else {
      list.insert(0, item);
    }
    await _write(_favorites, list);
  }

  String? get chatModel => _sp.getString(_model);
  Future<void> setChatModel(String? id) => id == null ? _sp.remove(_model) : _sp.setString(_model, id);

  bool get pushAsked => _sp.getBool(_pushAsked) ?? false;
  Future<void> setPushAsked() => _sp.setBool(_pushAsked, true);

  static bool _same(Json a, Json b) =>
      a['kind'] == b['kind'] && str(a['value']).toLowerCase() == str(b['value']).toLowerCase();

  List<Json> _read(String key) {
    final raw = _sp.getString(key);
    if (raw == null) return [];
    try {
      return jsonList(jsonDecode(raw));
    } on FormatException {
      return [];
    }
  }

  Future<void> _write(String key, List<Json> items) => _sp.setString(key, jsonEncode(items));
}

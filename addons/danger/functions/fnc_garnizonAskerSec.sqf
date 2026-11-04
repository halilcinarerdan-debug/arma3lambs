#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KARAKOL GARNIZONU: ASKER SECIMI (v8.394; kullanici: 'garnizon icin istedigim askerleri menuden secebileyim'). Zeus 'ELITE Karakol Garnizon' modulunde 'Asker secimi = Elle' ise, ayar panelinden sonra acilan liste:
 * modulun 800 m cevresindeki AI askerler (oyuncusuz, aracta degil, bayilmamis, garnizon alt grubunda degil; yakindan uzaga, en fazla 48) 8'erli sayfalarla onay kutusu olarak listelenir.
 * Isaretlenenler garnizon HAVUZU olur (yaricap / 'kaynak grupta en az 3 asker' kurali uygulanmaz): nobetci, devriye ve ust kat nobeti YALNIZ bu askerlerden kurulur. Hicbiri secilmezse istek GONDERILMEZ.
 * Sunucu tarafi karakolun tarafindan farkli askerleri atlar (liste tum taraflari gosterir; taraf harfi etikette).
 *
 * Arguments:
 * 0: Modul konumu <ARRAY>
 * 1: Ayar degerleri [islem, nobet, devriye sayisi, devriye boyu, ust kat, arac, devriye mesafesi] <ARRAY>
 * 2: Adaylar (ilk cagrida []) <ARRAY>
 * 3: Baslangic indeksi <NUMBER>
 * 4: Secilen birim netId'leri <ARRAY>
 *
 * Return Value: None
 * Public: No
*/

params ["_poz", "_ayarD", ["_adaylar", []], ["_bas", 0], ["_secili", []]];

if (_adaylar isEqualTo []) then {
    _adaylar = allUnits select {
        alive _x && {!isPlayer _x} && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}
        && {(side (group _x)) in [west, east, independent]} && {(_x distance2D _poz) <= 800}
        && {((group _x) getVariable ["lambs_danger_garnizonAlt", ""]) isEqualTo ""}
    };
    _adaylar = [_adaylar, [], {_x distance2D _poz}, "ASCEND"] call BIS_fnc_sortBy;
    _adaylar = _adaylar select [0, 48 min (count _adaylar)];
    if (_adaylar isEqualTo []) exitWith {
        systemChat "[ELITE] Garnizon: modulun 800 m cevresinde secilebilir AI asker yok - istek gonderilmedi";
    };
};
if (_adaylar isEqualTo []) exitWith {};

private _parca = _adaylar select [_bas, 8];
if (_parca isEqualTo []) exitWith {
    if (_secili isEqualTo []) exitWith { systemChat "[ELITE] Garnizon: hic asker secilmedi - istek gonderilmedi"; };
    _ayarD params ["_islem", "_nobet", "_dev", "_devBoy", "_ust", "_arac", "_devMes", ["_iha", []], ["_aa", 0]];
    ["lambs_danger_garnizonIstegi", [_poz, _islem, round _nobet, round _dev, round _devBoy, _ust, _arac, _secili, round _devMes, [], _iha, _aa]] call CBA_fnc_serverEvent;
    diag_log format ["[KARAKOL-ISTEK] garnizon istegi (elle asker secimi %1) sunucuya gonderildi: nobet %2 | devriye %3 x %4 | devriye mesafesi %5", count _secili, round _nobet, round _dev, round _devBoy, round _devMes];
    systemChat format ["[ELITE] Karakol garnizon istegi gonderildi: %1 asker secildi", count _secili];
};

private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
private _alanlar = _parca apply {
    private _u = _x;
    [
        format ["%1 | %2 | %3 | %4 m | %5", name _u, [_u] call _rolFn, ["B", "O", "I"] select (([west, east, independent] find (side (group _u))) max 0), round (_u distance2D _poz), groupId (group _u)],
        "BOOLEAN",
        format ["%1 (%2). Isaretlenirse garnizon havuzuna girer (nobetci / devriye bu askerlerden kurulur). Etiket: ad | rol | taraf (B/O/I) | modulden uzaklik | grup.", name _u, rank _u],
        false,
        ""
    ]
};

[
    format ["ELITE Garnizon: asker secimi (%1-%2 / %3)", _bas + 1, _bas + count _parca, count _adaylar],
    _alanlar,
    {
        params ["_deger", "_args"];
        _args params ["_poz", "_ayarD", "_adaylar", "_bas", "_secili", "_parca"];
        {
            if (_deger select _forEachIndex) then { _secili pushBackUnique (netId _x); };
        } forEach _parca;
        [{
            params ["_poz", "_ayarD", "_adaylar", "_bas", "_secili"];
            [_poz, _ayarD, _adaylar, _bas + 8, _secili] call (missionNamespace getVariable ["lambs_danger_fnc_garnizonAskerSec", {}]);
        }, [_poz, _ayarD, _adaylar, _bas, _secili]] call CBA_fnc_execNextFrame;
    },
    {},
    {},
    [_poz, _ayarD, _adaylar, _bas, _secili, _parca]
] call EFUNC(main,showDialog);

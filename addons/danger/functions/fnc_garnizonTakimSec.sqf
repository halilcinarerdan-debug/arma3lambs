#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KARAKOL GARNIZONU: TAKIM (GRUP) SECIMI (v8.397; kullanici: 'hangi takimin garnizon atabilecegini secelim'). Zeus 'ELITE Karakol Garnizon' modulunde 'Asker secimi = Elle sec: takim (grup) listesi' ise ayar panelinden sonra acilan liste:
 * modulun 800 m cevresindeki AI takimlar (grup; oyuncusuz, canli lider, en az 4 saglam asker, garnizon alt grubu degil; yakindan uzaga, en fazla 24) 8'erli sayfalarla onay kutusu olarak listelenir.
 * Isaretlenen takimlar garnizon HAVUZUNU belirler: nobetci / devriye / ust kat nobeti YALNIZ bu takimlardan kurulur (yaricap kurali yok; 'kaynak takimda en az 3 asker kalir' ve hekim korumasi suruyor).
 * Hicbiri secilmezse istek GONDERILMEZ. Sunucu karakolun tarafindan farkli takimlari atlar (liste tum taraflari gosterir; taraf harfi etikette).
 *
 * Arguments:
 * 0: Modul konumu <ARRAY>
 * 1: Ayar degerleri [islem, nobet, devriye sayisi, devriye boyu, ust kat, arac, devriye mesafesi] <ARRAY>
 * 2: Adaylar (ilk cagrida []) <ARRAY>
 * 3: Baslangic indeksi <NUMBER>
 * 4: Secilen grup netId'leri <ARRAY>
 *
 * Return Value: None
 * Public: No
*/

params ["_poz", "_ayarD", ["_adaylar", []], ["_bas", 0], ["_secili", []]];

if (_adaylar isEqualTo []) then {
    _adaylar = allGroups select {
        private _l = leader _x;
        !isNull _l && {alive _l} && {!isPlayer _l} && {(side _x) in [west, east, independent]}
        && {({isPlayer _x} count (units _x)) isEqualTo 0}
        && {({alive _x && {(lifeState _x) in ["HEALTHY", "INJURED"]}} count (units _x)) >= 4}
        && {(_x getVariable ["lambs_danger_garnizonAlt", ""]) isEqualTo ""}
        && {(_l distance2D _poz) <= 800}
    };
    _adaylar = [_adaylar, [], {(leader _x) distance2D _poz}, "ASCEND"] call BIS_fnc_sortBy;
    _adaylar = _adaylar select [0, 24 min (count _adaylar)];
    if (_adaylar isEqualTo []) exitWith {
        systemChat "[ELITE] Garnizon: modulun 800 m cevresinde secilebilir AI takim yok (en az 4 saglam asker) - istek gonderilmedi";
    };
};
if (_adaylar isEqualTo []) exitWith {};

private _parca = _adaylar select [_bas, 8];
if (_parca isEqualTo []) exitWith {
    if (_secili isEqualTo []) exitWith { systemChat "[ELITE] Garnizon: hic takim secilmedi - istek gonderilmedi"; };
    _ayarD params ["_islem", "_nobet", "_dev", "_devBoy", "_ust", "_arac", "_devMes"];
    ["lambs_danger_garnizonIstegi", [_poz, _islem, round _nobet, round _dev, round _devBoy, _ust, _arac, [], round _devMes, _secili]] call CBA_fnc_serverEvent;
    diag_log format ["[KARAKOL-ISTEK] garnizon istegi (elle takim secimi %1) sunucuya gonderildi: nobet %2 | devriye %3 x %4 | devriye mesafesi %5", count _secili, round _nobet, round _dev, round _devBoy, round _devMes];
    systemChat format ["[ELITE] Karakol garnizon istegi gonderildi: %1 takim secildi", count _secili];
};

private _alanlar = _parca apply {
    private _g = _x;
    private _l = leader _g;
    private _n = {alive _x} count (units _g);
    private _rol = _g getVariable ["lambs_danger_gorev", ""];
    [
        format ["%1 | %2 asker | %3 | %4 m | %5%6", groupId _g, _n, ["B", "O", "I"] select (([west, east, independent] find (side _g)) max 0), round (_l distance2D _poz), rank _l, ["", " | " + _rol] select (_rol isNotEqualTo "")],
        "BOOLEAN",
        format ["Lider %1 (%2). Isaretlenirse bu takim garnizona asker verebilir (nobetci / devriye; takimda en az 3 asker kalir). Etiket: takim | asker | taraf (B/O/I) | modulden uzaklik | lider rutbesi.", name _l, rank _l],
        false,
        ""
    ]
};

[
    format ["ELITE Garnizon: takim secimi (%1-%2 / %3)", _bas + 1, _bas + count _parca, count _adaylar],
    _alanlar,
    {
        params ["_deger", "_args"];
        _args params ["_poz", "_ayarD", "_adaylar", "_bas", "_secili", "_parca"];
        {
            if (_deger select _forEachIndex) then { _secili pushBackUnique (netId _x); };
        } forEach _parca;
        [{
            params ["_poz", "_ayarD", "_adaylar", "_bas", "_secili"];
            [_poz, _ayarD, _adaylar, _bas + 8, _secili] call (missionNamespace getVariable ["lambs_danger_fnc_garnizonTakimSec", {}]);
        }, [_poz, _ayarD, _adaylar, _bas, _secili]] call CBA_fnc_execNextFrame;
    },
    {},
    {},
    [_poz, _ayarD, _adaylar, _bas, _secili, _parca]
] call EFUNC(main,showDialog);

#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * 3DEN (EDEN EDITOR) MODUL YARDIMCILARI (v8.362; kullanici: 'zeus zorunlu olmasin, 3den senaryo yapilabilsin, modullerle sync'). Tum 3DEN modulleri (fnc_eden*) bu yardimciyi kullanir.
 *   "BEKLE"            : (zamanlanmis ortamda) ELITE sunucu kapisi + plan fonksiyonu hazir olana ve mission en az 4 sn ilerleyene kadar bekler (en cok 180 sn). Doner: hazir mi <BOOL>
 *   "SAYI" [modul, ad, varsayilan]  : modul niteligi (Edit / Combo) sayi olarak <NUMBER>
 *   "BOOL" [modul, ad, varsayilan]  : modul niteligi (Checkbox) <BOOL>
 *   "GRUPLAR" [modul]  : module SYNC ile baglanan askerlerin / araclarin (muretttebat komutani) benzersiz gruplari <ARRAY of GROUP>
 *   "BAGLI" [modul]    : module SYNC ile baglanan, modul olmayan nesneler <ARRAY>
 *   "MODUL" [modul, sinif] : module baglanan belirli sinifta moduller <ARRAY>
 *   "TARAF" [modul, nitelik adi, gruplar] : 0 = otomatik (ilk grubun tarafi, yoksa BLUFOR), 1 BLUFOR, 2 OPFOR, 3 INDEP <SIDE>
 *   "MESAJ" [metin]    : metni tum istemcilere (systemChat) + RPT'ye yazar
 * Log: [EDEN]
 *
 * Arguments: 0: islem <STRING>, 1: arguman dizisi <ARRAY>
 * Return Value: islemin sonucu
 * Public: No
*/

params [["_mod", "", [""]], ["_a", []]];

switch (_mod) do {
    case "BEKLE": {
        private _t = diag_tickTime + 180;
        waitUntil { sleep 0.5; ((!isNil "lambs_danger_planKapiStarted") && {!isNil "lambs_danger_fnc_komutanPlan"} && {time > 4}) || {diag_tickTime > _t} };
        !isNil "lambs_danger_planKapiStarted"
    };
    case "SAYI": {
        _a params ["_m", "_ad", ["_vars", 0]];
        private _v = _m getVariable [_ad, _vars];
        if (_v isEqualType "") then { parseNumber _v } else { if (_v isEqualType 0) then {_v} else {_vars} }
    };
    case "BOOL": {
        _a params ["_m", "_ad", ["_vars", false]];
        private _v = _m getVariable [_ad, _vars];
        if (_v isEqualType true) then {_v} else { if (_v isEqualType 0) then {_v > 0} else { if (_v isEqualType "") then { (toLower _v) in ["true", "1"] } else {_vars} } }
    };
    case "BAGLI": {
        _a params ["_m"];
        (synchronizedObjects _m) select {!isNull _x && {!(_x isKindOf "Logic")}}
    };
    case "MODUL": {
        _a params ["_m", "_sinif"];
        (synchronizedObjects _m) select {(typeOf _x) isEqualTo _sinif}
    };
    case "GRUPLAR": {
        _a params ["_m"];
        private _g = [];
        {
            private _o = _x;
            private _grp = grpNull;
            // v8.407: SYNC'li IHA (dron) ve ekibi plan grubu degildir (Objektif'e IHA destegi olarak baglanir)
            if (unitIsUAV _o || {_o isKindOf "CAManBase" && {!isNull objectParent _o} && {unitIsUAV (objectParent _o)}}) then { continue };
            if (_o isKindOf "CAManBase") then {
                _grp = group _o;
            } else {
                private _c = effectiveCommander _o;
                if (!isNull _c) then { _grp = group _c; };
            };
            if (!isNull _grp && {(side _grp) in [west, east, independent]}) then { _g pushBackUnique _grp; };
        } forEach (["BAGLI", [_m]] call FUNC(edenOrtak));
        _g
    };
    case "TARAF": {
        _a params ["_m", "_ad", ["_gr", []]];
        private _i = round (["SAYI", [_m, _ad, 0]] call FUNC(edenOrtak));
        if (_i <= 0) then {
            if (_gr isNotEqualTo []) then { side (_gr select 0) } else { west }
        } else {
            [west, east, independent] select ((_i - 1) min 2)
        }
    };
    case "MESAJ": {
        _a params ["_t"];
        diag_log format ["[EDEN] %1", _t];
        ["lambs_danger_garnizonYanit", [_t]] call CBA_fnc_globalEvent;
    };
    default { diag_log format ["[EDEN] bilinmeyen islem: %1", _mod]; nil };
};

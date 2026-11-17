#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * YAKIN MESAFE ALGISI (v8.567; kullanici: '20 metre icinde tum spot time ve kamuflaj farkindaligini dusuren seyleri kapatabilirsin').
 * Dusmana CBA 'yakinAlgiM' (20 m) icindeki yerel AI askerde algiyi DUSUREN katmanlar kapatilir:
 *   - kamuflaj: camouflageCoef (fnc_kamuflaj: duruyor / alaca / gece / sis / renk uyumu ile dusurulmus) en az 1.0'a cekilir (artiranlar korunur); fnc_kamuflaj o birime dokunmaz;
 *   - spot: spotDistance ve spotTime (fnc_ortamSkill isik / sis / yagmur cezasi + varsayilan beceri 'farkindalik' tabani) en az 0.95'e cikarilir; fnc_ortamSkill o birime dokunmaz.
 *   Dusman yaricap + 6 m disina cikinca (histerezis) eski camouflageCoef ve spot degerleri geri yazilir, katmanlar yeniden calisir. Oyuncuya, sivile dokunulmaz; dusman = taraf dostlugu < 0.6, canli, esir degil.
 * Tarama 1 sn'de bir (tick basina en cok 60 birim donusumlu; kapsamdaki birim her tick kontrol edilir). Log: [YAKIN-ALGI] (ilk 15) + 60 sn ozeti. Kapatma: CBA yakinAlgi.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_yakinAlgiStarted") exitWith {false};
lambs_danger_yakinAlgiStarted = true;
diag_log "[YAKIN-ALGI] yakin mesafe algisi (kamuflaj / spot dusurucu katmanlari kapat) baslatildi (v8.567)";

[] spawn {
    private _indeks = 0;
    private _logN = 0;
    private _giren = 0;
    private _cikan = 0;
    private _ozetT = time + 60;
    private _dusmanVar = {
        params ["_u", "_m"];
        private _s = side group _u;
        ((_u nearEntities ["CAManBase", _m]) findIf {
            _x isNotEqualTo _u && {alive _x} && {!captive _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {(side group _x) isNotEqualTo civilian} && {(_s getFriend (side group _x)) < 0.6}
        }) >= 0
    };
    while {true} do {
        sleep 1;
        private _aktif = missionNamespace getVariable ["lambs_danger_yakinAlgi", true];
        private _m = if (_aktif) then { (missionNamespace getVariable ["lambs_danger_yakinAlgiM", 20]) max 0 } else { 0 };
        // 1) kapsamdakiler: cikti mi? (her tick)
        {
            private _u = _x;
            if (!alive _u || {_m <= 0} || {!([_u, _m + 6] call _dusmanVar)}) then {
                private _eski = _u getVariable [QGVAR(yakinAlgiEski), []];
                if (alive _u && {_eski isNotEqualTo []}) then {
                    _u setSkill ["spotDistance", _eski select 0];
                    _u setSkill ["spotTime", _eski select 1];
                    _u setUnitTrait ["camouflageCoef", _eski select 2];
                };
                _u setVariable [QGVAR(yakinAlgi), nil];
                _u setVariable [QGVAR(yakinAlgiEski), nil];
                _cikan = _cikan + 1;
            };
        } forEach (allUnits select {local _x && {_x getVariable [QGVAR(yakinAlgi), false]}});
        if (_m <= 0) then { continue };
        // 2) girenler (donusumlu 60 birim)
        private _adaylar = allUnits select {local _x && {alive _x} && {!isPlayer _x} && {_x isKindOf "CAManBase"} && {(side group _x) in [west, east, resistance]} && {isNull objectParent _x} && {!(_x getVariable [QGVAR(yakinAlgi), false])}};
        private _n = count _adaylar;
        if (_n > 0) then {
            for "_i" from 0 to ((60 min _n) - 1) do {
                private _u = _adaylar select ((_indeks + _i) mod _n);
                if !([_u, _m] call _dusmanVar) then { continue };
                private _kc = _u getUnitTrait "camouflageCoef";
                private _sd = _u skill "spotDistance";
                private _st = _u skill "spotTime";
                _u setVariable [QGVAR(yakinAlgiEski), [_sd, _st, _kc]];
                _u setVariable [QGVAR(yakinAlgi), true];
                _u setUnitTrait ["camouflageCoef", _kc max 1];
                _u setSkill ["spotDistance", _sd max 0.95];
                _u setSkill ["spotTime", _st max 0.95];
                _giren = _giren + 1;
                if (_logN < 15) then {
                    _logN = _logN + 1;
                    diag_log format ["[YAKIN-ALGI] %1 %2 | %3 | dusman <= %4 m: camouflageCoef %5 -> %6 | spotDistance %7 -> %8 | spotTime %9 -> %10 | kamuflaj / ortam beceri katmanlari bu birimde durduruldu", str (side group _u), groupId group _u, name _u, _m, _kc toFixed 2, (_kc max 1) toFixed 2, _sd toFixed 2, (_sd max 0.95) toFixed 2, _st toFixed 2, (_st max 0.95) toFixed 2];
                };
            };
            _indeks = _indeks + 60;
        };
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if (_giren + _cikan > 0) then { diag_log format ["[YAKIN-ALGI-OZET] 60 sn: yakin algiya giren %1 | cikan %2 | su an kapsamda %3", _giren, _cikan, count (allUnits select {_x getVariable [QGVAR(yakinAlgi), false]})]; };
            _giren = 0; _cikan = 0;
        };
    };
};
true

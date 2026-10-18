#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TANK MURETTEBAT TAMAMLAMA + KOLTUK DEGISTIRME (v8.252) — kullanici (RPT f39a5919, 20:05-20:25): "bir crew yayan olarak kaldi, koltuk degistirme olabilir".
 * Olay: T-14 surucusuz (canMove false) kalinca murettebat (Egor Baranov (K) nisanci, Vasil Makarov, Yuri Ivanov) indi; arac 90 sn sonra hareket etti ama ucu yaya kaldi (biri baygin, biri araba carpti: [EZME-BAYGIN]),
 * murettebatKoru geri cagirmadi ('assignedVehicle' atamasi inme ile silindi + grup 20 sn temasli). Tank nisanci / surucu olmadan savasa girdi (T-14 20:18-20:25 yalniz surucuyla ilerledi).
 * Kural (3 sn'de bir; yerel, oyuncusuz TANK sinifi arac; yanan / hasar > 0.85 haric):
 *   1) KOLTUK DEGISTIRME: nisanci (oncelik 1) ya da surucu (2) koltugu bos / olu ise ve aracin icinde SAGLIKLI baska bir murettebat (komutan) varsa komutan o koltuga gecer (moveOut + 0.4 sn sonra moveIn; arac hizi < 6 km/s).
 *      Olu murettebat cesedi koltuktan cikarilir (moveOut) ki koltuk bos sayilsin. Baygin (ACE) murettebata dokunulmaz.
 *   2) GERI DONUS: kayitli murettebat (murettebatKoru kaydi) 150 m icinde yaya, saglikli / yarali ise ve bos koltugu varsa koltuguna doner (assignAs + moveIn <= 12 m, yoksa orderGetIn); inme atamasi silinmis olsa da.
 *      Grup son 8 sn temasliysa yalniz 40 m icindekiler doner (ates altinda uzaga kosturulmaz). 6 sn / birim bekleme (murDonT, murettebatKoru ile ortak).
 * Kapatma: lambs_danger_tankMurettebatOff = true.  Log: [TANK-MURETTEBAT] (ilk 60).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_tankMurettebatStarted") exitWith {false};
lambs_danger_tankMurettebatStarted = true;

diag_log "[TANK-MURETTEBAT] tank murettebat tamamlama + koltuk degistirme watchdog'u baslatildi (v8.252)";

private _calis = {
    private _logN = 0;
    private _saglikli = {
        params ["_u"];
        alive _u && {(lifeState _u) in ["HEALTHY", "INJURED"]} && {!(_u getVariable ["ACE_isUnconscious", false])}
    };
    private _koltuga = {
        // [birim, arac, rol (STRING)] ; rol: "gunner" | "driver" | "commander"
        params ["_u", "_v", "_rol"];
        _u setVariable [QGVAR(murDonT), time];
        _u enableAI "PATH";
        _u enableAI "MOVE";
        switch (_rol) do {
            case "gunner": { _u assignAsGunner _v; };
            case "driver": { _u assignAsDriver _v; };
            default { _u assignAsCommander _v; };
        };
        if ((_u distance2D _v) < 12 || {(vehicle _u) isEqualTo _v}) then {
            switch (_rol) do {
                case "gunner": { _u moveInGunner _v; };
                case "driver": { _u moveInDriver _v; };
                default { _u moveInCommander _v; };
            };
        } else {
            [_u] orderGetIn true;
        };
    };
    while {true} do {
        sleep 3;
        if (missionNamespace getVariable ["lambs_danger_tankMurettebatOff", false]) then { continue };
        {
            private _v = _x;
            if (!local _v || {!alive _v} || {!(_v isKindOf "LandVehicle")} || {isBurning _v} || {(damage _v) > 0.85}) then { continue };
            if ((crew _v) findIf {isPlayer _x} >= 0) then { continue };
            if ((([_v] call FUNC(aracSinif)) select 0) isNotEqualTo "TANK") then { continue };

            private _fc = fullCrew [_v, "", true];
            private _gnU = objNull; private _drU = objNull; private _kmU = objNull;
            {
                _x params ["_u", "_rol"];
                switch (toLower _rol) do {
                    case "gunner": { _gnU = _u; };
                    case "driver": { _drU = _u; };
                    case "commander": { _kmU = _u; };
                };
            } forEach _fc;

            // olu murettebat cesedi koltugu tikamasin
            {
                if (!isNull _x && {!alive _x}) then {
                    moveOut _x;
                    if (_x isEqualTo _gnU) then { _gnU = objNull; };
                    if (_x isEqualTo _drU) then { _drU = objNull; };
                    if (_x isEqualTo _kmU) then { _kmU = objNull; };
                };
            } forEach [_gnU, _drU, _kmU];

            private _eksik = [];
            if (isNull _gnU && {(_v emptyPositions "gunner") > 0}) then { _eksik pushBack "gunner"; };
            if (isNull _drU && {(_v emptyPositions "driver") > 0}) then { _eksik pushBack "driver"; };
            if (_eksik isEqualTo []) then { continue };

            // kayitli murettebat yayada mi? (geri donus)
            private _kayit = (_v getVariable [QGVAR(murKayit), []]) select {alive (_x select 0) && {isNull objectParent (_x select 0)}};
            private _gr = group (driver _v);
            private _grTemas = if (isNull _gr) then {false} else {(time - (_gr getVariable [QGVAR(contact), -999])) < 8};
            {
                private _rol = _x;
                private _donen = objNull;
                // once ayni rolun sahibi, sonra herhangi bir kayitli murettebat
                private _adaylar = _kayit select {([_x select 0] call _saglikli) && {(time - ((_x select 0) getVariable [QGVAR(murDonT), -999])) >= 6} && {((_x select 0) distance2D _v) <= 150} && {!_grTemas || {((_x select 0) distance2D _v) < 40}}};
                _adaylar = [_adaylar, [], {([0, -1000] select ((toLower (_x select 1)) isEqualTo _rol)) + ((_x select 0) distance2D _v)}, "ASCEND"] call BIS_fnc_sortBy;
                if (_adaylar isNotEqualTo []) then { _donen = (_adaylar select 0) select 0; };
                if (!isNull _donen) then {
                    [_donen, _v, _rol] call _koltuga;
                    _kayit = _kayit select {(_x select 0) isNotEqualTo _donen};
                    if (_logN < 60) then {
                        _logN = _logN + 1;
                        diag_log format ["[TANK-MURETTEBAT] %1 (%2) | %3 yayaydi (%4 m) -> %5 koltuguna donuyor", getText (configOf _v >> "displayName"), groupId (group _donen), name _donen, round (_donen distance2D _v), _rol];
                    };
                    continue
                };
                // aracin icinden koltuk degistirme: komutan nisanci / surucu koltuguna gecer
                if (!isNull _kmU && {[_kmU] call _saglikli} && {(abs (speed _v)) < 6} && {(time - (_kmU getVariable [QGVAR(murDonT), -999])) >= 6}) then {
                    private _kmEski = _kmU;
                    _kmU = objNull;
                    _kmEski setVariable [QGVAR(murDonT), time];
                    moveOut _kmEski;
                    [{
                        params ["_u", "_arac", "_r", "_koltuga"];
                        if (alive _u && {alive _arac}) then {
                            switch (_r) do {
                                case "gunner": { _u assignAsGunner _arac; _u moveInGunner _arac; };
                                default { _u assignAsDriver _arac; _u moveInDriver _arac; };
                            };
                        };
                    }, [_kmEski, _v, _rol, _koltuga], 0.4] call CBA_fnc_waitAndExecute;
                    if (_logN < 60) then {
                        _logN = _logN + 1;
                        diag_log format ["[TANK-MURETTEBAT] %1 (%2) | %3 koltuk degistirdi: komutan -> %4 (koltuk bos / olu)", getText (configOf _v >> "displayName"), groupId (group _kmEski), name _kmEski, _rol];
                    };
                };
            } forEach _eksik;
        } forEach (vehicles select {_x isKindOf "LandVehicle" && {alive _x} && {local _x}});
    };
};

[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log "[WATCHDOG-YENIDEN] tankMurettebat betigi sonlandi (hata?)";
        sleep 5;
    };
};

true

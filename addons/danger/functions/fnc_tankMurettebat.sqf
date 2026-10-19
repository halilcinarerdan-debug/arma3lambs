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
 *      Grup son 8 sn temasliysa yalniz 80 m icindekiler doner (ates altinda uzaga kosturulmaz). 6 sn / birim bekleme (murDonT, murettebatKoru ile ortak).
 *   3) ARAC BEKLER (kullanici: 'yayan kaldi, tank ilerledi, squad leader olarak o kovaladi'): nisanci / surucu koltugu bos ve kayitli murettebat 150 m icinde yayaysa, en yakin dusman >= 150 m ise arac surucusu doStop alir
 *      (en cok 25 sn; planZirh 20 sn dokunmaz - tankManevraT yenilenir), murettebat binince / sure dolunca birakilir. [TANK-MURETTEBAT] ... BEKLIYOR.
 * v8.256 (RPT e31bd8bd, 10:12-10:15): motoru vurulan (hitengine 0.90, canMove false) hasarsiz T-14'un murettebati MOTOR HASARI SONRASI motor zorunlu olarak 'GET OUT' aldi (AI terk eder), v8.252 mantigi onlari geri soktu, motor yine kovdu: 3 kisi 2.5 dk
 *   surekli in / bin dongusunde ([ARAC-TERK] 48, [ARAC-BINDI] 41). Duzeltme: (a) TANK / IFV icin 'allowCrewInImmobile true' (hareket edemeyen arac sabit mevzi olarak murettebatini tutar; ates edebildigi surece);
 *   (b) dongu kesici: ayni aracta 60 sn'de >= 6 geri donus -> 120 sn durur ([TANK-MURETTEBAT] DONGU KESILDI). Kapatma: lambs_danger_crewImmobileOff = true (yalniz (a)).
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
            private _sinifTM = (([_v] call FUNC(aracSinif)) select 0);
            if (_sinifTM in ["TANK", "IFV"] && {!(_v getVariable [QGVAR(crewImmobileAyar), false])} && {!(missionNamespace getVariable ["lambs_danger_crewImmobileOff", false])}) then {
                _v setVariable [QGVAR(crewImmobileAyar), true];
                _v allowCrewInImmobile true;
            };
            if (_sinifTM isNotEqualTo "TANK") then { continue };
            // dongu kesici
            if (time < (_v getVariable [QGVAR(murDongu), 0])) then { continue };
            private _donL = (_v getVariable [QGVAR(murDonL), []]) select {(time - _x) < 60};
            // v8.258: esik 6 -> 3 ve bekleme 120 -> 300 sn (RPT f8ad6949: allowCrewInImmobile motor hasarinda (hitengine 0.90) murettebatin inmesini ONLEMEDI - T-72 murettebati 8 kez dongu kesiciye takildi); terk edilen motor-oldu tank birakilir
            if ((count _donL) >= 3) then {
                _v setVariable [QGVAR(murDonL), []];
                _v setVariable [QGVAR(murDongu), time + 300];
                if (_logN < 60) then { _logN = _logN + 1; diag_log format ["[TANK-MURETTEBAT] %1 | DONGU KESILDI: 60 sn'de %2 geri donus -> 300 sn durur (arac hasar %3, canMove %4)", getText (configOf _v >> "displayName"), count _donL, (damage _v) toFixed 2, canMove _v]; };
                continue
            };
            _v setVariable [QGVAR(murDonL), _donL];

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
            if (_eksik isEqualTo []) then { _v setVariable [QGVAR(murBekleT0), -1]; continue };

            // kayitli murettebat yayada mi? (geri donus)
            private _kayit = (_v getVariable [QGVAR(murKayit), []]) select {alive (_x select 0) && {isNull objectParent (_x select 0)}};
            // ARAC BEKLER: yayadaki saglikli murettebat 150 m icinde, dusman yakin degil -> surucu durur (en cok 25 sn)
            private _yayaMur = _kayit select {([_x select 0] call _saglikli) && {((_x select 0) distance2D _v) <= 150}};
            private _surucu = driver _v;
            if (_yayaMur isNotEqualTo [] && {!isNull _surucu} && {alive _surucu} && {!isPlayer _surucu}) then {
                private _bT0 = _v getVariable [QGVAR(murBekleT0), -1];
                if (_bT0 < 0) then { _bT0 = time; _v setVariable [QGVAR(murBekleT0), time]; };
                private _dusman = (driver _v) findNearestEnemy _v;
                if ((time - _bT0) <= 25 && {isNull _dusman || {(_v distance2D _dusman) >= 150}}) then {
                    doStop _surucu;
                    _v setVariable [QGVAR(tankManevraT), time];
                    if ((time - (_v getVariable [QGVAR(murBekleLogT), -999])) > 20 && {_logN < 60}) then {
                        _v setVariable [QGVAR(murBekleLogT), time];
                        _logN = _logN + 1;
                        diag_log format ["[TANK-MURETTEBAT] %1 | BEKLIYOR: %2 murettebat yayada (en yakin %3 m), koltuk bos: %4 | en cok 25 sn", getText (configOf _v >> "displayName"), count _yayaMur, round (selectMin (_yayaMur apply {(_x select 0) distance2D _v})), _eksik];
                    };
                };
            } else {
                _v setVariable [QGVAR(murBekleT0), -1];
            };
            private _gr = group (driver _v);
            private _grTemas = if (isNull _gr) then {false} else {(time - (_gr getVariable [QGVAR(contact), -999])) < 8};
            {
                private _rol = _x;
                private _donen = objNull;
                // once ayni rolun sahibi, sonra herhangi bir kayitli murettebat
                private _adaylar = _kayit select {([_x select 0] call _saglikli) && {(time - ((_x select 0) getVariable [QGVAR(murDonT), -999])) >= 6} && {((_x select 0) distance2D _v) <= 150} && {!_grTemas || {((_x select 0) distance2D _v) < 80}}};
                _adaylar = [_adaylar, [], {([0, -1000] select ((toLower (_x select 1)) isEqualTo _rol)) + ((_x select 0) distance2D _v)}, "ASCEND"] call BIS_fnc_sortBy;
                if (_adaylar isNotEqualTo []) then { _donen = (_adaylar select 0) select 0; };
                if (!isNull _donen) then {
                    [_donen, _v, _rol] call _koltuga;
                    (_v getVariable [QGVAR(murDonL), []]) pushBack time;
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

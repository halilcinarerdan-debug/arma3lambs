#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TANK DRON SAVUNMASI (v8.280; kullanici: 'tanklar drona karsi tavir takinsin, daha koordine ve zeki olsunlar'). FPV-AT kamikaze dronlari (Crocus AT) zirhin motor / ust bolgesine dalar.
 * Mevzideki / hareket halindeki tank (fnc_planZirh, 3 sn'de bir):
 *   - tehdit: 700 m icinde, <= 200 m yukseklikte, DUSMAN (getFriend < 0.6) dron; grup lideri bilir (knowsAbout > 0.2) YA DA yakin dost tankin 20 sn icindeki dron uyarisi (koordinasyon)
 *   - 1) UYARI: yakindaki (<= 900 m) dost zirhli araclara dron konumu / zaman bildirilir (lambs_danger_tankDronUyari)
 *   - 2) YON: tehdit <= 600 m ise murettebat dronun gelis yonune doWatch (taret ve komutan dronu izler)
 *   - 3) ATES: <= 500 m ise taret disindaki (komutan / nisanci) MG'li murettebat doTarget + doFire (koaksiyel / komutan makineli); 3 sn'de bir
 *   - 4) DUMAN: kamikaze tur, <= 520 m ve (yaklasiyor ya da <= 300 m) ise fnc_aracDuman (gorus hattini keser; v8.318: 14 sn bekleme)
 *   - 5) KACINMA: v8.318 zigzag: <= 380 m ve kapanma > 4 m/sn, canMove: 38 m yana + 4.5 sn sonra ters yana (FULL hiz), mevzi kilidi gecici acilir, ~11 sn sonra durur. 12 sn bekleme.
 * Kapatma: lambs_danger_tankDronOff = true.  Log: [TANK-DRON]
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Arac <OBJECT>
 * 2: Surucu <OBJECT>
 *
 * Return Value: Tepki verildi mi <BOOL>
 * Public: No
*/

params ["_g", "_v", "_d"];
if (missionNamespace getVariable ["lambs_danger_tankDronOff", false]) exitWith {false};
if (isNull _v || {!alive _v} || {!local _v}) exitWith {false};
if ((time - (_v getVariable [QGVAR(tankDronT), -99])) < 3) exitWith {false};
_v setVariable [QGVAR(tankDronT), time];

private _l = leader _g;
private _taraf = side _g;
private _dronlar = (_v nearEntities ["Air", 700]) select {
    unitIsUAV _x && {alive _x} && {((getPosATL _x) select 2) <= 200}
    && {(_taraf getFriend (side (group (effectiveCommander _x)))) < 0.6}
    && {((_g knowsAbout _x) > 0.2) || {(!isNull _l && {(_l knowsAbout _x) > 0.2})} || {(time - (_v getVariable [QGVAR(tankDronUyari), [-99]] select 0)) < 20}}   // v8.319: grup bilgisi de sayilir
};
// koordinasyon: dost tankin uyarisi (dron henuz bilinmiyor olsa da)
private _dr = objNull;
if (_dronlar isNotEqualTo []) then {
    _dr = ([_dronlar, [], {_x distance _v}, "ASCEND"] call BIS_fnc_sortBy) select 0;
};
if (isNull _dr) exitWith {false};

private _dist = _v distance _dr;
private _tip = [_dr] call FUNC(ihaTip);
private _kamikaze = _tip in ["FPV-AT", "FPV-AP", "BOMBA"] || {((_dr weaponsTurret [-1]) isNotEqualTo [])};
// kapanma hizi: dronun hizinin tanka dogru bileseni
private _yonT = (getPosASL _v) vectorDiff (getPosASL _dr);
private _kap = if ((vectorMagnitude _yonT) > 1) then { (velocity _dr) vectorDotProduct (vectorNormalized _yonT) } else {0};

// 1) UYARI: yakin dost zirhli araclar
{
    if (_x isNotEqualTo _v && {local _x}) then {
        _x setVariable [QGVAR(tankDronUyari), [time, getPosATL _dr]];
    };
} forEach ((_v nearEntities [["Tank", "Wheeled_APC_F", "Tracked_APC_F"], 900]) select {(side (group (effectiveCommander _x))) isEqualTo _taraf});

private _eylem = [];
// 2) YON: murettebat dronu izler
if (_dist <= 600) then {
    { if (alive _x) then { _x doWatch _dr; }; } forEach (crew _v);
    _eylem pushBack "YON";
};
// 3) ATES: komutan / nisanci makineli (taret ana topu disinda MG)
if (_dist <= 500) then {
    private _n = 0;
    {
        private _u = _x;
        if (alive _u && {!isPlayer _u}) then {
            private _yol = _v unitTurret _u;
            private _silahlar = (_v weaponsTurret _yol) select {
                private _a = getText (configFile >> "CfgAmmo" >> getText (configFile >> "CfgMagazines" >> ((getArray (configFile >> "CfgWeapons" >> _x >> "magazines")) param [0, ""]) >> "ammo") >> "simulation");
                (toLower _a) in ["shotbullet", "shotsubmunitions", "shotbullet"]
            };
            if (_silahlar isNotEqualTo []) then {
                (group _u) reveal [_dr, 4];
                _u doTarget _dr;
                _u doFire _dr;
                _n = _n + 1;
                // v8.300 ZORLA ATES (piyadede v8.295-v8.299'da dogrulandi: doTarget / doFire kucuk dronu AI tarafindan yok sayiliyor, zorla atis calisti): taret MG'si dronun ongorulu noktasina doWatch ile cevrilir,
                //   silah yonu <= 5 derece olunca vehicle fireAtTarget ile 4'lu kisa atis. 5 sn'lik dongu, 5 sn'de bir birim basina. Kapatma: lambs_danger_tankZorlaOff = true.
                if (!(missionNamespace getVariable ["lambs_danger_tankZorlaOff", false]) && {(time - (_u getVariable [QGVAR(tankZorlaT), -99])) > 5}) then {
                    _u setVariable [QGVAR(tankZorlaT), time];
                    if (isNil {_v getVariable QGVAR(tankAtisEH)}) then {
                        _v setVariable [QGVAR(tankAtisEH), true];
                        _v addEventHandler ["Fired", { params ["_vv"]; if ((time - (_vv getVariable [QGVAR(tankZorlaT2), -99])) < 8) then { _vv setVariable [QGVAR(tankAtisN), (_vv getVariable [QGVAR(tankAtisN), 0]) + 1]; }; }];
                    };
                    [_v, _u, _silahlar select 0, _dr] spawn {
                        params ["_v", "_u", "_w", "_dr"];
                        _v setVariable [QGVAR(tankZorlaT2), time];
                        private _bit = time + 5;
                        private _wT = 0;
                        private _min = 180;
                        while {time < _bit && {alive _v} && {alive _u} && {!isNull _dr} && {alive _dr} && {(_v ammo _w) > 0}} do {
                            private _lead = ASLToAGL ((getPosASL _dr) vectorAdd ((velocity _dr) vectorMultiply (((_v distance _dr) / 800) min 1.5)));
                            if (time >= _wT) then { _u doWatch _lead; _wT = time + 1; };
                            sleep 0.3;
                            private _fark = (AGLToASL _lead) vectorDiff (getPosASL _v);
                            private _wd = _v weaponDirection _w;
                            if ((vectorMagnitude _fark) > 1 && {(vectorMagnitude _wd) > 0.1}) then {
                                private _aci = acos ((((vectorNormalized _wd) vectorDotProduct (vectorNormalized _fark)) min 1) max -1);
                                if (_aci < _min) then { _min = _aci; };
                                if (_aci < 5) then {
                                    for "_k" from 1 to 4 do {
                                        _v fireAtTarget [_dr, _w];
                                        _v setVariable [QGVAR(tankZorlaN), (_v getVariable [QGVAR(tankZorlaN), 0]) + 1];
                                        sleep 0.12;
                                    };
                                };
                            };
                        };
                        _u doWatch objNull;
                        _v setVariable [QGVAR(tankZorlaAci), _min];
                    };
                };
            };
        };
    } forEach ([(commander _v), (gunner _v)] select {!isNull _x});
    if (_n > 0) then { _eylem pushBack format ["ATES(%1)", _n]; };
};
// 4) DUMAN
// v8.318 (kullanici: 'yakinlasinca smoke kullanimi artsin, bu testte hic olmadi'; RPT 24-10 03:01: dron hic bilinmedi -> TANK-DRON 0; Crocus CBA ayari duzeltildi): kamikaze <= 520 m ve (yaklasiyor ya da <= 300 m) -> duman; ayni arac icin bekleme 30 -> 14 sn (ikinci / ucuncu perde)
if (_kamikaze && {_dist <= 520} && {_kap > 0 || {_dist <= 300}}) then {
    if ((time - (_v getVariable [QGVAR(tankDronDumanT), -99])) > 14) then {
        _v setVariable [QGVAR(tankDronDumanT), time];
        [{ params ["_vv"]; if (!isNull _vv && {alive _vv}) then { [_vv, 14] call FUNC(aracDuman); }; }, [_v], 1.0] call CBA_fnc_waitAndExecute;
        _eylem pushBack "DUMAN";
    };
};
// 5) KACINMA (v8.318: 'araca dron gelirken kacsin, hareket edebilsin')
//   kamikaze <= 380 m ve kapanma > 4 m/sn: ZIGZAG kacis: 1. ayak dronun gelis yonune dik 38 m (+ 10 m geri), 4.5 sn sonra 2. ayak ters yana (+ 15 m geri); FULL hiz, hareket kilidi (mevzi) gecici acilir, ~11 sn sonra durur / yeniden kilitlenir. 12 sn bekleme.
if (_kamikaze && {_dist <= 380} && {_kap > 4} && {canMove _v} && {(time - (_v getVariable [QGVAR(tankDronKacT), -99])) > 12}) then {
    _v setVariable [QGVAR(tankDronKacT), time];
    private _gelisDir = _v getDir _dr;
    private _taraf2 = selectRandom [90, -90];
    private _yan1 = (_v getPos [38, _gelisDir + _taraf2]) getPos [10, _gelisDir + 180];
    if (!surfaceIsWater _yan1) then {
        _d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1; _d setSpeedMode "FULL";
        _d doMove _yan1;
        _v setVariable [QGVAR(tankManevraT), time + 8];   // planZirh yeniden yonlendirmesi susar (8 sn daha)
        _eylem pushBack "KACINMA";
        [_v, _d, _g, _gelisDir, _taraf2] spawn {
            params ["_vv", "_dd", "_g2", "_gd", "_t2"];
            sleep 4.5;
            if (isNull _vv || {!alive _vv} || {isNull _dd} || {!alive _dd} || {!canMove _vv}) exitWith {};
            private _yan2 = (_vv getPos [34, _gd - _t2]) getPos [15, _gd + 180];
            if (!surfaceIsWater _yan2) then { _dd enableAI "MOVE"; _dd doMove _yan2; };
            sleep 6;
            if (isNull _vv || {!alive _vv} || {isNull _dd} || {!alive _dd}) exitWith {};
            doStop _dd;
            if (_g2 getVariable ["lambs_danger_planZirhKilit", false]) then { _dd disableAI "MOVE"; };
        };
    };
};

if (_eylem isNotEqualTo [] && {(time - (_v getVariable [QGVAR(tankDronLogT), -99])) > 8}) then {
    _v setVariable [QGVAR(tankDronLogT), time];
    diag_log format ["[TANK-DRON] %1 | %2 | dron %3 (%4) %5 m | kapanma %6 m/sn | yukseklik %7 m | tepki: %8 | GERCEK ATIS %9 | zorla atis %10 | en kucuk nisan acisi %11 derece", groupId _g, getText (configOf _v >> "displayName"), typeOf _dr, _tip, round _dist, _kap toFixed 1, round ((getPosATL _dr) select 2), _eylem joinString "+", _v getVariable [QGVAR(tankAtisN), 0], _v getVariable [QGVAR(tankZorlaN), 0], round (_v getVariable [QGVAR(tankZorlaAci), 180])];
};
_eylem isNotEqualTo []

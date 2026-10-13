#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KINEMATIK SURUS (v8.209) — AI surucu arac emrini yurutmedigi zaman (RPT cbe5b5ed / 77520229 / 91b5ffbd: RHS Stryker + M113A3 kalkmadi; fizik serbest, rota hesaplanabiliyor, setDriveOnPath da sonuc vermedi) SON CARE:
 * arac, calculatePath ile hesaplanan rota (yoksa dogrudan cizgi) boyunca betikle surulur. 7.5 m/s (~27 km/s), dikey vektor korunur, hiz aracin kendi ekseninde, hedef 25 m ilerideki dugum,
 * 9 m onunde arac / yaya varsa durur. Hedefe 45 m kala ya da arac yolcu biraktiginda (yolcuBirak) / nakil bitince (tasimaMesgul false) / 700 sn'de biter. Yolcular aracta kalir. Bu bir HILEDIR; yalniz AI hic kalkmadiginda cagrilir.
 * Kullananlar: fnc_aracTasima (40 sn takilma), fnc_reconArac (35 sn ilerleme yok).  Log: [TASIMA-KIN]
 *
 * Arguments:
 * 0: Arac <OBJECT>
 * 1: Surucu <OBJECT>
 * 2: Hedef konum <ARRAY>
 * 3: Grup adi (log) <STRING>
 *
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

params [["_v", objNull, [objNull]], ["_d", objNull, [objNull]], ["_drop", [0, 0, 0], [[]]], ["_gid", "?", [""]]];
if (isNull _v || {isNull _d} || {!alive _v} || {_v getVariable [QGVAR(kinSurus), false]}) exitWith {false};
_v setVariable [QGVAR(kinSurus), true];

[_v, _d, _drop, _gid] spawn {
    params ["_v3", "_d3", "_drop3", "_gid3"];
    // rota: tazeden hesaplanir (en cok 4 sn beklenir); olmazsa dogrudan cizgi
    _v3 setVariable ["lambs_danger_yolDugum", []];
    private _ajan = calculatePath [["wheeled_APC", "tank"] select (((toLower (getText (configOf _v3 >> "simulation"))) find "tank") >= 0), "safe", getPosATL _v3, _drop3];
    _ajan setVariable ["arac", _v3];
    _ajan addEventHandler ["PathCalculated", {
        params ["_a", "_yol"];
        private _av = _a getVariable ["arac", objNull];
        if (!isNull _av && {count _yol > 1}) then { _av setVariable ["lambs_danger_yolDugum", _yol]; };
        deleteVehicle _a;
    }];
    private _bekle = time + 4;
    waitUntil { sleep 0.3; (count (_v3 getVariable ["lambs_danger_yolDugum", []])) > 1 || {time > _bekle} };
    private _yol3 = _v3 getVariable ["lambs_danger_yolDugum", []];
    if (count _yol3 < 2) then { _yol3 = [getPosATL _v3, _drop3]; };
    diag_log format ["[TASIMA-KIN] %1 | AI surmuyor: kinematik surus basladi (%2 dugum, inise %3 m)", _gid3, count _yol3, round (_v3 distance2D _drop3)];
    private _i3 = 1;
    private _t3 = time;
    private _sonLog = time;
    while {alive _v3 && {alive _d3} && {_v3 getVariable [QGVAR(tasimaMesgul), false]} && {!(_v3 getVariable [QGVAR(yolcuBirak), false])} && {(_v3 distance2D _drop3) > 45} && {(time - _t3) < 700} } do {
        // v8.208 PURUZSUZ SURUS (kullanici: "arkadaki arabalar titreyerek gitti"): (1) setDir her 0.1 sn egim / yatis sifirliyordu -> yatay donus vektoru, dikey vektor korunur; (2) hiz dunya eksenine degil ARACIN KENDI eksenine verilir (yan kayma yok);
        //   (3) rota 25 m ilerisindeki dugume yonlendirilir (sik dugum zikzagi yok); (AI devralma tespiti denendi ve KALDIRILDI: serbest birakinca yuvarlanan arac yanlis "AI suruyor" sayilip duruyordu)
        while {(_i3 < ((count _yol3) - 1)) && {(_v3 distance2D (_yol3 select _i3)) < 25}} do { _i3 = _i3 + 1; };
        private _hedef3 = _yol3 select (_i3 min ((count _yol3) - 1));
        private _yon3 = _v3 getDir _hedef3;
        private _hdg3 = getDir _v3;
        private _fark3 = ((_yon3 - _hdg3 + 540) mod 360) - 180;
        private _dlt3 = (_fark3 max -2.5) min 2.5;
        private _vd3 = vectorDir _v3;
        private _yeniDir3 = [(_vd3 select 0) * (cos _dlt3) + (_vd3 select 1) * (sin _dlt3), (_vd3 select 1) * (cos _dlt3) - (_vd3 select 0) * (sin _dlt3), _vd3 select 2];
        private _engel3 = ((_v3 modelToWorld [0, 9, 0]) nearEntities [["LandVehicle", "CAManBase"], 5]) select {_x isNotEqualTo _v3 && {alive _x} && {(vehicle _x) isNotEqualTo _v3}};
        private _hiz3 = if (_engel3 isNotEqualTo []) then {0} else { if ((abs _fark3) > 35) then {3} else {7.5} };
        _v3 setVectorDirAndUp [_yeniDir3, vectorUp _v3];
        _v3 setVelocityModelSpace [0, _hiz3, (velocityModelSpace _v3) select 2];
        if ((time - _sonLog) > 20) then {
            _sonLog = time;
            diag_log format ["[TASIMA-KIN] %1 | kinematik surus: inise %2 m | dugum %3/%4 | hiz %5 km/s", _gid3, round (_v3 distance2D _drop3), _i3, count _yol3, round (speed _v3)];
        };
        sleep 0.1;
    };
    if (alive _v3) then { _v3 setVelocity [0, 0, (velocity _v3) select 2]; };
    diag_log format ["[TASIMA-KIN] %1 | kinematik surus bitti: inise %2 m", _gid3, round (_v3 distance2D _drop3)];
    _v3 setVariable [QGVAR(kinSurus), nil];
};

true

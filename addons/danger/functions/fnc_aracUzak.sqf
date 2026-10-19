#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ARACTAN / ENKAZDAN UZAK DUR (v8.182) — kullanici: "combat sirasinda apc'den uzaklasmiyorlar, yanan araclardan ve etkisiz hale gelmis araclardan uzak dursunlar".
 * Her makinede 3 sn'de bir, yerel AI yaya askerler (asker basina en az 8 sn aralikla) icin:
 *   TEHLIKE: 35 m icinde YANAN (isBurning), yeni imha olmus (son 150 sn) ya da etkisiz (hareket edemez + hasar > 0.7, patlayabilir) kara / hava araci -> asker tehlikeden >= 40 m uzaga, tercihen arada siper veren objenin arkasina gider.
 *   KALABALIK: grup son 12 sn'de temasta ve asker 12 m icinde DOST murettebatli zirhli / kara aracinin yaninda (arac ates ceker, hedef olur, ilerleyemez / ezer) -> aractan >= 26 m uzaga gider.
 * v8.252 KENDI MURETTEBATI ISTISNASI (RPT f39a5919, 20:06: tankindan inen murettebat 'dost arac (temas)' kuraliyla 9-11 m'den 40 m uzaga gonderildi, tank onlari birakip ilerledi, lider yaya kovaladi, bir murettebat dost T-14'e ezildi):
 *   asker, aracin kayitli murettebati ya da atanmis surucusu / nisancisi ise (murKayit / assignedVehicle) ve arac yanmiyor + hasar <= 0.85 ise o aractan UZAKLASTIRILMAZ (geri binmesi fnc_tankMurettebat / murettebatKoru'nun isi). Kapatma: lambs_danger_aracUzakMurOff = true.
 * v8.256 HENDEK ISTISNASI (RPT e31bd8bd, 10:12-10:13: hendekteki piyade, hendek yakinindaki DOST T-14 'dost arac (temas)' kuraliyla 29-37 m uzaga itildi = hendekten ciktilar; 'trenchden ayrilmasinlar'):
 *   mevzide / hendekte (fnc_mevziDeMi) olan gruplara KALABALIK kurali (dost arac yani) uygulanmaz; yanan / etkisiz arac TEHLIKE kurali (patlama) hala gecerli.
 * Atlanir: oyuncu, aracta olan, TCCC mesgul, ELITE nakil bekleme / iniş toplanma bayragi, ELITE zirh destek, kapali: lambs_danger_aracUzakOff. Log: [ARAC-UZAK] (ilk 80 olay).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_aracUzakStarted") exitWith {false};
lambs_danger_aracUzakStarted = true;
diag_log "[ARAC-UZAK] aractan / enkazdan uzak dur watchdog'u baslatildi (v8.182)";

private _calis = {
    private _logN = 0;
    while {true} do {
        sleep 3;
        if (missionNamespace getVariable ["lambs_danger_aracUzakOff", false]) then { continue };
        {
            private _g = _x;
            if (!local _g || {isPlayer (leader _g)} || {(side _g) isEqualTo civilian}) then { continue };
            private _temas = (time - (_g getVariable [QGVAR(contact), -999])) < 12;
            {
                private _u = _x;
                if (!alive _u || {isPlayer _u} || {!isNull objectParent _u} || {time < (_u getVariable [QGVAR(aracUzakT), 0])}) then { continue };
                if (!((lifeState _u) in ["HEALTHY", "INJURED"]) || {time < (_u getVariable [QGVAR(tcccBusy), 0])} || {_u getVariable [QGVAR(tasimaBekle), false]}) then { continue };
                private _pu = getPosATL _u;
                private _kaynak = objNull;
                private _kendiMur = {
                    params ["_unit", "_arac"];
                    !(missionNamespace getVariable ["lambs_danger_aracUzakMurOff", false]) && {alive _arac} && {!isBurning _arac} && {(damage _arac) <= 0.85}
                    && {((assignedVehicle _unit) isEqualTo _arac) || {((_arac getVariable [QGVAR(murKayit), []]) findIf {(_x select 0) isEqualTo _unit}) >= 0}}
                };
                private _gerek = 0;
                // 1) tehlike: yanan / yeni imha / etkisiz arac
                private _yakin = nearestObjects [_pu, ["LandVehicle", "Air"], 35];
                {
                    private _v = _x;
                    private _tehlike = false;
                    if (!alive _v) then {
                        if ((_v getVariable [QGVAR(enkazT), -1]) < 0) then { _v setVariable [QGVAR(enkazT), time]; };
                        _tehlike = (time - (_v getVariable [QGVAR(enkazT), time])) < 150;
                    } else {
                        _tehlike = (isBurning _v) || {(!canMove _v) && {(damage _v) > 0.05} && {!(_v isKindOf "StaticWeapon")}};   // v8.187: etkisiz = hareket edemez + hasar > 0.05 (palet isabeti dusuk hasarla da araci durdurur; RPT 95be8b53: 3 APC "HASARLI" ama tehlike sayilmadi)
                    };
                    if (_tehlike && {[_u, _v] call _kendiMur}) then { _tehlike = false; };
                    if (_tehlike) exitWith { _kaynak = _v; _gerek = 40; };
                } forEach _yakin;
                // 2) kalabalik: temasta iken dost murettebatli arac yaninda
                if (isNull _kaynak && {_temas} && {!([_g] call FUNC(mevziDeMi))}) then {
                    private _av = _yakin findIf {alive _x && {(_x distance2D _u) < 12} && {(side (group (driver _x))) isEqualTo (side _g)} && {(count (crew _x)) > 0} && {!(_x isKindOf "StaticWeapon")} && {!(_x isKindOf "Air")} && {!([_u, _x] call _kendiMur)}};
                    if (_av >= 0) then { _kaynak = _yakin select _av; _gerek = 26; };
                };
                if (isNull _kaynak) then { continue };
                // hedef: kaynaktan uzakta, arada siper veren obje (tercih), yoksa dogrudan uzaklasma
                private _ks = getPosATL _kaynak;
                private _uzak = _pu getDir _ks;
                private _tp = [];
                private _objeler = (nearestTerrainObjects [_pu, ["TREE", "ROCK", "WALL", "BUILDING", "HIDE"], 45, true, true]) select {((getPosATL _x) distance2D _ks) >= _gerek};
                if (_objeler isNotEqualTo []) then { _tp = (getPosATL (_objeler select 0)) getPos [2.2, _ks getDir (getPosATL (_objeler select 0))]; };
                if (_tp isEqualTo [] || {surfaceIsWater _tp} || {(_tp distance2D _ks) < _gerek}) then { _tp = _ks getPos [_gerek + 6, _ks getDir _pu]; };
                if (surfaceIsWater _tp) then { continue };
                _u setVariable [QGVAR(aracUzakT), time + 8 + random 4];
                _u setVariable [QGVAR(forceMove), true];
                _u doMove _tp;
                [_u, _tp] spawn { params ["_u", "_tp"]; private _t = time + 14; waitUntil { sleep 1; !alive _u || {(_u distance2D _tp) < 4} || {time > _t} }; if (alive _u) then { _u setVariable [QGVAR(forceMove), nil]; }; };   // v8.184: LAMBS geri cekmesin (ayni asker 10 sn'de bir tekrar uzaklastirilip geri geliyordu)
                if (_logN < 80) then {
                    _logN = _logN + 1;
                    diag_log format ["[ARAC-UZAK] %1 | %2 | %3 (%4) %5 m -> %6 m uzaga | %7", groupId _g, name _u, getText (configOf _kaynak >> "displayName"), ["etkisiz / yanan / enkaz", "dost arac (temas)"] select (_gerek < 40), round (_u distance2D _kaynak), round (_tp distance2D _ks), mapGridPosition _tp];
                };
            } forEach ((units _g) select {alive _x});
        } forEach allGroups;
    };
};

[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log "[WATCHDOG-YENIDEN] aracUzak betigi sonlandi (hata?)";
        sleep 5;
    };
};

true

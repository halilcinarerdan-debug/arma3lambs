#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DRONA KARSI TEPKI + DRON YONU (v8.280; kullanici: 'drona ates etsinler eger uygunsa ve dronun geldigi yonu dusman bilsin').
 * Fnc_havaFarkindalik'tan, grubun ilgili (bilinen) DUSMAN dronu icin cagrilir.
 *   1) IZ: dronun konumu 2 sn'de bir kaydedilir (lambs_danger_dronIz, son 14 kayit). >= 6 sn'lik iz ve >= 25 m yer degistirme varsa gelis yonu = iz dogrultusu; OPERATOR / FIRLATMA YONU = gelisin TERSI
 *      (hile yok: yalniz gorulen ucus yolundan geri cikarim). Grup ve 400 m icindeki dost yerel gruplar `lambs_danger_dronYon` = [geri yon, zaman, ilk gorulen konum] alir,
 *      `sesSonPos` (supheli dusman konumu: ilk gorulen konumdan geri yonde 700 m, +-%15 hata) ve 2 asker 12 sn o yone bakar. Log: [DRON-YON]
 *   2) ATES (uygunsa): KAMIKAZE / bomba / silahli dron (FPV-AT, FPV-AP, BOMBA, silahli) <= lambs_danger_dronAtesM (varsayilan 450 m) ve yukseklik <= 200 m ise grup ates eder:
 *      yatayda hareketsiz silahli askerler ongorulu (lead) toplu ates (doSuppressiveFire), en yakin 3 asker doTarget + doFire; combatMode en az YELLOW, behaviour SAFE / CARELESS ise AWARE. 3 sn'de bir.
 *      GOZLEM dronu: yalniz <= 100 m (ates konumu ele verir; ATP 3-01.8: once pasif onlem).
 *      Retreat / Evade / BreakContact / sniper grubu bu fonksiyona zaten hic gelmez (havaFarkindalik atlar).
 *   v8.288: kamikaze / silahli dron <= 700 m ise ayrica fnc_dronSakla (dagil + siper / yat); cagiran havaFarkindalik 25 sn boyunca eski toplu HIDE / GARRISON'u atlar.
 *   Doner: ates edildi mi <BOOL> (true ise cagiran diger pasif onlemleri - saklanma - atlar).
 * Kapatma: lambs_danger_dronTepkiOff = true.
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Dron <OBJECT>
 * 2: Yatay mesafe <NUMBER>
 *
 * Return Value: Ates edildi mi <BOOL>
 * Public: No
*/

params [["_g", grpNull, [grpNull]], ["_dr", objNull, [objNull]], ["_d", 0, [0]]];
if (isNull _g || {isNull _dr} || {!alive _dr} || {missionNamespace getVariable ["lambs_danger_dronTepkiOff", false]}) exitWith {false};
private _l = leader _g;
if (isNull _l || {!alive _l}) exitWith {false};

private _tip = [_dr] call FUNC(ihaTip);
private _silahli = ((_dr weaponsTurret [-1]) isNotEqualTo []) || {(_dr weaponsTurret [0]) isNotEqualTo []};
private _kamikaze = _silahli || {_tip in ["FPV-AT", "FPV-AP", "BOMBA"]};

// ---- 1) IZ + GELIS YONU ----
private _iz = _dr getVariable [QGVAR(dronIz), []];
if (_iz isEqualTo [] || {(time - ((_iz select (count _iz - 1)) select 0)) >= 2}) then {
    _iz pushBack [time, getPosATL _dr];
    if ((count _iz) > 14) then { _iz deleteAt 0; };
    _dr setVariable [QGVAR(dronIz), _iz];
};
if ((count _iz) >= 3 && {(time - ((_iz select 0) select 0)) >= 6}) then {
    private _p0 = (_iz select 0) select 1;
    private _p1 = (_iz select (count _iz - 1)) select 1;
    if ((_p0 distance2D _p1) >= 25 && {(time - (_g getVariable [QGVAR(dronYonT), -999])) > 15}) then {
        private _gelis = _p0 getDir _p1;
        private _geri = (_gelis + 180) mod 360;
        private _hata = (random 30) - 15;
        private _supheli = _p0 getPos [700, _geri + _hata];
        private _bilgi = [_geri, time, _p0];
        private _n = 0;
        {
            if (local _x && {!isNull (leader _x)} && {(side _x) isEqualTo (side _g)} && {((leader _x) distance2D _l) < 400}) then {
                _x setVariable [QGVAR(dronYon), _bilgi];
                _x setVariable [QGVAR(dronYonT), time];
                _x setVariable [QGVAR(sesSonZaman), time];
                _x setVariable [QGVAR(sesSonPos), _supheli];
                private _ud = (units _x) select {alive _x && {isNull objectParent _x}};
                { _x doWatch _supheli; [{ params ["_c"]; if (alive _c) then { _c doWatch objNull; }; }, [_x], 12] call CBA_fnc_waitAndExecute; } forEach (_ud select [0, 2]);
                if ((behaviour (leader _x)) in ["SAFE", "CARELESS"]) then { _x setBehaviour "AWARE"; };
                _n = _n + 1;
            };
        } forEach allGroups;
        _g setVariable [QGVAR(dronYonT), time];
        if ((time - (_dr getVariable [QGVAR(dronYonLogT), -999])) > 20) then {
            _dr setVariable [QGVAR(dronYonLogT), time];
            diag_log format ["[DRON-YON] %1 | %2 (%3) | gelis %4 derece -> operator / firlatma yonu %5 derece (700 m, hata +-15) | iz %6 m / %7 sn | haberdar edilen grup %8", groupId _g, typeOf _dr, _tip, round _gelis, round _geri, round (_p0 distance2D _p1), round (time - ((_iz select 0) select 0)), _n];
        };
    };
};

// ---- 2) ATES ----
private _menzil = if (_kamikaze) then { missionNamespace getVariable ["lambs_danger_dronAtesM", 450] } else {100};
private _egik = _l distance _dr;
// v8.288 DAGIL + SAKLAN (kullanici: 'botlar dusman dronu gorunce mesafeyi arttirsinlar ve saklansinlar'): kamikaze / silahli dron <= 700 m ise grup dagilir ve siper alir (fnc_dronSakla); ates menzilindeyse 3 nisanci yerinde kalir
if (_kamikaze && {_egik <= 700} && {((getPosATL _dr) select 2) <= 200}) then { [_g, _dr, _egik <= _menzil] call FUNC(dronSakla); };
if (_egik > _menzil || {((getPosATL _dr) select 2) > 200}) exitWith {false};
if ((time - (_g getVariable [QGVAR(dronAtesT), -99])) < 3) exitWith {true};
_g setVariable [QGVAR(dronAtesT), time];
if ((combatMode _g) in ["BLUE", "GREEN", "WHITE"]) then { _g setCombatMode "YELLOW"; };
if ((behaviour _l) in ["SAFE", "CARELESS"]) then { _g setBehaviour "AWARE"; };

private _vel = velocity _dr;
private _tp = getPosASL _dr;
private _adaylar = (units _g) select {alive _x && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {(primaryWeapon _x) isNotEqualTo ""} && {(speed _x) < 3}};
_g reveal [_dr, 4];
private _n = 0;
{
    private _u = _x;
    private _iv = getNumber (configFile >> "CfgMagazines" >> (currentMagazine _u) >> "initSpeed");
    if (_iv <= 0) then { _iv = 800 };
    private _tof = ((_u distance _dr) / (_iv * 0.9)) min 2;
    private _lead = ASLToAGL (_tp vectorAdd (_vel vectorMultiply _tof));
    if (_n < 3) then {
        _u doTarget _dr;
        _u doFire _dr;
    } else {
        _u doSuppressiveFire _lead;
    };
    _n = _n + 1;
} forEach ([_adaylar, [], {_x distance _dr}, "ASCEND"] call BIS_fnc_sortBy);

if ((time - (_g getVariable [QGVAR(dronAtesLogT), -999])) > 8) then {
    _g setVariable [QGVAR(dronAtesLogT), time];
    diag_log format ["[DRON-ATES] %1 | %2 (%3) %4 m (egik) | yukseklik %5 m | ates eden %6 | tur %7", groupId _g, typeOf _dr, _tip, round _egik, round ((getPosATL _dr) select 2), _n, ["GOZLEM", "KAMIKAZE / SILAHLI"] select _kamikaze];
};
_n > 0

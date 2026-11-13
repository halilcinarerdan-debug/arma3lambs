#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TANK / IFV KESIF ATESI = BILINEN KONUMA ATES (v8.523; kullanici: 'tanklar en ufak bir gorus engellemesinde ates etmiyor, bugday tarlasi falan varsa bilinen konuma atabilsin, doktrini arastir').
 *
 * DOKTRIN (yerel kaynak kaynaklar_doktrin/): FM 3-34 (2014) 12-90 "RECONNAISSANCE BY FIRE": 'a reconnaissance technique in which a unit fires on a suspected enemy position. Appropriate when time is critical and stealthy
 *   maneuver to develop the situation further is not possible. The fires may be direct, indirect, or both to cause the enemy forces to disclose their presence by movement or return fire ...
 *   may not cause a seasoned or prepared enemy force to react.' ATP 7-100.1 4-21: 'typically used only when other reconnaissance means are not available, and timeliness requires this action ... employs fires on suspected
 *   positions to prompt a reaction' ('considerations for unmasking' = ates eden kendi yerini ele verir).  ATP 3-20.15 (tank takimi): bastirma ve kesin atis ayrimi (yerel ozet DOKTRIN_KAYNAKLARI.md 'tank mevzisi').
 *   (FM 17-15 / ATP 3-20.15 tam metnine ag kisiti yuzunden ulasilamadi; asagidaki sayilar TASARIM degeridir, kaynakli degil.)
 * NEDEN: AI nisanci hedefi yalniz 'gorunur' (checkVisibility) oldugunda ates eder; bugday / yuksek ot / cali / sis / toz hedefi kismen perdeleyince BILINEN dusmana hic ates edilmiyordu.
 * KOSUL (2 sn'de bir, yerel AI suruculu, oyuncusuz TANK / IFV; arac basina bekleme 18-28 sn + hedef basina 120 sn'de en cok 4 seri = cephane disiplini):
 *   - grup temasta; arac < 25 km/s; atilacak mermi var;
 *   - aday: BILINEN gercek dusman (knowsAbout >= SUPHE 0.5; targetKnowledge son gorulme <= 40 sn), 150-1400 m; oncelik zirhli / AT'li, sonra yakin;
 *   - 'perdeli': nisancidan hedefe checkVisibility < 0.5 (gorus engeli) AMA FIRE LOD hatti temiz (tepe / duvar / bina gibi SERT engel yok: o halde mermi gitmez);
 *   - hedef cevresi 25 m'de dost yok;  konum = hedefin BILINEN konumu + bilgi hatasi (posError 8-40 m) kadar sapma (mukemmel bilgi degil).
 *   ATIS: nisanciya doSuppressiveFire (bilinen konuma); 7 sn sonra hedef secimi serbest (doTarget objNull). Piyadeye karsi motor genelde koaksiyel MG secer, zirhli / bina icin top.
 * Kapatma: lambs_danger_tankBilinenAtes = false.  Log: [TANK-BILINEN] (ilk 30) + 60 sn ozeti.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_tankBilinenStarted") exitWith {false};
lambs_danger_tankBilinenStarted = true;
diag_log "[TANK-BILINEN] kesif atesi (bilinen konuma ates) baslatildi (v8.523; FM 3-34 12-90 reconnaissance by fire): gorus engeli (bugday / cali / sis) olan BILINEN dusmana bastirma";

[] spawn {
    private _logN = 0;
    private _say = createHashMapFromArray [["ates", 0], ["gorunur", 0], ["sert_engel", 0], ["dost", 0], ["bekleme", 0], ["hedef_yok", 0]];
    private _ozetT = time + 60;
    while {true} do {
        sleep 2;
        if !(missionNamespace getVariable ["lambs_danger_tankBilinenAtes", true]) then { continue };
        {
            private _v = _x;
            if (!local _v || {!alive _v} || {!(_v isKindOf "LandVehicle")}) then { continue };
            if (time < (_v getVariable [QGVAR(tankBilinenT), 0])) then { continue };
            private _d = driver _v;
            if (isNull _d || {!alive _d} || {isPlayer _d} || {(crew _v) findIf {isPlayer _x} >= 0}) then { continue };
            if (!(((([_v] call FUNC(aracSinif)) select 0)) in ["TANK", "IFV"])) then { continue };
            if ((speed _v) > 25 || {!someAmmo _v}) then { continue };
            private _gn = gunner _v;
            if (isNull _gn || {!alive _gn}) then { _gn = commander _v; };
            if (isNull _gn || {!alive _gn} || {isPlayer _gn}) then { continue };
            private _g = group _d;
            private _l = leader _g;
            if (isNull _l || {((_g getVariable [QGVAR(contact), 0]) <= time)}) then { continue };
            private _tf = side _g;
            if (_tf isEqualTo civilian) then { continue };

            // adaylar: bilinen gercek dusman 150-1400 m, son gorulme <= 40 sn
            private _tbl = missionNamespace getVariable ["lambs_danger_tankBilinenTbl", createHashMap];
            missionNamespace setVariable ["lambs_danger_tankBilinenTbl", _tbl];
            private _adaylar = [];
            {
                private _o = _x select 4;
                if (!isNull _o && {alive _o} && {(_tf getFriend (_x select 2)) < 0.6} && {(_x select 2) isNotEqualTo civilian} && {[_o] call FUNC(gercekHedef)}) then {
                    private _dm = _v distance2D _o;
                    if (_dm >= 150 && {_dm <= 1400} && {(_l knowsAbout _o) >= (["SUPHE"] call FUNC(bilgiEsik))}) then {
                        private _tk = _l targetKnowledge _o;
                        private _ls = (_tk select 2) max (_tk select 3);   // lastSeenByGroup / ByUnit (oyun zamani)
                        if (_ls > 0 && {(time - _ls) <= 40} && {(_tbl getOrDefault [netId _o, [0, -999]]) params ["_n", "_t0"]; (time - _t0 > 120) || {_n < 4}}) then {
                            private _agir = !(_o isKindOf "CAManBase") || {(secondaryWeapon _o) isNotEqualTo ""};
                            _adaylar pushBack [([1, 0] select _agir) * 10000 + _dm, _o, _tk];
                        };
                    };
                };
            } forEach (_l nearTargets 1400);
            if (_adaylar isEqualTo []) then { _say set ["hedef_yok", (_say get "hedef_yok") + 1]; continue };
            _adaylar sort true;
            (_adaylar select 0) params ["_sk", "_o", "_tk"];

            // perdeli mi (gorus engeli) ama FIRE LOD hatti temiz mi (sert engel yok)
            private _eyeG = eyePos _gn;
            private _hedefASL = aimPos _o;
            private _vis = [_v, "VIEW", _o] checkVisibility [_eyeG, _hedefASL];
            if (_vis >= 0.5) then { _say set ["gorunur", (_say get "gorunur") + 1]; continue };
            if ((terrainIntersectASL [_eyeG, _hedefASL]) || {(lineIntersectsSurfaces [_eyeG, _hedefASL, _v, _o, true, 1, "FIRE", "NONE"]) isNotEqualTo []}) then {
                _say set ["sert_engel", (_say get "sert_engel") + 1];
                _v setVariable [QGVAR(tankBilinenT), time + 6];
                continue;
            };

            // bilinen konum + bilgi hatasi kadar sapma (kesif atesi: konum kesin degil)
            private _err = ((_tk select 7) max 8) min 40;   // targetKnowledge [.. positionError = indeks 7 ..]
            private _poz = (getPosATL _o) getPos [random _err, random 360];
            _poz set [2, 0];
            if (((_poz nearEntities ["CAManBase", 25]) findIf {alive _x && {(_tf getFriend (side group _x)) >= 0.6}}) > -1) then {
                _say set ["dost", (_say get "dost") + 1];
                _v setVariable [QGVAR(tankBilinenT), time + 8];
                continue;
            };

            // ATIS
            _gn doSuppressiveFire _poz;
            _v setVariable [QGVAR(tankBilinenT), time + 18 + (random 10)];
            private _kayit = _tbl getOrDefault [netId _o, [0, time]];
            if ((time - (_kayit select 1)) > 120) then { _kayit = [0, time]; };
            _kayit set [0, (_kayit select 0) + 1];
            _tbl set [netId _o, _kayit];
            _say set ["ates", (_say get "ates") + 1];
            [{ params ["_gg"]; if (alive _gg) then { _gg doTarget objNull; _gg doWatch objNull; }; }, [_gn], 7] call CBA_fnc_waitAndExecute;
            if (_logN < 30) then {
                _logN = _logN + 1;
                diag_log format ["[TANK-BILINEN] %1 | %2 | hedef %3 (%4) %5 m | gorunurluk %6 (< 0.5, perdeli) | bilgi hatasi %7 m | son gorulme %8 sn once | bilinen konuma BASTIRMA ATESI (7 sn)", groupId _g, typeOf _v, typeOf _o, ["AT / zirhli", "piyade"] select ((_sk) >= 10000), round (_v distance2D _o), _vis toFixed 2, round _err, round (time - ((_tk select 2) max (_tk select 3)))];
            };
        } forEach vehicles;
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if (((_say get "ates") + (_say get "gorunur") + (_say get "sert_engel") + (_say get "dost")) > 0) then {
                diag_log format ["[TANK-BILINEN-OZET] 60 sn: ates %1 | hedef gorunur (motor kendi ates eder) %2 | sert engel (tepe / duvar) %3 | hedefte dost %4 | aday yok %5", _say get "ates", _say get "gorunur", _say get "sert_engel", _say get "dost", _say get "hedef_yok"];
            };
            { _say set [_x, 0]; } forEach (keys _say);
        };
    };
};
true

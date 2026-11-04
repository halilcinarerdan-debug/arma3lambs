#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ACIKTA BEKLEME (v8.377; kullanici: 'bazen squad leaderler acikta mal mal bekliyor').
 *
 * NEDEN: fnc_coverHug / fnc_acikSiper yalniz BILINEN dusman varken ve temas bayragi aciksa siper arar. Temas bittikten sonra (dusman bilinmiyor) ya da hedefe varip bekleyen
 *   (hide / hold / hedefte dur) lider ve askerler kaldigi yerde, acik arazide, AYAKTA bekliyordu.
 *
 * ISLEYIS (2 sn'de bir, yerel AI grup, oyuncusuz lider; tik basina en cok 3 asker):
 *   - Asker 8 sn'den uzun suredir duruyor (hiz < 0.6), AYAKTA (STAND), acikta (3 m'de agac / kaya / duvar / cit / bina YOK), davranis AWARE / COMBAT / STEALTH (SAKIN / CARELESS degil).
 *   - Tehdit yonu: en yakin bilinen dusman -> son ses konumu (60 sn) -> komutan raporu -> bakis yonu.
 *   - 18 m icinde SERT nesne (agac / kaya / duvar / cit, yukseklik >= 0.9 m) varsa ARKASINA gider (tehdide gore 0.6 m arka), orada comelir; yoksa oldugu yerde COMELIR (15 sn).
 *   - Lider dahil. Rezerv defteri (lambs_danger_acikSiperDolu) ile ayni noktaya 2 asker gitmez (4 m).
 *   MUAF: oyuncu, arac, bina ici, forceMove / taktikKilit / hekim / bomba / yeniden doldurma / panik, retreat / evade / temas kes / supurme / bounding / keskin nisanci / mevzi / disableGroupAI,
 *     hedefe 6 m'den yakin dusman (dovusur), nokta elemani / yan guvenlik gozcusu.
 *   Kapatma: lambs_danger_acikBeklemeOff = true.   Log: [ACIK-BEKLE] (ilk 40) + 60 sn ozeti.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_acikBeklemeStarted") exitWith {false};
lambs_danger_acikBeklemeStarted = true;

diag_log "[ACIK-BEKLE] acikta bekleme denetimi baslatildi (v8.377): duran + ayakta + acikta asker / lider siper arkasina ya da comelir";

[] spawn {
    private _logN = 0;
    private _ozetT = time + 60;
    private _say = createHashMapFromArray [["siper", 0], ["comel", 0]];
    private _sert = ["TREE", "SMALL TREE", "ROCK", "ROCKS", "WALL", "FENCE", "BUILDING", "HOUSE"];
    while {true} do {
        sleep 2;
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if (((_say get "siper") + (_say get "comel")) > 0) then {
                diag_log format ["[ACIK-BEKLE-OZET] 60 sn: siper arkasina %1 | comelen %2", _say get "siper", _say get "comel"];
            };
            { _say set [_x, 0]; } forEach (keys _say);
        };
        if (missionNamespace getVariable ["lambs_danger_acikBeklemeOff", false]) then { continue };

        private _butce = 3;
        {
            if (_butce <= 0) exitWith {};
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {isPlayer _l} || {!local _g}) then { continue };
            if (
                (_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]}
                || {_g getVariable [QGVAR(isSweeping), false]} || {_g getVariable [QGVAR(isBounding), false]} || {_g getVariable [QGVAR(isPeeling), false]}
                || {_g getVariable [QGVAR(sniperTeam), false]} || {_g getVariable [QGVAR(disableGroupAI), false]} || {_g getVariable ["lambs_danger_disableGroupAI", false]}
                || {[_g] call FUNC(mevziDeMi)}
            ) then { continue };

            {
                if (_butce <= 0) exitWith {};
                private _u = _x;
                if (
                    !alive _u || {!local _u} || {isPlayer _u} || {!isNull objectParent _u} || {captive _u}
                    || {!((lifeState _u) in ["HEALTHY", "INJURED"])} || {(insideBuilding _u) > 0.5}
                    || {_u getVariable [QGVAR(forceMove), false]} || {(_u getVariable [QGVAR(taktikKilit), 0]) > time} || {time < (_u getVariable [QGVAR(tcccBusy), 0])}
                    || {(_u getVariable [QGVAR(grState), []]) isNotEqualTo []} || {(_u getVariable [QGVAR(reloadState), []]) isNotEqualTo []}
                    || {time < (_u getVariable [QGVAR(panikBitis), 0])} || {_u getVariable [QGVAR(disableAI), false]}
                    || {_u getVariable [QGVAR(noktaEk), false]} || {!isNil {_u getVariable QGVAR(yanGuv)}}
                ) then { _u setVariable [QGVAR(acikDurT), nil]; continue };

                // duruyor mu, ne kadar suredir
                if ((speed _u) >= 0.6) then { _u setVariable [QGVAR(acikDurT), nil]; continue };
                private _dt = _u getVariable [QGVAR(acikDurT), -1];
                if (_dt < 0) then { _u setVariable [QGVAR(acikDurT), time]; continue };
                if ((time - _dt) < 8) then { continue };
                if (time < (_u getVariable [QGVAR(acikBekT), 0])) then { continue };
                if ((stance _u) isNotEqualTo "STAND") then { continue };
                if !((behaviour _u) in ["AWARE", "COMBAT", "STEALTH"]) then { continue };

                // acikta mi: 3 m'de sert nesne yok
                if ((nearestTerrainObjects [_u, _sert, 3, false, true]) isNotEqualTo []) then { continue };
                // v8.402: turu tanimsiz / simple object sert nesne de 'siper yaninda' sayilir (yukseklik >= 0.9 m)
                if (!(missionNamespace getVariable ["lambs_danger_siperYedekOff", false]) && {((nearestObjects [_u, [], 3]) findIf {
                    !(_x isKindOf "Man") && {!(_x isKindOf "AllVehicles")} && {!(_x isKindOf "Logic")} && {((typeOf _x) select [0, 1]) isNotEqualTo "#"} && {((getModelInfo _x) select 0) isNotEqualTo ""}
                    && {private _bq = boundingBoxReal _x; (((_bq select 1) select 2) - ((_bq select 0) select 2)) >= 0.9}
                }) >= 0}) then { continue };

                // yakin dusman varsa dovusur
                private _en = _u findNearestEnemy _u;
                if (!isNull _en && {alive _en} && {(_u distance2D _en) < 6}) then { continue };

                _u setVariable [QGVAR(acikBekT), time + 25];
                _butce = _butce - 1;

                // tehdit yonu
                private _tPos = [];
                if (!isNull _en && {alive _en} && {(_u distance2D _en) < 500}) then { _tPos = getPosATL _en; } else {
                    private _sp = _g getVariable [QGVAR(sesSonPos), []];
                    if (_sp isNotEqualTo [] && {(time - (_g getVariable [QGVAR(sesSonZaman), -999])) < 60}) then { _tPos = _sp; } else {
                        private _sit = _g getVariable [QGVAR(cmdSit), []];
                        if (_sit isNotEqualTo [] && {(time - (_sit select 0)) < 300} && {(_sit select 7) isEqualType []} && {(_sit select 7) isNotEqualTo [0,0,0]}) then { _tPos = _sit select 7; };
                    };
                };
                if (_tPos isEqualTo []) then { _tPos = (getPosATL _u) getPos [100, getDir _u]; };

                private _dolu = (missionNamespace getVariable ["lambs_danger_acikSiperDolu", []]) select {(time - (_x select 1)) < 30};
                private _en2 = [];
                private _enS = 1e9;
                {
                    private _o = _x;
                    private _bb = boundingBoxReal _o;
                    private _yk = ((_bb select 1) select 2) - ((_bb select 0) select 2);
                    private _ad = toLower ([typeOf _o, (getModelInfo _o) select 0] select ((typeOf _o) isEqualTo ""));
                    if (_yk >= 0.9 && {((["wire", "powerline", "powerpole", "pole", "cable", "lamp", "antenna", "pylon"] findIf {(_ad find _x) >= 0}) < 0)}) then {
                        private _op = getPosATL _o;
                        private _r = (((((_bb select 1) select 0) - ((_bb select 0) select 0)) max (((_bb select 1) select 1) - ((_bb select 0) select 1))) / 2) min 2.5;
                        private _p = _op getPos [_r + 0.6, _tPos getDir _op];
                        if (!surfaceIsWater _p && {(_dolu findIf {((_x select 0) distance2D _p) < 4}) < 0} && {(nearestTerrainObjects [_p, ["BUILDING", "HOUSE"], 2, false, true]) isEqualTo []}) then {
                            private _sk = _u distance2D _p;
                            if (_sk < _enS) then { _enS = _sk; _en2 = _p; };
                        };
                    };
                } forEach ((nearestTerrainObjects [_u, ["TREE", "SMALL TREE", "ROCK", "ROCKS", "WALL"], 18, false, true])
                    // v8.402 TUR-BAGIMSIZ YEDEK (kullanici: 'pmc terrain kendi objelerini kullandim, simple object olabilir'; RPT: cok sayida '18 m'de siper yok -> comeldi'): turu tanimsiz / simple object nesneler de adaydir (ayni yukseklik >= 0.9 sarti)
                    + (if (missionNamespace getVariable ["lambs_danger_siperYedekOff", false]) then {[]} else { ((nearestObjects [_u, [], 18]) select {
    !(_x isKindOf "Man") && {!(_x isKindOf "AllVehicles")} && {!(_x isKindOf "House")} && {!(_x isKindOf "Logic")} && {!isObjectHidden _x}
    && {((typeOf _x) select [0, 1]) isNotEqualTo "#"} && {((getModelInfo _x) select 0) isNotEqualTo ""}
}) }));
                // v8.402 TANI (siper bulunamadiysa, oyun basina en cok 8 kez): cevredeki nesne turleri ve tur-bagimsiz nesne adlari -> arazi nesnesi 'simple object' mi / hangi tur, RPT'den okunur
                if (_en2 isEqualTo [] && {(missionNamespace getVariable ["lambs_danger_siperTaniN", 0]) < 8} && {(time - (missionNamespace getVariable ["lambs_danger_siperTaniT", -999])) > 20}) then {
                    missionNamespace setVariable ["lambs_danger_siperTaniN", (missionNamespace getVariable ["lambs_danger_siperTaniN", 0]) + 1];
                    missionNamespace setVariable ["lambs_danger_siperTaniT", time];
                    private _tt = ["TREE", "SMALL TREE", "BUSH", "ROCK", "ROCKS", "WALL", "FENCE", "HIDE", "BUNKER", "RUIN", "BUILDING", "HOUSE"] apply {format ["%1:%2", _x, count (nearestTerrainObjects [_u, [_x], 18, false, true])]};
                    private _no = ((nearestObjects [_u, [], 18]) select {!(_x isKindOf "Man") && {((typeOf _x) select [0, 1]) isNotEqualTo "#"}}) apply {
                        private _bbT = boundingBoxReal _x;
                        format ["%1[%2 m%3]", [typeOf _x, (getModelInfo _x) select 0] select ((typeOf _x) isEqualTo ""), (((_bbT select 1) select 2) - ((_bbT select 0) select 2)) toFixed 1, ["", ", simple"] select (isSimpleObject _x)]
                    };
                    diag_log format ["[SIPER-TANI] %1 | %2 | arazi nesne turleri (18 m): %3 | tur-bagimsiz nesneler (ilk 14 / %4): %5 | arazi %6", groupId _g, name _u, _tt joinString " ", count _no, (_no select [0, 14]) joinString " ; ", worldName];
                };

                if (_en2 isNotEqualTo []) then {
                    _dolu pushBack [_en2, time];
                    missionNamespace setVariable ["lambs_danger_acikSiperDolu", _dolu];
                    _u setVariable [QGVAR(taktikKilit), time + 12];
                    _u doMove _en2;
                    _say set ["siper", (_say get "siper") + 1];
                    [{ params ["_uu", "_hp"]; !alive _uu || {(_uu distance2D _hp) < 1.8} }, { params ["_uu"]; if (alive _uu) then { _uu setUnitPosWeak "MIDDLE"; _uu doWatch ((getPosATL _uu) getPos [100, getDir _uu]); }; }, [_u, _en2], 12, {}] call CBA_fnc_waitUntilAndExecute;
                    [{ params ["_uu"]; if (alive _uu) then { _uu setUnitPos "AUTO"; }; }, [_u], 30] call CBA_fnc_waitAndExecute;
                    if (_logN < 40) then {
                        _logN = _logN + 1;
                        diag_log format ["[ACIK-BEKLE] %1 | %2%3 | %4 sn acikta duruyor -> nesne arkasi (%5 m)", groupId _g, name _u, [""," (LIDER)"] select (_u isEqualTo _l), round (time - _dt), round _enS];
                    };
                } else {
                    _u setUnitPosWeak "MIDDLE";
                    _say set ["comel", (_say get "comel") + 1];
                    [{ params ["_uu"]; if (alive _uu) then { _uu setUnitPos "AUTO"; }; }, [_u], 15] call CBA_fnc_waitAndExecute;
                    if (_logN < 40) then {
                        _logN = _logN + 1;
                        diag_log format ["[ACIK-BEKLE] %1 | %2%3 | %4 sn acikta duruyor, 18 m'de siper yok -> comeldi", groupId _g, name _u, [""," (LIDER)"] select (_u isEqualTo _l), round (time - _dt)];
                    };
                };
            } forEach (units _g);
        } forEach (allGroups select {local _x && {!isNull leader _x} && {!(_x getVariable ["lambs_danger_tarafKapali", false])}});
    };
};

true

#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * SIPERDE MIKRO DUZELTME KATMANI (v8.640; kullanici: 'eger gorus acisi yoksa siperde mikro duzeltme katmani ekle, calilarda falan ise yarar'):
 * Sipere / cali / agac dibine yapisan asker bazen o kadar gomulur ki dusmani GOREMEZ (cali yapragi / govde gorus hattini kapatir; ates edemez). Bu katman 1 sn'de bir (en cok 10 asker / tur):
 *   - Kosul: temasli grup (30 sn), yerel AI, durmus (< 1.5 m/sn), bina disi, yakin zamanda sipere yapisti (coverHug 25 sn / acikSiper hedefi 40 sn), bilinen dusman 15-300 m (knowsAbout >= SEZILDI)
 *   - Gorus hatti (VIEW LOD, goz -> dusmanin gogsu) 3.5 m icindeki bir nesne (cali / govde) tarafindan KAPALI ve 2 sn boyunca kapali kaldiysa
 *   - Arama: dusman yonune DIK yanal kayma 0.3 / 0.6 / 1.0 m (iki yon; CBA siperMikroM'e kadar), yer hatti (GEOM) acik ve YENI goz noktasindan dusmana gorus hatti ACIK olan en KUCUK kayma secilir; kayma yoksa bir durus kademe kalk (CROUCH / PRONE -> UP gibi goz yuksekligi +0.5 m) denenir
 *   - Uygulama: 8 adimda yumusak kayma (setPosATL, ~0.5 sn); 4 sn bekleme; bulunamazsa 6 sn bekleme. Oyuncu / oyuncu komutasi, arac, forceMove, taktikKilit, kose temkini, teslim atlanir.
 * CBA: lambs_danger_siperMikro (acik / kapali), lambs_danger_siperMikroM (en cok kayma m). Log: [SIPER-MIKRO] (ilk 20) + [SIPER-MIKRO-OZET] 60 sn.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_siperMikroStarted") exitWith {false};
lambs_danger_siperMikroStarted = true;

diag_log "[SIPER-MIKRO] siperde mikro duzeltme (gorus acisi yoksa yanal kayma / durus) baslatildi (v8.640)";

[] spawn {
    private _logN = 0;
    private _say = createHashMapFromArray [["kontrol", 0], ["kapali", 0], ["duzeltilen", 0], ["durus", 0], ["bulunamadi", 0]];
    private _ozetT = time + 60;
    while {true} do {
        sleep ([1, true, true] call FUNC(dusunSure));
        if !(missionNamespace getVariable ["lambs_danger_siperMikro", true]) then { continue };
        private _maks = ((missionNamespace getVariable ["lambs_danger_siperMikroM", 1]) max 0.3) min 2;
        private _esik = ["SEZILDI"] call FUNC(bilgiEsik);
        private _n = 0;
        {
            private _u = _x;
            if (_n >= 10) exitWith {};
            if (
                !local _u || {isPlayer _u} || {!alive _u} || {!isNull objectParent _u} || {!((lifeState _u) in ["HEALTHY", "INJURED"])}
                || {captive _u} || {_u getVariable [QGVAR(teslim), false]} || {(speed _u) > 1.5} || {(insideBuilding _u) > 0.5}
                || {time < (_u getVariable [QGVAR(mikroT), 0])}
                || {((group _u) getVariable [QGVAR(contact), 0]) < (time - 30)}
                || {_u getVariable [QGVAR(forceMove), false]} || {(_u getVariable [QGVAR(taktikKilit), 0]) > time} || {!isNil {_u getVariable QGVAR(koseAktif)}}
                || {(_u getVariable [QGVAR(reloadState), []]) isNotEqualTo []}
                || {((time - (_u getVariable [QGVAR(hugAt), -999])) > 25) && {(time - ((_u getVariable [QGVAR(acikSiperHedef), [0, -999]]) param [1, -999])) > 40}}
                || {[_u] call FUNC(oyuncuKomutaMi)}
            ) then { continue };
            private _e = _u findNearestEnemy _u;
            if (isNull _e || {!alive _e} || {!(_e isKindOf "CAManBase")} || {(_u distance _e) < 15} || {(_u distance _e) > 300} || {(_u knowsAbout _e) < _esik}) then { continue };
            _n = _n + 1;
            _say set ["kontrol", (_say get "kontrol") + 1];
            private _eye = eyePos _u;
            private _tgt = aimPos _e;
            private _ht = lineIntersectsSurfaces [_eye, _tgt, _u, _e, true, 1, "VIEW", "NONE"];
            if (_ht isEqualTo [] || {((_ht select 0) select 0) distance _eye > 3.5}) then { _u setVariable [QGVAR(mikroKapaliT), nil]; continue };
            private _kt = _u getVariable [QGVAR(mikroKapaliT), -1];
            if (_kt < 0) then { _u setVariable [QGVAR(mikroKapaliT), time]; continue };
            if ((time - _kt) < 2) then { continue };
            _say set ["kapali", (_say get "kapali") + 1];
            private _d = vectorNormalized [(_tgt select 0) - (_eye select 0), (_tgt select 1) - (_eye select 1), 0];
            private _perp = [-(_d select 1), _d select 0, 0];
            private _g0 = (getPosASL _u) vectorAdd [0, 0, 0.6];
            private _sec = 0;
            {
                private _o = _x;
                if ((abs _o) > _maks) then { continue };
                private _c = _eye vectorAdd (_perp vectorMultiply _o);
                private _yerAcik = (lineIntersectsSurfaces [_g0, _g0 vectorAdd (_perp vectorMultiply _o), _u, objNull, true, 1, "GEOM", "NONE"]) isEqualTo [];
                if (_yerAcik && {(lineIntersectsSurfaces [_c, _tgt, _u, _e, true, 1, "VIEW", "NONE"]) isEqualTo []} && {!(terrainIntersectASL [_c, _tgt])}) exitWith { _sec = _o; };
            } forEach [0.3, -0.3, 0.6, -0.6, 1, -1];
            _u setVariable [QGVAR(mikroKapaliT), nil];
            if (_sec isNotEqualTo 0) then {
                private _p0 = getPosATL _u;
                private _p1 = _p0 vectorAdd [(_perp select 0) * _sec, (_perp select 1) * _sec, 0];
                if (!surfaceIsWater _p1) then {
                    _u setVariable [QGVAR(mikroT), time + 4];
                    // yeni nokta = yeni siper hedefi (coverHug 'acikSiperHedef' kaymasi / yapisma eski cali dibine GERI CEKMESIN: git-gel onleme)
                    _u setVariable [QGVAR(acikSiperHedef), [_p1, time, "mikro"]];
                    _u setVariable [QGVAR(hugPos), _p1];
                    _u setVariable [QGVAR(hugAt), time];
                    [_u, _p1] spawn FUNC(yumusakKay);
                    _say set ["duzeltilen", (_say get "duzeltilen") + 1];
                    if (_logN < 20) then { _logN = _logN + 1; diag_log format ["[SIPER-MIKRO] %1 | %2 | dusman %3 m | gorus hatti %4 m onundeki nesne tarafindan kapaliydi -> yanal kayma %5 m | durus %6", groupId (group _u), name _u, round (_u distance _e), round (((_ht select 0) select 0) distance _eye), _sec toFixed 1, stance _u]; };
                    continue
                };
            };
            // kayma yetmedi: bir durus kademe kalk (goz +0.5 m)
            private _st = stance _u;
            if (_st in ["CROUCH", "PRONE"] && {(lineIntersectsSurfaces [_eye vectorAdd [0, 0, 0.5], _tgt, _u, _e, true, 1, "VIEW", "NONE"]) isEqualTo []}) then {
                _u setUnitPosWeak (["UP", "MIDDLE"] select (_st isEqualTo "PRONE"));
                _u setVariable [QGVAR(mikroT), time + 4];
                _say set ["durus", (_say get "durus") + 1];
                if (_logN < 20) then { _logN = _logN + 1; diag_log format ["[SIPER-MIKRO] %1 | %2 | dusman %3 m | gorus hatti kapali, kayma yok -> durus kademe kalkti (%4)", groupId (group _u), name _u, round (_u distance _e), _st]; };
            } else {
                _u setVariable [QGVAR(mikroT), time + 6];
                _say set ["bulunamadi", (_say get "bulunamadi") + 1];
            };
        } forEach allUnits;
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if ((_say get "kontrol") > 0) then {
                diag_log format ["[SIPER-MIKRO-OZET] 60 sn: kontrol %1 | gorus kapali (> 2 sn) %2 | yanal kayma %3 | durus kalkti %4 | cozum bulunamadi %5 | en cok kayma %6 m", _say get "kontrol", _say get "kapali", _say get "duzeltilen", _say get "durus", _say get "bulunamadi", _maks toFixed 1];
            };
            { _say set [_x, 0]; } forEach ["kontrol", "kapali", "duzeltilen", "durus", "bulunamadi"];
        };
    };
};
true

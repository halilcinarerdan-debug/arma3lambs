#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * GIYIM / TECHIZAT TANISI (v8.152) — kullanici: "AT ve MG asistanlar cirilciplak oluyor, istisnasiz, bizim modla alakali bir durum" (RPT 391409e8 / c855053b, GM Weferlingen).
 * KANIT (RPT): bu modun hicbir yerinde forceAddUniform / removeUniform / setUnitLoadout / removeAllWeapons yok (yalniz cephane aktarimi addMagazine / removeMagazines ve teslimiyette DropWeapon).
 * Sunucu loglarinda bazi askerler dogdugu anda "RIFLE | sarjor:0 | anim:...nonwnon" (silahsiz, sarjorsuz) gorundu -> bos teçhizatla yaratilmis olabilir (mod degil, GM / gorev betigi / Zeus).
 * Bu izleyici bunu KANITLAR: her makinede, yerel AI askerleri 5 sn'de bir tarar; ILK GORULEN teçhizat anlik goruntusu (kiyafet, yelek, sirt cantasi, miğfer, silah, roketatar, sarjor sayisi)
 * AT / MG / MG_ASIST rolunde ya da kiyafetsiz / silahsiz dogan her asker icin [GIYIM-TANI] ILK satiri; sonradan kiyafet / yelek / canta / silah KAYBI olursa [GIYIM-TANI] DEGISTI (once -> sonra + saat + son mod islemleri).
 * Davranisi degistirmez (yalniz log). Kapatma: lambs_danger_giyimTaniOff = true.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_giyimTaniStarted") exitWith {false};
lambs_danger_giyimTaniStarted = true;

diag_log "[GIYIM-TANI] giyim / teçhizat izleyicisi baslatildi (v8.152)";

private _calis = {
    private _gor = createHashMap;
    private _logN = 0;
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
    while {true} do {
        sleep 5;
        if (missionNamespace getVariable ["lambs_danger_giyimTaniOff", false]) then { continue };
        {
            private _g = _x;
            if (!local _g || {isPlayer (leader _g)}) then { continue };
            {
                private _u = _x;
                if (!alive _u || {isPlayer _u} || {!isNull objectParent _u}) then { continue };
                // v8.163 SU TANISI (kullanici: "bazi askerler suya girdi"): yaya AI suda / sig suda ise bir kez (120 sn / asker) neden baglamiyla logla (ilk 60 satir)
                if (surfaceIsWater (getPosATL _u) && {(time - (_u getVariable [QGVAR(suLogT), -999])) > 120} && {(missionNamespace getVariable ["lambs_danger_suLogN", 0]) < 60}) then {
                    _u setVariable [QGVAR(suLogT), time];
                    missionNamespace setVariable ["lambs_danger_suLogN", (missionNamespace getVariable ["lambs_danger_suLogN", 0]) + 1];
                    private _bayraklar = ["planAktif", "isBounding", "isRetreating", "isEvading", "isBreakingContact", "isExecutingTactic"] select {_g getVariable ["lambs_danger_" + _x, false]};
                    private _wi = currentWaypoint _g;
                    private _wpAd = if (_wi > 0 && {_wi < count (waypoints _g)}) then { waypointName ((waypoints _g) select _wi) } else { "-" };
                    diag_log format ["[SU-TANI] %1 | grup %2 | derinlik %3 m | hiz %4 km/s | komut %5 | bayrak %6 | waypoint '%7' | lider suda mi %8 | temas %9 sn once",
                        name _u, groupId _g, (0 - (getTerrainHeightASL (getPosATL _u))) toFixed 2, round speed _u, currentCommand _u, _bayraklar, _wpAd, surfaceIsWater (getPosATL (leader _g)), round (time - (_g getVariable ["lambs_danger_contact", -999]))];
                };
                private _snap = [uniform _u, vest _u, backpack _u, headgear _u, primaryWeapon _u, secondaryWeapon _u, count (magazines _u), currentWeapon _u];
                private _k = netId _u;
                private _eski = _gor getOrDefault [_k, []];
                if (_eski isEqualTo []) then {
                    _gor set [_k, _snap];
                    _u setVariable [QGVAR(giyimIlkT), time];
                    private _rol = [_u] call _rolFn;
                    if (_logN < 120 && {(_rol in ["AT", "MG", "MG_ASIST"]) || {(_snap select 0) isEqualTo ""} || {(_snap select 4) isEqualTo ""}}) then {
                        _logN = _logN + 1;
                        diag_log format ["[GIYIM-TANI] ILK | %1 (%2) | rol %3 | faction %4 | kiyafet '%5' | yelek '%6' | canta '%7' | migfer '%8' | ana silah '%9' | roketatar '%10' | sarjor %11 | grup %12",
                            name _u, typeOf _u, _rol, faction _u, _snap select 0, _snap select 1, _snap select 2, _snap select 3, _snap select 4, _snap select 5, _snap select 6, groupId _g];
                    };
                } else {
                    // kayip: kiyafet / yelek / canta / ana silah dolu iken bos oldu
                    private _kayip = [];
                    { if ((_eski select _x) isNotEqualTo "" && {(_snap select _x) isEqualTo ""}) then { _kayip pushBack (["kiyafet", "yelek", "canta", "migfer", "ana silah", "roketatar"] select _x); }; } forEach [0, 1, 2, 3, 4, 5];
                    // v8.159b: bayilan askerin silahi dusmesi ACE'in normal davranisi (kullanici dogruladi) -> silah kaybi bayilmis askerde loglanmaz
                    if ((_u getVariable ["ACE_isUnconscious", false]) || {(lifeState _u) isEqualTo "INCAPACITATED"}) then { _kayip = _kayip - ["ana silah", "roketatar"]; };
                    if (_kayip isNotEqualTo [] && {_logN < 200}) then {
                        _logN = _logN + 1;
                        diag_log format ["[GIYIM-TANI] DEGISTI | %1 (%2) | rol %3 | KAYIP: %4 | once %5 | sonra %6 | t=%7 | tcccMesgul %8 | cephaneT %9 | grup %10 | teslim %11",
                            name _u, typeOf _u, [_u] call _rolFn, _kayip, _eski, _snap, round time, time < (_u getVariable [QGVAR(tcccBusy), 0]), _u getVariable [QGVAR(cephaneT), -1], groupId _g, _u getVariable [QGVAR(teslim), false]];
                        diag_log format ["[GIYIM-TANI] DEGISTI-BAGLAM | %1 | lifeState %2 | ACE bayilma %3 | anim %4 | yakinda silah yigini (6 m) %5 | hasar %6 | baski %7", name _u, lifeState _u, _u getVariable ["ACE_isUnconscious", false], animationState _u, count (nearestObjects [_u, ["WeaponHolder", "GroundWeaponHolder", "WeaponHolderSimulated"], 6]), (damage _u) toFixed 2, (getSuppression _u) toFixed 2];
                    };
                    // v8.152b: silah degisimi ani ("silah degistirirken ciplak oluyor", spawn aninda): AT / MG / MG_ASIST ya da ilk 120 sn
                    if ((_eski param [7, ""]) isNotEqualTo (_snap select 7)) then {
                        private _ilkT = _u getVariable [QGVAR(giyimIlkT), time];
                        _u setVariable [QGVAR(giyimIlkT), _ilkT];
                        private _rol2 = [_u] call _rolFn;
                        if (_logN < 250 && {(_rol2 in ["AT", "MG", "MG_ASIST"]) || {(time - _ilkT) < 120}}) then {
                            _logN = _logN + 1;
                            diag_log format ["[GIYIM-TANI] SILAH | %1 (%2) | rol %3 | %4 -> %5 | anim %6 | kiyafet '%7' | canta '%8' | roketatar '%9' | grup %10 | temas %11 sn once | t=%12",
                                name _u, typeOf _u, _rol2, _eski param [7, ""], _snap select 7, animationState _u, _snap select 0, _snap select 2, _snap select 5, groupId _g, round (time - (_g getVariable [QGVAR(contact), -999])), round time];
                        };
                    };
                    _gor set [_k, _snap];
                };
            } forEach (units _g);
        } forEach allGroups;
    };
};

[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log "[WATCHDOG-YENIDEN] giyimTani betigi sonlandi (hata?)";
        sleep 5;
    };
};

true

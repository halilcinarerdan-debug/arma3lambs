#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ARACLI MEDEVAC (v8.82) — ilgilenilmeyen baygin yaraliyi guvenli noktaya ARACLA tasir (kullanici: "arac getirebilirsin", "saglikci takimi arac kullansin").
 *
 * TETIK (5 sn'de bir, yerel gruplar): baygin yarali (INCAPACITATED / ACE_isUnconscious) >= 40 sn onlenemedi (hekim yok / uzak / TCCC almadi: tcccBy bos),
 *   yaralinin grubu son 10 sn temasta degil, bilinen dusman (cmdSit) yaraliya >= 120 m.
 * ARAC: ayni taraf, KARA araci (APC / IFV / kamyon / arac), motor yakit > %10, hareket edebilir, bos kargo yeri >= 1, surucu AI + yerel, grup TAMAMEN aracin icinde (mürettebat grubu:
 *   piyadeyi bolmez), grup retreat / bounding / taktik / sniper / pusu / IED isinde degil ve son 30 sn temasta degil, yaraliya <= 1500 m. Turda 1 gorev / taraf; ayni arac 180 sn bekler.
 * GOREV (spawn, en fazla 240 sn): (1) arac yaraliya dusmandan uzak taraftan yaklasir (15 m), (2) durur, yuklenir (yarali basina 6 sn; en cok 3 yarali / 25 m icinden), (3) dusmandan uzaga ~350 m
 *   toplanma noktasina surer, (4) yaralilari indirir; hekim varsa (arac mürettebatinda Medic trait / sargi tasiyan) ona atar (hqMedic) yoksa TCCC / HQ medevac devralir. Gorev sonu grup eski haline doner.
 * YUKLEME ışınlama (moveInCargo) ile yapilir (fiziksel tasima animasyonu YOK). Her adim [ARAC-MEDEVAC] loglanir; iptal nedenleri: arac / surucu oldu, sure doldu, yaklasma yolunda temas, yaralilar kayboldu.
 * Kapatma: lambs_danger_aracMedevacOff = true.   Esikler TASARIM tahmini.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_aracMedevacStarted") exitWith {false};
lambs_danger_aracMedevacStarted = true;

diag_log "[ARAC-MEDEVAC] aracli medevac watchdog'u baslatildi (v8.82)";

// ---- gorev yurutucu ----
private _gorev = {
    params ["_vg", "_v", "_d", "_yaralilar", "_tehditPos", "_yPos"];
    private _t0 = time;
    private _iptal = "";
    private _eskiBeh = behaviour (leader _vg);
    private _eskiHiz = speedMode _vg;
    private _eskiAC = _d checkAIFeature "AUTOCOMBAT";
    _vg setVariable [QGVAR(aracMedevacT), time];
    _vg setVariable [QGVAR(isExecutingTactic), true];
    _vg setVariable [QGVAR(hqGorevT), time];
    _d setVariable [QGVAR(forceMove), true];
    _vg setBehaviour "AWARE";
    _vg setSpeedMode "FULL";
    _d disableAI "AUTOCOMBAT";
    { _x setVariable [QGVAR(tcccBy), _d]; } forEach _yaralilar;

    // (1) yaklasma noktasi: yaralidan dusmandan UZAK tarafta 15 m
    private _yon = if (_tehditPos isNotEqualTo [0,0,0]) then { _tehditPos getDir _yPos } else { random 360 };
    private _ap = _yPos getPos [15, _yon];
    if (surfaceIsWater _ap) then { _ap = _yPos; };
    diag_log format ["[ARAC-MEDEVAC] %1 | GOREV BASLADI | arac %2 | yarali %3 | yaraliya %4 m | tehdit yonu %5", groupId _vg, typeOf _v, _yaralilar apply {name _x}, round (_v distance2D _yPos), round _yon];
    _d doMove _ap;
    private _yakl = time + 120;
    waitUntil {
        sleep 1;
        !alive _v || {!alive _d} || {(_v distance2D _ap) < 18} || {time > _yakl}
        || {(_yaralilar findIf {alive _x}) < 0}
        || {(time - ((group (_yaralilar select 0)) getVariable [QGVAR(contact), -999])) < 5 && {(_v distance2D _ap) > 60}}
    };
    if (!alive _v || {!alive _d}) then { _iptal = "arac / surucu oldu"; };
    if (_iptal isEqualTo "" && {(_yaralilar findIf {alive _x}) < 0}) then { _iptal = "yaralilar kayboldu / oldu"; };
    if (_iptal isEqualTo "" && {time > _yakl}) then { _iptal = "yaklasma suresi doldu (120 sn)"; };
    if (_iptal isEqualTo "" && {(_v distance2D _ap) >= 18}) then { _iptal = "yaklasma yolunda temas basladi"; };

    // (2) yukleme
    private _yuklenen = [];
    if (_iptal isEqualTo "") then {
        doStop _d;
        _v setVelocity [0,0,0];
        diag_log format ["[ARAC-MEDEVAC] %1 | VARDI (%2 m) | yukleme basliyor", groupId _vg, round (_v distance2D _yPos)];
        private _adaylar = (_yaralilar select {alive _x && {(_x distance2D _v) < 25}});
        {
            if (!alive _v || {(_v emptyPositions "cargo") < 1}) exitWith {};
            sleep 6;
            if (alive _x && {isNull objectParent _x}) then {
                _x moveInCargo _v;
                if (!isNull objectParent _x) then { _yuklenen pushBack _x; };
            };
        } forEach (_adaylar select [0, 3]);
        if (_yuklenen isEqualTo []) then { _iptal = "yuklenemedi (kargo yeri yok / yarali yuklenmedi)"; };
    };

    // (3) toplanma noktasina surus
    // v8.129 DOKTRIN: yaralilar cepheden uzaga (CCP / geri), duşman biliniyorsa duşmandan en az 600 m (ya da yaralinin mesafesi + 250 m) uzaga tasinir; asla cepheye dogru degil
    private _tp = if (_tehditPos isNotEqualTo [0,0,0]) then { _tehditPos getPos [(600 max ((_tehditPos distance2D _yPos) + 250)), _yon] } else { _yPos getPos [350, _yon] };
    // v8.115: aktif komutan planinin yarali toplama noktasi (CCP) 1000 m icindeyse arac oraya tasir
    private _ccpAday = (missionNamespace getVariable ["lambs_danger_planCCPlar", []]) select {(_x select 1) isEqualTo (side _vg) && {((_x select 2) distance2D _yPos) < 1000}};
    if (_ccpAday isNotEqualTo []) then { _tp = (_ccpAday select 0) select 2; };
    if (_iptal isEqualTo "") then {
        if (surfaceIsWater _tp) then { _tp = _yPos getPos [200, _yon]; };
        diag_log format ["[ARAC-MEDEVAC] %1 | YUKLENDI %2 | toplanma noktasina %3 m", groupId _vg, _yuklenen apply {name _x}, round (_v distance2D _tp)];
        _d doMove _tp;
        private _sur = time + 120;
        waitUntil { sleep 1; !alive _v || {!alive _d} || {(_v distance2D _tp) < 25} || {time > _sur} };
        if (!alive _v || {!alive _d}) then { _iptal = "tasima sirasinda arac / surucu oldu"; };
        if (_iptal isEqualTo "" && {time > _sur}) then { _iptal = "toplanma noktasina varilamadi (120 sn) - yerinde indirildi"; };
    };

    // (4) indirme + hekim atamasi
    doStop _d;
    private _hekim = objNull;
    {
        if (alive _x && {_x getUnitTrait "Medic" || {((items _x) findIf {(toLower _x) in ["ace_packingbandage", "ace_elasticbandage", "ace_fielddressing", "ace_tourniquet"]}) > -1}}) exitWith { _hekim = _x; };
    } forEach ((crew _v) - _yuklenen);
    {
        if (alive _x && {!isNull objectParent _x}) then {
            moveOut _x;
            unassignVehicle _x;
            _x setPosATL ((getPosATL _v) getPos [4 + random 3, (getDir _v) + 90]);
        };
        _x setVariable [QGVAR(tcccBy), objNull];
        _x setVariable [QGVAR(tcccDone), -999];
        if (!isNull _hekim) then { _x setVariable [QGVAR(hqMedic), _hekim]; };
    } forEach _yuklenen;
    { if (!(_x in _yuklenen)) then { _x setVariable [QGVAR(tcccBy), objNull]; }; } forEach _yaralilar;
    diag_log format ["[ARAC-MEDEVAC] %1 | %2 | indirilen %3 | hekim:%4 | sure %5 sn", groupId _vg, ["TAMAM", "IPTAL: " + _iptal] select (_iptal isNotEqualTo ""), _yuklenen apply {name _x}, ["yok (TCCC / HQ medevac devralir)", name _hekim] select (!isNull _hekim), round (time - _t0)];

    // gorev sonu: grup eski haline
    if (!isNull _vg) then {
        _vg setVariable [QGVAR(isExecutingTactic), nil];
        _vg setBehaviour _eskiBeh;
        _vg setSpeedMode _eskiHiz;
        _vg setVariable [QGVAR(aracMedevacT), time];
    };
    if (alive _d) then {
        _d setVariable [QGVAR(forceMove), nil];
        if (_eskiAC) then { _d enableAI "AUTOCOMBAT"; };
        _d doFollow (leader _vg);
    };
};
missionNamespace setVariable ["lambs_danger_aracMedevacGorevFn", _gorev];

private _calis = {
    missionNamespace setVariable ["lambs_danger_aracMedevacAdim", "basladi"];
    private _yaraliFn = {
        params ["_u"];
        alive _u && {((lifeState _u) isEqualTo "INCAPACITATED") || {_u getVariable ["ACE_isUnconscious", false]}}
    };
    private _gorevFn = missionNamespace getVariable "lambs_danger_aracMedevacGorevFn";
    private _bekleT = createHashMap;
    private _logN = 0;
    while {true} do {
        sleep 5;
        if (missionNamespace getVariable ["lambs_danger_aracMedevacOff", false]) then { continue };
        {
            private _taraf = _x;
            // taraf basina tek gorev
            if ((missionNamespace getVariable [format ["lambs_danger_aracMedevacMesgul_%1", _taraf], 0]) > time) then { continue };
            private _yaralilar = [];
            {
                private _u = _x;
                if ((side (group _u)) isNotEqualTo _taraf || {isPlayer _u} || {!([_u] call _yaraliFn)}) then {
                    _u setVariable [QGVAR(amYarT), nil];
                    continue
                };
                if (!isNull (_u getVariable [QGVAR(tcccBy), objNull])) then { _u setVariable [QGVAR(amYarT), nil]; continue };
                if (isNil {_u getVariable QGVAR(amYarT)}) then { _u setVariable [QGVAR(amYarT), time]; };
                if ((time - (_u getVariable [QGVAR(amYarT), time])) >= 40) then { _yaralilar pushBack _u; };
            } forEach (allUnits select {side (group _x) isEqualTo _taraf && {!(isPlayer _x)}});
            if (_yaralilar isEqualTo []) then { continue };
            private _y = _yaralilar select 0;
            private _yg = group _y;
            private _sit = _yg getVariable [QGVAR(cmdSit), []];
            private _tp = [0,0,0];
            private _enM = 9999;
            if (_sit isNotEqualTo [] && {(_sit select 7) isEqualType []} && {(_sit select 7) isNotEqualTo [0,0,0]}) then {
                _tp = _sit select 7;
                _enM = _y distance2D _tp;
            };
            if ((time - (_yg getVariable [QGVAR(contact), -999])) < 10 || {_enM < 120}) then { continue };
            private _yPos = getPosATL _y;

            // arac ara
            private _aday = [];
            private _standoffRed = 0;
            // v8.127: Zeus 'ELITE Gorev Ata' MEDEVAC: bu tarafta atanmis arac / grup varsa yalniz atananlar kullanilir
            private _mdAtanmis = (allGroups select {(side _x) isEqualTo _taraf}) select {
                ((_x getVariable ["lambs_danger_gorev", ""]) isEqualTo "MEDEVAC") || {((vehicle (leader _x)) getVariable ["lambs_danger_gorev", ""]) isEqualTo "MEDEVAC"}
            };
            {
                private _vg = _x;
                if (_mdAtanmis isNotEqualTo [] && {!(_vg in _mdAtanmis)}) then { continue };
                private _l = leader _vg;
                if (isNull _l || {!local _vg} || {isPlayer _l} || {(side _vg) isNotEqualTo _taraf}) then { continue };
                private _v = vehicle _l;
                if (_v isEqualTo _l || {!(_v isKindOf "LandVehicle")} || {!alive _v} || {!canMove _v} || {(fuel _v) < 0.1}) then { continue };
                if ((_v emptyPositions "cargo") < 1) then { continue };
                if (_v getVariable [QGVAR(tasimaMesgul), false]) then { continue };
                if ("KARAKOL_ARAC" in [_v getVariable ["lambs_danger_gorev", ""], _vg getVariable ["lambs_danger_gorev", ""]]) then { continue };
                // v8.129 DOKTRIN: tahliye araci cepheye girmez. Standoff (duşmana en az): zirhli 300 m, yumusak arac 600 m
                //   (kaynak: AK-74 etkili menzil 500 m, RPG-7 ~200 m, RH 6524-6541; kitapta arac standoff'u sayisi YOK -> TASARIM). Yaralidan duşmana mesafe bu kadar degilse bu arac gitmez.
                private _zirhli = (getNumber (configOf _v >> "armor")) >= 100;
                if (_enM < ([600, 300] select _zirhli)) then { _standoffRed = _standoffRed + 1; continue };
                private _d = driver _v;
                if (isNull _d || {isPlayer _d} || {!local _d} || {!alive _d} || {(group _d) isNotEqualTo _vg}) then { continue };
                if (((units _vg) select {alive _x && {(vehicle _x) isNotEqualTo _v}}) isNotEqualTo []) then { continue };   // grup tamamen aracin icinde
                if ((time - (_vg getVariable [QGVAR(aracMedevacT), -999])) < 180) then { continue };
                if ((time - (_vg getVariable [QGVAR(contact), -999])) < 30) then { continue };
                if (({_vg getVariable ["lambs_danger_" + _x, false]} count ["isRetreating", "isEvading", "isBounding", "isExecutingTactic", "isBreakingContact", "isSonDirenis", "isAmbushing", "sniperTeam", "disableGroupAI"]) > 0) then { continue };
                private _dm = _v distance2D _yPos;
                if (_dm > 1500) then { continue };
                _aday pushBack [_dm, _vg, _v, _d];
            } forEach (allGroups select {(side _x) isEqualTo _taraf});
            if (_aday isEqualTo []) then {
                if ((time - (_bekleT getOrDefault [str _taraf, -999])) > 120 && {_logN < 40}) then {
                    _bekleT set [str _taraf, time];
                    _logN = _logN + 1;
                    diag_log format ["[ARAC-MEDEVAC] %1 | baygin yarali %2 (%3 sn) | uygun arac YOK (kara araci + bos kargo + tamamen binmis surucu grubu + temasta degil + duşman standoff: zirhli 300 / yumusak 600 m; standoff yuzunden elenen: %4)", _taraf, name _y, round (time - (_y getVariable [QGVAR(amYarT), time])), _standoffRed];
                };
                continue;
            };
            _aday = [_aday, [], {_x select 0}] call BIS_fnc_sortBy;
            (_aday select 0) params ["_dm0", "_vg0", "_v0", "_d0"];
            // ayni yakindaki yaralilar (<= 25 m)
            private _grup = _yaralilar select {(_x distance2D _y) <= 25};
            missionNamespace setVariable [format ["lambs_danger_aracMedevacMesgul_%1", _taraf], time + 240];
            [_vg0, _v0, _d0, _grup, _tp, _yPos] spawn _gorevFn;
        } forEach [west, east, independent];
        missionNamespace setVariable ["lambs_danger_aracMedevacAdim", "tur bitti"];
    };
};

// bekci: betik hata ile olurse yeniden baslat
[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log format ["[WATCHDOG-YENIDEN] arac medevac betigi sonlandi (hata?), son adim: %1", missionNamespace getVariable ["lambs_danger_aracMedevacAdim", "?"]];
        sleep 5;
    };
};

true

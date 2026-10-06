#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * SINSI GERI CEKILME (v8.95) — kullanici: "lider adam gorunce kac kisi olduklarini goruyor ama en onde oldugu icin ates etmeye devam ediyor;
 *   azicik sinsi olsunlar, ates etmesin, geri cekilsin, digerlerini beklesin; ozellikle OPFOR / teror icin; digerleri icin de gecerli".
 * Mantik (TASARIM — kaynakli degil; davranis ozeti): grup KENDISI henuz ates altinda degil ve dusman acik ustun (oran >= 1.4) -> temas acmak yerine
 *   ates kesilir (hold fire), STEALTH + egil, ONDEKI askerler (grup medyanindan >= 8 m dusmana yakin; lider dahil) dusmana gorunmeyen arka noktaya cekilir,
 *   digerleri yerinde gozler; 25 sn toparlandiktan sonra serbest (pusu / normal akis devralir).
 * TETIK: lider yerel + AI, >= 3 piyade, taktik / retreat / bounding / pusu vb. yok, cmdSit <= 8 sn, dusman 90-450 m, oran >= 1.4 (DUZENSIZ doktrini 1.25),
 *   grup bastirilmamis (ort. < 0.1), son 20 sn ates edilmemis, kayip orani <= 0.15, 90 sn cooldown.
 * IPTAL (hemen ates serbest): bastirma > 0.25 / kayip / dusman < 70 m / oran < 1.1 / 75 sn sinir.  Ates altindaki / kayip veren grupta tetiklenmez.
 * Kapatma: lambs_danger_sinsiGeriOff = true.  Log: [SINSI-GERI] + [SINSI-GERI-OZET]
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_sinsiGeriStarted") exitWith {false};
lambs_danger_sinsiGeriStarted = true;

diag_log "[SINSI-GERI] sinsi geri cekilme watchdog'u baslatildi (v8.95)";

private _calis = {
    missionNamespace setVariable ["lambs_danger_sinsiGeriAdim", "basladi"];
    private _say = createHashMap;
    private _ozetT = time + 90;
    while {true} do {
        sleep 2;
        if (missionNamespace getVariable ["lambs_danger_sinsiGeriOff", false]) then { continue };
        {
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {!local _g} || {isPlayer _l} || {!alive _l} || {!isNull objectParent _l}) then { continue };
            missionNamespace setVariable ["lambs_danger_sinsiGeriAdim", format ["grup %1", groupId _g]];

            private _us = (units _g) select {alive _x && {isNull objectParent _x} && {!isPlayer _x} && {!((lifeState _x) in ["INCAPACITATED", "UNCONSCIOUS"])} && {!(_x getVariable ["ACE_isUnconscious", false])}};
            private _durum = _g getVariable [QGVAR(sinsiDurum), []];   // [bitisSiniri, noktaVarisT, nokta, enemyPos, eskiCM, eskiBeh, baslangicAdet]

            private _sit = _g getVariable [QGVAR(cmdSit), []];
            private _sitTaze = _sit isNotEqualTo [] && {(time - (_sit select 0)) < 8};
            private _mesafe = [9999, _sit select 1] select _sitTaze;
            private _oran = [0, _sit select 5] select _sitTaze;
            private _dPos = [[], _sit select 7] select (_sitTaze && {(_sit select 7) isEqualType []} && {(_sit select 7) isNotEqualTo [0,0,0]});
            private _bas = 0; { _bas = _bas + (getSuppression _x); } forEach _us;
            if ((count _us) > 0) then { _bas = _bas / (count _us); };

            // ---------------- AKTIF EPIZOT ----------------
            if (_durum isNotEqualTo []) then {
                _durum params ["_son", "_varisT", "_nokta", "_ePos", "_eskiCM", "_eskiBeh", "_adet"];
                private _iptal = "";
                if ((count _us) < _adet) then { _iptal = "kayip"; };
                if (_iptal isEqualTo "" && {_bas > 0.25}) then { _iptal = format ["bastirma %1", _bas toFixed 2]; };
                if (_iptal isEqualTo "" && {_sitTaze} && {_mesafe < 70}) then { _iptal = format ["dusman %1 m", round _mesafe]; };
                if (_iptal isEqualTo "" && {_sitTaze} && {_oran < 1.1}) then { _iptal = format ["oran %1", _oran toFixed 2]; };
                if (_iptal isEqualTo "" && {time > _son}) then { _iptal = "sure"; };
                if (_iptal isEqualTo "" && {({_g getVariable [_x, false]} count [QGVAR(isRetreating), QGVAR(isEvading), QGVAR(isExecutingTactic), QGVAR(isBreakingContact), QGVAR(isSonDirenis)]) > 0}) then { _iptal = "baska taktik"; };
                if (_iptal isEqualTo "" && {_varisT > 0} && {time > (_varisT + 25)}) then { _iptal = "bekleme bitti"; };

                if (_iptal isNotEqualTo "") then {
                    { if (alive _x) then { _x setVariable [QGVAR(sinsiHareket), nil]; if !(time < (_x getVariable [QGVAR(tcccBusy), 0])) then { _x setVariable [QGVAR(forceMove), nil]; }; _x doWatch objNull; _x doFollow _l; }; } forEach _us;
                    _g setCombatMode _eskiCM;
                    _g setBehaviour _eskiBeh;
                    _g setVariable [QGVAR(sinsiDurum), []];
                    _g setVariable [QGVAR(sinsiBitisT), time];
                    _say set ["bitis", (_say getOrDefault ["bitis", 0]) + 1];
                    diag_log format ["[SINSI-GERI] %1 | BITTI (%2) | %3 sn | dusman %4 m oran %5", groupId _g, _iptal, round (time - (_son - 75)), round _mesafe, _oran toFixed 2];
                    continue;
                };
                // ates kesik kalsin (LAMBS geri acabilir)
                if ((combatMode _g) isNotEqualTo "GREEN") then { _g setCombatMode "GREEN"; };
                if ((behaviour _l) isNotEqualTo "STEALTH") then { _g setBehaviour "STEALTH"; };
                // varis
                if (_varisT < 0) then {
                    private _varanlar = _us select {_x getVariable [QGVAR(sinsiHareket), false]};
                    private _gelenler = _varanlar select {(_x distance2D _nokta) < 8};
                    if (count _gelenler >= ((count _varanlar) * 0.7) || {_varanlar isEqualTo []}) then {
                        _durum set [1, time];
                        _g setVariable [QGVAR(sinsiDurum), _durum];
                        { _x setUnitPos "MIDDLE"; _x doWatch _ePos; } forEach _us;
                    };
                };
                continue;
            };

            // ---------------- TETIK ----------------
            if (time - (_g getVariable [QGVAR(sinsiBitisT), -999]) < 90) then { continue };
            if ((count _us) < 3 || {!_sitTaze} || {_dPos isEqualTo []}) then { continue };
            if (_mesafe < 90 || {_mesafe > 450}) then { continue };
            private _esik = [1.4, 1.25] select (([_g, "ad", "GENEL"] call FUNC(dk)) isEqualTo "DUZENSIZ");
            if (_oran < _esik) then { continue };
            if (_bas > 0.1) then { continue };
            if (({_g getVariable [_x, false]} count [QGVAR(isRetreating), QGVAR(isEvading), QGVAR(isBounding), QGVAR(isExecutingTactic), QGVAR(isBreakingContact), QGVAR(isAmbushing), QGVAR(sniperTeam), QGVAR(isSonDirenis), QGVAR(disableGroupAI), QGVAR(isATEngage)]) > 0) then { continue };
            if (((_g getVariable [QGVAR(iedIs), []]) isNotEqualTo []) || {_g getVariable [QGVAR(grState), []] isNotEqualTo []}) then { continue };
            // grup ates etti / kayip verdi: sinsilik kalmadi
            if ((_us findIf {(time - (_x getVariable [QGVAR(sonAtisT), -999])) < 20}) >= 0) then { continue };
            if ((_sit select 6) > 0.15) then { continue };   // kayip veren grupta sinsilik kalmadi

            // onde olanlar: dusmana medyandan >= 8 m yakin (lider dahil)
            private _mes = _us apply {_x distance2D _dPos};
            private _sirali = +_mes; _sirali sort true;
            private _med = _sirali select (floor ((count _sirali) / 2));
            private _onde = _us select {(_x distance2D _dPos) <= (_med - 8)};
            if !(_l in _onde) then { _onde pushBackUnique _l; };
            if (count _onde < 1) then { continue };

            // geri nokta: dusmandan uzaklasma yonu, 50-80 m, dusman gozunden gizli + suyu olmayan
            private _gp = getPosATL _l;
            private _yon = _dPos getDir _gp;
            private _en = [0,0,1.5] vectorAdd _dPos;
            private _nokta = [];
            private _ns = -9999;
            { private _a = _yon + _x; { private _p = _gp getPos [_x, _a]; if (!surfaceIsWater _p) then {
                private _s = 0;
                if (lineIntersects [AGLToASL _en, AGLToASL (_p vectorAdd [0,0,1.2])]) then { _s = _s + 30; };
                _s = _s + 3 * (count (nearestTerrainObjects [_p, ["BUSH", "TREE", "ROCK", "WALL", "BUILDING", "HOUSE"], 8, false, true]));
                _s = _s - 0.1 * abs (_x - 65);
                if (_s > _ns) then { _ns = _s; _nokta = _p; };
            }; } forEach [50, 65, 80]; } forEach [0, 30, -30];
            if (_nokta isEqualTo []) then { continue };

            private _eskiCM = combatMode _g;
            private _eskiBeh = behaviour _l;
            _g setCombatMode "GREEN";
            _g setBehaviour "STEALTH";
            {
                private _u = _x;
                if (time < (_u getVariable [QGVAR(tcccBusy), 0]) || {_u getVariable [QGVAR(forceMove), false]}) then { continue };
                _u setVariable [QGVAR(forceMove), true];
                if (_u in _onde) then {
                    _u setVariable [QGVAR(sinsiHareket), true];
                    _u doMove _nokta;
                    _u setUnitPos "MIDDLE";
                } else {
                    _u doWatch _dPos;
                    _u setUnitPos "MIDDLE";
                };
            } forEach _us;
            _g setVariable [QGVAR(sinsiDurum), [time + 75, -1, _nokta, _dPos, _eskiCM, _eskiBeh, count _us]];
            _say set ["baslat", (_say getOrDefault ["baslat", 0]) + 1];
            diag_log format ["[SINSI-GERI] %1 | BASLADI | dusman %2 m oran %3 (esik %4) | %5/%6 asker onde (lider dahil) %7 m geri noktaya | ates kesik + STEALTH", groupId _g, round _mesafe, _oran toFixed 2, _esik, count _onde, count _us, round (_l distance2D _nokta)];
        } forEach (allGroups select {local _x && {!isNull leader _x} && {!(_x getVariable ["lambs_danger_tarafKapali", false])}});
        if (time > _ozetT) then {
            _ozetT = time + 90;
            if (count _say > 0) then { diag_log format ["[SINSI-GERI-OZET] son 90 sn: %1", (keys _say) apply {format ["%1:%2", _x, _say get _x]}]; };
            _say = createHashMap;
        };
        missionNamespace setVariable ["lambs_danger_sinsiGeriAdim", "tur bitti"];
    };
};

// bekci: betik hata ile olurse yeniden baslat
[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log format ["[WATCHDOG-YENIDEN] sinsiGeri betigi sonlandi (hata?), son adim: %1", missionNamespace getVariable ["lambs_danger_sinsiGeriAdim", "?"]];
        sleep 5;
    };
};

true

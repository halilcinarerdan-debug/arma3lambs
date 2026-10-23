#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ATES VE HAREKET (v8.317; kullanici: 'botlar f2f de seni gordukten sonra siperde karsilik vermezsen uzerine geliyorlar ve hepsi acikta yakalaniyor ... kitaba gore ... a sikki agirlikli, b cok zor durumda; hibrit').
 * KAYNAK (TC 3-21.76 Ranger Handbook, ates ve hareket / saldiri): askerler SIPERLI pozisyondan ates eder; hareket eden eleman bir sonraki siperli noktayi hareketten ONCE secer, <= 5 sn'lik koslarla (rush) ya da surunerek gider;
 *   ates / yeniden doldurma zamanlanir; hareket eden ilerleyemezse bastirmaya gecer. Ates TABAN ATES elemanindan gelir, hareket eden ates etmez.
 * TETIK (grup, 1 sn'de bir, yerel oyuncusuz): temasta, bilinen (knowsAbout >= 0.6) dusman piyade 30-220 m, grupta EN AZ 1 asker dusmana ACIK (dusman gozunden gogus hizasina hat serbest); retreat / evade / temas kes / bounding (BND) / tarama haric.
 * ISLEYIS:
 *   TABAN ATES (BOF): MG oncelikli, grubun ~yarisi: siperde (fnc_acikSiper) kalir, dusmana bastirma atesi (doSuppressiveFire, 3 sn'de bir); ilerlemez.
 *   HAREKET (MOV): kalan yari: taban ates >= 3-4 sn kurulduktan SONRA, dusmandan GIZLI en yakin siperli noktaya (agac / kaya / duvar arkasi, bina ici; ilerleme / yan, geri degil; 25 m'den yakin degil) 5 sn'lik RUSH:
 *       FULL hiz, kosarken AUTOTARGET + TARGET kapali (ATES ETMEZ - 'a' sikki), varinca siper durusu (UP / MIDDLE / DOWN) ve yeniden acilir. Siperli nokta YOKSA ilerlemez: yatar (acikta yurume yok).
 *   TAKAS: hareket eden tamamen vardiktan ve faz >= 8 sn sonra roller degisir (taban <-> hareket).
 *   'b' SIKKI (hareket halinde ates): yalniz ZOR DURUM (rush eden askerde baski > 0.5 ya da grup kaybi >= %40) + CBA orani (lambs_danger_atesHareketOran, varsayilan 0.10): kosarken hedefe bastirma atesi, AI kapatilmaz.
 * Guvenlik: AI kapatma <= 6 sn, her rush'ta CBA bekleme + her tick kurtarma taramasi (sure dolunca TARGET / AUTOTARGET / PATH yeniden acilir); teslim / captive askere dokunulmaz.
 * CBA 'ELITE siper': lambs_danger_atesHareketAktif, lambs_danger_atesHareketOran.   Kapatma: lambs_danger_atesHareketOff = true.   Log: [ATES-HAREKET] / [ATES-HAREKET-OZET]
 *
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_atesHareketStarted") exitWith {false};
lambs_danger_atesHareketStarted = true;
diag_log "[ATES-HAREKET] ates ve hareket (taban ates / rush / takas) izleyicisi baslatildi (v8.317)";

// AI geri acma: global (CBA geri cagrilarinda kullanilir)
lambs_danger_fhGeriAc = {
    params ["_u"];
    if (!isNull _u && {alive _u} && {!(_u getVariable ["lambs_danger_teslim", false])} && {!captive _u}) then {
        _u enableAI "TARGET";
        _u enableAI "AUTOTARGET";
    };
    if (!isNull _u) then { _u setVariable ["lambs_danger_fhAIBit", nil]; };
};
lambs_danger_atesHareketSay = createHashMapFromArray [["rush", 0], ["b_mod", 0], ["siperYok", 0], ["takas", 0], ["bof_ates", 0]];

[] spawn {
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
    private _logN = 0;
    private _sonOzet = time + 60;

    // ileri / yan siperli nokta: [pos, durus] ya da []
    private _siperBul = {
        params ["_u", "_en"];
        private _p = getPosATL _u;
        private _eASL = eyePos _en;
        private _ed = _u distance2D _en;
        private _dolu = (missionNamespace getVariable ["lambs_danger_acikSiperDolu", []]) select {(time - (_x select 1)) < 30};
        private _en_iyi = [];
        private _skor = 1e9;
        {
            private _o = _x;
            private _op = getPosATL _o;
            private _bb = boundingBoxReal _o;
            private _yk = ((_bb select 1) select 2) - ((_bb select 0) select 2);
            if (_yk >= 0.7) then {
                private _r = (((((_bb select 1) select 0) - ((_bb select 0) select 0)) max (((_bb select 1) select 1) - ((_bb select 0) select 1))) / 2) min 2.5;
                private _pos = _op getPos [_r + 0.55, _en getDir _o];
                private _pd = _pos distance2D _en;
                private _ud = _u distance2D _pos;
                if (_pd >= 25 && {_pd <= (_ed + 3)} && {_ud >= 5} && {_ud <= 32} && {!surfaceIsWater _pos} && {(_dolu findIf {((_x select 0) distance2D _pos) < 1.5}) < 0}) then {
                    private _gASL = ATLToASL [_pos select 0, _pos select 1, 0];
                    private _bl = [1.5, 1.0, 0.4] apply { (lineIntersectsSurfaces [_eASL, _gASL vectorAdd [0, 0, _x], _en, _u, true, 1, "FIRE", "NONE"]) isNotEqualTo [] };
                    private _ds = if (_bl select 0) then {["UP", 0]} else { if (_bl select 1) then {["MIDDLE", 2]} else { if (_bl select 2) then {["DOWN", 5]} else {["", 99]} } };
                    if ((_ds select 0) isNotEqualTo "") then {
                        private _sk = _pd + ((_ds select 1) * 3) + (_ud * 0.3);
                        if (_sk < _skor) then { _skor = _sk; _en_iyi = [_pos, _ds select 0]; };
                    };
                };
            };
        } forEach (nearestTerrainObjects [_p, ["TREE", "SMALL TREE", "ROCK", "ROCKS", "WALL", "HIDE"], 30, false, true]);
        {
            private _b = _x;
            {
                private _bp = _x;
                private _pd = _bp distance2D _en;
                private _ud = _u distance2D _bp;
                if (_ud >= 5 && {_ud <= 32} && {_pd >= 25} && {_pd <= (_ed + 3)} && {(_dolu findIf {((_x select 0) distance2D _bp) < 1.8}) < 0}) then {
                    if (lineIntersects [_eASL, (AGLToASL _bp) vectorAdd [0, 0, 1.3], _en, _u]) then {
                        private _sk = _pd + 4 + (_ud * 0.3);
                        if (_sk < _skor) then { _skor = _sk; _en_iyi = [_bp, "AUTO"]; };
                    };
                };
            } forEach ((_b buildingPos -1) select [0, 14]);
        } forEach ((nearestObjects [_p, ["House"], 32]) select {(count (_x buildingPos -1)) > 0});
        _en_iyi
    };

    while {true} do {
        sleep 1;
        // ---- kurtarma: AI kapatma suresi dolanlar ----
        {
            [_x] call lambs_danger_fhGeriAc;
        } forEach (allUnits select {local _x && {(_x getVariable [QGVAR(fhAIBit), -1]) > 0} && {time > (_x getVariable [QGVAR(fhAIBit), -1])}});

        if (missionNamespace getVariable ["lambs_danger_atesHareketOff", false] || {!(missionNamespace getVariable ["lambs_danger_atesHareketAktif", true])}) then { continue };
        private _say = lambs_danger_atesHareketSay;
        private _butce = 4;

        {
            if (_butce <= 0) exitWith {};
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {!local _g} || {isPlayer _l} || {!alive _l} || {(side _g) isEqualTo civilian}) then { continue };
            if ((_g getVariable [QGVAR(contact), 0]) <= time) then { continue };
            if ((_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]} || {_g getVariable [QGVAR(isSweeping), false]} || {_g getVariable [QGVAR(isBounding), false]} || {_g getVariable [QGVAR(teslimOldu), false]}) then { continue };
            private _uyeler = (units _g) select {
                alive _x && {local _x} && {!isPlayer _x} && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}
                && {!(_x getVariable [QGVAR(teslim), false])} && {!captive _x} && {!(_x getVariable [QGVAR(forceMove), false])} && {time >= (_x getVariable [QGVAR(tcccBusy), 0])}
                && {(_x getVariable [QGVAR(taktikKilit), 0]) <= time || {(_x getVariable [QGVAR(fhTK), -1]) isEqualTo (_x getVariable [QGVAR(taktikKilit), 0])}}
            };
            if ((count _uyeler) < 2) then { continue };

            // ---- dusman: bilinen piyade 30-220 m ----
            private _taraf = side _g;
            private _dus = (_l nearTargets 240) select {
                private _o = _x select 4;
                !isNull _o && {alive _o} && {_o isKindOf "CAManBase"} && {(_taraf getFriend (side (group _o))) < 0.6} && {(_l knowsAbout _o) >= 0.6}
            };
            if (_dus isEqualTo []) then { continue };
            private _en = ([_dus, [], {(_x select 4) distance _l}, "ASCEND"] call BIS_fnc_sortBy) select 0 select 4;
            private _ed = _l distance2D _en;
            if (_ed < 30 || {_ed > 220}) then { continue };
            // acikta olan var mi (dusman gozunden gogus hizasi hatti serbest)
            private _acik = _uyeler select { !(lineIntersects [eyePos _en, (getPosASL _x) vectorAdd [0, 0, 1.1], _en, _x]) };
            if (_acik isEqualTo []) then { continue };

            // ---- roller ----
            private _bof = (_g getVariable [QGVAR(fhBof), []]) select {_x in _uyeler};
            private _mov = _uyeler select {!(_x in _bof)};
            if (_bof isEqualTo [] || {_mov isEqualTo []} || {(time - (_g getVariable [QGVAR(fhT), -999])) > 40}) then {
                private _sirali = [_uyeler, [], {
                    private _r = ([_x] call (missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}])) isEqualTo "MG";
                    ([0, 1000] select _r) - (speed _x)
                }, "DESCEND"] call BIS_fnc_sortBy;
                private _bn = ((ceil ((count _uyeler) / 2)) max 1) min ((count _uyeler) - 1);
                _bof = _sirali select [0, _bn];
                _mov = _uyeler select {!(_x in _bof)};
                _g setVariable [QGVAR(fhBof), _bof];
                _g setVariable [QGVAR(fhT), time];
                _g setVariable [QGVAR(fhFazT), time];
            };
            // takas: hareket edenler vardi (ya da 12 sn gecti) ve faz >= 8 sn
            private _fazYas = time - (_g getVariable [QGVAR(fhFazT), time]);
            private _hepVardi = (_mov findIf {(time < (_x getVariable [QGVAR(fhRushBit), -1])) || {!(_x getVariable [QGVAR(fhVardi), false]) && {(_x getVariable [QGVAR(fhRushBit), -1]) > 0}}}) < 0;
            if (_fazYas > 8 && {_hepVardi || _fazYas > 12}) then {
                private _eskiBof = _bof;
                _bof = _mov;
                _mov = _eskiBof;
                _g setVariable [QGVAR(fhBof), _bof];
                _g setVariable [QGVAR(fhFazT), time];
                { _x setVariable [QGVAR(fhVardi), nil]; } forEach _uyeler;
                _fazYas = 0;
                _say set ["takas", (_say get "takas") + 1];
            };

            // ---- TABAN ATES ----
            {
                private _u = _x;
                if (_butce <= 0) exitWith {};
                if ((time - (_u getVariable [QGVAR(fhBofT), -999])) > 3) then {
                    _u setVariable [QGVAR(fhBofT), time];
                    if ((speed _u) > 1.5 || {!(lineIntersects [eyePos _en, (getPosASL _u) vectorAdd [0, 0, 1.1], _en, _u])}) then { [_u, _en] call FUNC(acikSiper); };
                    if (((primaryWeapon _u) isNotEqualTo "") && {(_u ammo (primaryWeapon _u)) > 0} && {!(_u getVariable [QGVAR(fhAIBit), -1] > 0)}) then {
                        _u doSuppressiveFire _en;
                        _say set ["bof_ates", (_say get "bof_ates") + 1];
                    };
                    _butce = _butce - 1;
                };
            } forEach _bof;

            // ---- HAREKET: taban ates kuruldu mu? ----
            private _bofKurulu = _fazYas >= 3.5 || {(_bof findIf {(speed _x) < 1}) >= 0 && {_fazYas >= 2.5}};
            if (!_bofKurulu) then { continue };
            private _kayipOran = 1 - ((count _uyeler) / (((_g getVariable [QGVAR(moralIlk), count _uyeler]) max (count _uyeler))));
            private _rushN = 0;
            private _bN = 0;
            private _yokN = 0;
            {
                private _u = _x;
                if (_butce <= 0) exitWith {};
                if ((time >= (_u getVariable [QGVAR(fhRushBit), -1])) && {time >= (_u getVariable [QGVAR(fhNextT), -1])} && {!(_u getVariable [QGVAR(fhVardi), false])}) then {
                    private _nokta = [_u, _en] call _siperBul;
                    if (_nokta isEqualTo []) then {
                        // siperli nokta yok: ilerlemez, yatar (acikta yurume yok)
                        _u setUnitPos "DOWN";
                        _u setVariable [QGVAR(fhNextT), time + 4];
                        _u setVariable [QGVAR(fhVardi), true];
                        _yokN = _yokN + 1;
                        _say set ["siperYok", (_say get "siperYok") + 1];
                    } else {
                        private _dolu = (missionNamespace getVariable ["lambs_danger_acikSiperDolu", []]);
                        _dolu pushBack [_nokta select 0, time];
                        missionNamespace setVariable ["lambs_danger_acikSiperDolu", _dolu];
                        private _dire = ((getSuppression _u) > 0.5) || {_kayipOran >= 0.4} || {(random 1) < (missionNamespace getVariable ["lambs_danger_atesHareketOran", 0.10])};
                        _u setVariable [QGVAR(fhRushBit), time + 5];
                        _u setVariable [QGVAR(fhVardi), nil];
                        private _tk = time + 6;
                        _u setVariable [QGVAR(taktikKilit), _tk];
                        _u setVariable [QGVAR(fhTK), _tk];
                        if (_dire) then {
                            _u doSuppressiveFire _en;
                            _bN = _bN + 1;
                            _say set ["b_mod", (_say get "b_mod") + 1];
                        } else {
                            _u disableAI "TARGET";
                            _u disableAI "AUTOTARGET";
                            _u setVariable [QGVAR(fhAIBit), time + 6.5];
                        };
                        _u forceSpeed -1;
                        _u setSpeedMode "FULL";
                        _u setUnitPos "AUTO";
                        _u doMove (_nokta select 0);
                        [{
                            params ["_uu", "_hp", "_ds"];
                            !alive _uu || {(_uu distance2D _hp) < 2.5}
                        }, {
                            params ["_uu", "_hp", "_ds"];
                            if (alive _uu) then {
                                _uu setUnitPos _ds;
                                [_uu] call lambs_danger_fhGeriAc;
                                _uu setVariable ["lambs_danger_fhVardi", true];
                                _uu setVariable ["lambs_danger_fhNextT", time + 2.5];
                            };
                        }, [_u, _nokta select 0, _nokta select 1], 5.5, {
                            params ["_uu", "_hp", "_ds"];
                            if (alive _uu) then {
                                _uu setUnitPos _ds;
                                [_uu] call lambs_danger_fhGeriAc;
                                _uu setVariable ["lambs_danger_fhVardi", true];
                                _uu setVariable ["lambs_danger_fhNextT", time + 2.5];
                            };
                        }] call CBA_fnc_waitUntilAndExecute;
                        _rushN = _rushN + 1;
                        _say set ["rush", (_say get "rush") + 1];
                    };
                    _butce = _butce - 1;
                };
            } forEach _mov;

            if ((_rushN + _yokN) > 0 && {(time - (_g getVariable [QGVAR(fhLogT), -999])) > 10} && {_logN < 80}) then {
                _g setVariable [QGVAR(fhLogT), time];
                _logN = _logN + 1;
                diag_log format ["[ATES-HAREKET] %1 | dusman %2 m (acikta %3/%4) | TABAN ATES %5 asker / HAREKET %6 asker | rush %7 (b: %8) siperli nokta yok (yatar) %9 | faz %10 sn kayip %11", groupId _g, round _ed, count _acik, count _uyeler, count _bof, count _mov, _rushN, _bN, _yokN, round _fazYas, _kayipOran toFixed 2];
            };
        } forEach allGroups;

        if (time > _sonOzet) then {
            _sonOzet = time + 60;
            private _s = lambs_danger_atesHareketSay;
            diag_log format ["[ATES-HAREKET-OZET] 60 sn: rush %1 | 'b' (hareket halinde ates) %2 | siperli nokta yok %3 | takas %4 | taban ates emri %5", _s get "rush", _s get "b_mod", _s get "siperYok", _s get "takas", _s get "bof_ates"];
            { _s set [_x, 0]; } forEach (keys _s);
        };
    };
};
true

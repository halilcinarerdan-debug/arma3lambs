#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * MORAL + TESLIMIYET v1 (VBS4 "surrender / morale" fikri) — grup basina moral endeksi (0..1) ve umutsuz durumda teslim.
 *
 * MORAL ENDEKSI (5 sn'de bir; baslangic 1.0; hedefe dogru %20 / tick yaklasir = yumusak):
 *   hedef = 1 - 0.50 x kayip orani (baslangictan) - 0.25 x ort. baski - 0.15 x (cephane dusuk askerler orani) - 0.15 (lider olu) - 0.10 (en yakin dost > 100 m)
 *           + 0.10 (temas > 60 sn yok)    sinir 0..1
 *   (kayip orani: lambs_danger_cmdInitialCount ya da grubun ilk gorulen sayisi)
 *
 * TESLIM (hepsi saglanirsa): doktrin teslim = true; moral < teslimEsik (0.15); kalan <= 2 asker; >= %70 kayip; ort. baski >= 0.6;
 *   bilinen dusman <= 50 m; grup retreat / evade / temas kes / pusu degil; ayni grup daha once teslim olmadi.
 *   Etki: askerler LAMBS birim bayragi ile kapatilir, setCaptive true, silah birakilir, "Surrender" aksiyonu; olay "Teslim". Dusman menzilden
 *   cikinca (> 150 m, 60 sn) sadece moral toparlanir (teslim geri alinmaz).
 * DUZENSIZ (Taliban-tipi) profili teslim = false.
 *
 * Kapatma: lambs_danger_moralV1 = false  (teslim yalniz: lambs_danger_teslimV1 = false).
 * Log: [MORAL] (grup basina moral degisince, en fazla 30 sn'de bir), [TESLIM], [MORAL-OZET] 60 sn.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_moralStarted") exitWith {false};
lambs_danger_moralStarted = true;

diag_log "[MORAL] moral + teslimiyet izleyicisi baslatildi";

[] spawn {
    private _gonder = missionNamespace getVariable ["lambs_danger_fnc_olayGonder", {false}];
    private _sonOzet = time;
    private _teslimSay = 0;
    while {true} do {
        sleep 5;
        if (!(missionNamespace getVariable ["lambs_danger_moralV1", true])) then { continue };
        private _gSay = 0;
        private _dusukSay = 0;
        {
            private _g = _x;
            if (isNull _g || {!local _g} || {(side _g) isEqualTo civilian}) then { continue };
            if ((units _g) findIf {isPlayer _x} > -1) then { continue };
            private _us = (units _g) select {alive _x && {isNull objectParent _x}};
            if (_us isEqualTo []) then { continue };
            if (_g getVariable [QGVAR(teslimOldu), false]) then { continue };
            _gSay = _gSay + 1;

            private _ilk = _g getVariable [QGVAR(moralIlk), 0];
            if (_ilk < (count _us)) then { _ilk = count _us; _g setVariable [QGVAR(moralIlk), _ilk]; };
            private _init = _g getVariable [QGVAR(cmdInitialCount), _ilk];
            if (!(_init isEqualType 0) || {_init < (count _us)}) then { _init = _ilk max (count _us); };
            private _kayip = (1 - ((count _us) / (_init max 1))) max 0;

            private _l = leader _g;
            private _bsk = 0;
            private _dusukC = 0;
            { _bsk = _bsk + ((getSuppression _x) min 1); if ((count (magazines _x)) <= 1 && {(_x ammo (primaryWeapon _x)) < 10}) then { _dusukC = _dusukC + 1; }; } forEach _us;
            _bsk = _bsk / (count _us);
            private _komsu = 9999;
            if ((count _us) > 1 && {!isNull _l}) then {
                { if (_x isNotEqualTo _l) then { _komsu = _komsu min (_l distance2D _x); }; } forEach _us;
            } else { _komsu = 0; };
            private _temasYok = (_g getVariable [QGVAR(contact), 0]) < (time - 60);

            private _hedef = 1 - (0.50 * _kayip) - (0.25 * _bsk) - (0.15 * (_dusukC / (count _us))) - ([0, 0.15] select (isNull _l || {!alive _l})) - ([0, 0.10] select (_komsu > 100)) + ([0, 0.10] select _temasYok);
            _hedef = (_hedef max 0) min 1;
            private _m0 = _g getVariable [QGVAR(moral), 1];
            private _m = _m0 + ((_hedef - _m0) * 0.2);
            _g setVariable [QGVAR(moral), _m];
            if (_m < 0.5) then { _dusukSay = _dusukSay + 1; };

            if ((abs (_m - (_g getVariable [QGVAR(moralLog), 1]))) >= 0.15 && {(time - (_g getVariable [QGVAR(moralLogT), -99])) > 30}) then {
                _g setVariable [QGVAR(moralLog), _m];
                _g setVariable [QGVAR(moralLogT), time];
                diag_log format ["[MORAL] %1 | moral:%2 | kalan:%3/%4 (kayip %5%%) | baski:%6 | cephane dusuk:%7 | komsu:%8 m | temas yok:%9", groupId _g, _m toFixed 2, count _us, _init, round (_kayip * 100), _bsk toFixed 2, _dusukC, if (_komsu > 9000) then {"-"} else {round _komsu}, _temasYok];
            };

            // --- TESLIM ---
            if (
                (missionNamespace getVariable ["lambs_danger_teslimV1", true])
                && {[_g, "teslim", true] call FUNC(dk)}
                && {_m < ([_g, "teslimEsik", 0.15] call FUNC(dk))}
                && {(count _us) <= 2} && {_kayip >= 0.70} && {_bsk >= 0.6}
                && {!(_g getVariable [QGVAR(isRetreating), false])} && {!(_g getVariable [QGVAR(isEvading), false])}
                && {!(_g getVariable [QGVAR(isBreakingContact), false])} && {!(_g getVariable [QGVAR(isAmbushing), false])}
            ) then {
                private _en = _l findNearestEnemy _l;
                if (!isNull _en && {alive _en} && {(_l distance2D _en) <= 50}) then {
                    _g setVariable [QGVAR(teslimOldu), true];
                    _teslimSay = _teslimSay + 1;
                    {
                        _x setVariable [QGVAR(disableAI), true];
                        _x setCaptive true;
                        _x setVariable [QGVAR(teslim), true, true];
                        private _w = primaryWeapon _x;
                        if (_w isNotEqualTo "") then { _x action ["DropWeapon", _x, _w]; };
                        _x action ["Surrender", _x];
                        _x doWatch objNull;
                    } forEach _us;
                    _g setBehaviour "SAFE";
                    _g setCombatMode "BLUE";
                    diag_log format ["[TESLIM] %1 | %2 asker teslim oldu | moral:%3 kayip:%4%% baski:%5 | dusman:%6 m | taraf:%7", groupId _g, count _us, _m toFixed 2, round (_kayip * 100), _bsk toFixed 2, round (_l distance2D _en), side _g];
                    [_g, "Teslim", count _us] call _gonder;
                };
            };
        } forEach allGroups;

        if ((time - _sonOzet) >= 60) then {
            _sonOzet = time;
            diag_log format ["[MORAL-OZET] yerel AI grup:%1 | moral < 0.5: %2 | toplam teslim (oturum): %3", _gSay, _dusukSay, _teslimSay];
        };
    };
};

true

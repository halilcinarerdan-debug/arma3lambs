#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * C2 ISTEMCI: HARITA TIKLAMASI (v8.391) — fnc_c2Baslat'in MapSingleClick olayindan cagrilir; fnc_c2Sec'in actigi bekleme durumunu ilerletir.
 *   TOPCU: tiklanan nokta hedef -> sunucuya [tur, nokta, gozlemci] (fnc_c2TopcuIste)
 *   EMIR : adim 0 = tiklamaya en yakin dost BOT grup lideri (CBA c2EmirYaricap, oyuncu liderli gruplar secilmez); TUT / SERBEST ise emir hemen gider, MOVE / SAD ise adim 1 = hedef nokta
 * Bekleme durumu: lambs_danger_c2Bekle = [amac, veri, bitis (diag_tickTime), adim, grup netId].
 *
 * Arguments:
 * 0: Tiklanan konum <ARRAY>
 *
 * Return Value: None
 * Public: No
*/

params [["_poz", [], [[]]]];

private _b = missionNamespace getVariable ["lambs_danger_c2Bekle", []];
if (_poz isNotEqualTo [] && {_b isNotEqualTo []}) then {
    if (diag_tickTime > (_b select 2)) then {
        missionNamespace setVariable ["lambs_danger_c2Bekle", []];
    } else {
        _b params ["_amac", "_veri", "_son", "_adim", "_grup"];
        private _p = [_poz select 0, _poz select 1, 0];
        private _kod = _veri param [0, ""];

        if (_amac isEqualTo "TOPCU") then {
            missionNamespace setVariable ["lambs_danger_c2Bekle", []];
            [_kod, _p, player] remoteExecCall ["lambs_danger_fnc_c2TopcuIste", 2];
            systemChat format ["[C2] Topcu istegi gonderildi: %1 | hedef GRID %2", _kod, mapGridPosition _p];
        };

        if (_amac isEqualTo "EMIR") then {
            if (_adim isEqualTo 0) then {
                private _taraf = side (group player);
                private _yar = missionNamespace getVariable ["lambs_danger_c2EmirYaricap", 150];
                private _adaylar = allGroups select {
                    (side _x) isEqualTo _taraf && {!isNull (leader _x)} && {alive (leader _x)} && {!isPlayer (leader _x)}
                    && {((leader _x) distance2D _p) < _yar}
                };
                if (_adaylar isEqualTo []) then {
                    systemChat format ["[C2] Tikladigin noktanin %1 m cevresinde dost bot grubu yok; tekrar dene.", round _yar];
                } else {
                    private _g = ([_adaylar, [], {(leader _x) distance2D _p}, "ASCEND"] call BIS_fnc_sortBy) select 0;
                    if (_kod in ["TUT", "SERBEST"]) then {
                        missionNamespace setVariable ["lambs_danger_c2Bekle", []];
                        [netId _g, _kod, [], player] remoteExecCall ["lambs_danger_fnc_c2Emir", 2];
                        systemChat format ["[C2] Emir gonderildi: %1 -> %2", _kod, groupId _g];
                    } else {
                        missionNamespace setVariable ["lambs_danger_c2Bekle", [_amac, _veri, _son, 1, netId _g]];
                        systemChat format ["[C2] Secilen grup: %1 (%2 kisi). Simdi HEDEF noktaya tikla.", groupId _g, {alive _x} count (units _g)];
                    };
                };
            } else {
                missionNamespace setVariable ["lambs_danger_c2Bekle", []];
                [_grup, _kod, _p, player] remoteExecCall ["lambs_danger_fnc_c2Emir", 2];
                systemChat format ["[C2] Emir gonderildi: %1 | hedef GRID %2", _kod, mapGridPosition _p];
            };
        };
    };
};

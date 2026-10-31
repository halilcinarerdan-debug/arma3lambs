#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ZIRH ARALIGI (v8.348; kullanici: 'tanklar bazen 2 ya da daha fazla iken birbirlerinin ustune biniyorlar'). Sunucu bekcisi, 3 sn'de bir; AI suruculu, yerel, motoru acik tank / IFV / APC ciftlerini denetler.
 * Kitap: MCWP 3-11.1 satir 8742-8766 (arac ARALIGI arazi ve duruma gore; birbirini gorecek kadar yakin; sinirli gorusta daralir) + ATP 3-20.15 / genel zirh ilkesi: dagilma (tek atisla iki arac kaybedilmesin, karsilikli destek); sayilar [T].
 * ONLEM / KURTARMA (kademeler):
 *   1) YAKLASIYOR (hareketli, merkezler < 22 m, biri digerine dogru gidiyor): arkadan gelen / yavas arac 4 sn durdurulur (doStop + forceSpeed 0), sonra serbest birakilir.
 *   2) PARK ARALIGI (ikisi de duruyor, merkezler < 26 m): SONRA duran arac digerinden uzaklasan 40 m'lik bos noktaya kayar (grup mevzi noktasi da guncellenir). Kitap: dagilma.
 *   3) UST USTE / IC ICE (merkezler < 10 m ya da yukseklik farki > 1.2 m ve yatay < 13 m): geri al + uzaklas (setVelocityModelSpace -3 m/sn 2 sn + 45 m ara nokta); 10 sn sonra hala ic icesiyse en yakin bos konuma setVehiclePosition.
 * Ayni arac icin 25 sn kilit. Atlanir: oyuncu surucu, motor kapali, hareket edemeyen arac, nakil sirasinda yolcu indirme. Kapatma: CBA tankAralikAktif / lambs_danger_tankAralikOff = true. Log: [TANK-ARALIK].
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isServer || {!isNil "lambs_danger_tankAralikStarted"}) exitWith {false};
lambs_danger_tankAralikStarted = true;

[] spawn {
    private _ozetT = time + 90;
    private _say = [0, 0, 0, 0];
    while {true} do {
        sleep 3;
        if (missionNamespace getVariable ["lambs_danger_tankAralikOff", false] || {!(missionNamespace getVariable ["lambs_danger_tankAralikAktif", true])}) then { continue };
        private _araclar = vehicles select {
            alive _x && {local _x} && {isEngineOn _x} && {canMove _x} && {_x isKindOf "LandVehicle"} && {!unitIsUAV _x}   // v8.357: insansiz kara araci (UGV, displayName "Ground") tank sayilmaz (RPT 30-10: "Ground / Ground (1 m)" USTUSTE)
            && {(_x isKindOf "Tank") || {_x isKindOf "Wheeled_APC_F"} || {_x isKindOf "APC_Tracked_01_base_F"} || {(getNumber (configOf _x >> "armor")) >= 200}}
            && {private _dd = driver _x; !isNull _dd && {!isPlayer _dd} && {local _dd}}
        };
        if ((count _araclar) < 2) then { continue };
        private _isleme = [];
        for "_i" from 0 to ((count _araclar) - 2) do {
            for "_j" from (_i + 1) to ((count _araclar) - 1) do {
                private _a = _araclar select _i;
                private _b = _araclar select _j;
                private _d2 = _a distance2D _b;
                if (_d2 >= 26) then { continue };
                private _dz = abs (((getPosATL _a) select 2) - ((getPosATL _b) select 2));
                private _ha = (speed _a) > 3;
                private _hb = (speed _b) > 3;
                private _tur = "";
                if (_d2 < 10 || {_dz > 1.2 && {_d2 < 13}}) then { _tur = "USTUSTE"; } else {
                    if ((_ha || _hb) && {_d2 < 22}) then { _tur = "YAKLASIYOR"; } else {
                        if (!_ha && {!_hb}) then { _tur = "PARK"; };
                    };
                };
                if (_tur isNotEqualTo "") then { _isleme pushBack [_a, _b, _tur, _d2]; };
            };
        };
        {
            _x params ["_a", "_b", "_tur", "_d2"];
            // hareket edecek arac: park / ust uste -> SONRA duran (aralikDurT buyuk olan); yaklasma -> yavas olan
            private _tA = _a getVariable [QGVAR(aralikDurT), 0];
            private _tB = _b getVariable [QGVAR(aralikDurT), 0];
            if ((speed _a) < 3 && {_tA <= 0}) then { _a setVariable [QGVAR(aralikDurT), time]; _tA = time; };
            if ((speed _b) < 3 && {_tB <= 0}) then { _b setVariable [QGVAR(aralikDurT), time]; _tB = time; };
            if ((speed _a) > 3) then { _a setVariable [QGVAR(aralikDurT), 0]; };
            if ((speed _b) > 3) then { _b setVariable [QGVAR(aralikDurT), 0]; };
            private _mv = if (_tur isEqualTo "YAKLASIYOR") then { [_a, _b] select ((speed _b) < (speed _a)) } else { [_a, _b] select (_tB > _tA) };
            private _di = [_b, _a] select (_mv isEqualTo _b);
            if ((time - (_mv getVariable [QGVAR(aralikT), -99])) < 25) then { continue };
            _mv setVariable [QGVAR(aralikT), time];
            private _dr = driver _mv;
            private _g = group _dr;
            if (_tur isEqualTo "YAKLASIYOR") then {
                _say set [0, (_say select 0) + 1];
                doStop _dr;
                _dr forceSpeed 0;
                [{ params ["_dd"]; if (!isNull _dd) then { _dd forceSpeed -1; }; }, [_dr], 4] call CBA_fnc_waitAndExecute;
                diag_log format ["[TANK-ARALIK] YAKLASIYOR: %1 -> %2 (%3 m): %1 4 sn durduruldu (carpisma onlemi)", getText (configOf _mv >> "displayName"), getText (configOf _di >> "displayName"), round _d2];
            } else {
                private _uzak = (getPosATL _di) getDir (getPosATL _mv);
                private _hedef = (getPosATL _di) getPos [([40, 48] select (_tur isEqualTo "USTUSTE")), _uzak + ((random 30) - 15)];
                private _bos = _hedef findEmptyPosition [0, 25, typeOf _mv];
                if (_bos isNotEqualTo []) then { _hedef = _bos; };
                if (surfaceIsWater _hedef) then { _hedef = (getPosATL _mv) getPos [40, _uzak]; };
                if (_tur isEqualTo "USTUSTE") then {
                    _say set [2, (_say select 2) + 1];
                    // geri al + uzaklas
                    _mv setVelocityModelSpace [0, -3, 0];
                    [{ params ["_vv"]; if (alive _vv) then { _vv setVelocityModelSpace [0, -3, 0]; }; }, [_mv], 0.8] call CBA_fnc_waitAndExecute;
                    [{
                        params ["_vv", "_dd2", "_bb"];
                        // 10 sn sonra hala ic icesiyse en yakin bos konuma tasi
                        if (alive _vv && {alive _bb} && {(_vv distance2D _bb) < 11}) then {
                            private _p = (getPosATL _bb) vectorAdd [0, 0, 0];
                            private _kc = (getPosATL _bb) getDir (getPosATL _vv);
                            private _yeni = (getPosATL _bb) getPos [22, _kc];
                            _vv setVehiclePosition [_yeni, [], 6, "NONE"];
                            diag_log format ["[TANK-ARALIK] USTUSTE devam: %1 bos konuma TASINDI (%2)", getText (configOf _vv >> "displayName"), mapGridPosition _yeni];
                        };
                    }, [_mv, _dr, _di], 10] call CBA_fnc_waitAndExecute;
                } else { _say set [1, (_say select 1) + 1]; };
                (group _dr) setBehaviour "AWARE";
                _dr enableAI "PATH"; _dr enableAI "MOVE"; _dr forceSpeed -1;
                _dr doMove _hedef;
                // plan mevzi noktasi: lider aracsa guncelle (planZirh geri cekmesin)
                if ((_g getVariable ["lambs_danger_planZirhPoz", []]) isNotEqualTo [] && {vehicle (leader _g) isEqualTo _mv}) then { _g setVariable ["lambs_danger_planZirhPoz", _hedef]; };
                diag_log format ["[TANK-ARALIK] %1: %2 / %3 (%4 m) -> %2 %5 uzaklasiyor (%6)", _tur, getText (configOf _mv >> "displayName"), getText (configOf _di >> "displayName"), round _d2, mapGridPosition _hedef, ["kitap: dagilma (MCWP 3-11.1 arac araligi)", "ic ice / ust uste: geri al + uzaklas"] select (_tur isEqualTo "USTUSTE")];
            };
        } forEach _isleme;
        if (time > _ozetT) then {
            _ozetT = time + 90;
            if ((_say select 0) + (_say select 1) + (_say select 2) > 0) then {
                diag_log format ["[TANK-ARALIK-OZET] son 90 sn: yaklasma durdurma %1 | park araligi %2 | ust uste %3", _say select 0, _say select 1, _say select 2];
            };
            _say = [0, 0, 0, 0];
        };
    };
};

diag_log "[TANK-ARALIK] zirh araligi bekcisi baslatildi (v8.348): yaklasma durdurma, park araligi (< 26 m), ust uste kurtarma";
true

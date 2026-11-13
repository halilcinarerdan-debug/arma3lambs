#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ARAC GIT-GEL TESHISI (v8.525; kullanici: 'araclar hala kipraniyor gibi oluyor, yakininda engel varken').
 * Neden: son RPT'ler yalniz piyade senaryosu (arac olayi yok); hangi katmanin (motor yol bulma / aracUnstuck / ezmeKoruma / mekanizeIzle / aracSenkron / tankAralik / aracZirhKac ...) aracı ileri-geri salladigi bilinmiyor.
 * Bu bekci DAVRANIS DEGISTIRMEZ: yerel AI suruculu kara araclarinin ileri hizinin isaretini (velocityModelSpace Y, |v| >= 0.8 m/s) 0.5 sn'de bir izler; 20 sn icinde >= 3 yon degisimi (ileri <-> geri)
 * olursa bir kez (arac basina 40 sn'de bir) yazar: sinif, hiz, yon degisim sayisi, cevredeki engeller (agac / kaya / duvar / bina / cali, en yakin mesafe), surucu komutu (currentCommand), beklenen hedef
 * (expectedDestination: mod + mesafe), aracin ve surucu grubunun SON 5 sn'de dokunulmus / true olan lambs_danger_* degiskenleri (hangi ELITE katmani kilitlemis / emir vermis), aracUnstuck asama sayaci.
 * Log: [ARAC-GITGEL] (ilk 40) + [ARAC-GITGEL-OZET] 60 sn (sinif basina sayi). Kapatma: lambs_danger_aracGitGelOff = true.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_aracGitGelStarted") exitWith {false};
lambs_danger_aracGitGelStarted = true;
diag_log "[ARAC-GITGEL] arac ileri-geri salinim teshisi baslatildi (v8.525; davranis degistirmez): 20 sn'de >= 3 yon degisimi + engel / komut / ELITE degisken kaydi";

[] spawn {
    private _logN = 0;
    private _say = createHashMap;
    private _ozetT = time + 60;
    while {true} do {
        sleep 0.5;
        if (missionNamespace getVariable ["lambs_danger_aracGitGelOff", false]) then { continue };
        {
            private _v = _x;
            if (!local _v || {!alive _v} || {!(_v isKindOf "LandVehicle")} || {!isEngineOn _v}) then { continue };
            private _d = driver _v;
            if (isNull _d || {!alive _d} || {isPlayer _d} || {(crew _v) findIf {isPlayer _x} >= 0}) then { continue };
            private _vy = (velocityModelSpace _v) select 1;
            if ((abs _vy) < 0.8) then { continue };
            private _isaret = [-1, 1] select (_vy > 0);
            private _once = _v getVariable [QGVAR(ggIsaret), 0];
            if (_once isEqualTo 0) then { _v setVariable [QGVAR(ggIsaret), _isaret]; continue };
            if (_once isEqualTo _isaret) then { continue };
            _v setVariable [QGVAR(ggIsaret), _isaret];
            private _fl = (_v getVariable [QGVAR(ggFlips), []]) select {(time - _x) < 20};
            _fl pushBack time;
            _v setVariable [QGVAR(ggFlips), _fl];
            if ((count _fl) >= 3 && {time > (_v getVariable [QGVAR(ggLogT), 0])}) then {
                _v setVariable [QGVAR(ggLogT), time + 40];
                private _bb = boundingBoxReal _v;
                private _uz = abs (((_bb select 1) select 1) - ((_bb select 0) select 1));
                private _eng = nearestTerrainObjects [_v, ["TREE", "ROCK", "ROCKS", "WALL", "BUILDING", "HOUSE", "BUSH", "SMALL TREE"], (_uz / 2) + 6, false, true];
                private _engS = if (_eng isEqualTo []) then {"engel yok"} else { format ["%1 engel, en yakin %2 m (%3)", count _eng, round ((_v distance2D (_eng select 0)) * 10) / 10, (getModelInfo (_eng select 0)) select 0] };
                private _ed = expectedDestination _d;
                private _degs = [];
                {
                    private _src = _x;
                    {
                        if (((_x select [0, 12]) isEqualTo "lambs_danger_") && {count _degs < 8}) then {
                            private _val = _src getVariable [_x, nil];
                            if (!isNil "_val") then {
                                if (_val isEqualTo true || {_val isEqualType 0 && {_val > (time - 5)} && {_val < (time + 90)}}) then { _degs pushBack format ["%1=%2", _x select [12], _val]; };
                            };
                        };
                    } forEach (allVariables _src);
                } forEach [_v, group _d, _d];
                if (_logN < 40) then {
                    _logN = _logN + 1;
                    diag_log format ["[ARAC-GITGEL] %1 | grup %2 | hiz %3 km/s | 20 sn'de %4 yon degisimi | %5 | komut '%6' | hedef %7 m (%8) | aktif ELITE degiskenleri: %9", typeOf _v, groupId (group _d), round (speed _v), count _fl, _engS, currentCommand _d, if (_ed isEqualTo []) then {"-"} else {round (_v distance2D (_ed select 0))}, if (_ed isEqualTo []) then {"-"} else {_ed select 1}, if (_degs isEqualTo []) then {"yok (motor yol bulma)"} else {_degs joinString ", "}];
                };
                private _k = typeOf _v;
                _say set [_k, (_say getOrDefault [_k, 0]) + 1];
            };
        } forEach vehicles;
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if (count _say > 0) then { diag_log format ["[ARAC-GITGEL-OZET] 60 sn: %1", (_say toArray false) apply { format ["%1=%2", _x select 0, _x select 1] }]; };
            _say = createHashMap;
        };
    };
};
true

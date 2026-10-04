#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TEK KALANLAR DIGER SQUAD'A KATILIR (v8.67) — grupta <= 2 canli asker kalirsa en yakin dost squad'a katilir (joinSilent).
 *
 * Kural (kullanici istegi: "telsizleri varsa veya yakin mesafede ise"):
 *   - <= 150 m icinde uygun dost grup: dogrudan katilir
 *   - telsiz (ItemRadio / ACRE / TFAR "radio|prc|anprc") varsa ve hedef liderde de telsiz varsa <= 1500 m: hedefe dogru ilerler ([ZEKA-YETIM] YOLDA), <= 150 m ye gelince katilir; 120 sn icinde varamazsa vazgecer
 *   - hedef: ayni taraf, oyuncu icermeyen, >= 3 canli, katilimdan sonra <= 14 kisi, retreat / yer-degistirme disinda
 * AI hilesi yok: tum bilgi dost birimlerin gercek konumu / ekipmanidir (telsiz yoksa yalniz gorus mesafesi). Kapatma: lambs_danger_yetimOff = true.   Log: [ZEKA-YETIM]
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_yetimStarted") exitWith {false};
lambs_danger_yetimStarted = true;

diag_log "[ZEKA-YETIM] tek kalan katilim watchdog'u baslatildi (v8.67)";

private _calis = {
    missionNamespace setVariable ["lambs_danger_yetimAdim", "basladi"];
    private _logN = 0;
    private _telsizMi = {
        params ["_u"];
        private _oge = (assignedItems _u) + (items _u);
        (_oge findIf {private _k = toLower _x; (_k find "radio") >= 0 || {(_k find "prc") >= 0} || {_k find "tf_" == 0}}) > -1
    };
    while {true} do {
        sleep 10;
        if (missionNamespace getVariable ["lambs_danger_yetimOff", false]) then { continue };
        {
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {!local _g} || {!alive _l} || {isPlayer _l}) then { continue };
            private _canli = (units _g) select {alive _x};
            private _n = count _canli;
            if (_n < 1 || {_n > 2} || {(_canli findIf {isPlayer _x}) > -1}) then { continue };
            if ((_canli findIf {!isNull objectParent _x}) > -1) then { continue };
            if (time < (_g getVariable [QGVAR(yetimBekle), 0])) then { continue };
            missionNamespace setVariable ["lambs_danger_yetimAdim", format ["grup %1", groupId _g]];

            private _taraf = side _g;
            private _poz = getPosATL _l;
            private _telsizim = [_l] call _telsizMi;

            // mevcut yoldaki hedef
            private _hedefG = _g getVariable [QGVAR(yetimHedef), grpNull];
            private _hedefL = leader _hedefG;
            private _gecerli = (!isNull _hedefG) && {!isNull _hedefL} && {alive _hedefL} && {(count ((units _hedefG) select {alive _x})) >= 3};

            if (!_gecerli) then {
                _hedefG = grpNull;
                private _adaylar = [];
                {
                    private _ag = _x;
                    if (_ag isEqualTo _g || {side _ag isNotEqualTo _taraf}) then { continue };
                    private _al = leader _ag;
                    if (isNull _al || {!alive _al} || {isPlayer _al}) then { continue };
                    private _ac = (units _ag) select {alive _x};
                    if ((count _ac) < 3 || {(count _ac) + _n > 14} || {(_ac findIf {isPlayer _x}) > -1}) then { continue };
                    if (_ag getVariable [QGVAR(isRetreating), false] || {_ag getVariable [QGVAR(isSonDirenis), false]}) then { continue };
                    private _d = _poz distance2D (getPosATL _al);
                    private _yakin = _d <= 150;
                    private _radyo = _telsizim && {[_al] call _telsizMi} && {_d <= 1500};
                    if (_yakin || _radyo) then { _adaylar pushBack [_d, _ag, _yakin]; };
                } forEach (allGroups select {side _x isEqualTo _taraf});
                if (_adaylar isEqualTo []) then {
                    _g setVariable [QGVAR(yetimBekle), time + 20];
                    if ((_g getVariable [QGVAR(yetimLogT), 0]) + 90 < time && {_logN < 80}) then {
                        _g setVariable [QGVAR(yetimLogT), time];
                        _logN = _logN + 1;
                        diag_log format ["[ZEKA-YETIM] %1 | %2 kisi kaldi | uygun dost grup YOK (telsiz:%3)", groupId _g, _n, _telsizim];
                    };
                    continue;
                };
                _adaylar = [_adaylar, [], {_x select 0}] call BIS_fnc_sortBy;
                (_adaylar select 0) params ["_d0", "_g0", "_y0"];
                _hedefG = _g0;
                _g setVariable [QGVAR(yetimHedef), _hedefG];
                _g setVariable [QGVAR(yetimBasT), time];
                if (_logN < 80) then {
                    _logN = _logN + 1;
                    diag_log format ["[ZEKA-YETIM] %1 | %2 kisi kaldi -> %3'e katilacak | mesafe %4 m | %5 | aday %6", groupId _g, _n, groupId _hedefG, round _d0, ["TELSIZ", "YAKIN"] select _y0, count _adaylar];
                };
            };

            private _hl = leader _hedefG;
            private _dm = _poz distance2D (getPosATL _hl);
            if (_dm <= 150) then {
                { [_x] joinSilent _hedefG; } forEach _canli;
                if (_logN < 120) then {
                    _logN = _logN + 1;
                    diag_log format ["[ZEKA-YETIM] KATILDI | %1 kisi -> %2 | mesafe %3 m | yeni grup boyu %4", _n, groupId _hedefG, round _dm, count ((units _hedefG) select {alive _x})];
                };
                _g setVariable [QGVAR(yetimHedef), nil];
            } else {
                if ((time - (_g getVariable [QGVAR(yetimBasT), time])) > 120) then {
                    _g setVariable [QGVAR(yetimHedef), nil];
                    _g setVariable [QGVAR(yetimBekle), time + 60];
                    if (_logN < 120) then {
                        _logN = _logN + 1;
                        diag_log format ["[ZEKA-YETIM] %1 | 120 sn icinde varamadi (%2 m kaldi) -> vazgecti", groupId _g, round _dm];
                    };
                } else {
                    { _x doMove (getPosATL _hl); _x setSpeedMode "FULL"; } forEach _canli;
                    if ((_g getVariable [QGVAR(yetimLogT), 0]) + 30 < time && {_logN < 120}) then {
                        _g setVariable [QGVAR(yetimLogT), time];
                        _logN = _logN + 1;
                        diag_log format ["[ZEKA-YETIM] %1 | YOLDA -> %2 | %3 m kaldi", groupId _g, groupId _hedefG, round _dm];
                    };
                };
            };
        } forEach (allGroups select {local _x && {!isNull leader _x}});
        missionNamespace setVariable ["lambs_danger_yetimAdim", "tur bitti"];
    };
};

// bekci: betik hata ile olurse yeniden baslat
[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log format ["[WATCHDOG-YENIDEN] yetim katilim betigi sonlandi (hata?), son adim: %1", missionNamespace getVariable ["lambs_danger_yetimAdim", "?"]];
        sleep 5;
    };
};

true

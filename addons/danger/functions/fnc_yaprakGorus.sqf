#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * YAPRAK ARKASI GORUS KIRICI v1 (in-the-box) — AI cali / kucuk agac / uzun cimen ARKASINDAKI dusmani gormemeli.
 * (Kullanici ayri "cali arkasi gorus" modunu paketten cikardi; islev bu fork'a alindi.)
 *
 * YONTEM (gozlemci -> hedef):
 *   1) Her 1.5 sn'de en fazla yaprakCap (8, otomatik 3..12) yerel AI gozlemci; her biri icin en yakin 3 BILINEN dusman piyadesi (nearTargets, 20-350 m).
 *   2) Gozlemci gozunden hedef govdesine (stance'a gore 1.4 / 0.9 / 0.35 m) 8 m'de bir ornek; her ornekte 1.4 m icinde BUSH / SMALL TREE varsa
 *      VE isin o noktada yerden < 2.2 m ise o nesne SAYILIR (ayni nesne bir kez) -> kalinlik.
 *      Uzun cimen: hedef YATIK, yuzey sinifi "grass" icerir, mesafe > 40 m -> +1.
 *   3) GIZLI karari: kalinlik >= esik (AYAKTA 2, comelmis / yatik 1). GIZLI ise gozlemci hedefi UNUTUR (forgetTarget), motor yeniden gorene kadar.
 *      Atlanir (unutmaz): hedef son 4 sn'de ates ettiyse | gozlemci baski > 0.3 | mesafe < 25 m | ayni cift icin 4 sn bekleme suresi.
 *
 * DEBUG (sağlam):
 *   [YAPRAK-TANI]   acilistan 20 sn sonra: harita, 150 m'deki BUSH / SMALL TREE / TREE sayilari, yuzey sinifi (siniflar taninmiyorsa UYARI)
 *   [YAPRAK]        her UNUTMA karari (ilk 120, sonra her 10.): gozlemci -> hedef | mesafe | stance | kalinlik (nesne turleri) | cim | knowsAbout | neden
 *   [YAPRAK-TEST]   lambs_danger_yaprakTest = true iken HER degerlendirme (ilk 400): ornek sayisi, isabet, esik, karar
 *   [YAPRAK-OZET]   60 sn'de bir: kontrol / gizli / unuttu / bekleme / atlanan (ates, baski, yakin) / tick ort-max ms / cap
 *   [YAPRAK-PERF]   tick ortalamasi > 10 ms ise cap azalir (ve < 3 ms ise artar); satir olarak yazilir
 * Kapatma: lambs_danger_yaprakV1 = false. Esik ayari: lambs_danger_yaprakEsikAyakta (2), lambs_danger_yaprakEsikYatik (1).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_yaprakStarted") exitWith {false};
lambs_danger_yaprakStarted = true;

diag_log "[YAPRAK] yaprak arkasi gorus kirici baslatildi (BUSH / SMALL TREE / uzun cimen; forgetTarget)";

[] spawn {
    private _say = createHashMapFromArray [["kontrol", 0], ["gizli", 0], ["unuttu", 0], ["bekle", 0], ["ates", 0], ["baski", 0], ["yakin", 0]];
    private _cd = createHashMap;
    private _indeks = 0;
    private _cap = 8;
    private _msT = 0;
    private _msMax = 0;
    private _tickN = 0;
    private _sonOzet = time;
    private _logUnuttu = 0;
    private _logTest = 0;

    // --- acilis tanisi ---
    sleep 20;
    private _ilk = (allUnits select {alive _x && {local _x}}) param [0, objNull];
    if (!isNull _ilk) then {
        private _p = getPosATL _ilk;
        private _b = count (nearestTerrainObjects [_p, ["BUSH"], 150, false, true]);
        private _st = count (nearestTerrainObjects [_p, ["SMALL TREE"], 150, false, true]);
        private _tr = count (nearestTerrainObjects [_p, ["TREE"], 150, false, true]);
        diag_log format ["[YAPRAK-TANI] harita:%1 | 150 m: BUSH:%2 SMALL TREE:%3 TREE:%4 | yuzey:%5", worldName, _b, _st, _tr, surfaceType _p];
        if ((_b + _st) isEqualTo 0) then {
            diag_log "[YAPRAK-TANI] UYARI: bu bolgede BUSH / SMALL TREE yok (ya da harita farkli sinif adlari kullaniyor) -> kirici bu bolgede etkisiz kalir";
        };
    };

    while {true} do {
        sleep 1.5;
        if (!(missionNamespace getVariable ["lambs_danger_yaprakV1", true])) then { continue };
        private _test = missionNamespace getVariable ["lambs_danger_yaprakTest", false];
        private _esikA = missionNamespace getVariable ["lambs_danger_yaprakEsikAyakta", 2];
        private _esikY = missionNamespace getVariable ["lambs_danger_yaprakEsikYatik", 1];
        private _t0 = diag_tickTime;

        private _gozlemciler = [];
        {
            private _g = _x;
            if (isNull _g || {!local _g} || {(side _g) isEqualTo civilian}) then { continue };
            if ((units _g) findIf {isPlayer _x} > -1) then { continue };
            { if (alive _x && {local _x} && {isNull objectParent _x}) then { _gozlemciler pushBack _x; }; } forEach (units _g);
        } forEach allGroups;
        private _n = count _gozlemciler;
        if (_n > 0) then {
            private _kesit = _cap min _n;
            for "_i" from 0 to (_kesit - 1) do {
                private _o = _gozlemciler select ((_indeks + _i) mod _n);
                private _oSide = side _o;
                private _hedefler = (_o nearTargets 350) select {
                    private _h = _x select 4;
                    !isNull _h && {alive _h} && {_h isKindOf "CAManBase"} && {isNull objectParent _h}
                    && {((_oSide getFriend (_x select 2)) < 0.6)}
                    && {(_o distance2D _h) >= 20}
                };
                _hedefler = [_hedefler, [], {_o distance2D (_x select 4)}, "ASCEND"] call BIS_fnc_sortBy;
                _hedefler = _hedefler select [0, 3 min (count _hedefler)];

                {
                    private _h = _x select 4;
                    private _anahtar = (netId _o) + "|" + (netId _h);
                    if ((time - (_cd getOrDefault [_anahtar, -99])) < 4) then { _say set ["bekle", (_say get "bekle") + 1]; continue };

                    private _d = _o distance2D _h;
                    if (_d < 25) then { _say set ["yakin", (_say get "yakin") + 1]; continue };
                    if ((time - (_h getVariable [QGVAR(sonAtisT), -99])) < 4) then { _say set ["ates", (_say get "ates") + 1]; continue };
                    if ((getSuppression _o) > 0.3) then { _say set ["baski", (_say get "baski") + 1]; continue };

                    _say set ["kontrol", (_say get "kontrol") + 1];
                    private _st = stance _h;
                    private _yuk = [1.4, 0.9, 0.35] select ((["STAND", "CROUCH", "PRONE"] find _st) max 0);
                    private _oASL = eyePos _o;
                    private _tASL = (getPosASL _h) vectorAdd [0, 0, _yuk];
                    private _ornek = ((ceil (_d / 8)) min 40) max 2;
                    private _gorulen = [];
                    private _tipler = [];
                    for "_s" from 1 to (_ornek - 1) do {
                        private _pASL = _oASL vectorAdd ((_tASL vectorDiff _oASL) vectorMultiply (_s / _ornek));
                        private _pAGL = ASLToAGL _pASL;
                        if (((_pASL select 2) - (getTerrainHeightASL _pAGL)) < 2.2) then {
                            {
                                if (!(_x in _gorulen)) then {
                                    _gorulen pushBack _x;
                                    _tipler pushBackUnique ((str _x) select [0, 14]);
                                };
                            } forEach (nearestTerrainObjects [_pAGL, ["BUSH", "SMALL TREE"], 1.4, false, true]);
                        };
                    };
                    private _kalin = count _gorulen;
                    private _cim = false;
                    if (_st isEqualTo "PRONE" && {_d > 40} && {((toLower (surfaceType (getPosATL _h))) find "grass") >= 0}) then {
                        _cim = true;
                        _kalin = _kalin + 1;
                    };
                    private _esik = [_esikA, _esikY] select (_st in ["PRONE", "CROUCH"]);
                    private _gizli = _kalin >= _esik;

                    if (_test && {_logTest < 400}) then {
                        _logTest = _logTest + 1;
                        diag_log format ["[YAPRAK-TEST] %1 -> %2 | d:%3 | %4 | ornek:%5 | kalinlik:%6 (cim:%7) esik:%8 | gizli:%9", name _o, name _h, round _d, _st, _ornek, _kalin, _cim, _esik, _gizli];
                    };

                    if (_gizli) then {
                        _say set ["gizli", (_say get "gizli") + 1];
                        private _bilgi = _o knowsAbout _h;
                        _o forgetTarget _h;
                        _cd set [_anahtar, time];
                        _say set ["unuttu", (_say get "unuttu") + 1];
                        _logUnuttu = _logUnuttu + 1;
                        if (_logUnuttu <= 120 || {(_logUnuttu mod 10) isEqualTo 0}) then {
                            diag_log format ["[YAPRAK] %1 -> %2 | d:%3 m | %4 | kalinlik:%5 %6 | cim:%7 | knows:%8 | UNUTTU (#%9)", name _o, name _h, round _d, _st, _kalin, _tipler select [0, 3 min (count _tipler)], _cim, _bilgi toFixed 2, _logUnuttu];
                        };
                    };
                } forEach _hedefler;
            };
            _indeks = _indeks + _kesit;
        };

        // --- sure olcumu + adaptif cap ---
        private _ms = (diag_tickTime - _t0) * 1000;
        _msT = _msT + _ms;
        _msMax = _msMax max _ms;
        _tickN = _tickN + 1;

        if ((time - _sonOzet) >= 60) then {
            private _ort = _msT / (_tickN max 1);
            diag_log format [
                "[YAPRAK-OZET] kontrol:%1 gizli:%2 unuttu:%3 | atlanan: bekle:%4 ates:%5 baski:%6 yakin:%7 | tick ort:%8 ms max:%9 ms | cap:%10 | gozlemci:%11",
                _say get "kontrol", _say get "gizli", _say get "unuttu", _say get "bekle", _say get "ates", _say get "baski", _say get "yakin",
                _ort toFixed 1, _msMax toFixed 1, _cap, _n
            ];
            if (_ort > 10 && {_cap > 3}) then {
                _cap = _cap - 1;
                diag_log format ["[YAPRAK-PERF] tick ort %1 ms > 10 -> cap %2", _ort toFixed 1, _cap];
            };
            if (_ort < 3 && {_cap < 12} && {_n > _cap}) then {
                _cap = _cap + 1;
                diag_log format ["[YAPRAK-PERF] tick ort %1 ms < 3 -> cap %2", _ort toFixed 1, _cap];
            };
            { _say set [_x, 0]; } forEach (keys _say);
            _msT = 0; _msMax = 0; _tickN = 0; _sonOzet = time;
        };
    };
};

true

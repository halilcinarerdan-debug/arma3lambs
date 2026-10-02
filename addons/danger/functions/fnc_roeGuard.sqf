#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ROE KORUMASI (SIVIL / DOST / TESLIM) — AI'nin SIVILLERE ya da dostlara ates etmesini ONLER + TESPIT EDER (kullanici: "askerler sivillere de ates ediyor").
 *
 * Her 1.5 sn'de en fazla 30 yerel, oyuncusuz AI askeri (donusumlu): getAttackTarget (su an saldirdigi hedef) kontrol edilir.
 *   IHLAL = hedef  sivil taraf  |  askerin tarafi hedefin tarafiyla DOST (getFriend >= 0.6)  |  hedef captive (teslim olmus / esir)
 *   MESRU MUDAFAA (ihlal sayilmaz): hedef son 6 sn'de ates ettiyse (firedHub sonAtisT) ya da hedef silahli ve askere 25 m'den yakin + silahi cevirmis (ates etmis sayilir).
 *   Ihlalde: forgetTarget (birim + grup) + doWatch objNull; log [ROE-IHLAL] (ilk 60): asker / hedef / taraf iliskisi / mesafe / gorev / hedef silahli mi.
 *   [ROE-OZET] 60 sn: kontrol / ihlal / siviller (oturumda).
 * NOT: Sivil ZARAR kaynagi bazen dolayli ates (bastirma / el bombasi / UGL / roket) olabilir; bu watcher yalniz DOGRUDAN hedef secimini yakalar. Sivil olusunca
 *   lambs_danger_roeGuardV1 = false ile kapatilabilir.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_roeGuardStarted") exitWith {false};
lambs_danger_roeGuardStarted = true;

diag_log "[ROE] sivil / dost / esir koruma izleyicisi baslatildi (getAttackTarget -> forgetTarget)";

[] spawn {
    private _indeks = 0;
    private _kontrol = 0;
    private _ihlal = 0;
    private _sivil = 0;
    private _logN = 0;
    private _sonOzet = time;
    while {true} do {
        sleep 1.5;
        if (!(missionNamespace getVariable ["lambs_danger_roeGuardV1", true])) then { continue };
        private _askerler = [];
        {
            private _g = _x;
            if (isNull _g || {!local _g} || {(side _g) isEqualTo civilian}) then { continue };
            if ((units _g) findIf {isPlayer _x} > -1) then { continue };
            { if (alive _x && {local _x} && {isNull objectParent _x}) then { _askerler pushBack _x; }; } forEach (units _g);
        } forEach allGroups;
        private _n = count _askerler;
        if (_n > 0) then {
            private _kesit = 30 min _n;
            for "_i" from 0 to (_kesit - 1) do {
                private _u = _askerler select ((_indeks + _i) mod _n);
                private _t = getAttackTarget _u;
                if (isNull _t || {!alive _t}) then { continue };
                _kontrol = _kontrol + 1;
                private _tSide = side group _t;
                private _fr = (side group _u) getFriend _tSide;
                private _sivilMi = (_tSide isEqualTo civilian) || {captive _t};
                private _dostMu = _fr >= 0.6;
                if (!(_sivilMi || _dostMu)) then { continue };
                // mesru mudafaa: hedef son 6 sn'de ates etti
                if ((time - (_t getVariable [QGVAR(sonAtisT), -99])) < 6) then { continue };
                _ihlal = _ihlal + 1;
                if (_tSide isEqualTo civilian) then { _sivil = _sivil + 1; };
                _u forgetTarget _t;
                (group _u) forgetTarget _t;
                _u doWatch objNull;
                if (_logN < 60) then {
                    _logN = _logN + 1;
                    diag_log format ["[ROE-IHLAL] %1 (%2) -> %3 (%4) | iliski:%5 | captive:%6 | mesafe:%7 m | silahli:%8 | gorev:%9 | beh:%10 -> hedef UNUTTURULDU", name _u, side group _u, name _t, _tSide, _fr toFixed 1, captive _t, round (_u distance2D _t), (weapons _t) isNotEqualTo [], _u getVariable [QEGVAR(main,currentTask), "-"], behaviour _u];
                };
            };
            _indeks = _indeks + _kesit;
        };
        if ((time - _sonOzet) >= 60) then {
            _sonOzet = time;
            if (_ihlal > 0 || {_kontrol > 0}) then { diag_log format ["[ROE-OZET] 60 sn: kontrol:%1 ihlal:%2 (sivil hedef:%3)", _kontrol, _ihlal, _sivil]; };
            _kontrol = 0; _ihlal = 0; _sivil = 0;
        };
    };
};

true

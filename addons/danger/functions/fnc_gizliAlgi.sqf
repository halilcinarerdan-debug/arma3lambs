#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * GIZLI ALGI (v8.75) — oyuncunun gizlice yaklasmasi: AYAK / HAREKET SESI + ISIK KAYNAKLARI (el feneri, IR lazer).
 * Hile yok: bot yalnizca fiziksel olarak duyabilecegi / gorebilecegi seyi algilar; sonuc kesin konum degil, mesafeyle azalan bilgi (reveal) + yaklasik yon (doWatch + hata payi).
 * Oyuncuya karsi (dusman taraf botlar; oyuncu yerel degil de olsa speed / stance / isik durumu globaldir).  Tum rakamlar TASARIM tahmini, doktrin / olcum degil.
 *
 * 1) AYAK SESI (yaya oyuncu; 1 sn'de bir): yaricap r = 1.6 x hiz(km/s) x durus x yuzey, en fazla 45 m
 *      durus: ayakta 1.0 | comelmis 0.6 | yatik (surunme) 0.25     yuzey: yol / beton / kaya 1.3, digeri 1.0     durmus (< 1.5 km/s) = ses yok
 *      ornek: yurume 5 km/s ~ 8 m | kosu 12 km/s ~ 19 m | sprint 20 km/s ~ 32 m | comelmis yurume 3 km/s ~ 3 m
 *    botun duyma katsayisi: CARELESS 0.5 | SAFE 0.8 | AWARE 1.0 | COMBAT 1.1 | STEALTH 1.2;  maskeleme: yagmur > 0.4 x0.8, ruzgar > 6 m/s x0.8, botun grubu temasta x0.7
 *    r icindeyse: bilgi seviyesi 0.5 + 0.5 x (1 - d / r) (reveal), bot yaklasik yone (hata payi d x 0.25 + 4 m) bakar; ayni bot-oyuncu cifti icin 4 sn bekleme.
 * 2) ISIK (gece / karanlik ya da bina ici, hat gorusu sart):
 *      EL FENERI acik: isik huzmesi (20 derece koni) icindeki botlar <= 250 m (seviye 1.3); huzme disi sacilan isik <= 50 m (seviye 0.9)
 *      IR LAZER acik: yalniz NVG takan botlar (hmd bos degil), 12 derece koni <= 500 m (seviye 1.2)
 *    ayni bot icin 5 sn bekleme.  (Gunduz fener / IR botu etkilemez.)
 * Komutlar (isFlashlightOn / isIRLaserOn) surum farki icin compile ile denenir; calismazsa isik kismi kapanir ve RPT'ye yazilir ([GIZLI] KOMUT YOK).
 * Kapatma: lambs_danger_gizliAlgiOff = true; ayri: lambs_danger_adimSesOff / lambs_danger_isikAlgiOff.   Log: [ADIM-SES] / [ISIK-ALGI] (ilk 100) + [GIZLI-OZET] 90 sn
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_gizliStarted") exitWith {false};
lambs_danger_gizliStarted = true;

diag_log "[GIZLI] gizli algi (ayak sesi + isik) watchdog'u baslatildi (v8.75)";

private _calis = {
    missionNamespace setVariable ["lambs_danger_gizliAdim", "basladi"];
    private _fener = compile "params ['_u']; (_u isFlashlightOn (primaryWeapon _u)) || {_u isFlashlightOn (handgunWeapon _u)}";
    private _irLazer = compile "params ['_u']; (_u isIRLaserOn (primaryWeapon _u)) || {_u isIRLaserOn (handgunWeapon _u)}";
    // komut denemesi (sozdizimi / surum): nil donerse kullanilamaz
    private _p0 = objNull;
    private _komutOk = false;
    waitUntil { sleep 2; ((allPlayers select {!(_x isKindOf "HeadlessClient_F")}) isNotEqualTo []) };
    _p0 = (allPlayers select {!(_x isKindOf "HeadlessClient_F")}) select 0;
    private _t1 = [_p0] call _fener;
    private _t2 = [_p0] call _irLazer;
    _komutOk = !isNil "_t1" && {!isNil "_t2"};
    diag_log format ["[GIZLI] komut denemesi | fener:%1 irlazer:%2 -> isik algisi:%3", _t1, _t2, _komutOk];
    if (!_komutOk) then { diag_log "[GIZLI] KOMUT YOK (isFlashlightOn / isIRLaserOn kullanilamiyor): isik algisi kapali, yalniz ayak sesi calisir"; };

    private _logN = 0;
    private _say = createHashMap;
    private _ozetT = time + 90;
    private _hizTablo = [["road", 1.3], ["conc", 1.3], ["asph", 1.3], ["rock", 1.3], ["stone", 1.3]];
    while {true} do {
        sleep 1;
        if (missionNamespace getVariable ["lambs_danger_gizliAlgiOff", false]) then { continue };
        private _adimAcik = !(missionNamespace getVariable ["lambs_danger_adimSesOff", false]);
        private _isikAcik = _komutOk && {!(missionNamespace getVariable ["lambs_danger_isikAlgiOff", false])};
        private _oyuncular = allPlayers select {alive _x && {!(_x isKindOf "HeadlessClient_F")} && {(lifeState _x) in ["HEALTHY", "INJURED"]}};
        if (_oyuncular isEqualTo []) then { continue };
        private _yagmur = rain;
        private _ruzgar = vectorMagnitude wind;
        private _karanlik = sunOrMoon < 0.4;
        private _tepki = 0;

        {
            private _p = _x;
            missionNamespace setVariable ["lambs_danger_gizliAdim", format ["oyuncu %1", name _p]];
            private _pPos = getPosATL _p;
            private _pEye = eyePos _p;
            private _pSide = side (group _p);

            // ---- 1) ayak sesi ----
            private _r = 0;
            if (_adimAcik && {isNull objectParent _p}) then {
                private _spd = speed _p;
                if (_spd >= 1.5) then {
                    private _durus = switch (stance _p) do { case "CROUCH": {0.6}; case "PRONE": {0.25}; default {1.0}; };
                    private _yuzey = toLower (surfaceType _pPos);
                    private _yk = 1;
                    { if ((_yuzey find (_x select 0)) >= 0) exitWith { _yk = _x select 1; }; } forEach _hizTablo;
                    _r = ((1.6 * _spd * _durus * _yk) min 45);
                };
            };
            private _adimTara = _r > 1;
            private _fenerAcik = _isikAcik && {(_karanlik || {(insideBuilding _p) > 0.5})} && {[_p] call _fener};
            private _irAcik = _isikAcik && {_karanlik} && {[_p] call _irLazer};
            if (!_adimTara && {!_fenerAcik} && {!_irAcik}) then { continue };

            private _tara = if (_fenerAcik) then { 250 } else { [_r, 500] select (_irAcik) };
            private _bakisYon = getDir _p;
            {
                private _b = _x;
                if (_tepki >= 12) exitWith {};
                if (!local _b || {isPlayer _b} || {!alive _b} || {!isNull objectParent _b}) then { continue };
                if (((side _b) getFriend _pSide) >= 0.6 || {(side _b) isEqualTo civilian}) then { continue };
                if ((lifeState _b) in ["INCAPACITATED", "UNCONSCIOUS"] || {_b getVariable ["ACE_isUnconscious", false]}) then { continue };
                private _bPos = getPosATL _b;
                private _d = _pPos distance _bPos;
                if (_d > _tara) then { continue };
                private _gk = format ["gizliT_%1", netId _p];
                private _isikK = format ["gizliI_%1", netId _p];

                private _seviye = 0;
                private _tur = "";
                private _tag = "";
                // isik
                if (_fenerAcik || _irAcik) then {
                    if ((time - (_b getVariable [_isikK, -999])) >= 5) then {
                        private _aci = abs ((((_pPos getDir _bPos) - _bakisYon) + 540) mod 360 - 180);
                        if (_fenerAcik) then {
                            if (_aci <= 20 && {_d <= 250}) then { _seviye = 1.3; _tur = "FENER (huzme)"; _tag = "ISIK"; } else { if (_d <= 50) then { _seviye = 0.9; _tur = "FENER (sacilan isik)"; _tag = "ISIK"; }; };
                        };
                        if (_seviye == 0 && {_irAcik} && {(hmd _b) isNotEqualTo ""} && {_aci <= 12} && {_d <= 500}) then { _seviye = 1.2; _tur = "IR LAZER (NVG)"; _tag = "ISIK"; };
                        if (_seviye > 0 && {lineIntersects [_pEye, eyePos _b, _p, _b]}) then { _seviye = 0; };   // engel (duvar / arazi) varsa isik gorulmez
                        if (_seviye > 0) then { _b setVariable [_isikK, time]; };
                    };
                };
                // ayak sesi
                if (_seviye == 0 && {_adimTara} && {_d <= _r} && {(time - (_b getVariable [_gk, -999])) >= 4}) then {
                    private _bk = switch (behaviour _b) do { case "CARELESS": {0.5}; case "SAFE": {0.8}; case "COMBAT": {1.1}; case "STEALTH": {1.2}; default {1.0}; };
                    private _mask = 1;
                    if (_yagmur > 0.4) then { _mask = _mask * 0.8; };
                    if (_ruzgar > 6) then { _mask = _mask * 0.8; };
                    if (((group _b) getVariable [QGVAR(contact), 0]) > time) then { _mask = _mask * 0.7; };
                    private _rEfekt = _r * _bk * _mask;
                    if (_d <= _rEfekt) then {
                        _seviye = 0.5 + (0.5 * (1 - (_d / (_rEfekt max 1))));
                        _tur = format ["AYAK SESI (r %1 m)", round _rEfekt]; _tag = "AYAK";
                        _b setVariable [_gk, time];
                    };
                };
                if (_seviye <= 0) then { continue };

                (group _b) reveal [_p, _seviye];
                private _hata = (_d * 0.25) + 4;
                _b doWatch (_pPos getPos [random _hata, random 360]);
                _tepki = _tepki + 1;
                _say set [_tag, (_say getOrDefault [_tag, 0]) + 1];
                if (_logN < 100) then {
                    _logN = _logN + 1;
                    diag_log format ["[%1] %2 | bot %3 (%4) | %5 m | seviye %6 | durum: hiz %7 km/s durus %8 | karanlik:%9", ["ADIM-SES", "ISIK-ALGI"] select (_tag isEqualTo "ISIK"), _tur, name _b, groupId (group _b), round _d, _seviye toFixed 2, round (speed _p), stance _p, _karanlik];
                };
            } forEach (allUnits select {(_x distance2D _p) <= _tara && {(side _x) isNotEqualTo _pSide}});
        } forEach _oyuncular;

        if (time > _ozetT) then {
            _ozetT = time + 90;
            if (count _say > 0) then { diag_log format ["[GIZLI-OZET] son 90 sn tepki: %1", (keys _say) apply {format ["%1:%2", _x, _say get _x]}]; };
            _say = createHashMap;
        };
        missionNamespace setVariable ["lambs_danger_gizliAdim", "tur bitti"];
    };
};

// bekci: betik hata ile olurse yeniden baslat
[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log format ["[WATCHDOG-YENIDEN] gizli algi betigi sonlandi (hata?), son adim: %1", missionNamespace getVariable ["lambs_danger_gizliAdim", "?"]];
        sleep 5;
    };
};

true

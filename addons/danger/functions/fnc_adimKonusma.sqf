#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * AYAK SESI + KONUSMA FARKINDALIGI (v8.535; kullanici: 'foot step farkindaligi ekle, kendi arkadaslari etki etmesin, burada hile yapabilirsin; botlarin ve oyuncularin konusmasi surdurulurse,
 * stealth modda degilse squad konusma sesleri konusma suresince kisitli mesafede dusmana bilgi versin').
 * Mevcut fnc_gizliAlgi yalniz INSAN OYUNCUNUN ayak sesini isler; bu izleyici ona EK olarak iki sey yapar. 'Hile' serbest: kaynagin GERCEK konumu kullanilir (yalniz yon hata payi eklenir).
 *
 * 1) BOT AYAK SESI [CBA botAdim]: oyuncu OLMAYAN yaya askerler (bot) icin ayni formul (gizliAlgi): yaricap r = 1.6 x hiz(km/s) x durus (ayakta 1.0 / comel 0.6 / yatik 0.25) x yuzey (yol / beton / kaya 1.3), en cok 45 m.
 *    Dinleyici: yerel, DUSMAN taraf (getFriend < 0.6; DOST / sivil etkilenmez), canli, bilincli, yaya. Katsayilar: dinleyicinin davranisi CARELESS 0.5 / SAFE 0.8 / AWARE 1.0 / COMBAT 1.1 / STEALTH 1.2;
 *    yagmur > 0.4 x0.8, ruzgar > 6 m/s x0.8, dinleyici grubu temasta x0.7. r icinde bilgi (reveal) 0.45 + 0.45 x (1 - d / r) + yaklasik yon (doWatch, hata d x 0.25 + 4 m). Dinleyici basina 3 sn'de bir.
 * 2) KONUSMA [CBA konusmaAlgi, konusmaM (60 m)]: bir birim KONUSURKEN (bot: LAMBS callout'u 2.2 sn / oyuncu: ses (VON) konusmasi) ve davranisi STEALTH DEGILSE, <= konusmaM mesafedeki DUSMAN
 *    askerler konusmanin SURESI BOYUNCA konusanin konumunu duyar: bilgi 0.4 + 0.5 x (1 - d / M) (en cok 0.9), yaklasik yon (hata d x 0.15 + 3 m); duvar / bina araya girerse etkin mesafe x1.8. Dinleyici basina 1.5 sn'de bir.
 *    OYUNCU KONUSMA ALGISI: bu makinedeki yerel oyuncu icin once ACRE2 (ACRE_LOCAL_SPEAKING; ACRE2 kaynagindan: localStartSpeaking / localStopSpeaking), sonra TFAR (TFAR_fnc_isSpeaking), sonra vanilla getPlayerChannel
 *    (>= 0 = bir kanalda KONUSUYOR; surume bagli, test edilmeli) kullanilir. ACRE2'de konusma SES SEVIYESI menzili olcekler: ses egrisi katsayisi linearConversion [0,1,seviye,0.1,1.3] / 0.7 (fisilti kisa, bagirma uzun; telsizde seviye -0.25);
 *    sonuc lambs_danger_konusmaBit (serverTime bitis) olarak HERKESE yayilir. Baska bir mod / betik ayni degiskeni setVariable ile verebilir: unit setVariable ["lambs_danger_konusmaBit", serverTime + 2, true].
 *    Acilista [KONUSMA] komut denemesi satiri hangi yolun kullanildigini yazar.
 * Kapatma: CBA botAdim / konusmaAlgi.  Log: [ADIM-BOT] / [KONUSMA] (ilk 30 + 60 sn ozeti [ADIM-KONUSMA-OZET]).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_adimKonusmaStarted") exitWith {false};
lambs_danger_adimKonusmaStarted = true;
diag_log "[ADIM-KONUSMA] bot ayak sesi + konusma farkindaligi baslatildi (v8.535): dost etkilenmez; konusma (STEALTH degilse) kisitli mesafede dusmana bilgi verir";

// ---- oyuncu konusma algilama (yalniz bu makinenin yerel oyuncusu) ----
if (hasInterface) then {
    [] spawn {
        waitUntil { sleep 1; !isNull player };
        // ACRE2 (ACRE_LOCAL_SPEAKING: ACRE2 localStartSpeaking / localStopSpeaking ile true / false; konusma sesi ister dogrudan ister telsizde), sonra TFAR, sonra vanilla getPlayerChannel
        private _acre = !isNil "ACRE_LOCAL_SPEAKING";
        private _tfar = !isNil "TFAR_fnc_isSpeaking";
        private _degerler = [];
        for "_i" from 0 to 2 do { _degerler pushBack (getPlayerChannel player); sleep 0.2; };
        diag_log format ["[KONUSMA] komut denemesi | ACRE2:%1 (ACRE_LOCAL_SPEAKING) | TFAR:%2 | getPlayerChannel (konusmuyorken) = %3 | kullanilan yol: %4", _acre, _tfar, _degerler, ["vanilla getPlayerChannel (>= 0 = konusuyor; surume bagli, DOGRULANMADI)", ["TFAR_fnc_isSpeaking", "ACRE2 ACRE_LOCAL_SPEAKING"] select _acre] select (_tfar || _acre)];
        private _ilkLog = true;
        while {true} do {
            sleep 0.4;
            if !(missionNamespace getVariable ["lambs_danger_konusmaAlgi", true]) then { continue };
            private _konusuyor = false;
            private _carpan = 1;
            if (_acre) then {
                _konusuyor = (missionNamespace getVariable ["ACRE_LOCAL_SPEAKING", false]) isEqualTo true;
                if (_konusuyor) then {
                    // ACRE2 ses egrisi: menzil katsayisi = linearConversion [0, 1, seviye, 0.1, 1.3] (varsayilan seviye 0.5 -> 0.7); telsizde konusurken ACRE seviyeyi 0.25 dusurur
                    private _sv = (missionNamespace getVariable ["acre_sys_gui_volumeLevel", 0.5]) - ([0, 0.25] select ((missionNamespace getVariable ["ACRE_LOCAL_BROADCASTING", false]) isEqualTo true));
                    _carpan = (((linearConversion [0, 1, _sv, 0.1, 1.3, true]) / 0.7) max 0.15) min 1.9;
                };
            } else {
                if (_tfar) then { _konusuyor = [player] call TFAR_fnc_isSpeaking; } else { _konusuyor = (getPlayerChannel player) >= 0; };
            };
            if (_konusuyor isEqualTo true) then {
                player setVariable ["lambs_danger_konusmaCarpan", _carpan, true];
                player setVariable ["lambs_danger_konusmaBit", serverTime + 0.9, true];
                if (_ilkLog) then { _ilkLog = false; diag_log format ["[KONUSMA] yerel oyuncu KONUSUYOR algilandi (%1): konusma bilgisi dusmana aktariliyor | ses menzil carpani %2", ["vanilla / TFAR", "ACRE2"] select _acre, _carpan toFixed 2]; };
            };
        };
    };
};

[] spawn {
    private _logN = 0;
    private _say = createHashMapFromArray [["adim", 0], ["konusma", 0]];
    private _ozetT = time + 60;
    private _hizTablo = [["road", 1.3], ["conc", 1.3], ["asph", 1.3], ["rock", 1.3], ["stone", 1.3]];
    private _davK = createHashMapFromArray [["CARELESS", 0.5], ["SAFE", 0.8], ["AWARE", 1], ["COMBAT", 1.1], ["STEALTH", 1.2]];
    while {true} do {
        sleep 0.5;
        private _adimAcik = missionNamespace getVariable ["lambs_danger_botAdim", true];
        private _konAcik = missionNamespace getVariable ["lambs_danger_konusmaAlgi", true];
        if (!_adimAcik && {!_konAcik}) then { continue };
        private _yagmur = rain;
        private _ruzgar = vectorMagnitude wind;
        private _konM = missionNamespace getVariable ["lambs_danger_konusmaM", 60];
        private _tepki = 0;

        // ---------- 2) KONUSMA ----------
        if (_konAcik) then {
            {
                private _s = _x;
                if ((behaviour _s) isEqualTo "STEALTH" || {!alive _s} || {(lifeState _s) in ["INCAPACITATED", "UNCONSCIOUS"]}) then { continue };
                private _sSide = side group _s;
                if (_sSide isEqualTo civilian) then { continue };
                private _sPos = getPosATL _s;
                private _sEye = eyePos _s;
                private _konMs = _konM * ((_s getVariable ["lambs_danger_konusmaCarpan", 1]) max 0.15 min 1.9);   // ACRE2 ses seviyesi (fisilti / normal / bagirma) menzili olcekler
                {
                    private _b = _x;
                    if (_tepki >= 24) exitWith {};
                    if (!local _b || {isPlayer _b} || {!alive _b} || {_b isEqualTo _s} || {!isNull objectParent _b}) then { continue };
                    private _bSide = side group _b;
                    if (_bSide isEqualTo civilian || {(_bSide getFriend _sSide) >= 0.6}) then { continue };
                    if ((lifeState _b) in ["INCAPACITATED", "UNCONSCIOUS"] || {_b getVariable ["ACE_isUnconscious", false]}) then { continue };
                    if (time < (_b getVariable [QGVAR(konT), 0])) then { continue };
                    private _d = _sPos distance (getPosATL _b);
                    private _dEtkin = _d * ([1, 1.8] select (lineIntersects [_sEye, eyePos _b, _s, _b]));
                    if (_dEtkin > _konMs) then { continue };
                    _b setVariable [QGVAR(konT), time + 1.5];
                    private _lvl = (0.4 + (0.5 * (1 - (_dEtkin / (_konMs max 1))))) min 0.9;
                    if (_lvl > (_b knowsAbout _s)) then { _b reveal [_s, _lvl]; };
                    private _g = group _b;
                    if (((_g getVariable [QGVAR(contact), 0]) < time) && {isNull (assignedTarget _b)}) then {
                        _b doWatch (_sPos getPos [random ((_d * 0.15) + 3), random 360]);
                        [{ params ["_c"]; if (alive _c) then { _c doWatch objNull; }; }, [_b], 5] call CBA_fnc_waitAndExecute;
                        if (_lvl >= 0.6 && {(behaviour _b) in ["SAFE", "CARELESS"]}) then { _g setBehaviour "AWARE"; };
                    };
                    _tepki = _tepki + 1;
                    _say set ["konusma", (_say get "konusma") + 1];
                    if (_logN < 30) then {
                        _logN = _logN + 1;
                        diag_log format ["[KONUSMA] %1 -> %2 | %3 m (etkin %4) | konusma duyuldu | bilgi %5 | konusan %6", name _s, groupId _g, round _d, round _dEtkin, _lvl toFixed 2, ["bot", "OYUNCU"] select (isPlayer _s)];
                    };
                } forEach (_sPos nearEntities ["CAManBase", _konMs * 1.8]);
            } forEach (allUnits select {(_x getVariable ["lambs_danger_konusmaBit", 0]) > serverTime});
        };

        // ---------- 1) BOT AYAK SESI ----------
        if (_adimAcik) then {
            private _kaynaklar = allUnits select {
                alive _x && {!isPlayer _x} && {isNull objectParent _x} && {(speed _x) >= 1.5} && {(side group _x) isNotEqualTo civilian} && {!captive _x}
                && {(lifeState _x) in ["HEALTHY", "INJURED"]}
            };
            private _n = 0;
            {
                private _s = _x;
                if (_n >= 30) exitWith {};
                private _spd = speed _s;
                private _durus = switch (stance _s) do { case "CROUCH": {0.6}; case "PRONE": {0.25}; default {1.0}; };
                private _sPos = getPosATL _s;
                private _yuzey = toLower (surfaceType _sPos);
                private _yk = 1;
                { if ((_yuzey find (_x select 0)) >= 0) exitWith { _yk = _x select 1; }; } forEach _hizTablo;
                private _r = (1.6 * _spd * _durus * _yk) min 45;
                if (_r <= 1) then { continue };
                _n = _n + 1;
                private _sSide = side group _s;
                {
                    private _b = _x;
                    if (_tepki >= 24) exitWith {};
                    if (!local _b || {isPlayer _b} || {!alive _b} || {_b isEqualTo _s} || {!isNull objectParent _b}) then { continue };
                    private _bSide = side group _b;
                    if (_bSide isEqualTo civilian || {(_bSide getFriend _sSide) >= 0.6}) then { continue };
                    if ((lifeState _b) in ["INCAPACITATED", "UNCONSCIOUS"] || {_b getVariable ["ACE_isUnconscious", false]}) then { continue };
                    if (time < (_b getVariable [QGVAR(adimT), 0])) then { continue };
                    private _g = group _b;
                    private _k = (_davK getOrDefault [behaviour _b, 1]) * ([1, 0.8] select (_yagmur > 0.4)) * ([1, 0.8] select (_ruzgar > 6)) * ([1, 0.7] select ((_g getVariable [QGVAR(contact), 0]) > time));
                    private _rEtkin = _r * _k;
                    private _d = _sPos distance (getPosATL _b);
                    if (_d > _rEtkin) then { continue };
                    _b setVariable [QGVAR(adimT), time + 3];
                    private _lvl = (0.45 + (0.45 * (1 - (_d / (_rEtkin max 1))))) min 0.9;
                    if (_lvl > (_b knowsAbout _s)) then { _b reveal [_s, _lvl]; };
                    if (((_g getVariable [QGVAR(contact), 0]) < time) && {isNull (assignedTarget _b)}) then {
                        _b doWatch (_sPos getPos [random ((_d * 0.25) + 4), random 360]);
                        [{ params ["_c"]; if (alive _c) then { _c doWatch objNull; }; }, [_b], 5] call CBA_fnc_waitAndExecute;
                        if (_lvl >= 0.7 && {(behaviour _b) in ["SAFE", "CARELESS"]}) then { _g setBehaviour "AWARE"; };
                    };
                    _tepki = _tepki + 1;
                    _say set ["adim", (_say get "adim") + 1];
                    if (_logN < 30) then {
                        _logN = _logN + 1;
                        diag_log format ["[ADIM-BOT] %1 -> %2 | %3 m (menzil %4 m, hiz %5 km/s, %6) | ayak sesi duyuldu | bilgi %7", name _s, groupId _g, round _d, round _rEtkin, round _spd, stance _s, _lvl toFixed 2];
                    };
                } forEach (_sPos nearEntities ["CAManBase", 50]);
            } forEach _kaynaklar;
        };

        if (time > _ozetT) then {
            _ozetT = time + 60;
            if (((_say get "adim") + (_say get "konusma")) > 0) then {
                diag_log format ["[ADIM-KONUSMA-OZET] 60 sn: bot ayak sesi duyulma %1 | konusma duyulma %2", _say get "adim", _say get "konusma"];
            };
            { _say set [_x, 0]; } forEach ["adim", "konusma"];
        };
    };
};
true

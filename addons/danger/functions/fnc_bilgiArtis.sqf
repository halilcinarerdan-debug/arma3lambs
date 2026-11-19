#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * GENEL BILGI ARTISI (v8.688; kullanici: 'genel bilgi artisini ayarlayabilelim cbadan, op mod icin daha net tahmin etsinler yerimizi').
 * Temasli yerel AI grubunun BILDIGI dusmanlarin (grup uyelerinden birinin knowsAbout >= SUPHE) bilgisi 2 sn'de bir YUKSELTILIR: group reveal [hedef, seviye];
 *   seviye = max( mevcut x (1 + bilgiArtis), bilgiTaban ), en cok 4. Yuksek seviye = konum hatasi kucuk ('yerimizi daha net tahmin eder').
 * SINIR (surekli duvar hilesi olmasin): ayni (grup, hedef) cifti icin artis en cok lambs_danger_bilgiSure (45 sn) surer, sonra 3x sure dinlenir (gercek algi surer, yalniz yardim kesilir).
 *   Hedef siniri: lambs_danger_bilgiYalnizOyuncu (acik: yalniz insan oyuncular / oyuncu murettebatli arac; kapali: tum dusmanlar). Menzil: lambs_danger_bilgiMenzil.
 * KAPALI: bilgiArtis = 0 VE bilgiTaban = 0 (varsayilan). Oyuncu liderli gruba dokunmaz. Log: [BILGI-ARTIS] (ilk 15) + 60 sn ozeti.
 * CBA: lambs_danger_bilgiArtis (0-1), bilgiTaban (0-4), bilgiMenzil (m), bilgiSure (sn), bilgiYalnizOyuncu.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_bilgiArtisStarted") exitWith {false};
lambs_danger_bilgiArtisStarted = true;
diag_log "[BILGI-ARTIS] genel bilgi artisi (bilinen dusmanin bilgisi / konum netligi CBA ile artar) baslatildi (v8.688)";

[] spawn {
    private _logN = 0;
    private _say = 0;
    private _grupSay = 0;
    private _ozetT = time + 60;
    while {true} do {
        sleep 2;
        private _k = ((missionNamespace getVariable ["lambs_danger_bilgiArtis", 0]) max 0) min 1;
        private _tb = ((missionNamespace getVariable ["lambs_danger_bilgiTaban", 0]) max 0) min 4;
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if (_say > 0) then { diag_log format ["[BILGI-ARTIS-OZET] 60 sn: yukseltilen bilgi %1 | grup %2 | artis x%3 taban %4", _say, _grupSay, 1 + _k, _tb]; };
            _say = 0; _grupSay = 0;
        };
        if (_k <= 0 && {_tb <= 0}) then { continue };
        private _r = ((missionNamespace getVariable ["lambs_danger_bilgiMenzil", 400]) max 100) min 800;
        private _sure = ((missionNamespace getVariable ["lambs_danger_bilgiSure", 45]) max 10) min 300;
        private _sadeceOy = missionNamespace getVariable ["lambs_danger_bilgiYalnizOyuncu", true];
        private _esik = ["SUPHE"] call FUNC(bilgiEsik);
        private _n = 0;
        {
            private _g = _x;
            if (_n >= 12) exitWith {};
            private _l = leader _g;
            if (isNull _l || {!local _g} || {isPlayer _l} || {!alive _l}) then { continue };
            if ((_g getVariable [QGVAR(contact), 0]) < (time - 60)) then { continue };
            _n = _n + 1;
            private _h = _g getVariable [QGVAR(bilgiH), createHashMap];
            _g setVariable [QGVAR(bilgiH), _h];
            private _uy = (units _g) select {alive _x};
            private _bu = false;
            {
                private _e = _x;
                if (!alive _e) then { continue };
                if (_sadeceOy && {!(isPlayer _e)} && {((crew _e) findIf {isPlayer _x}) < 0}) then { continue };
                private _cur = 0;
                { _cur = _cur max (_x knowsAbout _e); } forEach _uy;
                if (_cur < _esik) then { continue };
                private _key = netId _e;
                private _ent = _h getOrDefault [_key, -999];
                if (time > (_ent + (_sure * 3))) then { _ent = time; _h set [_key, _ent]; };
                if (time > (_ent + _sure)) then { continue };
                private _yeni = (((_cur * (1 + _k)) max _tb)) min 4;
                if (_yeni > (_cur + 0.05)) then {
                    _g reveal [_e, _yeni];
                    _say = _say + 1;
                    _bu = true;
                    if (_logN < 15) then {
                        _logN = _logN + 1;
                        diag_log format ["[BILGI-ARTIS] %1 | hedef %2 (%3 m) | bilgi %4 -> %5 | artis x%6 taban %7 | sure %8 / %9 sn", groupId _g, name _e, round (_l distance2D _e), _cur toFixed 2, _yeni toFixed 2, 1 + _k, _tb, round (time - _ent), _sure];
                    };
                };
            } forEach (_l targets [true, _r, [], 40]);
            if (_bu) then { _grupSay = _grupSay + 1; };
        } forEach allGroups;
    };
};
true

#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * YAN KORUMA + ARKA EMNIYET (v8.65) — hareket halindeki squad'da 360 derece gozetleme.
 *
 * Doktrin ilkesi (genel; sayisal esik kaynakta yok): hareketteki birimde her yone guvenlik; kanat ve arka askerleri kendi sektorlerini (disa dogru) gozler.
 * Kosullar (6 sn'de bir, yerel AI grup): >= 5 canli piyade, lider hareket halinde (> 3 km/s), temas YOK, taktik / retreat / evade / bounding / temas kesme / keskin nisanci YOK, oyuncu lider degil.
 * Secim: lider hareket yonune gore SAG kanat (en sagdaki, yanal > 6 m), SOL kanat (en soldaki, yanal < -6 m), ARKA (en geride, boyuna < -8 m); lider / saglikci / EOD / taktik kilitli / noktada olanlar disinda.
 * Etki: lookAt (yalniz BAKIS; doWatch govdeyi cevirip yan / geri yuruttugu icin kullanilmaz) 60 m'lik disa nokta. Hareket durunca / temas olunca / kosullar bozulunca bakis serbest birakilir.
 * Kapatma: lambs_danger_yanGuvenlikOff = true.   Log: [ZEKA-YAN] (atama, 60 sn'de bir; serbest birakma nedeni)
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_yanGuvStarted") exitWith {false};
lambs_danger_yanGuvStarted = true;

diag_log "[ZEKA-YAN] yan koruma + arka emniyet watchdog'u baslatildi (v8.65)";

private _calis = {
    missionNamespace setVariable ["lambs_danger_yanAdim", "basladi"];
    private _logN = 0;
    while {true} do {
        sleep 6;
        if (missionNamespace getVariable ["lambs_danger_yanGuvenlikOff", false]) then { continue };
        {
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {isPlayer _l} || {!local _l} || {!alive _l} || {!isNull objectParent _l}) then { continue };
            missionNamespace setVariable ["lambs_danger_yanAdim", format ["grup %1", groupId _g]];

            private _canli = (units _g) select {alive _x && {isNull objectParent _x} && {!isPlayer _x}};
            private _eski = _g getVariable [QGVAR(yanGuvListe), []];

            // serbest birakma nedeni
            private _neden = "";
            if ((count _canli) < 5) then { _neden = "asker < 5"; };
            if (_neden isEqualTo "" && {(speed _l) <= 3}) then { _neden = "lider durdu"; };
            if (_neden isEqualTo "" && {(_g getVariable [QGVAR(contact), 0]) > time}) then { _neden = "temas"; };
            if (_neden isEqualTo "" && {
                (_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]}
                || {_g getVariable [QGVAR(isBounding), false]} || {_g getVariable [QGVAR(isExecutingTactic), false]} || {_g getVariable [QGVAR(sniperTeam), false]}
                || {(_g getVariable [QGVAR(iedIs), []]) isNotEqualTo []}
            }) then { _neden = "taktik / retreat / bounding / IED isi"; };
            if (_neden isNotEqualTo "") then {
                if (_eski isNotEqualTo []) then {
                    { if (!isNull _x && {alive _x}) then { _x lookAt objNull; _x setVariable [QGVAR(yanGuv), nil]; }; } forEach _eski;
                    _g setVariable [QGVAR(yanGuvListe), []];
                    if (_logN < 80) then { _logN = _logN + 1; diag_log format ["[ZEKA-YAN] %1 | SERBEST | neden: %2", groupId _g, _neden]; };
                };
                continue;
            };

            // hareket yonu
            private _v = velocity _l;
            private _dir = if (((_v select 0) ^ 2 + (_v select 1) ^ 2) > 0.5) then { (_v select 0) atan2 (_v select 1) } else { getDir _l };
            private _lp = getPosATL _l;

            private _aday = _canli select {
                _x isNotEqualTo _l && {!(_x getUnitTrait "medic")} && {!(_x getUnitTrait "explosiveSpecialist")}
                && {(_x getVariable [QGVAR(taktikKilit), 0]) <= time} && {!(_x getVariable [QGVAR(forceMove), false])}
                && {isNil {_x getVariable QGVAR(noktaEk)}}
            };
            if ((count _aday) < 3) then { continue };
            private _olc = _aday apply {
                private _u = _x;
                private _r = (_lp getDir _u) - _dir;
                private _m = _lp distance2D _u;
                [_m * (sin _r), _m * (cos _r), _u]   // [yanal (+sag), boyuna (+ileri), birim]
            };
            private _sag = objNull; private _sagY = 6;
            private _sol = objNull; private _solY = -6;
            private _arka = objNull; private _arkaB = -8;
            { if ((_x select 0) > _sagY) then { _sagY = _x select 0; _sag = _x select 2; }; if ((_x select 0) < _solY) then { _solY = _x select 0; _sol = _x select 2; }; if ((_x select 1) < _arkaB) then { _arkaB = _x select 1; _arka = _x select 2; }; } forEach _olc;
            // ayni asker iki gorev almasin: arka gorev kanatla cakisirsa arka bos birakilir
            if (!isNull _arka && {_arka isEqualTo _sag || {_arka isEqualTo _sol}}) then { _arka = objNull; };

            private _yeni = [];
            { if (!isNull _x) then { _yeni pushBack _x; }; } forEach [_sag, _sol, _arka];
            // artik gorevde olmayanlari serbest birak
            { if (!isNull _x && {alive _x} && {!(_x in _yeni)}) then { _x lookAt objNull; _x setVariable [QGVAR(yanGuv), nil]; }; } forEach _eski;

            if (!isNull _sag) then { _sag lookAt (_lp getPos [60, _dir + 90]); _sag setVariable [QGVAR(yanGuv), "SAG"]; };
            if (!isNull _sol) then { _sol lookAt (_lp getPos [60, _dir - 90]); _sol setVariable [QGVAR(yanGuv), "SOL"]; };
            if (!isNull _arka) then { _arka lookAt (_lp getPos [60, _dir + 180]); _arka setVariable [QGVAR(yanGuv), "ARKA"]; };

            // log: yeni atama olunca ya da 60 sn'de bir
            private _imza = _yeni apply {name _x};
            if ((_imza isNotEqualTo (_g getVariable [QGVAR(yanGuvImza), []])) || {(time - (_g getVariable [QGVAR(yanGuvLogT), -999])) > 60}) then {
                _g setVariable [QGVAR(yanGuvImza), _imza];
                _g setVariable [QGVAR(yanGuvLogT), time];
                if (_logN < 80) then {
                    _logN = _logN + 1;
                    diag_log format ["[ZEKA-YAN] %1 | hareket yonu:%2 | SAG:%3 | SOL:%4 | ARKA:%5 | aday:%6 | lider hiz:%7 km/s", groupId _g, round _dir, if (isNull _sag) then {"-"} else {name _sag}, if (isNull _sol) then {"-"} else {name _sol}, if (isNull _arka) then {"-"} else {name _arka}, count _aday, round (speed _l)];
                };
            };
            _g setVariable [QGVAR(yanGuvListe), _yeni];
        } forEach (allGroups select {local _x && {!isNull leader _x} && {!(_x getVariable ["lambs_danger_tarafKapali", false])}});
        missionNamespace setVariable ["lambs_danger_yanAdim", "tur bitti"];
    };
};

[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log format ["[WATCHDOG-YENIDEN] yan guvenlik betigi sonlandi (hata?), son adim: %1", missionNamespace getVariable ["lambs_danger_yanAdim", "?"]];
        sleep 5;
    };
};

true

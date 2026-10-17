#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * GELEN TOPCU / HAVAN TEPKISI (v8.228; kullanici: "top yemi olmamalari icin havada calan isliga ve patlamadan kendilerini guvenli bir yere proneleyebilecek bir sistem") —
 * Atesleyen makinede topcu / havan mermisi (artilleryScanner'li arac ya da yuksek acili atis; ShellBase) izlenir; inis evresinde (dikey hiz asagi) balistik tahminle DUSME NOKTASI + SURE bulunur,
 * kalan sure <= 7 sn ise tum makinelere CBA olayi 'lambs_danger_topGelen' yayilir. Her makine KENDI yerel AI piyadelerini tehlike yaricapi icinde bulur:
 *   - sure >= 2.5 sn ve birim yaricap icindeyse: dusme noktasindan UZAKLASAN yone kosar (en cok 18 m, 3.5 m/sn), patlamadan ~1.2 sn once YATAR (setUnitPos DOWN + doStop),
 *   - patlamadan sonra 7 sn yatik kalir (siddetli etki + parca), sonra serbest birakilir (doFollow).
 *   Ayni birim icin ard arda mermi gelirse yatma suresi UZAR (tek betik). Aracta olanlar, oyuncular, bayilanlar, tedavi animasyonundakiler hariç.
 * Kaynak ilkesi (TC 3-21.76 / ATP 3-21.8 genel: dolayli atesten anindan yere yat / siper al; kitapta SAYISAL esik YOK) — TASARIM DEGERLERI: 7 sn uyari, tehlike yaricapi = 3 x indirectHitRange (35-120 m), 18 m kacis, 7 sn yatik.
 * Tahmin basit balistik (hava direnci yok) — gercek dusme birkac on metre sapabilir; yaricap payi bunu karsilar.
 * v8.238 HENDEK ONCELIGI (kullanici: "hendek bilinci yarim, topcu gelince oraya cekilmiyorlar ama hendek kullaniyorlar, daha cok hendege oncelik verebilirler"): hendek alani varsa uyari 7 -> 22 sn
 *   once yayinlanir; erisim 20 -> en cok 60 m ((sure - 1.5) x 3.5); dusme noktasi mesafesi 8 -> 5 m; ZATEN HENDEKTEYSE (<= 2.5 m) hendekten cikip kacmaz, yatar; hendekte barajdan 5 sn sonra kalkar ve formasyona kosmaz;
 *   grup 'topUyariT' isaretlenir (fnc_hendekBilinc topcu altindaki grubu temassiz da hendege sokar). Hendek yoksa davranis eskisi gibi (son 7 sn). Geri alma: lambs_danger_hendekOncelikOff = true.
 * Kapatma: lambs_danger_topSiperOff = true.  Log: [TOP-GELEN] (ilk 40, sonra 10'da bir).
 *
 * Arguments: None (acilista bir kez)
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_topSiperStarted") exitWith {false};
lambs_danger_topSiperStarted = true;
lambs_danger_topIzN = 0;
lambs_danger_topLogN = 0;
lambs_danger_topTepkiN = 0;

// izleyici (hem Fired hem tarama yolu kullanir): dusme noktasini tahmin eder, <= 7 sn kala yayinlar; yukseklik >= 40 m sartı: dogrudan atis mermisi sayilmaz
lambs_danger_topIzle = {
    params ["_p", "_a"];
    if (lambs_danger_topIzN > 40) exitWith {};
    lambs_danger_topIzN = lambs_danger_topIzN + 1;
    private _hr = getNumber (configFile >> "CfgAmmo" >> _a >> "indirectHitRange");
    private _R = ((_hr * 3) max 35) min 120;
    private _t0 = time;
    private _duyuru = false;
    private _ufuk = if ((["LISTE"] call FUNC(hendekAlani)) isEqualTo [] || {missionNamespace getVariable ["lambs_danger_hendekOncelikOff", false]}) then {7} else {22};
    while {!isNull _p && {!_duyuru} && {(time - _t0) < 120}} do {
        private _pos = getPosASL _p;
        private _vel = velocity _p;
        if ((_vel select 2) < -5) then {
            private _h = ((ASLToATL _pos) select 2) max 0;
            private _vz = -(_vel select 2);
            private _t = ((-_vz) + sqrt (_vz * _vz + 19.62 * _h)) / 9.81;
            // v8.238: hendek alani varsa uyari 22 sn once (hendege kosmak icin sure), yoksa eski 7 sn
            if (_t <= _ufuk && {_h >= 40}) then {
                _duyuru = true;
                private _ip = [(_pos select 0) + (_vel select 0) * _t, (_pos select 1) + (_vel select 1) * _t, 0];
                ["lambs_danger_topGelen", [_ip, _t, _R, _a]] call CBA_fnc_globalEvent;
            };
        };
        sleep 0.2;
    };
    lambs_danger_topIzN = (lambs_danger_topIzN - 1) max 0;
};

// ---- 1) ATESLEYEN MAKINE: mermiyi izle, dusme noktasini tahmin et, yayinla ----
["AllVehicles", "Fired", {
    params ["_v", "_wep", "_muz", "_mode", "_ammo", "_mag", "_proj"];
    if (missionNamespace getVariable ["lambs_danger_topSiperOff", false] || {isNull _proj} || {!(_ammo isKindOf "ShellBase")}) exitWith {};
    private _v0 = velocity _proj;
    private _tepe = (_v0 select 2) / ((vectorMagnitude _v0) max 1);
    if ((getNumber (configOf _v >> "artilleryScanner")) <= 0 && {_tepe < 0.45}) exitWith {};   // dolayli ates degil (dogrudan tank / top mermisi)
    _proj setVariable ["lambs_danger_topIz", true, true];
    [_proj, _ammo] spawn lambs_danger_topIzle;
}, true, [], true] call CBA_fnc_addClassEventHandler;

// ---- 2) HER MAKINE: yerel AI piyadeleri tepki verir ----
["lambs_danger_topGelen", {
    params ["_ip", "_eta", "_R", "_ammo"];
    if (missionNamespace getVariable ["lambs_danger_topSiperOff", false]) exitWith {};
    private _aday = (_ip nearEntities ["CAManBase", _R * 1.25]) select {
        local _x && {alive _x} && {!isPlayer _x} && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}
        && {!(_x getVariable ["ACE_isUnconscious", false])} && {((animationState _x) find "medic") < 0}
    };
    if (_aday isEqualTo []) exitWith {};
    lambs_danger_topLogN = lambs_danger_topLogN + 1;
    if (lambs_danger_topLogN <= 40 || {lambs_danger_topLogN % 10 isEqualTo 0}) then {
        diag_log format ["[TOP-GELEN] #%1 | %2 | dusme %3 | kalan %4 sn | tehlike yaricapi %5 m | bu makinede %6 yerel piyade tepki veriyor", lambs_danger_topLogN, _ammo, mapGridPosition _ip, (_eta toFixed 1), round _R, count _aday];
    };
    {
        [_x, _ip, _eta, _R] spawn {
            params ["_u", "_ip", "_eta", "_R"];
            private _bit = time + _eta + 7;
            private _tImp = time + _eta;
            // v8.238 HENDEK ONCELIGI: erisilebilir hendek (sure x 3.5 m/sn, en cok 60 m) varsa oraya; zaten hendekteyse (<= 2.5 m) KALIR (hendekten cikip kacmak yok); dusme noktasi hendek noktasina >= 5 m
            private _hn = [];
            private _icinde = false;
            if (!(missionNamespace getVariable ["lambs_danger_hendekOncelikOff", false]) || {_eta <= 7}) then {
                _hn = ["EN-YAKIN", getPosATL _u, ((_eta - 1.5) * 3.5) min 60, side (group _u)] call FUNC(hendekAlani);
                if (_hn isNotEqualTo []) then {
                    _icinde = (_hn select 2) <= 2.5;
                    if (!_icinde && {((_hn select 0) distance2D _ip) < 5}) then { _hn = []; };
                };
            };
            if (_hn isNotEqualTo []) then { _bit = _bit + 5; };   // hendekte barajin bitmesini biraz daha bekle
            _u setVariable [QGVAR(topBitis), _bit max (_u getVariable [QGVAR(topBitis), 0])];
            (group _u) setVariable [QGVAR(topUyariT), (time + _eta + 60) max ((group _u) getVariable [QGVAR(topUyariT), 0])];   // hendekBilinc: topcu altindaki grup hendege girer
            if (_u getVariable [QGVAR(topAktif), false]) exitWith {};   // betik zaten calisiyor; bitis uzatildi
            _u setVariable [QGVAR(topAktif), true];
            private _etaIlk = _eta;
            private _tehlikede = (_u distance2D _ip) < _R;
            // v8.243 (RPT c7592408: Alpha 1-2 acikta, hendek erisimi yok, 16.6 sn uyari -> 9.6 sn bekleyip son 7 sn'de en cok 18 m kostu; 7 kisi bir salvoda oldu): tehlike yaricapi ICINDEKI birim hendek yoksa
            //   bekleme yapmadan hemen uzaklasir (kosu tavani 18 -> 45 m, uyari >= 10 sn ise). Disindakiler eski sirayla (son 7 sn). Kapatma: lambs_danger_topErkenKacisOff = true.
            private _erkenKac = _tehlikede && {_etaIlk > 10} && {!(missionNamespace getVariable ["lambs_danger_topErkenKacisOff", false])};
            if (_hn isEqualTo [] && {_eta > 7} && {!_erkenKac}) then {
                // hendek yok / erisilemiyor: klasik tepki (uzaklas + yat) son 7 sn'de baslar
                sleep (_eta - 7);
                _eta = 7;
            };
            if (lambs_danger_topTepkiN < 30) then {
                lambs_danger_topTepkiN = lambs_danger_topTepkiN + 1;
                diag_log format ["[TOP-TEPKI] %1 | %2 | dusme noktasina %3 m (tehlike %4 m) | uyari %5 sn | karar: %6", groupId (group _u), name _u, round (_u distance2D _ip), round _R, _etaIlk toFixed 1,
                    if (_hn isNotEqualTo []) then { if (_icinde) then {"ZATEN HENDEKTE (kalir, yatar)"} else {format ["HENDEGE kosuyor (%1 m)", round (_hn select 2)]} } else { if (_erkenKac) then {"HENDEK YOK: hemen uzaklasiyor"} else { if (_tehlikede) then {"HENDEK YOK: son 7 sn'de uzaklasir"} else {"tehlike disinda: kalir, yatar"} } }];
            };
            private _d = _u distance2D _ip;
            if (_hn isNotEqualTo []) then {
                _u setVariable [QGVAR(topHendek), true];
                if (!_icinde) then {
                    private _hdf = (_hn select 0) getPos [random 1.2, random 360];
                    _u enableAI "PATH"; _u enableAI "MOVE"; _u forceSpeed -1;
                    _u setUnitPos "UP"; _u setSpeedMode "FULL";
                    _u doMove _hdf;
                    private _bitisKos = time + (_eta - 1.2);
                    waitUntil { sleep 0.2; time > _bitisKos || {!alive _u} || {(_u distance2D _hdf) < 2} };
                };
            } else {
                if (_eta >= 2.5 && {_d < _R}) then {
                    private _kos = (((_R - _d) + 6) min (_eta * 3.5) min ([18, 45] select _erkenKac)) max 4;
                    private _hdf = (getPosATL _u) getPos [_kos, _ip getDir _u];
                    if (surfaceIsWater _hdf) then { _hdf = (getPosATL _u) getPos [_kos, (_ip getDir _u) + 70]; };
                    if (!surfaceIsWater _hdf) then {
                        _u enableAI "PATH"; _u enableAI "MOVE"; _u forceSpeed -1;
                        _u setUnitPos "UP"; _u setSpeedMode "FULL";
                        _u doMove _hdf;
                        private _bitisKos = time + (_eta - 1.2);
                        waitUntil { sleep 0.2; time > _bitisKos || {!alive _u} || {(_u distance2D _hdf) < 2} };
                    };
                };
            };
            if (_hn isNotEqualTo []) then {
                // hendekte: patlamaya ~4 sn kala yatar (22 sn erken geldiyse boyunca comelir)
                _u setUnitPos "MIDDLE";
                waitUntil { sleep 0.3; !alive _u || {time > (_tImp - 4)} };
            };
            while {alive _u && {time < (_u getVariable [QGVAR(topBitis), 0])}} do {
                _u setUnitPos "DOWN";
                doStop _u;
                sleep 0.5;
            };
            private _hendekteydi = _u getVariable [QGVAR(topHendek), false];
            _u setVariable [QGVAR(topHendek), nil];
            if (alive _u) then {
                _u setUnitPos "AUTO";
                // hendekteki birim formasyona geri kosmaz: hendek bilinci / SAVUN gruplari kendi cikis kurallariyla serbest birakir
                if (!_hendekteydi) then { _u doFollow (leader (group _u)); };
            };
            _u setVariable [QGVAR(topAktif), nil];
        };
    } forEach _aday;
}] call CBA_fnc_addEventHandler;

diag_log "[TOP-SIPER] gelen topcu / havan tepkisi baslatildi (v8.228; v8.229 hendek alani; v8.238 hendek onceligi: 22 sn erken uyari, hendekteyse kal; v8.243 hendek yoksa erken kacis + [TOP-TEPKI] logu): 7 sn uyari, uzaklas / hendege + yat, 7 sn yatik";
true

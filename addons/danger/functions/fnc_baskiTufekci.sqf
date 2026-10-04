#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * BASKI TUFEKCISI (v8.64) — squad'da GERCEK MG (kapasite >= 75 / bilinen MG adi) yoksa en uygun tufekliyi otomatik tufekci / MG rolune atar.
 *
 * Neden: test squad'larinda MG:0 ([ROL-SIRA]); baski ateşi (alana baski, overwatch istasyonu, ates ekibi omurgasi) hic yoktu.
 * Secim (>= 4 canli asker, gercek MG yok, atanmis kisi yok / oldu): lider / UGL tasiyici / AT / saglikci / nisanci DISINDA tufeklilerden;
 *   puan = otomatik silah adi (M27 / IAR / M249 / RPK / SAW / LSAT / MK46 / M60) +100, sarjor kapasitesi (>= 30: +20), yedek sarjor sayisi x 3, + kucuk rastgele.
 * Etki: fnc_getUnitRole atanmis birime "MG" doner (kendi gucu hesabinda 2.0 agirlik; dusman hesabinda yok sayilir) -> roleStation MG istasyonu + alana baski, splitFireTeams ates ekibi, buddyPairs oncelik, bounding overwatch.
 * Atama kalicidir; atanan olunce / grupta gercek MG belirince temizlenir. Kapatma: lambs_danger_baskiTufekciOff = true.   Log: [ZEKA-BASKI]
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_baskiTufStarted") exitWith {false};
lambs_danger_baskiTufStarted = true;

diag_log "[ZEKA-BASKI] baski tufekcisi atama watchdog'u baslatildi (v8.64)";

private _calis = {
    missionNamespace setVariable ["lambs_danger_baskiAdim", "basladi"];
    private _logN = 0;
    while {true} do {
        sleep 10;
        if (missionNamespace getVariable ["lambs_danger_baskiTufekciOff", false]) then { continue };
        private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
        private _uglFn = missionNamespace getVariable ["lambs_danger_fnc_hasUGL", {""}];
        {
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {isPlayer _l} || {!local _l} || {!alive _l}) then { continue };
            missionNamespace setVariable ["lambs_danger_baskiAdim", format ["grup %1", groupId _g]];
            private _canli = (units _g) select {alive _x && {isNull objectParent _x}};
            if ((count _canli) < 4) then { continue };

            // mevcut atama
            private _atanan = _canli select {_x getVariable [QGVAR(baskiTuf), false]};
            private _gercekMg = _canli select {([_x, true] call _rolFn) isEqualTo "MG"};
            if (_gercekMg isNotEqualTo []) then {
                // gercek MG var: atamalari temizle
                { _x setVariable [QGVAR(baskiTuf), nil]; } forEach _atanan;
                continue;
            };
            if (_atanan isNotEqualTo []) then { continue };

            // aday secimi
            private _aday = _canli select {
                _x isNotEqualTo _l && {([_x, true] call _rolFn) isEqualTo "RIFLE"} && {([_x] call _uglFn) isEqualTo ""}
            };
            if (_aday isEqualTo []) then { continue };
            private _skorlu = _aday apply {
                private _u = _x;
                private _w = toUpper (primaryWeapon _u);
                private _mag = (primaryWeaponMagazine _u) param [0, ""];
                private _kap = getNumber (configFile >> "CfgMagazines" >> _mag >> "count");
                private _yedek = {(toLower _x) isEqualTo (toLower _mag)} count (magazines _u);
                private _otomatik = (["M27", "IAR", "M249", "RPK", "SAW", "LSAT", "MK46", "M60", "AUTO"] findIf {(_w find _x) >= 0}) > -1;
                private _sk = ([0, 100] select _otomatik) + ([0, 20] select (_kap >= 30)) + (_yedek * 3) + (random 2);
                [_sk, _u, _w, _kap, _yedek, _otomatik]
            };
            _skorlu sort false;
            private _secilen = _skorlu select 0;
            _secilen params ["_sk", "_u", "_w", "_kap", "_yedek", "_otomatik"];
            _u setVariable [QGVAR(baskiTuf), true];
            if (_logN < 60) then {
                _logN = _logN + 1;
                diag_log format ["[ZEKA-BASKI] %1 | MG yok -> BASKI TUFEKCISI: %2 | silah %3 | sarjor kapasite %4, yedek %5 | otomatik silah:%6 | skor %7 | aday %8", groupId _g, name _u, _w, _kap, _yedek, _otomatik, _sk toFixed 1, count _aday];
            };
        } forEach (allGroups select {local _x && {!isNull leader _x}});
        missionNamespace setVariable ["lambs_danger_baskiAdim", "tur bitti"];
    };
};

// bekci: betik hata ile olurse yeniden baslat
[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log format ["[WATCHDOG-YENIDEN] baski tufekcisi betigi sonlandi (hata?), son adim: %1", missionNamespace getVariable ["lambs_danger_baskiAdim", "?"]];
        sleep 5;
    };
};

true

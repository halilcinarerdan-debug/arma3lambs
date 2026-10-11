#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KALDIR PANELI (v8.176) — "ELITE Karakol / Plan KALDIR" modulunun squad-secimine benzer listesi: sunucudan gelen kayitlar (karakol / HQ / mevzi + aktif planlar),
 * panel basina 8 onay kutusu; isaretlenenler sunucuya 'lambs_danger_kaldirIstegi' ile gonderilir. Hicbiri isaretlenmezse hicbir sey silinmez.
 *
 * Arguments:
 * 0: Liste <ARRAY> [[anahtar, etiket, poz], ...]
 * 1: Baslangic indeksi <NUMBER>
 * 2: Secilen anahtarlar <ARRAY>
 *
 * Return Value: None
 * Public: No
*/

params [["_liste", []], ["_bas", 0], ["_secili", []]];

if (_liste isEqualTo []) exitWith { systemChat "[ELITE] Kaldirilacak karakol / mevzi / aktif plan YOK"; };

private _parca = _liste select [_bas, 8];
if (_parca isEqualTo []) exitWith {
    if (_secili isEqualTo []) exitWith { systemChat "[ELITE] Hicbiri isaretlenmedi - hicbir sey kaldirilmadi"; };
    ["lambs_danger_kaldirIstegi", [_secili]] call CBA_fnc_serverEvent;
    diag_log format ["[KALDIR-ISTEK] sunucuya gonderildi: %1", _secili];
    systemChat format ["[ELITE] %1 kayit icin kaldirma istegi gonderildi", count _secili];
};

private _alanlar = _parca apply {
    [_x select 1, "BOOLEAN", "Isaretlenirse KALDIRILIR (karakol: kayit + harita isareti + yanindaki savunma plani; plan: iptal edilir, gruplar serbest kalir).", false, ""]
};

[
    format ["ELITE Kaldir: karakol / mevzi / plan (%1-%2 / %3)", _bas + 1, _bas + count _parca, count _liste],
    _alanlar,
    {
        params ["_deger", "_args"];
        _args params ["_liste", "_bas", "_secili", "_parca"];
        {
            if (_deger select _forEachIndex) then { _secili pushBackUnique (_x select 0); };
        } forEach _parca;
        [{
            params ["_liste", "_bas", "_secili"];
            [_liste, _bas + 8, _secili] call (missionNamespace getVariable ["lambs_danger_fnc_kaldirPanel", {}]);
        }, [_liste, _bas, _secili]] call CBA_fnc_execNextFrame;
    },
    {},
    {},
    [_liste, _bas, _secili, _parca]
] call EFUNC(main,showDialog);

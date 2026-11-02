#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * 3DEN: ELITE Gorev Ata modulu (v8.362). Module SYNC ile baglanan asker / grup / arac icin secilen gorevi yazar (Zeus 'ELITE Gorev Ata' ile ayni sunucu olayi: lambs_danger_gorevAta).
 * Kodlar: Otomatik (sil), MANEVRA, DESTEK, YEDEK, HARIC, MEDEVAC, TOPCU, TOPCU_YOK, TASIMA, RECON, OYUNCU, ELITE_TAM, RECON_ARAC.
 * Arguments: 0: modul <OBJECT>, 1: baglananlar (kullanilmaz), 2: etkin <BOOL>
 * Return Value: None
 * Public: No
*/

params ["_logic", "", "_activated"];
if (!_activated || {!isServer}) exitWith {};

[_logic] spawn {
    params ["_logic"];
    if !(["BEKLE"] call FUNC(edenOrtak)) exitWith { diag_log "[EDEN] Gorev Ata: ELITE hazir olmadi (180 sn)" };
    private _kodlar = ["", "MANEVRA", "DESTEK", "YEDEK", "HARIC", "MEDEVAC", "TOPCU", "TOPCU_YOK", "", "TASIMA", "RECON", "OYUNCU", "ELITE_TAM", "RECON_ARAC"];
    private _k = (round (["SAYI", [_logic, "lambs_danger_edGorKod", 0]] call FUNC(edenOrtak))) max 0 min 13;
    private _kod = _kodlar select _k;
    private _bagli = ["BAGLI", [_logic]] call FUNC(edenOrtak);
    if (_bagli isEqualTo []) exitWith { diag_log format ["[EDEN] Gorev Ata (3DEN) %1: module bagli birim yok", mapGridPosition _logic] };
    {
        ["lambs_danger_gorevAta", [_x, _kod]] call CBA_fnc_serverEvent;
    } forEach _bagli;
    diag_log format ["[EDEN] Gorev Ata (3DEN) | %1 -> %2 birim: %3", ["Otomatik (sil)", _kod] select (_kod isNotEqualTo ""), count _bagli, _bagli apply {typeOf _x}];
};

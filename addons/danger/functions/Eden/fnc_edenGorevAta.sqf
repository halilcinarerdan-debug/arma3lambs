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
    private _kodlar = ["", "MANEVRA", "DESTEK", "YEDEK", "HARIC", "MEDEVAC", "TOPCU", "TOPCU_YOK", "", "TASIMA", "RECON", "OYUNCU", "ELITE_TAM", "RECON_ARAC", ""];
    private _k = (round (["SAYI", [_logic, "lambs_danger_edGorKod", 0]] call FUNC(edenOrtak))) max 0 min 14;
    private _kod = _kodlar select _k;
    ["DEGISKENLER", [_logic]] call FUNC(edenOrtak);
    private _bagli = ["BAGLI", [_logic]] call FUNC(edenOrtak);
    if (_bagli isEqualTo []) exitWith { diag_log format ["[EDEN] Gorev Ata (3DEN) %1: module bagli birim yok", mapGridPosition _logic] };
    // v8.406: 'Otomatik' (0) artik mevcut gorevi SILMEZ (RPT: 'recon' / 'recon araci' modulleri varsayilan Otomatik'te kaldi -> RECON / RECON_ARAC etiketi silindi -> recon normal asker sayildi, kesif kapisi kurulmadi). Silmek icin 14 'Zorla sil'.
    private _zorlaSil = _k isEqualTo 14;
    {
        private _h = _x;
        private _hg = if (_h isEqualType grpNull) then {_h} else {group (effectiveCommander _h)};
        private _mevcut = ((_h getVariable ["lambs_danger_gorev", ""]) + (if (isNull _hg) then {""} else {_hg getVariable ["lambs_danger_gorev", ""]}));
        if (_kod isEqualTo "" && {!_zorlaSil} && {_mevcut isNotEqualTo ""}) then {
            diag_log format ["[EDEN] Gorev Ata (3DEN) | UYARI: %1 modulu 'Otomatik' ama birimde gorev var (%2) -> KORUNDU (silmek icin 'Zorla sil' secin)", typeOf _h, _mevcut];
        } else {
            ["lambs_danger_gorevAta", [_h, _kod]] call CBA_fnc_serverEvent;
        };
    } forEach _bagli;
    diag_log format ["[EDEN] Gorev Ata (3DEN) | %1 -> %2 birim: %3", [["Otomatik", "Zorla sil"] select _zorlaSil, _kod] select (_kod isNotEqualTo ""), count _bagli, _bagli apply {typeOf _x}];
};

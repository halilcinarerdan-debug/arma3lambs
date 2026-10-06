#include "script_component.hpp"

// ELITE fork (v8.128): "ELITE Karakol / HQ" Zeus modulu — HARITADA (modulun birakildigi noktada) bir karakol / mevzi / komuta noktasi tanimlar.
// Tarihsel canlandirma (ornegin bir karakol baskini): savunan taraf icin karakol; saldiran icin ELITE Objektif ile (Baskin = vur-cek) hedef.
//   Tanim: taraf, ad (hazir liste), yaricap (30-300 m), savunma sekli.
//   Savunma: 'Yok' yalniz isaret + kayit; 'Hemen' yaricap x1.5 icindeki savunan AI gruplari icin SAVUN plani (sektor + garrison) kurulur;
//            'Alarm' duşman karakolun 800 m icinde savunan gruplarca BILINIRSE (knowsAbout >= 0.5) savunma plani otomatik kurulur (hile yok: gercek bilgi);
//            'KALDIR' bu noktadaki karakol kaydi + isareti siler.
// Isaret: harita + Zeus'ta ELITE_KARAKOL_<n>; kayit lambs_danger_karakollar (sunucu). Log: [KARAKOL].

params ["_logic", "", "_activated"];

if (_activated && local _logic) then {
    private _poz = getPosATL _logic;
    deleteVehicle _logic;
    [
        "ELITE Karakol / HQ",
        [
            ["Taraf (savunan / sahip)", "LIST", "Karakolun ait oldugu taraf.", ["BLUFOR", "OPFOR", "INDEP"], 0],
            ["Ad / tur", "LIST", "Harita isaretindeki ad.", ["Karakol", "Mevzi", "HQ / Komuta noktasi", "Gozetleme noktasi", "Ussu"], 0],
            ["Yaricap (m)", "SLIDER", "Karakolun cevre yaricapi; savunma sektorleri ve 'icindeki gruplar' buna gore.", [30, 300], [10, 50], 120, 0],
            ["Savunma", "LIST", "Yok: yalniz isaret. Hemen: yaricap x1.5 icindeki savunan AI gruplari icin savunma plani. Alarm: duşman 800 m icinde savunanlarca bilinince plan otomatik kurulur. KALDIR: bu noktadaki karakolu sil.", ["Yok (yalniz isaret)", "Savunma plani HEMEN", "Alarm (duşman yaklasinca)", "KALDIR"], 0]
        ],
        {
            params ["_data", "_args"];
            _args params ["_poz"];
            _data params ["_tarafI", "_adI", "_yar", "_sav"];
            private _taraf = [west, east, independent] select (_tarafI max 0 min 2);
            ["lambs_danger_karakolIstegi", [_taraf, _poz, _adI, round _yar, _sav]] call CBA_fnc_serverEvent;
            diag_log format ["[KARAKOL-ISTEK] sunucuya gonderildi: %1 | %2 | %3 m | savunma %4", _taraf, mapGridPosition _poz, round _yar, _sav];
            systemChat "[ELITE] Karakol istegi sunucuya gonderildi";
        }, {}, {}, [_poz]
    ] call EFUNC(main,showDialog);
};

#include "script_component.hpp"

// ELITE fork (v8.128): "ELITE Karakol / Mevzi (savunma noktasi)" Zeus modulu — HARITADA (modulun birakildigi noktada) bir karakol / mevzi / komuta noktasi tanimlar.
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
        "ELITE Karakol / Mevzi",
        [
            ["Taraf (savunan / sahip)", "LIST", "Karakolun ait oldugu taraf.", ["BLUFOR", "OPFOR", "INDEP"], 0],
            ["Ad / tur", "LIST", "Harita isaretindeki ad.", ["Karakol", "Mevzi", "Gozetleme noktasi"], 0],
            ["Yaricap (m)", "SLIDER", "Karakolun cevre yaricapi; savunma sektorleri ve 'icindeki gruplar' buna gore.", [30, 300], [10, 50], 120, 0],
            ["Savunma", "LIST", "Yok: yalniz isaret. Hemen: yaricap x1.5 icindeki savunan AI gruplari icin savunma plani. Alarm: duşman 800 m icinde savunanlarca bilinince plan otomatik kurulur.", ["Yok (yalniz isaret)", "Savunma plani HEMEN", "Alarm (duşman yaklasinca)"], 0],
            ["Grup secimi (yalniz 'HEMEN' icin)", "LIST", "Otomatik: yaricap x1.5 icindeki savunan gruplar kendiliginden alinir (yanlis grup girebilir). Elle: istek gonderildikten sonra squad listesi acilir, mevziye atanacaklari siz isaretlersiniz.", ["Otomatik (yaricap x1.5)", "Elle sec (liste)"], 1]
        ],
        {
            params ["_data", "_args"];
            _args params ["_poz"];
            _data params ["_tarafI", "_adI", "_yar", "_sav", ["_secimModu", 1]];
            private _taraf = [west, east, independent] select (_tarafI max 0 min 2);
            private _elle = (_sav isEqualTo 1) && {_secimModu isEqualTo 1};
            ["lambs_danger_karakolIstegi", [_taraf, _poz, _adI, round _yar, _sav, _elle]] call CBA_fnc_serverEvent;
            // v8.176: ELLE secim -> squad listesi (objektifGrupSec) acilir; secilen gruplar SAVUN plani ile bu mevziye atanir (kullanici hatasi: yanlis grup / uzak grup / baska planda olan grup girmesin)
            if (_elle) then {
                [{
                    params ["_taraf", "_poz", "_yar"];
                    [_taraf, _poz, createHashMapFromArray [["tip", 1], ["grupN", 8], ["grupMesafe", _yar * 1.5], ["bina", true], ["piyade", true], ["rallyM", 250], ["orpM", 150], ["basla", 0], ["baslik", "ELITE Karakol / Mevzi: atanacak squadlar"]]] call (missionNamespace getVariable ["lambs_danger_fnc_objektifGrupSec", {systemChat "[ELITE] objektifGrupSec yuklu degil"}]);
                }, [_taraf, _poz, round _yar]] call CBA_fnc_execNextFrame;
            };
            diag_log format ["[KARAKOL-ISTEK] sunucuya gonderildi: %1 | %2 | %3 m | savunma %4", _taraf, mapGridPosition _poz, round _yar, _sav];
            systemChat "[ELITE] Karakol istegi sunucuya gonderildi";
        }, {}, {}, [_poz]
    ] call EFUNC(main,showDialog);
};

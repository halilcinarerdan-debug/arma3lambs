#include "script_component.hpp"

// ELITE fork (v8.128): "ELITE Karakol / Mevzi (savunma noktasi)" Zeus modulu — HARITADA (modulun birakildigi noktada) bir karakol / mevzi / komuta noktasi tanimlar.
// Tarihsel canlandirma (ornegin bir karakol baskini): savunan taraf icin karakol; saldiran icin ELITE Objektif ile (Baskin = vur-cek) hedef.
//   Tanim: taraf, ad (hazir liste), yaricap (30-1500 m; v8.393: eskiden 300), savunma sekli.
//   Sade surum (sade-waypoint): plan / objektif katmani yok; karakol = harita isareti + kayit (+ garnizon). 'KALDIR' bu noktadaki kaydi + isareti siler.
// v8.400: 'Garnizon (hazir ayar)' secimi ayni modulle garnizon da kurar (Yok / Hafif / Standart / Guclu / Ozel panel; fnc_garnizonHazir / fnc_garnizonPanel).
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
            ["Yaricap (m)", "SLIDER", "Karakolun cevre yaricapi; savunma sektorleri, garnizon (nobet / devriye / arac mevzisi) alani ve 'icindeki gruplar' buna gore. v8.393: ust sinir 300 -> 1500 m (genis garnizon bolgesi).", [30, 1500], [10, 50], 120, 0],
            ["Savunma", "LIST", "Yok: yalniz isaret + garnizon. KALDIR: bu noktadaki karakol kaydini siler. (Plan / objektif katmani kaldirildi; savunma icin garnizon ayari ve Mevzi / Gozetleme Ata kullan.)", ["Yok (yalniz isaret)", "Yok (yalniz isaret)", "Yok (yalniz isaret)", "KALDIR"], 0],
            ["Garnizon (hazir ayar)", "LIST", "v8.400 tek modulle karakol + garnizon. Hafif: 2 nobetci + 1 devriye x 2. Standart: 4 nobetci + 2 devriye x 3 + arac mevzisi. Guclu: 6 nobetci + 3 devriye x 3 + arac + anti-air + IHA alarmda gozlem. Ozel: garnizon paneli acilir (asker / takim secimi, IHA, AA ...; 'Elle sec (liste)' ile birlikte kullanilamaz). Garnizon sonradan 'ELITE Karakol Garnizon' modulu ile degistirilir.", ["Yok", "Hafif", "Standart", "Guclu", "Ozel (panel ac)"], 0]
        ],
        {
            params ["_data", "_args"];
            _args params ["_poz"];
            _data params ["_tarafI", "_adI", "_yar", "_sav", ["_garHazir", 0]];
            private _taraf = [west, east, independent] select (_tarafI max 0 min 2);
            private _elle = false;
            ["lambs_danger_karakolIstegi", [_taraf, _poz, _adI, round _yar, _sav, _elle]] call CBA_fnc_serverEvent;
            // v8.400: hazir garnizon ayari (karakol kaydi ayni istemciden once gittigi icin sunucuda sirayla islenir) / Ozel = panel
            private _gh = [_garHazir] call FUNC(garnizonHazir);
            if (_gh isNotEqualTo []) then {
                _gh params ["_gN", "_gD", "_gB", "_gU", "_gA", "_gAA", "_gI"];
                ["lambs_danger_garnizonIstegi", [_poz, 0, _gN, _gD, _gB, _gU, _gA, [], 0, [], [_gI, 0, 0, []], _gAA]] call CBA_fnc_serverEvent;
                diag_log format ["[KARAKOL-ISTEK] hazir garnizon (%1): nobet %2 | devriye %3 x %4 | ust kat %5 | arac %6 | AA %7 | IHA mod %8", ["", "hafif", "standart", "guclu"] select ((round _garHazir) max 0 min 3), _gN, _gD, _gB, _gU, _gA, _gAA, _gI];
            };
            if ((round _garHazir) >= 4) then {
                if (_elle) then {
                    systemChat "[ELITE] Garnizon = Ozel, 'Elle sec (liste)' ile ayni anda acilamaz: once squad listesi; garnizon icin 'ELITE Karakol Garnizon' modulunu kullan";
                } else {
                    [{ [_this select 0] call FUNC(garnizonPanel); }, [_poz]] call CBA_fnc_execNextFrame;
                };
            };
            diag_log format ["[KARAKOL-ISTEK] sunucuya gonderildi: %1 | %2 | %3 m | savunma %4", _taraf, mapGridPosition _poz, round _yar, _sav];
            systemChat "[ELITE] Karakol istegi sunucuya gonderildi";
        }, {}, {}, [_poz]
    ] call EFUNC(main,showDialog);
};

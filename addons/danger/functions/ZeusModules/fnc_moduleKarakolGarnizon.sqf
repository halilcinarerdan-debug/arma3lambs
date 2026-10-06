#include "script_component.hpp"

// ELITE fork (v8.130): "ELITE Karakol Garnizon" Zeus modulu — bir KARAKOLUN (ELITE Karakol / HQ) icinde nobetci, devriye alt gruplari, ust kat pozisyonlari ve arac mevzileri.
// Modul karakolun yaricapi (+150 m) icine birakilir; ayni modul tekrar calistirilirsa ayar ve pozisyonlar YENIDEN hesaplanir (birimler orijinal gruplarina doner, sonra yeniden dagitilir).
// Yeni birimler (karakol icine konan / gelen) bir sonraki 15 sn'lik turda havuza girer ve eksik nobet / devriyeyi tamamlar. Kaldir: garnizon bosaltilir.

params ["_logic", "", "_activated"];

if (_activated && local _logic) then {
    private _poz = getPosATL _logic;
    deleteVehicle _logic;
    [
        "ELITE Karakol Garnizon",
        [
            ["Islem", "LIST", "Uygula: ayar yeniden hesaplanir (tekrar tekrar duzeltilebilir). Kaldir: nobetciler / devriyeler orijinal gruplarina doner, araclar serbest.", ["Uygula / yeniden duzenle", "Garnizonu KALDIR"], 0],
            ["Nobetci sayisi", "SLIDER", "Onemli pozisyonlarda (ust kat / yuksek arazi) tek basina nobet tutan asker. Tufekci / nisanci once; lider, hekim, MG, AT en son.", [0, 8], [1, 1], 3, 0],
            ["Devriye alt grubu sayisi", "SLIDER", "Karakol cevresinde dolasan devriye grubu. Temas olunca cevre savunmasina gecer.", [0, 3], [1, 1], 1, 0],
            ["Devriye boyu (asker)", "SLIDER", "Her devriye grubundaki asker sayisi.", [2, 6], [1, 1], 3, 0],
            ["Ust kat / cati nobet pozisyonlari", "BOOLEAN", "Binalarin >= 2.5 m yuksekteki ic pozisyonlari nobet icin aday olur (hakim, dis cepheyi goren). Kapali: yalniz yuksek arazi.", true, ""],
            ["Araclar mevzi olsun (APC / kamyon)", "BOOLEAN", "Karakol icindeki AI suruculu kara araclari cevrede ates mevzisine gider, muretteat icinde kalir.", true, ""]
        ],
        {
            params ["_data", "_args"];
            _args params ["_poz"];
            _data params ["_islem", "_nobet", "_dev", "_devBoy", "_ust", "_arac"];
            ["lambs_danger_garnizonIstegi", [_poz, _islem, round _nobet, round _dev, round _devBoy, _ust, _arac]] call CBA_fnc_serverEvent;
            diag_log format ["[KARAKOL-ISTEK] garnizon istegi sunucuya gonderildi: islem %1 | nobet %2 | devriye %3 x %4 | ust kat %5 | arac %6", _islem, round _nobet, round _dev, round _devBoy, _ust, _arac];
            systemChat "[ELITE] Karakol garnizon istegi sunucuya gonderildi";
        }, {}, {}, [_poz]
    ] call EFUNC(main,showDialog);
};

#include "script_component.hpp"

// ELITE fork (v8.130): "ELITE Karakol Garnizon" Zeus modulu — bir KARAKOLUN (ELITE Karakol / HQ) icinde nobetci, devriye alt gruplari, ust kat pozisyonlari ve arac mevzileri.
// Modul karakolun yaricapi + CBA garnizonEk (v8.393: varsayilan 500 m, eskiden sabit 150) icine birakilir (en yakin karakol secilir; GARNIZON ALANI karakolun yaricapidir, modulun konumu degil); ayni modul tekrar calistirilirsa ayar ve pozisyonlar YENIDEN hesaplanir (birimler orijinal gruplarina doner, sonra yeniden dagitilir).
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
            ["Araclar mevzi olsun (APC / kamyon)", "BOOLEAN", "Karakol icindeki AI suruculu kara araclari cevrede ates mevzisine gider, muretteat icinde kalir.", true, ""],
            ["Asker secimi", "LIST", "Otomatik: karakol yaricapinin x1.5 icindeki gruplardan asker alinir. Asker listesi: modulun 800 m cevresindeki AI askerler listelenir; isaretlediklerin garnizon havuzu olur (yaricap kurali yok). Takim listesi: 800 m cevresindeki AI takimlar (grup) listelenir; yalniz isaretlediklerin garnizona asker verir (her takimda en az 3 asker kalir).", ["Otomatik (yaricap havuzu)", "Elle sec: asker listesi", "Elle sec: takim (grup) listesi"], 0],
            ["Devriye mesafesi (m)", "SLIDER", "Devriye rotasinin karakol MERKEZINE uzakligi (halka). 0 = karakol yaricapinin %60'i (varsayilan; yaricap kucukse devriye merkezin dibinde doner). Uzak devriye icin buyuk deger (ornek 600); su varsa mesafe %75 / %50'ye kisilir.", [0, 2000], [10, 100], 0, 0]
        ],
        {
            params ["_data", "_args"];
            _args params ["_poz"];
            _data params ["_islem", "_nobet", "_dev", "_devBoy", "_ust", "_arac", ["_secim", 0], ["_devMes", 0]];
            if (_secim isEqualTo 2 && {_islem isEqualTo 0}) exitWith {
                // v8.397: takim (grup) secimi paneli (sonraki karede)
                [{
                    params ["_poz", "_ayarD"];
                    [_poz, _ayarD] call (missionNamespace getVariable ["lambs_danger_fnc_garnizonTakimSec", {systemChat "[ELITE] garnizonTakimSec bu istemcide yuklu degil (eski mod surumu?)"}]);
                }, [_poz, [_islem, _nobet, _dev, _devBoy, _ust, _arac, _devMes]]] call CBA_fnc_execNextFrame;
            };
            if (_secim isEqualTo 1 && {_islem isEqualTo 0}) exitWith {
                // v8.394: elle asker secimi paneli (sonraki karede)
                [{
                    params ["_poz", "_ayarD"];
                    [_poz, _ayarD] call (missionNamespace getVariable ["lambs_danger_fnc_garnizonAskerSec", {systemChat "[ELITE] garnizonAskerSec bu istemcide yuklu degil (eski mod surumu?)"}]);
                }, [_poz, [_islem, _nobet, _dev, _devBoy, _ust, _arac, _devMes]]] call CBA_fnc_execNextFrame;
            };
            ["lambs_danger_garnizonIstegi", [_poz, _islem, round _nobet, round _dev, round _devBoy, _ust, _arac, [], round _devMes, []]] call CBA_fnc_serverEvent;
            diag_log format ["[KARAKOL-ISTEK] garnizon istegi sunucuya gonderildi: islem %1 | nobet %2 | devriye %3 x %4 | ust kat %5 | arac %6 | devriye mesafesi %7", _islem, round _nobet, round _dev, round _devBoy, _ust, _arac, round _devMes];
            systemChat "[ELITE] Karakol garnizon istegi sunucuya gonderildi";
        }, {}, {}, [_poz]
    ] call EFUNC(main,showDialog);
};

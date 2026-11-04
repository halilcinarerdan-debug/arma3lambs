#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * GARNIZON AYAR PANELI (v8.400; eskiden ZeusModules/fnc_moduleKarakolGarnizon.sqf icindeydi): nobetci / devriye / ust kat / arac / asker secimi / AA / IHA ayarlari.
 * 'ELITE Karakol Garnizon' Zeus modulu ve 'ELITE Karakol / Mevzi' modulunun 'Garnizon = Ozel' secimi bu paneli acar (sadelestirme: tek panel, iki giris).
 * Karakol yoksa garnizon istegi OTOMATIK karakol kurar (sunucu; fnc_komutanPlanKapi lambs_danger_garnizonIstegi).
 *
 * Arguments:
 * 0: Konum <ARRAY>
 *
 * Return Value: None
 * Public: No
*/

params [["_poz", [0, 0, 0], [[]]]];

[
    "ELITE Karakol Garnizon",
    [
        ["Islem", "LIST", "Uygula: ayar yeniden hesaplanir (tekrar tekrar duzeltilebilir). Kaldir: nobetciler / devriyeler orijinal gruplarina doner, araclar serbest.", ["Uygula / yeniden duzenle", "Garnizonu KALDIR"], 0],
        ["Nobetci sayisi", "SLIDER", "Onemli pozisyonlarda (ust kat / yuksek arazi) tek basina nobet tutan asker. Tufekci / nisanci once; lider, hekim, MG, AT en son.", [0, 8], [1, 1], 3, 0],
        ["Devriye alt grubu sayisi", "SLIDER", "Karakol cevresinde dolasan devriye grubu. Akilli devriye (CBA): her devriye farkli bir sektoru planli turlarla gezer, diger devriyelerin yerini bilir, temas haberi paylasilir. Temas olunca cevre savunmasina gecer.", [0, 3], [1, 1], 1, 0],
        ["Devriye boyu (asker)", "SLIDER", "Her devriye grubundaki asker sayisi.", [2, 6], [1, 1], 3, 0],
        ["Ust kat / cati nobet pozisyonlari", "BOOLEAN", "Binalarin >= 2.5 m yuksekteki ic pozisyonlari nobet icin aday olur (hakim, dis cepheyi goren). Kapali: yalniz yuksek arazi.", true, ""],
        ["Araclar mevzi olsun (APC / kamyon)", "BOOLEAN", "Karakol icindeki AI suruculu kara araclari cevrede ates mevzisine gider, muretteat icinde kalir.", true, ""],
        ["Asker secimi", "LIST", "Otomatik: karakol yaricapinin x1.5 icindeki gruplardan asker alinir. Asker listesi: modulun 800 m cevresindeki AI askerler listelenir; isaretlediklerin garnizon havuzu olur (yaricap kurali yok). Takim listesi: 800 m cevresindeki AI takimlar (grup) listelenir; yalniz isaretlediklerin garnizona asker verir (her takimda en az 3 asker kalir).", ["Otomatik (yaricap havuzu)", "Elle sec: asker listesi", "Elle sec: takim (grup) listesi"], 0],
        ["Anti-air konumlandirma", "LIST", "Otomatik: MANPADS (Stinger / Igla / Zipkin ...) tasiyan askerler ayri acik / yuksek AA nobet noktalarina (en cok 3, 55 m aralikla); kendiyurur AA araclari (SPAAG: ZSU-23-4 / Tunguska ...) karakolun ic halkasina; STATIK AA (ZU-23 vb.) YERINDE KALIR. Elle tanim: nesne init this setVariable [lambs_danger_aa, SPAAG, true] (MANPADS / SPAAG / STATIK / NONE).", ["Yok", "Otomatik"], 1],
        ["IHA gozlem (karakola bagli)", "LIST", "Surekli: karakol merkezinde gozlem devriyesi atan bosta IHA (ayni taraf, ucan, GOZLEM tipi: FPV / bomba degil; karakol yaricapinin x1.5 icinde, yakit > %30). Alarmda: yalniz grup temasinda kalkar. IHA gorevi bitince / dusunce 90 sn sonra yenisi secilir; karakol kaldirilinca gorev kaldirilir. Belirli IHA icin 3DEN modulu (SYNC) kullanilir (SYNC'li IHA varsa 'Yok' secilse bile Surekli sayilir).", ["Yok", "Surekli gozlem devriyesi", "Alarmda gozlem"], 0],
        ["IHA devriye yaricapi (m)", "SLIDER", "0 = karakol yaricapi (100-800 m). IHA bu yaricapta karakol merkezi etrafinda devriye atar.", [0, 800], [10, 100], 0, 0],
        ["IHA gozlem suresi (dk)", "SLIDER", "0 = CBA 'Gozlem IHA suresi' (varsayilan 20 dk). Sure dolunca 90 sn sonra yeni IHA / sorti.", [0, 60], [1, 5], 0, 0],
        ["Devriye mesafesi (m)", "SLIDER", "Devriye rotasinin karakol MERKEZINE uzakligi. 0 = karakol yaricapinin %60'i (varsayilan; yaricap kucukse devriye merkezin dibinde doner). Uzak devriye icin buyuk deger (ornek 600); su varsa mesafe %75 / %50'ye kisilir.", [0, 2000], [10, 100], 0, 0]
    ],
    {
        params ["_data", "_args"];
        _args params ["_poz"];
        _data params ["_islem", "_nobet", "_dev", "_devBoy", "_ust", "_arac", ["_secim", 0], ["_aa", 1], ["_ihaMod", 0], ["_ihaYar", 0], ["_ihaSure", 0], ["_devMes", 0]];
        if (_secim isEqualTo 2 && {_islem isEqualTo 0}) exitWith {
            // v8.397: takim (grup) secimi paneli (sonraki karede)
            [{
                params ["_poz", "_ayarD"];
                [_poz, _ayarD] call (missionNamespace getVariable ["lambs_danger_fnc_garnizonTakimSec", {systemChat "[ELITE] garnizonTakimSec bu istemcide yuklu degil (eski mod surumu?)"}]);
            }, [_poz, [_islem, _nobet, _dev, _devBoy, _ust, _arac, _devMes, [_ihaMod, round _ihaYar, round _ihaSure, []], _aa]]] call CBA_fnc_execNextFrame;
        };
        if (_secim isEqualTo 1 && {_islem isEqualTo 0}) exitWith {
            // v8.394: elle asker secimi paneli (sonraki karede)
            [{
                params ["_poz", "_ayarD"];
                [_poz, _ayarD] call (missionNamespace getVariable ["lambs_danger_fnc_garnizonAskerSec", {systemChat "[ELITE] garnizonAskerSec bu istemcide yuklu degil (eski mod surumu?)"}]);
            }, [_poz, [_islem, _nobet, _dev, _devBoy, _ust, _arac, _devMes, [_ihaMod, round _ihaYar, round _ihaSure, []], _aa]]] call CBA_fnc_execNextFrame;
        };
        ["lambs_danger_garnizonIstegi", [_poz, _islem, round _nobet, round _dev, round _devBoy, _ust, _arac, [], round _devMes, [], [_ihaMod, round _ihaYar, round _ihaSure, []], _aa]] call CBA_fnc_serverEvent;
        diag_log format ["[KARAKOL-ISTEK] garnizon istegi sunucuya gonderildi: islem %1 | nobet %2 | devriye %3 x %4 | ust kat %5 | arac %6 | devriye mesafesi %7", _islem, round _nobet, round _dev, round _devBoy, _ust, _arac, round _devMes];
        systemChat "[ELITE] Karakol garnizon istegi sunucuya gonderildi";
    }, {}, {}, [_poz]
] call EFUNC(main,showDialog);

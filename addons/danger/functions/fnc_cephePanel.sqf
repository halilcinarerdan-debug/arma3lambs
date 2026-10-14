#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * CEPHE PANELI (v8.237, Dilim A0) — Zeus'ta (istemci) faction listesinden asker sayisi + Personnel Replacement ayarlari. Kullanici karari: "slider = DAW'daki FADER gibi
 * (soldan saga surukle + yaninda sayi); asker sayisi icin 10'ar adim". v1: fader sayfalari; gercek '+ / -' butonlu liste ozel GUI (sonraki dilim).
 * Sayfalar (her biri showDialog, <= 7 alan; sonraki sayfa bir sonraki karede acilir):
 *   0 ana sayfa    : islem secimi
 *   1 faction      : faction (otomatik liste) + asker sayisi (fader) + rezerv havuzu (fader) + yerlesim yaricapi (fader) + 'bu konum takviye varis noktasi'
 *   2 PR taraf 1/2 : taraf, takviye hizi, gecikme, min squad, es zamanli paket
 *   3 PR taraf 2/2 : beceri, cepheye yakinlik carpani, havuz bitince, konvoy zaiyat olasiligi
 *   4 durum        : sunucudan rapor (RPT + sohbet)
 *   5 sil          : faction (ya da tumu) profillerini sil
 *   6 varis noktasi: bu konumu bir tarafin takviye varis noktasi yap
 * Sayisal alanlarin hepsi TAM SAYIDIR (kesirli fader desteklenmiyor; yuzde olarak girilir). Panelde gorunen PR varsayilanlari CBA'dan okunur; taraf bazli
 * onceki panel degerleri istemciye gonderilmez (sunucuda ustune yazilir).
 *
 * Arguments:
 * 0: Modul konumu <ARRAY>
 * 1: Sayfa <NUMBER> (default: 0)
 * 2: Sayfa argumanlari <ARRAY> (default: [])
 *
 * Return Value: None
 * Public: No
*/

params [["_poz", [0, 0, 0], [[]]], ["_sayfa", 0, [0]], ["_arg", [], [[]]]];

private _cba = { params ["_ad", "_def"]; missionNamespace getVariable [format ["lambs_danger_%1", _ad], _def] };
private _tarafAd = ["BLUFOR (west)", "OPFOR (east)", "INDEPENDENT"];
private _tarafSide = [west, east, independent];

switch (_sayfa) do {
    // ------------------------------------------------------------------ ana sayfa
    case 0: {
        [
            "ELITE Cephe Paneli",
            [
                ["Islem", "LIST", "Faction asker ekle: faction listesinden (RHS / GM / vb. otomatik) asker sayisi, SANAL profil olarak bu konum etrafina dagitilir; cepheye yaklasinca / temasta fiziksel olur. Personnel Replacement: taraf bazli takviye ayarlari. Silme: geri alinamaz.",
                    ["Faction asker ekle (sanal profil)", "Personnel Replacement ayarlari (taraf)", "Durum raporu (RPT + sohbet)", "Faction profillerini SIL", "Bu konumu takviye varis noktasi yap"], 0]
            ],
            {
                params ["_d", "_args"];
                _args params ["_poz"];
                private _i = round (_d select 0);
                [{ params ["_p", "_s", "_a"]; [_p, _s, _a] call (missionNamespace getVariable ["lambs_danger_fnc_cephePanel", {}]); }, [_poz, [1, 2, 4, 5, 6] select _i, []]] call CBA_fnc_execNextFrame;
            }, {}, {}, [_poz]
        ] call EFUNC(main,showDialog);
    };

    // ------------------------------------------------------------------ faction asker ekle
    case 1: {
        private _liste = call FUNC(cepheFactionListe);
        if (_liste isEqualTo []) exitWith { systemChat "[ELITE Cephe] faction bulunamadi (CfgFactionClasses / yaya sinif taramasi bos)"; };
        private _etiket = _liste apply {
            _x params ["_f", "_ad", "_sd", "_sab", "_n"];
            format ["%1 [%2] - %3 sablon, %4 sinif", _ad, ["OPFOR", "BLUFOR", "INDEP"] select _sd, _sab, _n]
        };
        [
            "ELITE Cephe: faction asker ekle",
            [
                ["Faction", "LIST", "Otomatik taninan faction (CfgFactionClasses). Sablon = hazir squad kompozisyonu sayisi; yoksa yaya siniflardan 8'lik squad kurulur.", _etiket, 0],
                ["Asker sayisi (eklenir)", "SLIDER", "Bu konum etrafina SANAL profil olarak eklenecek toplam asker. Fader: soldan saga surukle (10'ar adim). Fiziksel hale gelen en cok 'fiziksel tavan' kadar olur (CBA).", [0, 1500], [10, 50], 100, 0],
                ["Rezerv havuzu (takviye icin)", "SLIDER", "Personnel Replacement havuzu: kayip olan squadlar bu havuzdan tamamlanir (araca benzeri soyut konvoyla, ayara bagli gecikme / hizla). Mevcut rezerve EKLENIR.", [0, 1500], [10, 50], 50, 0],
                ["Yerlesim yaricapi (m)", "SLIDER", "Squadlar bu konum etrafinda bu yaricap icinde (kara, dusuk egim) dagitilir.", [100, 3000], [50, 250], 600, 0],
                ["Bu konum = takviye varis noktasi", "BOOLEAN", "Isaretliyse bu tarafin takviyeleri bu konuma (FOB / HQ) gelir ve buradan squadlara gider.", true, ""]
            ],
            {
                params ["_d", "_args"];
                _args params ["_poz", "_liste"];
                _d params ["_fi", "_adet", "_rez", "_yar", "_varis"];
                private _f = (_liste select (round _fi)) select 0;
                ["lambs_danger_cepheFactionIstegi", [_f, round _adet, round _rez, _poz, round _yar, _varis]] call CBA_fnc_serverEvent;
                diag_log format ["[CEPHE-ISTEK] faction istegi sunucuya gonderildi: %1 | +%2 asker | rezerv +%3 | yaricap %4 | varis %5 | %6", _f, round _adet, round _rez, round _yar, _varis, mapGridPosition _poz];
                systemChat format ["[ELITE Cephe] %1: +%2 asker (sanal), rezerv +%3 -> sunucuya gonderildi", _f, round _adet, round _rez];
            }, {}, {}, [_poz, _liste]
        ] call EFUNC(main,showDialog);
    };

    // ------------------------------------------------------------------ PR 1/2
    case 2: {
        [
            "ELITE Cephe: Personnel Replacement 1/2",
            [
                ["Taraf", "LIST", "Ayar bu tarafin TUM factionlarina uygulanir (taraf bazli).", _tarafAd, 0],
                ["Takviye hizi (asker / saat)", "SLIDER", "Taraf basina birikme hizi; 0 = takviye yok. TASARIM DEGERI (varsayilan CBA'dan).", [0, 600], [5, 25], ["cepheTakvHizSaat", 60] call _cba, 0],
                ["Kayiptan takviyeye gecikme (sn)", "SLIDER", "Squad min boyun altina dusunce takviye talebinin isleme alinmasi icin beklenen sure.", [0, 1800], [10, 60], ["cepheTakvGecikmeS", 300] call _cba, 0],
                ["Minimum squad boyu (asker)", "SLIDER", "Canli asker bu sayinin ALTINA dusunce takviye ister; tam kadroya kadar doldurulur.", [1, 12], [1, 1], ["cepheMinSquad", 4] call _cba, 0],
                ["Ayni anda en cok takviye paketi", "SLIDER", "Taraf basina yolda olabilecek paket (konvoy) sayisi.", [1, 10], [1, 1], ["cepheTakvEsZamanli", 2] call _cba, 0]
            ],
            {
                params ["_d", "_args"];
                _args params ["_poz"];
                _d params ["_ti", "_hiz", "_gecikme", "_minS", "_es"];
                [{ params ["_p", "_s", "_a"]; [_p, _s, _a] call (missionNamespace getVariable ["lambs_danger_fnc_cephePanel", {}]); }, [_poz, 3, [round _ti, round _hiz, round _gecikme, round _minS, round _es]]] call CBA_fnc_execNextFrame;
            }, {}, {}, [_poz]
        ] call EFUNC(main,showDialog);
    };

    // ------------------------------------------------------------------ PR 2/2
    case 3: {
        _arg params ["_ti", "_hiz", "_gecikme", "_minS", "_es"];
        [
            "ELITE Cephe: Personnel Replacement 2/2",
            [
                ["Takviye becerisi (yuzde)", "SLIDER", "Takviye askerlerin AI beceri seviyesi (0 = en dusuk, 100 = en yuksek). Mevcut askerlerin becerisini degistirmez.", [0, 100], [5, 10], ["cepheTakvBeceri", 60] call _cba, 0],
                ["Cepheye yakinlik carpani (yuzde)", "SLIDER", "Cephe seridindeki squadlara takviye bu kadar SIK gelir (200 = iki kat; 100 = fark yok; 50 = seyrek).", [25, 400], [25, 100], ["cepheTakvYakinCarpan", 200] call _cba, 0],
                ["Havuz bitince", "LIST", "Rezerv sifirlanip squad eksik kalinca: devam (hicbir sey), bitkin (beceri x0.85), cekil (takviye varis noktasina).", ["Devam", "Bitkin (beceri dusur)", "Cekil (varis noktasina)"], ["cepheHavuzBitince", 0] call _cba],
                ["Konvoy zaiyat olasiligi (yuzde)", "SLIDER", "Takviye paketi dusmana <= 600 m iken 30 sn'de uye basina olum olasiligi (soyut konvoy; A0'da gercek arac yok).", [0, 30], [1, 5], ["cepheKonvoyKayip", 5] call _cba, 0]
            ],
            {
                params ["_d", "_args"];
                _args params ["_ti", "_hiz", "_gecikme", "_minS", "_es"];
                _d params ["_beceri", "_yakin", "_bitince", "_kayip"];
                private _taraf = str ([west, east, independent] select (_ti min 2));
                ["lambs_danger_cepheTakvIstegi", [_taraf, [_hiz, _gecikme, _minS, _es, round _beceri, round _yakin, round _bitince, round _kayip]]] call CBA_fnc_serverEvent;
                systemChat format ["[ELITE Cephe] Personnel Replacement ayari gonderildi: %1 | %2 asker/saat, gecikme %3 sn, min squad %4", _taraf, _hiz, _gecikme, _minS];
            }, {}, {}, [_ti, _hiz, _gecikme, _minS, _es]
        ] call EFUNC(main,showDialog);
    };

    // ------------------------------------------------------------------ durum
    case 4: {
        ["lambs_danger_cepheDurumIstegi", [clientOwner]] call CBA_fnc_serverEvent;
        systemChat "[ELITE Cephe] durum raporu sunucudan isteniyor...";
    };

    // ------------------------------------------------------------------ sil
    case 5: {
        private _liste = call FUNC(cepheFactionListe);
        private _etiket = ["TUM CEPHE (hepsi)"] + (_liste apply { _x select 1 });
        [
            "ELITE Cephe: profilleri SIL",
            [
                ["Faction", "LIST", "Secilen faction'in tum profilleri (fiziksel olanlar dahil askerleri) ve rezervi silinir. GERI ALINAMAZ.", _etiket, 0],
                ["Eminim (silmek icin isaretle)", "BOOLEAN", "Isaretlenmezse hicbir sey silinmez.", false, ""]
            ],
            {
                params ["_d", "_args"];
                _args params ["_liste"];
                _d params ["_fi", "_emin"];
                if (!_emin) exitWith { systemChat "[ELITE Cephe] onay verilmedi - hicbir sey silinmedi"; };
                private _i = round _fi;
                private _f = ["", (_liste select (_i - 1)) select 0] select (_i > 0);
                ["lambs_danger_cepheSilIstegi", [_f]] call CBA_fnc_serverEvent;
                systemChat format ["[ELITE Cephe] silme istegi gonderildi: %1", ["TUM CEPHE", _f] select (_i > 0)];
            }, {}, {}, [_liste]
        ] call EFUNC(main,showDialog);
    };

    // ------------------------------------------------------------------ varis noktasi
    case 6: {
        [
            "ELITE Cephe: takviye varis noktasi",
            [["Taraf", "LIST", "Bu konum secilen tarafin takviye varis noktasi (FOB / HQ) olur; takviye paketleri buradan dogar.", _tarafAd, 0]],
            {
                params ["_d", "_args"];
                _args params ["_poz"];
                private _taraf = str ([west, east, independent] select ((round (_d select 0)) min 2));
                ["lambs_danger_cepheVarisIstegi", [_taraf, _poz]] call CBA_fnc_serverEvent;
                systemChat format ["[ELITE Cephe] takviye varis noktasi gonderildi: %1 | %2", _taraf, mapGridPosition _poz];
            }, {}, {}, [_poz]
        ] call EFUNC(main,showDialog);
    };
    default {};
};

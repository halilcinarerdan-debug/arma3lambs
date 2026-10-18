#include "script_component.hpp"

// ELITE fork (v8.113): "ELITE Objektif" Zeus modulu (LAMBS Danger kategorisi).
// Modulun yerlestirildigi nokta OBJEKTIF'tir. Zeus bir taraf secer, gorev tipini ve duşman hakkinda BILDIKLERINI verir ("sunlar var / sunlar yok");
// en yetkili grup lideri (rutbe) KOMUTAN olur, planlayici (fnc_komutanPlan) arazi tanima + rally point + ORP + destek / manevra / yedek rolleri + waypoint uretir.
// Waypoint'ler gercek (addWaypoint) -> Zeus'ta gorunur ve elle degistirilebilir. Hile yok: plan yalniz burada verilen bilgiye ve gruplarin kendi bildiklerine dayanir.

params ["_logic", "", "_activated"];

// v8.120: panel 20 alanla ekrana sigmiyor, OK / Close erisilemiyordu -> 3 kucuk panel zinciri (7 + 7 + 6 alan).
// Her panel bir oncekinin OK'inda sonraki karede acilir; herhangi birinde Iptal = plan kurulmaz.
if (_activated && local _logic) then {
    private _obj = getPosATL _logic;
    // modul nesnesi hemen silinir (pencere hata verse / kapansa bile modul tekrar tetiklenmez; RPT ffdca817: hata dongusu Zeus'u kilitledi)
    deleteVehicle _logic;
    // v8.178: HQ / US listesi (sunucudan yayinlanan lambs_danger_hqListe): [id, taraf, kategori, poz, yaricap, atanan_grup_sayisi]
    private _hqL = missionNamespace getVariable ["lambs_danger_hqListe", []];
    private _hqSecenekler = ["(secilmedi - ELE GECIR icin zorunlu)"] + (_hqL apply {format ["%1 | %2 | %3 | %4 squad", _x select 2, _x select 1, mapGridPosition (_x select 3), _x select 5]});
    [
        "ELITE Objektif 1/4: gorev",
        [
            ["Taraf", "LIST", "Plani uygulayacak taraf. (SIDE kontrolu yerine LIST: showDialog SIDE hatasi, RPT ffdca817)", ["BLUFOR", "OPFOR", "INDEP"], 0],
            ["Gorev tipi", "LIST", "ELE GECIR: toplan -> ORP -> kesif -> destek + manevra saldirisi -> toparlanma. SAVUN: toplan -> objektif cevresinde sektorlu mevzi + garrison. IPTAL: bu taraftaki aktif plani durdurur.", ["Ele gecir (saldiri)", "Savun (mevzilen)", "IPTAL (aktif plani durdur)", "ONAY VER (bekleyen plani baslat)"], 0],
            ["Tempo / komutan niyeti", "LIST", "Dengeli: normal. Sessiz / gizli: AWARE-STEALTH, yavas, saldiriya kadar ates disiplini (GREEN). Hizli / agresif: tam hiz, kisa kesif.", ["Dengeli", "Sessiz / gizli", "Hizli / agresif"], 0],
            ["Baslama (H-saati)", "LIST", "Plan kurulunca ne zaman harekete gecilsin. 'Zeus onayi': plan kurulur, harita isaretleri cikar, siz 'ONAY VER' modulunu koyana kadar beklenir.", ["Hemen", "30 sn", "60 sn", "120 sn", "300 sn", "Zeus onayi bekle"], 0],
            ["Sure siniri", "LIST", "ELE GECIR: toplam sure dolunca (hedef alinmadiysa) CEKILME. SAVUNMA: TEMASSIZ sure - son temas / bilinen dusmandan beri bu kadar sure HIC temas olmazsa savunma biter (temas surerken bitmez). Sinirsiz = Zeus iptal edene kadar.", ["Sinirsiz", "10 dk", "20 dk", "30 dk", "45 dk", "1 saat", "2 saat", "4 saat", "10 saat"], 0],
            ["Komuta noktasi (HQ / US)", "LIST", "Plan bu HQ / US kategorisinden baslar; katilacak squadlar YALNIZ bu kategoriye atananlardir (ELITE HQ / US Kur). ELE GECIR icin ZORUNLU. Iptal / basarisizlikta gruplar buraya doner.", _hqSecenekler, 0],
            ["Katilacak grup sayisi", "SLIDER", "Otomatik secimde: en yetkili (rutbe) ve en yakin gruplardan secilir; en yuksek rutbeli lider KOMUTAN olur.", [1, 8], [1, 1], 4, 0],
            ["Grup secimi", "LIST", "Otomatik: yukaridaki sayiya gore. Elle: panellerin sonunda squad listesi acilir, katilacaklari siz isaretlersiniz (mesafe siniri yok). HQ TAMAMI: secilen HQ / US'ye bagli TUM squadlar ve HQ yaricapinin cevresindeki karakol garnizonlari (nobet / devriye serbest birakilir, garnizon ayari silinir) ile birlikte saldirir - sayi sinirsiz; 'guvenlik birakilir' en zayif squadi HQ'da tutar (cevre emniyeti, MCWP 3-11.1); 'hepsi' hicbirini birakmaz. Savunma plani altindaki mevzi squadlari da alinir (o savunma plani durdurulur).", ["Otomatik (sayi)", "Elle sec (liste)", "HQ TAMAMI (guvenlik birakilir)", "HQ TAMAMI (hepsi)"], 0]
        ],
        {
            params ["_data", "_args"];
            _args params ["_obj"];
            [{
                params ["_obj", "_d1"];
                [
                    "ELITE Objektif 2/4: duşman bilgisi",
                    [
                        ["Duşman: piyade var", "BOOLEAN", "Objektifte duşman piyadesi var.", true, ""],
                        ["Duşman: zirh / arac var", "BOOLEAN", "Tank / APC / teknik var. Isaretli degilse: ZIRH YOK (AT esikligi gerekmez).", false, ""],
                        ["Duşman: AT / RPG var", "BOOLEAN", "Roketatar / fuze tasiyan duşman var.", false, ""],
                        ["Duşman: MG var", "BOOLEAN", "Makineli tufek var -> cepheden saldirma yerine kanat manevrasi (2+ grup varsa).", false, ""],
                        ["Duşman: nisanci var", "BOOLEAN", "Keskin nisanci / nisanci var.", false, ""],
                        ["Duşman: binalarda / mevzili", "BOOLEAN", "Binalarda veya hazir mevzilerde (CQB / bina temizleme beklenir).", false, ""],
                        ["Duşman sayisi (tahmin)", "SLIDER", "0 = bilinmiyor.", [0, 60], [1, 5], 0, 0]
                    ],
                    {
                        params ["_data", "_args"];
                        _args params ["_obj", "_d1"];
                        [{
                            params ["_obj", "_d1", "_d2"];
                            [
                                "ELITE Objektif 3/4: kisit / mesafe",
                                [
                                    ["Kisit: siviller var (ROE siki)", "BOOLEAN", "Destek grubu korleme baski atesi yapmaz; yalniz gorulen duşmana ates (YELLOW).", false, ""],
                                    ["Kisit: binalara agir silah / bomba yasak", "BOOLEAN", "Binadaki hedefe roket / fuze / 40 mm / bomba atilmaz (mermi iptal, [PLAN-ROE]).", false, ""],
                                    ["Rally point mesafesi (m)", "SLIDER", "Toplanma noktasi objektiften bu kadar geride, ortulu.", [250, 900], [10, 50], 450, 0],
                                    ["ORP mesafesi (m)", "SLIDER", "Objektif toplanma noktasi. KAYNAK: TC 3-21.76 s. 7-15: ORP tipik olarak objektiften 200-400 m (veya en az bir buyuk arazi ogesi geride); sinirli gorusta 100-200 m (s. 7-20). Ses ve gorus disinda olmali.", [100, 400], [10, 25], 300, 0],
                                    ["Baskin (vur-cek)", "LIST", "Hayir: hedef alinirsa toparlanma + cevre savunmasi. Evet: hedef temizlenince ya da sure dolunca CEKILME (karakol baskini / vur-cek canlandirmasi). Sure saldiri basladigindan itibaren.", ["Hayir (ele gecir)", "Evet: 5 dk", "Evet: 10 dk"], 0],
                                    ["Tehdit yonu (savunma)", "LIST", "Duşmanin objektife geldigi yon (objektiften duşmana). Savunma sektorleri bu yone yogunlasir; MG / destek grubu tam karsisinda.", ["Bilinmiyor", "Kuzey", "Kuzeydogu", "Dogu", "Guneydogu", "Guney", "Guneybati", "Bati", "Kuzeybati"], 0],
                                    ["Toplanma noktasi (dost karakol / mevzi)", "LIST", "Otomatik: arazi analizi objektiften geride ortulu bir nokta secer (haritada dusman mevzisine denk gelebilir). Isaretli nokta: haritadaki dost 'ELITE Karakol / Mevzi / Gozetleme' noktasi toplanma (RP) olur.", ["Otomatik (arazi analizi)"] + (([(allMapMarkers select {(_x find format ["ELITE_KARAKOL_%1_", str ([west, east, independent] select (((_d1 select 0) max 0) min 2))]) isEqualTo 0}), [], {(markerPos _x) distance2D _obj}, "ASCEND"] call BIS_fnc_sortBy) apply { format ["%1 [%2]", markerText _x, mapGridPosition (markerPos _x)] }), 0]
                                ],
                                {
                                    params ["_data", "_args"];
                                    _args params ["_obj", "_d1", "_d2"];
                                    [{
                                        params ["_obj", "_d1", "_d2", "_d3"];
                                        [
                                            "ELITE Objektif 4/4: istihbarat / ates destegi",
                                            [
                                                ["Bilgi guvenilirligi (iddia)", "LIST", "Komutanin ELINDEKI bilgi: Yetersiz = iddia var, delil yok (komutan cok temkinli: gizli tempo, uzun kesif); Orta = tek kaynak; Kesin = 'kesin' deniyor AMA yine IDDIA: gercek sahne (sayi, sivil) komutandan gizlidir ve farkli olabilir.", ["Yetersiz (iddia var, delil yok)", "Orta (tek kaynak)", "Kesin (ama yine iddia)"], 1],
                                                ["Dogrulama disiplini", "LIST", "Tam kesif: gozlem raporu gelmeden topcu atmaz; sivil gozlenirse atis iptal (PID). Son dogrulama: kisa gozlem (30-45 sn), sonra atis. YOK: komutan iddiaya guvenir, dogrulamadan atar / saldirir - yanlis istihbaratla sivil / dost kaybi canlandirmasi ([PLAN-ZARAR] AAR).", ["Tam kesif", "Son dogrulama (kisa)", "YOK (iddiaya guvenilir)"], 0],
                                                ["Ates destegi (topcu / havan)", "LIST", "Tarafin topcu / havan araclari (artilleryScanner) kullanilir. Hazirlik: kesiften sonra saldiriya kadar objektife. Cagri: saldiri basinda ve objektif temizlenmezse. Dost mesafesi < RED (TC 3-21.76 Tablo 3-3: 60 mm ~145, 82 mm ~195, 120 mm ~430, 105 / 155 mm ~455 m) ise o arac ATMAZ; <= 600 m: DANGER CLOSE loglanir. Topcu yoksa atlanir.", ["Yok", "Hazirlik atesi", "Cagri atesi", "Hazirlik + cagri"], 0],
                                                ["Topcu atis sayisi (mermi)", "SLIDER", "Atis seansi basina mermi.", [1, 12], [1, 2], 4, 0],
                                                ["Topcu modu", "LIST", "Standart: Dogrulama disiplini ve dost mesafesi (RED) kurallari uygulanir. BASIT: dogrulama beklenmez, plan baslar baslamaz (topcu menzile girdiginde) objektife atar; yalniz dost mesafesi (RED) ve menzil kurallari kalir. Topcu 'yok' ise etkisiz.", ["Standart (dogrulamali)", "BASIT (dogrulamasiz, hemen)"], 0],
                                                ["Hedef zinciri (cephe)", "LIST", "Hayir: bagimsiz plan. Zincire ekle: AYNI taraftaki AKTIF ele gecir planinin SIRADAKI hedefi olur; plan objektifi alinca (OBJEKTIF ALINDI) hayatta kalan gruplar duzenlenip siradaki hedefe otomatik ilerler (tek tek yeni plan kurmadan, cephe hatti ilerler). Aktif plan yoksa normal plan kurulur.", ["Hayir (bagimsiz plan)", "Zincire ekle (siradaki hedef)"], 0],
                                                ["Recon: ek gozlem (dusman noktalari)", "LIST", "Hayir: recon yalniz objektif gozlem noktasina gider. Evet: objektifin 2 km icindeki DUSMAN karakol / mevzi / gozetleme noktalarini da sirayla gizlice (STEALTH, ates yok) gozlemler ve raporlar.", ["Hayir", "Evet (gizlice incele)"], 0]
                                            ],
                                            {
                                                params ["_data", "_args"];
                                                _args params ["_obj", "_d1", "_d2", "_d3"];
                                                _d1 params ["_tarafI", "_tip", "_tempo", "_basla", "_sure", "_hqI", "_grupN", "_secimModu"];   // alan sirasi: Taraf, Gorev tipi, Tempo, Baslama, Sure, HQ / US, Grup sayisi, Grup secimi
                                                _d2 params ["_piy", "_zrh", "_at", "_mg", "_nis", "_bina", "_say"];
                                                _d3 params ["_sivil", "_agir", "_rally", "_orp", "_baskin", "_tehditY", ["_rpIsaretI", 0]];
                                                _data params ["_guven", "_dogr", "_topcu", "_topcuN", ["_topcuBasit", 0], ["_zincir", 0], ["_reconEk", 0]];
                                                private _taraf = [west, east, independent] select (_tarafI max 0 min 2);
                                                // v8.178 HQ DOGRULAMA (kullanici hatasi korumasi): ELE GECIR icin HQ / US zorunlu; secilen HQ'nun tarafi plan tarafi ile ayni olmali
                                                private _hqLi = missionNamespace getVariable ["lambs_danger_hqListe", []];
                                                private _hq = if (_hqI > 0 && {_hqI <= count _hqLi}) then {_hqLi select (_hqI - 1)} else {[]};
                                                if (_tip isEqualTo 0 && {_hq isEqualTo []}) exitWith {
                                                    systemChat "[ELITE] HATA: ELE GECIR icin bir HQ / US secin (once 'ELITE HQ / US Kur' modulu ile kurup squad atayin). Plan kurulmadi.";
                                                    diag_log "[PLAN-ISTEK] reddedildi: HQ / US secilmedi";
                                                };
                                                if (_hq isNotEqualTo [] && {(_hq select 1) isNotEqualTo (str _taraf)}) exitWith {
                                                    systemChat format ["[ELITE] HATA: secilen %1 (%2) ile plan tarafi (%3) ayni degil. Plan kurulmadi.", _hq select 2, _hq select 1, str _taraf];
                                                    diag_log format ["[PLAN-ISTEK] reddedildi: HQ tarafi %1 != plan tarafi %2", _hq select 1, str _taraf];
                                                };
                                                private _rpIsaret = "";
                                                if (_rpIsaretI > 0) then {
                                                    private _mkL = [(allMapMarkers select {(_x find format ["ELITE_KARAKOL_%1_", str _taraf]) isEqualTo 0}), [], {(markerPos _x) distance2D _obj}, "ASCEND"] call BIS_fnc_sortBy;
                                                    _rpIsaret = _mkL param [_rpIsaretI - 1, ""];
                                                };
                                                private _ayar = createHashMapFromArray [
                                                    ["hqId", if (_hq isEqualTo []) then {""} else {format ["%1_%2", _hq select 2, _hq select 1]}],
                                                    ["tip", _tip], ["grupN", round _grupN], ["tumHQ", _secimModu in [2, 3]], ["tumHQGuvenlik", _secimModu isEqualTo 2], ["piyade", _piy], ["zirh", _zrh], ["at", _at], ["mg", _mg], ["nisanci", _nis], ["bina", _bina],
                                                    ["sayi", round _say], ["rallyM", round _rally], ["orpM", round _orp], ["baskin", _baskin], ["guven", _guven], ["dogrulama", _dogr],
                                                    ["tempo", _tempo], ["basla", _basla], ["sure", _sure], ["tehditY", _tehditY], ["sivil", _sivil], ["agirYasak", _agir], ["topcu", _topcu], ["topcuN", round _topcuN], ["topcuBasit", _topcuBasit], ["zincir", _zincir isEqualTo 1], ["reconEk", _reconEk isEqualTo 1], ["rpIsaret", _rpIsaret]
                                                ];
                                                // v8.150: Elle grup secimi (yalniz ele gecir / savun): squad listesi paneli, secilenler "secili" ile gonderilir
                                                if (_secimModu isEqualTo 1 && {_tip in [0, 1]}) exitWith {
                                                    // v8.162: 4/4 paneli kapanirken ayni karede yeni dialog acilamiyordu ("4/4'ten sonra yok"); diger paneller gibi sonraki karede ac
                                                    [{
                                                        params ["_taraf", "_obj", "_ayar"];
                                                        [_taraf, _obj, _ayar] call (missionNamespace getVariable ["lambs_danger_fnc_objektifGrupSec", {systemChat "[ELITE] objektifGrupSec fonksiyonu bu istemcide yuklu degil (eski mod surumu?)"; diag_log "[PLAN-ISTEK] objektifGrupSec TANIMSIZ (istemci eski surum)";}]);
                                                    }, [_taraf, _obj, _ayar]] call CBA_fnc_execNextFrame;
                                                };
                                                // Zeus modulu curator'un makinesinde calisir; plan gruplarin yerel oldugu SUNUCUDA kurulur (CBA sunucu olayi; HashMap -> cift listesi)
                                                ["lambs_danger_planIstegi", [_taraf, _obj, _ayar toArray false]] call CBA_fnc_serverEvent;
                                                diag_log format ["[PLAN-ISTEK] sunucuya gonderildi: %1 | tip %2 | %3 | guven %4 dogrulama %5", _taraf, _tip, mapGridPosition _obj, _guven, _dogr];
                                                systemChat "[ELITE] Plan istegi sunucuya gonderildi - yanit gelmezse sunucuda mod yuklu / surum ayni degil";
                                            }, {}, {}, [_obj, _d1, _d2, _d3]
                                        ] call EFUNC(main,showDialog);
                                    }, [_obj, _d1, _d2, _data]] call CBA_fnc_execNextFrame;
                                }, {}, {}, [_obj, _d1, _d2]
                            ] call EFUNC(main,showDialog);
                        }, [_args select 0, _args select 1, _data]] call CBA_fnc_execNextFrame;
                    }, {}, {}, [_obj, _d1]
                ] call EFUNC(main,showDialog);
            }, [_obj, _data]] call CBA_fnc_execNextFrame;
        }, {}, {}, [_obj]
    ] call EFUNC(main,showDialog);
};

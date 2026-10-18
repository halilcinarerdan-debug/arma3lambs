#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KOMUTAN PLANI (v8.113) — kullanici: "dinamik patrol / arazi tanima / harekat plani / garrison / rally point; waypoint otomatik, Zeus'ta gorunsun; Zeus objektif + 'duşmanda sunlar var / yok' versin; komutan kitaba gore hareket etsin".
 * Kitap (kaynaklar_doktrin/TC_3-21.76 Ranger Handbook, MCWP 3-11.1 / 3-11.2): Troop Leading Procedures (gorevi al, tahmini plan, harekete basla, kesif, plani tamamla, emir ver, denetle), rally point / objective rally point (ORP),
 *   destek (support by fire) + manevra (assault) + yedek (reserve), kanat saldirisi, toparlanma (consolidate and reorganize). SAYISAL ESIKLER: KAYNAKLI = ORP 200-400 m (sinirli gorusta 100-200 m), TC 3-21.76 s. 7-15 / 7-20; rally point nitelikleri (ortulu, yol / akin yolu disi, kisa sure savunulabilir) s. 7-14; DANGER CLOSE <= 600 m + RED mesafeleri (Tablo 3-3) topcu icin. Digerleri (RP mesafesi 450 m, kanat 110 m, SBF 160-300 m, keşif 40 sn, 150 sn bekleme) TASARIM tahminidir, kitapta sayi YOK.
 * ISLEYIS (ELE GECIR): TOPLAN (RP'ye) -> ORP (manevra: ORP, destek: destek noktasi) -> KESIF (40 sn guvenlik) -> SALDIRI (destek ates + manevra [>= 2 grupta kanat noktalari] + hqEmir SALDIRI) -> TOPLANMA (cevre savunmasi + fnc_toparlan) -> BITTI.
 *   SAVUN: TOPLAN -> MEVZI (objektif cevresinde sektorlu halka noktalari; binalar varsa tacticsGarrison) -> BEKLE (sure sinirli).
 * KOMUTAN: katilan gruplar arasinda en yuksek rutbeli lider (esitlikte buyuk grup); >= 3 grupta komutan destek noktasinda (gorus). Roller: DESTEK (MG / AT / nisanci puani en yuksek), MANEVRA, YEDEK.
 * DUSMAN BILGISI (Zeus): piyade / zirh / AT / MG / nisanci / bina + sayi. Kullanim: destek puani (MG, AT [zirh varsa x3]), kanat gerekliligi (MG, bina veya sayi >= 8), loglanan uyarilar (zirh var + AT'li grup yok). HILE YOK: gizli konum okunmaz.
 * CIKTI: gercek waypoint (addWaypoint; "ELITE PLAN: ..." adli; Zeus'ta gorunur ve degistirilebilir) + harita isaretleri (ELITE_PLAN_*). Zeus'un elle koydugu waypoint SILINMEZ (yalniz kendi waypoint'lerimiz).
 * Temas: grup temastaysa plan o grubu zorlamaz (LAMBS / komutan beyni yonetir); temas kesilince plan devam eder.
 * Kapatma: lambs_danger_komutanPlanOff = true.  Log: [PLAN] (KURULDU / FAZ / ROL / BITTI / IPTAL).
 *
 * Arguments:
 * 0: Taraf <SIDE>
 * 1: Objektif pozisyonu <ARRAY>
 * 2: Ayarlar <HASHMAP> (tip 0 ele gecir / 1 savun / 2 iptal, grupN, piyade, zirh, at, mg, nisanci, bina, sayi, rallyM, orpM)
 *
 * Return Value: Plan kuruldu mu <BOOL>
 * Public: No
*/

params [["_taraf", sideUnknown, [sideUnknown]], ["_obj", [0, 0, 0], [[]]], ["_ayar", createHashMap, [createHashMap]]];

if (missionNamespace getVariable ["lambs_danger_komutanPlanOff", false]) exitWith {false};
if (isNil "lambs_danger_planlar") then { lambs_danger_planlar = createHashMap; };

private _tip = _ayar getOrDefault ["tip", 0];

// v8.214 HEDEF ZINCIRI (yol haritasi 6; Ukrayna tarzi sirali hedefler): "zincir" istegi ayni taraftaki AKTIF ele gecir planinin sirasina eklenir; plan objektifi alinca siradaki hedefe otomatik gecilir (fnc_komutanPlanDongu BITTI blogu)
private _zincirAna = createHashMap;
if (_tip isEqualTo 0 && {_ayar getOrDefault ["zincir", false]}) then {
    private _adaylar = (values lambs_danger_planlar) select {(_x get "taraf") isEqualTo _taraf && {(_x getOrDefault ["tip", 0]) isEqualTo 0} && {!((_x getOrDefault ["faz", ""]) in ["BITTI", "IPTAL", "DONUS", "CEKILME", "TOPLANMA"])}};
    if (_adaylar isNotEqualTo []) then { _zincirAna = _adaylar select 0; };
};
if (count _zincirAna > 0) exitWith {
    private _kuyruk = _zincirAna getOrDefault ["zincir", []];
    _kuyruk pushBack [+_obj, +_ayar];
    _zincirAna set ["zincir", _kuyruk];
    diag_log format ["[PLAN-ZINCIR] %1 | siradaki hedef eklendi: %2 (zincir %3 hedef)", _zincirAna get "id", mapGridPosition _obj, count _kuyruk];
    systemChat format ["[ELITE] Plan %1 icin siradaki hedef eklendi: %2 (toplam %3)", _zincirAna get "id", mapGridPosition _obj, count _kuyruk];
    true
};

// v8.175 COKLU PLAN ENGELI (kullanici: "ayni yere birden fazla hq / mevzi koyamayalim"): ayni taraf + ayni tur icin 150 m icinde AKTIF plan ya da son 20 sn'de baslayan istek varsa yenisi kurulmaz
if (_tip in [0, 1]) then {
    if (isNil "lambs_danger_planRezerv") then { lambs_danger_planRezerv = []; };
    lambs_danger_planRezerv = lambs_danger_planRezerv select {(time - (_x select 3)) < 20};
    private _cift = (lambs_danger_planRezerv findIf {(_x select 0) isEqualTo _taraf && {(_x select 2) isEqualTo _tip} && {((_x select 1) distance2D _obj) < 150}}) >= 0;
    if (!_cift && {(count lambs_danger_planlar) > 0}) then {
        _cift = ((values lambs_danger_planlar) findIf {
            (_x get "taraf") isEqualTo _taraf && {((_x get "obj") distance2D _obj) < 150} && {(_x getOrDefault ["tip", 0]) isEqualTo _tip} && {!((_x get "faz") in ["BITTI", "IPTAL"])}
        }) >= 0;
    };
    if (_cift) exitWith {
        diag_log format ["[PLAN] KURULAMADI: %1 icin ayni noktada (150 m) zaten %2 plani var / kuruluyor (cift plan engellendi)", _taraf, ["ELE GECIR", "SAVUN"] select (_tip isEqualTo 1)];
        missionNamespace setVariable ["lambs_danger_planRedNeden", format ["bu noktada (150 m) zaten bir %1 plani var - once ELITE Objektif -> IPTAL ile durdurun", ["ELE GECIR", "SAVUN"] select (_tip isEqualTo 1)]];
        systemChat "[ELITE] Bu noktada zaten ayni turde plan var - yenisi kurulmadi";
        false
    };
    lambs_danger_planRezerv pushBack [_taraf, +_obj, _tip, time];
};

// ---------------------------------------------------------------------------
// IPTAL: bu taraftaki aktif planlari durdur
// ---------------------------------------------------------------------------
if (_tip isEqualTo 2) exitWith {
    private _n = 0;
    {
        private _p = _y;
        if ((_p get "taraf") isEqualTo _taraf) then {
            // v8.178: HQ / US'ten baslayan plan iptal edilirse gruplar ve araclar HQ'ya geri doner (DONUS fazi); HQ'suz plan eskisi gibi hemen IPTAL
            if ((_p getOrDefault ["hqPoz", []]) isNotEqualTo [] && {!((_p getOrDefault ["faz", ""]) in ["DONUS", "BITTI", "IPTAL"])}) then {
                _p set ["faz", "DONUS"];
                _p set ["fazT", time];
                _p set ["fazBasT", time];
                _p set ["donusNeden", "Zeus IPTAL"];
            } else {
                _p set ["faz", "IPTAL"];
            };
            _n = _n + 1;
        };
    } forEach lambs_danger_planlar;
    diag_log format ["[PLAN] IPTAL: %1 tarafinin %2 plani durduruldu", _taraf, _n];
    _n > 0
};

// ONAY VER: Zeus onayi bekleyen plani baslat
if (_tip isEqualTo 3) exitWith {
    private _n = 0;
    {
        private _p = _y;
        if ((_p get "taraf") isEqualTo _taraf && {_p getOrDefault ["bekleOnay", false]}) then {
            _p set ["bekleOnay", false];
            _n = _n + 1;
        };
    } forEach lambs_danger_planlar;
    diag_log format ["[PLAN] ONAY: %1 tarafinin %2 plani onaylandi", _taraf, _n];
    _n > 0
};

// ---------------------------------------------------------------------------
// KATILAN GRUPLAR: taraf, yerel, AI lider, >= 3 asker, baska plana bagli degil, objektife <= 4000 m; en yuksek rutbe + buyuk grup + yakin
// ---------------------------------------------------------------------------
// v8.178 HQ / US: ELE GECIR bir komuta noktasindan baslar; katilacak gruplar o kategoriye atananlardir
private _hqId = _ayar getOrDefault ["hqId", ""];
private _hqKayit = [];
if (_hqId isNotEqualTo "" && {!isNil "lambs_danger_hqlar"}) then {
    private _hqi = lambs_danger_hqlar findIf {(_x select 0) isEqualTo _hqId};
    if (_hqi >= 0) then { _hqKayit = lambs_danger_hqlar select _hqi; };
};
if (_tip isEqualTo 0 && {_hqKayit isEqualTo []} && {missionNamespace getVariable ["lambs_danger_hqZorunlu", true]}) exitWith {
    diag_log format ["[PLAN] KURULAMADI: %1 icin ELE GECIR bir HQ / US gerektirir (secilen: '%2'); once 'ELITE HQ / US Kur' modulu", _taraf, _hqId];
    missionNamespace setVariable ["lambs_danger_planRedNeden", "ELE GECIR icin bir HQ / US secilmeli (once 'ELITE HQ / US Kur' modulu)"];
    false
};
if (_hqKayit isNotEqualTo [] && {(_hqKayit select 1) isNotEqualTo _taraf}) exitWith {
    diag_log format ["[PLAN] KURULAMADI: HQ %1 tarafi (%2) plan tarafi (%3) ile ayni degil", _hqId, _hqKayit select 1, _taraf];
    missionNamespace setVariable ["lambs_danger_planRedNeden", format ["secilen HQ / US (%1) baska bir tarafa ait (%2)", _hqId, _hqKayit select 1]];
    false
};
private _grupN = _ayar getOrDefault ["grupN", 4];
// v8.199 HQ TAMAMI (kullanici: "hq lar mevziler karakollar butun halde objektife saldirabilsin"): HQ'ya bagli TUM squadlar + cevredeki karakol garnizonlari + ayni HQ'nun savunma plani mevzi squadlari
private _tumHQ = (_ayar getOrDefault ["tumHQ", false]) && {_hqKayit isNotEqualTo []} && {_tip isEqualTo 0};
if (_tumHQ) then {
    private _hqP = _hqKayit select 2;
    private _hqY = (_hqKayit select 4) max 300;
    private _serbestFn = missionNamespace getVariable ["lambs_danger_garnizonSerbestFn", {}];
    {
        _x params ["_kt", "_kp", "_ky", "_kad", "_ksav", "_kmn"];
        if (_kt isEqualTo _taraf && {(_kp distance2D _hqP) < (_hqY * 1.5 + 200)}) then {
            [_kmn] call _serbestFn;
            if (!isNil "lambs_danger_karakolAyar") then { lambs_danger_karakolAyar deleteAt _kmn; };
            diag_log format ["[PLAN-HQ-TUM] %1 | karakol %2 garnizonu serbest birakildi (garnizon ayari silindi)", _hqId, _kad];
        };
    } forEach (missionNamespace getVariable ["lambs_danger_karakollar", []]);
    {
        private _p = _y;
        if ((_p get "taraf") isEqualTo _taraf && {(_p getOrDefault ["hqId", ""]) isEqualTo _hqId} && {(_p getOrDefault ["tip", 0]) isEqualTo 1} && {!((_p getOrDefault ["faz", ""]) in ["BITTI", "IPTAL", "DONUS"])}) then {
            { _x setVariable ["lambs_danger_planAktif", nil, true]; } forEach (_p getOrDefault ["gruplar", []]);
            _p set ["gruplar", []];
            _p set ["faz", "IPTAL"];
            diag_log format ["[PLAN-HQ-TUM] %1 | savunma plani %2 durduruldu, mevzi squadlari saldiriya alindi", _hqId, _p getOrDefault ["id", "?"]];
        };
    } forEach lambs_danger_planlar;
    _grupN = 99;
};
// v8.150: Zeus elle sectiyse yalniz bu gruplar (netId listesi); mesafe sinirina bakilmaz
private _secili = _ayar getOrDefault ["secili", []];
// v8.163: secilen ARAC gruplari (lider kara aracinda): tank / zirhli -> plan ZIRH DESTEK unsuru (zirhG); tasima kapasiteli arac (kargo >= 3) -> TASIMA gorevi (nakilde oncelikli). Piyade secimi eskisi gibi.
private _zirhG = [];
private _tasG = [];   // v8.166: secilen tasima araci gruplari (sunucuya devredilir; RPT 8640024e: surucu sunucuda yerel degildi, arac hic kipirdamadi)
if (_secili isNotEqualTo []) then {
    private _yayaSec = [];
    {
        private _sg = groupFromNetId _x;
        private _sl = if (isNull _sg) then {objNull} else {leader _sg};
        private _sv = if (isNull _sl) then {objNull} else {objectParent _sl};
        if (!isNull _sv && {_sv isKindOf "LandVehicle"} && {alive _sv}) then {
            private _sinifA = [_sv] call FUNC(aracSinif);
            private _tasiyici = (_sinifA select 0) in ["IFV", "APC", "KAMYON"];
            if ((_sinifA select 0) isEqualTo "TOPCU") then {
                diag_log format ["[PLAN-ARAC] %1 | %2 [TOPCU] plana KATILMAZ (topcu ayri atis destegi olarak calisir; secimden cikarildi)", groupId _sg, getText (configOf _sv >> "displayName")];
            } else {
            if (_tasiyici) then {
                _tasG pushBack _sg;
                _sg setVariable ["lambs_danger_gorev", "TASIMA", true];
                _sv setVariable ["lambs_danger_gorev", "TASIMA", true];
                _sv setVariable ["lambs_danger_ekipGrup", _sg, true];
                diag_log format ["[PLAN-ARAC] %1 | %2 [%3] TASIMA araci olarak secildi%4 (Zeus elle secim)", groupId _sg, getText (configOf _sv >> "displayName"), _sinifA select 0, [" (savas taksisi: indirir, geride rezerv)", " (IFV: indirdikten sonra ates destegi)"] select ((_sinifA select 0) isEqualTo "IFV")];
            } else {
                _zirhG pushBack _sg;
                diag_log format ["[PLAN-ARAC] %1 | %2 [%3] ZIRH DESTEK unsuru olarak secildi (Zeus elle secim)", groupId _sg, getText (configOf _sv >> "displayName"), _sinifA select 0];
            };
            };
        } else {
            _yayaSec pushBack _x;
        };
    } forEach _secili;
    _secili = _yayaSec;
    _grupN = count _secili;
    if (_secili isEqualTo []) then { _secili = ["-"]; };   // yalniz arac secildiyse piyade adayi yok (mesafe sinirina dusmesin)
};
// v8.246 OTOMATIK TANK (kullanici RPT b8f696ff: savunma/saldiri planinda 'tank objektife gitmedi'; otomatik secimde yalniz piyade aday oluyordu (lider aracta degil sarti), tank yalniz Zeus elle secimle plana girerdi):
//   elle secim YOKSA, taraftaki TANK sinifi (aracSinif) AI gruplari (lider tankta, oyuncusuz, gorev HARIC / TOPCU / TASIMA / RECON ... degil, baska planda degil, objektife <= grupMesafe) ZIRH DESTEK unsuru olur.
//   Zeus 'Gozetleme' atamasi gorevi HARIC yapar -> o tank plana ALINMAZ. IFV / APC ve topcu otomatik alinmaz (tasima / atis destegi ayri). Kapatma: lambs_danger_planOtoTankOff = true
if (_secili isEqualTo [] && {!(missionNamespace getVariable ["lambs_danger_planOtoTankOff", false])}) then {
    {
        private _tl = leader _x;
        private _tv = if (isNull _tl) then {objNull} else {objectParent _tl};
        if (!isNull _tv && {alive _tl} && {!isPlayer _tl} && {(side _x) isEqualTo _taraf} && {_tv isKindOf "LandVehicle"} && {alive _tv} && {(crew _tv) findIf {isPlayer _x} < 0}
            && {!(_x getVariable ["lambs_danger_tarafKapali", false])} && {!(_x getVariable ["lambs_danger_planAktif", false])}
            && {!((_x getVariable ["lambs_danger_gorev", ""]) in ["HARIC", "MEDEVAC", "TOPCU", "TOPCU_YOK", "TASIMA", "KARAKOL_ARAC", "RECON", "RECON_ARAC"])}
            && {_hqKayit isEqualTo [] || {(_x getVariable ["lambs_danger_hqId", ""]) isEqualTo _hqId}}
            && {(_tl distance2D _obj) <= (_ayar getOrDefault ["grupMesafe", 4000])}
            && {(([_tv] call FUNC(aracSinif)) select 0) isEqualTo "TANK"}) then {
            _zirhG pushBack _x;
            diag_log format ["[PLAN-ARAC] %1 | %2 [TANK] ZIRH DESTEK unsuru olarak OTOMATIK alindi (objektife %3 m)", groupId _x, getText (configOf _tv >> "displayName"), round (_tl distance2D _obj)];
        };
    } forEach allGroups;
};
private _aday = allGroups select {
    private _l = leader _x;
    !isNull _l && {alive _l} && {!isPlayer _l} && {(side _x) isEqualTo _taraf}
    && {({isPlayer _x} count (units _x)) isEqualTo 0}
    && {({alive _x && {(lifeState _x) in ["HEALTHY", "INJURED"]}} count (units _x)) >= 3}
    && {!(_x getVariable ["lambs_danger_tarafKapali", false])} && {!(_x getVariable ["lambs_danger_planAktif", false])}
    && {!((_x getVariable ["lambs_danger_gorev", ""]) in ["HARIC", "MEDEVAC", "TOPCU", "TOPCU_YOK", "TASIMA", "KARAKOL_ARAC", "RECON", "RECON_ARAC"])}
    && {(_x getVariable ["lambs_danger_garnizonAlt", ""]) isEqualTo ""}
    && {_hqKayit isEqualTo [] || {(_x getVariable ["lambs_danger_hqId", ""]) isEqualTo _hqId}}
    && {isNull objectParent _l} && {(_secili isEqualTo [] && {_hqKayit isNotEqualTo [] || {(_l distance2D _obj) <= (_ayar getOrDefault ["grupMesafe", 4000])}}) || {(netId _x) in _secili}}
};
if (_aday isEqualTo []) exitWith {
    // v8.161 TANI (elle secim): secilen her grubun neden elendigi tek tek
    if (_secili isNotEqualTo []) then {
        {
            private _sg = groupFromNetId _x;
            if (isNull _sg) then {
                diag_log format ["[PLAN] KURULAMADI (elle secim): netId %1 -> GRUP YOK (bu makinede bulunamadi)", _x];
            } else {
                private _sl = leader _sg;
                diag_log format ["[PLAN] KURULAMADI (elle secim): %1 (%2) | istenen taraf %3 | lider %4 (oyuncu %5) | saglam asker %6 | gorev '%7' | planAktif %8 | tarafKapali %9 | garnizonAlt '%10' | aracta %11 | yerel %12",
                    groupId _sg, side _sg, _taraf, if (isNull _sl) then {"yok"} else {name _sl}, !isNull _sl && {isPlayer _sl},
                    {alive _x && {(lifeState _x) in ["HEALTHY", "INJURED"]}} count (units _sg), _sg getVariable ["lambs_danger_gorev", ""], _sg getVariable ["lambs_danger_planAktif", false],
                    _sg getVariable ["lambs_danger_tarafKapali", false], _sg getVariable ["lambs_danger_garnizonAlt", ""], !isNull _sl && {!isNull objectParent _sl}, local _sg];
            };
        } forEach _secili;
    };
    // v8.121 TANI: her gruptan hangi filtre ilk elediyse say (neden belli olsun)
    private _tum = allGroups select {(side _x) isEqualTo _taraf};
    private _red = createHashMap;
    private _enYakin = 1e9;
    {
        private _l = leader _x;
        private _n = ({alive _x && {(lifeState _x) in ["HEALTHY", "INJURED"]}} count (units _x));
        private _neden = if (isNull _l || {!alive _l}) then {"lider yok / olu"}
            else {if (!local _x) then {"grup bu makinede yerel degil (sahibi baska makine / HC)"}
            else {if (isPlayer _l) then {"lider oyuncu"}
            else {if (({isPlayer _x} count (units _x)) > 0) then {"grupta oyuncu var"}
            else {if (_n < 3) then {"3'ten az saglam asker"}
            else {if (_x getVariable ["lambs_danger_tarafKapali", false]) then {"ELITE bu taraf icin kapali"}
            else {if (_x getVariable ["lambs_danger_planAktif", false]) then {"baska planda"}
            else {if (!isNull objectParent _l) then {"lider aracta"}
            else {if ((_l distance2D _obj) > 4000) then {"objektife > 4000 m"} else {"?"}}}}}}}}};
        _red set [_neden, (_red getOrDefault [_neden, 0]) + 1];
        if (!isNull _l) then { _enYakin = _enYakin min (_l distance2D _obj); };
    } forEach _tum;
    diag_log format ["[PLAN] KURULAMADI: %1 icin uygun grup yok | taraftaki grup:%2 | elenme nedenleri: %3 | objektife en yakin lider: %4 m | sunucu: isServer=%5", _taraf, count _tum, _red toArray false, round _enYakin, isServer];
    missionNamespace setVariable ["lambs_danger_planRedNeden", format ["uygun grup yok (taraftaki grup %1; elenme nedenleri: %2). 'baska planda' = grup zaten bir plana bagli; eski plani IPTAL edin", count _tum, _red toArray false]];
    false
};
// v8.127: Zeus 'ELITE Gorev Ata' ile MANEVRA / DESTEK / YEDEK atananlar once gelir ve grup sayisi sinirina bakilmaksizin plana girer
private _atanmis = _aday select {(_x getVariable ["lambs_danger_gorev", ""]) in ["MANEVRA", "DESTEK", "YEDEK"]};
_aday = [_aday, [], { ([0, 100000] select ((_x getVariable ["lambs_danger_gorev", ""]) in ["MANEVRA", "DESTEK", "YEDEK"])) + (rankId (leader _x)) * 1000 + ({alive _x} count (units _x)) * 10 - ((leader _x) distance2D _obj) / 100 }, "DESCEND"] call BIS_fnc_sortBy;
// v8.199: HQ TAMAMI (guvenlik birakilir): en zayif squad HQ'da kalir (cevre emniyeti)
if (_tumHQ && {_ayar getOrDefault ["tumHQGuvenlik", false]} && {(count _aday) > 2}) then {
    private _zayif = _aday select 0;
    { if (({alive _x} count (units _x)) < ({alive _x} count (units _zayif))) then { _zayif = _x; }; } forEach _aday;
    _aday = _aday - [_zayif];
    diag_log format ["[PLAN-HQ-TUM] %1 | guvenlik: %2 (%3 asker) HQ'da birakildi", _hqId, groupId _zayif, {alive _x} count (units _zayif)];
};
private _gruplar = _aday select [0, (_grupN max 1) max (count _atanmis)];
if (_atanmis isNotEqualTo []) then {
    diag_log format ["[PLAN-ATAMA] Zeus atamali gruplar plana alindi: %1", _atanmis apply {format ["%1=%2", groupId _x, _x getVariable ["lambs_danger_gorev", ""]]}];
};
// v8.131 RECON: Zeus 'Gorev Ata -> RECON' gruplari (>= 2 asker) planin KESIF unsuru olur: once gozlem noktasina (OP) sizip bilgi toplar (cogu gizlilik: STEALTH + GREEN), plana rapor verir
private _reconG = allGroups select {
    private _l = leader _x;
    (_x getVariable ["lambs_danger_gorev", ""]) isEqualTo "RECON" && {!isNull _l} && {alive _l} && {!isPlayer _l} && {(side _x) isEqualTo _taraf}
    && {({isPlayer _x} count (units _x)) isEqualTo 0} && {({alive _x} count (units _x)) >= 2} && {isNull objectParent _l}
    && {(_l distance2D _obj) <= (_ayar getOrDefault ["grupMesafe", 4000])} && {!(_x getVariable ["lambs_danger_planAktif", false])}
};
// v8.123: baska makinede (Zeus istemcisi / HC) duran AI gruplari sunucuya devredilir (RPT a5d90e6e: 4 grup yerel degil). Plan komutlari yerel grup ister.
// Oyuncu iceren grup zaten secilmez. Devir 6 sn icinde olmazsa o grup plandan cikar.
if (isServer) then {
    private _uzak = (_gruplar + _reconG + _zirhG + _tasG) select {!local _x};
    // v8.155: yeni yaratilmis (< 60 sn) uzak grubu hemen devretme (envanter / kiyafet kaybi, RPT 7ab83653): yasi dolana kadar bekle (en fazla 60 sn)
    if (_uzak isNotEqualTo []) then {
        private _t1 = time;
        waitUntil { sleep 1; ((_uzak findIf {(time - (_x getVariable [QGVAR(gorulduT), -999])) < 60}) isEqualTo -1) || {(time - _t1) > 60} };
    };
    {
        diag_log format ["[PLAN-DEVIR] %1 | sahip makine %2 -> sunucu (2)", groupId _x, groupOwner _x];
        _x setGroupOwner 2;
    } forEach _uzak;
    if (_uzak isNotEqualTo []) then {
        private _t0 = time;
        waitUntil {sleep 0.3; ((_uzak findIf {!local _x}) isEqualTo -1) || {(time - _t0) > 15}};
        private _kalan = _uzak select {!local _x};
        if (_kalan isNotEqualTo []) then {
            diag_log format ["[PLAN-DEVIR] DEVIR OLMADI (plandan cikarildi): %1", _kalan apply {groupId _x}];
            _gruplar = _gruplar - _kalan;
            _reconG = _reconG - _kalan;
            _zirhG = _zirhG - _kalan;
            _tasG = _tasG - _kalan;
        } else {
            diag_log format ["[PLAN-DEVIR] %1 grup sunucuya devredildi (%2 sn)", count _uzak, (time - _t0) toFixed 1];
        };
    };
};
if (_gruplar isEqualTo []) exitWith {
    diag_log "[PLAN] KURULAMADI: secilen gruplarin hicbiri sunucuya devredilemedi";
    missionNamespace setVariable ["lambs_danger_planRedNeden", "secilen gruplarin hicbiri sunucuya devredilemedi"];
    false
};
private _komutanG = _gruplar select 0;

// ---------------------------------------------------------------------------
// ARAZI TANIMA: yaklasma ekseni, rally point (RP), ORP, destek noktasi (SBF), kanat noktalari, cevre halkasi
// ---------------------------------------------------------------------------
private _araziFn = missionNamespace getVariable ["lambs_danger_fnc_araziAnaliz", {createHashMap}];
private _mx = 0; private _my = 0;
{ private _p = getPosATL (leader _x); _mx = _mx + (_p select 0); _my = _my + (_p select 1); } forEach _gruplar;
private _merkez = [_mx / (count _gruplar), _my / (count _gruplar), 0];
private _B = _obj getDir _merkez;   // objektiften dost gruplara yon (yaklasma ekseni)

// aday konumlar arasindan en ortulu (olu arazi) / kapali, yol disi, bina disi, su disi nokta
private _konumSec = {
    params ["_d", "_aciListesi"];
    private _en = []; private _enS = -1e9;
    {
        private _a = _x;
        {
            private _p = _obj getPos [_x, _B + _a];
            // v8.174 ISLAK / CUKUR ARAZI ELEME (kullanici: "sulak dere gibi yerlere waypoint atmasin, daha duz yerlere atsin"): 20 / 45 m halkada su ornegi, cevreye gore cukur (dere yatagi) ve egim
            private _islak = 0;
            { private _r = _x; for "_k" from 0 to 7 do { if (surfaceIsWater (_p getPos [_r, _k * 45])) then { _islak = _islak + 1; }; }; } forEach [20, 45];
            private _hOrt = 0;
            for "_k" from 0 to 7 do { _hOrt = _hOrt + (getTerrainHeightASL (_p getPos [40, _k * 45])); };
            private _cukur = ((_hOrt / 8) - (getTerrainHeightASL _p)) > 2.5;
            private _egim = ((surfaceNormal _p) select 2) < 0.95;
            if (!surfaceIsWater _p && {_islak < 3} && {!isOnRoad _p} && {(nearestObjects [_p, ["House"], 8]) isEqualTo []}) then {
                private _pr = [_p, 30, _obj] call _araziFn;
                private _s = 100 * (_pr getOrDefault ["olu", 0]);
                private _ac = _pr getOrDefault ["aciklik", "KARISIK"];
                _s = _s + ([0, 10, 20] select (((["ACIK", "KARISIK", "KAPALI"]) find _ac) max 0));
                if (_pr getOrDefault ["ufukRisk", false]) then { _s = _s - 25; };
                // v8.181 STRATEJIK / KORUNAKLI NOKTA: 40 m icindeki arazi objesi yogunlugu (agac / kaya / duvar / bina / cali) = siper; ortulu ama asiri yogun (> 45 = girilmez orman) degil; arac erisimi icin yol 120 m icinde ise bonus
                private _obje = count (nearestTerrainObjects [_p, ["TREE", "ROCK", "WALL", "BUILDING", "HIDE", "BUSH"], 40, false, true]);
                _s = _s + ((_obje min 24) * 1.2) - ([0, 12] select (_obje > 45)) + ([0, 8] select ((_p nearRoads 120) isNotEqualTo []));
                _s = _s - 0.05 * abs _a - 0.02 * (_p distance2D _merkez);
                _s = _s - 15 * _islak - ([0, 30] select _cukur) - ([0, 20] select _egim);
                if (_s > _enS) then { _enS = _s; _en = _p; };
            };
        } forEach [_d - 50, _d, _d + 50];
    } forEach _aciListesi;
    if (_en isEqualTo []) then { _en = _obj getPos [_d, _B]; };
    _en
};
private _rallyM = _ayar getOrDefault ["rallyM", 450];
private _orpM = _ayar getOrDefault ["orpM", 300];
private _rp = [_rallyM, [0, 12, -12, 24, -24, 36, -36, 52, -52, 70, -70]] call _konumSec;
private _orp = [_orpM, [0, 10, -10, 20, -20, 35, -35]] call _konumSec;
// v8.216 DOST TOPLANMA NOKTASI (kullanici: "objektif direk son nokta oluyor, dusman mevzisine rally koyuyorlar"): Zeus'ta secilen dost karakol / mevzi / gozetleme isareti RP olur (arazi analizi yerine)
private _rpIsaret = _ayar getOrDefault ["rpIsaret", ""];
if (_rpIsaret isNotEqualTo "" && {(markerPos _rpIsaret) isNotEqualTo [0, 0, 0]}) then {
    _rp = markerPos _rpIsaret;
    diag_log format ["[PLAN-RP-ISARET] %1 | toplanma noktasi dost isaret: %2 (%3), objektife %4 m", _taraf, markerText _rpIsaret, mapGridPosition _rp, round (_rp distance2D _obj)];
};

// grup rolleri
private _mg = _ayar getOrDefault ["mg", false];
private _bina = _ayar getOrDefault ["bina", false];
// v8.128: hedef yakininda (200 m) bir KARAKOL kaydi varsa (Zeus 'ELITE Karakol') dusman binali / mevzili sayilir ve loglanir
private _karakolHedef = (missionNamespace getVariable ["lambs_danger_karakollar", []]) select {((_x select 1) distance2D _obj) < 200 && {(_x select 0) isNotEqualTo _taraf}};
if (_karakolHedef isNotEqualTo []) then {
    _bina = true;
    _ayar set ["bina", true];
    diag_log format ["[PLAN] hedef bir KARAKOL: %1 (yaricap %2 m) -> duşman binali / mevzili sayildi", (_karakolHedef select 0) select 3, (_karakolHedef select 0) select 2];
};
private _zirh = _ayar getOrDefault ["zirh", false];
private _atVar = _ayar getOrDefault ["at", false];
private _sayi = _ayar getOrDefault ["sayi", 0];
private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
private _destekPuan = {
    params ["_g"];
    private _s = 0;
    {
        private _r = [_x] call _rolFn;
        if (_r isEqualTo "MG") then { _s = _s + 3; };
        if (_r isEqualTo "AT") then { _s = _s + ([1, 3] select _zirh); };
        if (_r isEqualTo "MARKSMAN") then { _s = _s + 2; };
    } forEach ((units _g) select {alive _x});
    _s
};
private _roller = createHashMap;
private _gn = count _gruplar;
if (_gn isEqualTo 1) then {
    _roller set [groupId _komutanG, "MANEVRA"];
} else {
    // destek: puani en yuksek grup; >= 3 grupta komutan destek noktasinda (gorus) — komutan grubunun puani yakinsa o
    private _sirali = [_gruplar, [], {[_x] call _destekPuan}, "DESCEND"] call BIS_fnc_sortBy;
    private _destekG = _sirali select 0;
    if (_gn >= 3 && {([_komutanG] call _destekPuan) >= (([_destekG] call _destekPuan) - 2)}) then { _destekG = _komutanG; };
    {
        private _g = _x;
        _roller set [groupId _g, ["MANEVRA", "DESTEK"] select (_g isEqualTo _destekG)];
    } forEach _gruplar;
    // 4+ grupta bir manevra grubu yedek
    if (_gn >= 4) then {
        private _manev = _gruplar select {(_roller get (groupId _x)) isEqualTo "MANEVRA"};
        if (count _manev >= 3) then { _roller set [groupId (_manev select -1), "YEDEK"]; };
    };
};

// v8.127: Zeus atamasi rolu ezer (MANEVRA / DESTEK / YEDEK)
{
    private _ga = _x getVariable ["lambs_danger_gorev", ""];
    if (_ga in ["MANEVRA", "DESTEK", "YEDEK"]) then {
        if ((_roller getOrDefault [groupId _x, ""]) isNotEqualTo _ga) then {
            diag_log format ["[PLAN-ATAMA] %1 rolu %2 -> %3 (Zeus atamasi)", groupId _x, _roller getOrDefault [groupId _x, "?"], _ga];
        };
        _roller set [groupId _x, _ga];
    };
} forEach _gruplar;

// destek noktasi (SBF): dusman gozetlenen, objektife arazi gorusu olan, dost eksenin yanlarinda yuksek nokta
private _sbf = [];
private _sbfS = -1e9;
private _hObj = getTerrainHeightASL _obj;
private _gozObj = AGLToASL (_obj vectorAdd [0, 0, 1.5]);
{
    private _a = _x;
    {
        private _p = _obj getPos [_x, _B + _a];
        if (!surfaceIsWater _p && {(nearestObjects [_p, ["House"], 8]) isEqualTo []}) then {
            if (!(terrainIntersectASL [AGLToASL (_p vectorAdd [0, 0, 1.2]), _gozObj])) then {
                private _s = ((getTerrainHeightASL _p) - _hObj) + 40 - 0.03 * (_p distance2D _rp) - ([0, 15] select (abs _a < 40));
                if (_s > _sbfS) then { _sbfS = _s; _sbf = _p; };
            };
        };
    } forEach [160, 230, 300];
} forEach [35, 55, 80, 105, -35, -55, -80, -105];
if (_sbf isEqualTo []) then { _sbf = _obj getPos [220, _B + 70]; };

// v8.131 RECON gozlem noktasi (OP): objektife 450-600 m (tufek etkili menzili 460 m civari: gozlem, temas degil), objektifi gorebilen, yuksek, bitki / kaya orten
private _op = [];
if (_reconG isNotEqualTo []) then {
    private _opS = -1e9;
    {
        private _a = _x;
        {
            private _p = _obj getPos [_x, _B + _a];
            if (!surfaceIsWater _p && {!isOnRoad _p} && {(nearestObjects [_p, ["House"], 12]) isEqualTo []}) then {
                if (!(terrainIntersectASL [AGLToASL (_p vectorAdd [0, 0, 0.8]), _gozObj])) then {
                    private _s = 1.5 * ((getTerrainHeightASL _p) - _hObj) + 2 * (count (nearestTerrainObjects [_p, ["TREE", "BUSH", "ROCK", "ROCKS"], 14])) - 0.2 * abs _a - 0.02 * (_x - 450);
                    if (_s > _opS) then { _opS = _s; _op = _p; };
                };
            };
        } forEach [450, 520, 600];
    } forEach [-45, -25, 0, 25, 45];
    if (_op isEqualTo []) then { _op = _obj getPos [500, _B]; };
};

// v8.216 RECON EK GOZLEM (kullanici: "recon dusman pozisyonlarini gizlice gozlemlesin"): objektifin 2 km icindeki DUSMAN karakol / mevzi / gozetleme noktalari; her biri icin 250 m geriden gozlem noktasi (OP -> nokta yonunden)
private _reconEkN = [];
if (_ayar getOrDefault ["reconEk", false]) then {
    private _dK = (missionNamespace getVariable ["lambs_danger_karakollar", []]) select {(_x select 0) isNotEqualTo _taraf && {((_x select 1) distance2D _obj) < 2000} && {((_x select 1) distance2D _obj) > 120}};
    private _son = _op;
    while {_dK isNotEqualTo []} do {
        _dK = [_dK, [], {(_x select 1) distance2D _son}, "ASCEND"] call BIS_fnc_sortBy;
        private _k = _dK deleteAt 0;
        private _hp = _k select 1;
        private _gp = _hp getPos [250, _hp getDir _son];
        if (surfaceIsWater _gp) then { _gp = _hp getPos [150, _hp getDir _son]; };
        _reconEkN pushBack [_gp, _hp, _k select 3];
        _son = _gp;
    };
    diag_log format ["[PLAN-RECON] %1 | ek gozlem noktalari: %2 dusman noktasi (%3)", _taraf, count _reconEkN, _reconEkN apply {format ["%1 %2", _x select 2, mapGridPosition (_x select 1)]}];
};

// kanat noktalari (>= 2 manevra grubu ve MG / bina / sayi >= 8): objektiften 110 m, eksenin +-75 derecesi
private _kanatGerek = _mg || _bina || (_sayi >= 8);
private _kanatNokta = [_obj getPos [110, _B + 75], _obj getPos [110, _B - 75]];

// ---------------------------------------------------------------------------
// MANUEL NOKTALAR (Zeus 'ELITE Plan Noktasi'): komutan hesapladigi noktalar yerine Zeus'un sectigini KULLANIR (emri uygular, itiraz etmez); sistem yalniz [PLAN-UYARI] loglar (tarihsel canlandirma: 'ne olurdu?')
// ---------------------------------------------------------------------------
private _manuel = missionNamespace getVariable ["lambs_danger_planManuel", createHashMap];
private _uyarilar = [];
private _manuelAd = [];
private _uyar = {
    params ["_ad", "_metin"];
    _uyarilar pushBack format ["%1: %2", _ad, _metin];
    diag_log format ["[PLAN-UYARI] %1 | %2", _ad, _metin];
};
private _gorunur = { params ["_p"]; !(terrainIntersectASL [AGLToASL (_p vectorAdd [0, 0, 1.2]), AGLToASL (_obj vectorAdd [0, 0, 1.5])]) };
private _ccp = _rp getPos [25, _B + 90];
{
    private _tip2 = _x;
    private _p = _manuel getOrDefault [format ["%1|%2", _taraf, _tip2], []];
    if (_p isNotEqualTo []) then {
        _manuelAd pushBack _tip2;
        private _d = _p distance2D _obj;
        switch (_tip2) do {
            case "RP": {
                _rp = _p;
                if (_d < 250) then { ["RP", format ["objektife cok yakin (%1 m < 250 m): ates / gorus altinda toplanma", round _d]] call _uyar; };
                if ([_p] call _gorunur) then { ["RP", "objektiften GORUNUR (arazi gorusu var)"] call _uyar; };
                if (isOnRoad _p) then { ["RP", "yol uzerinde (pusu / IED riski)"] call _uyar; };
                private _pr = [_p, 30, _obj] call _araziFn;
                if ((_pr getOrDefault ["olu", 1]) < 0.3) then { ["RP", format ["acik arazide (olu arazi orani %1)", (_pr getOrDefault ["olu", 0]) toFixed 2]] call _uyar; };
            };
            case "ORP": {
                _orp = _p;
                // KAYNAK TC 3-21.76 s. 7-15 / 7-20: ORP tipik 200-400 m (sinirli gorusta 100-200 m); ses ve gorus disinda
                private _sinirliGorus = (sunOrMoon < 0.15) || {fog > 0.4};
                private _alt = [200, 100] select _sinirliGorus;
                if (_d < _alt) then { ["ORP", format ["kitap ORP mesafesinin altinda (%1 m < %2 m, %3)", round _d, _alt, ["iyi gorus", "sinirli gorus"] select _sinirliGorus]] call _uyar; };
                if (_d > 400) then { ["ORP", format ["kitap ORP mesafesinin ustunde (%1 m > 400 m): objektife gec yetisilir / baglanti kopar", round _d]] call _uyar; };
                if ([_p] call _gorunur) then { ["ORP", "objektiften GORUNUR"] call _uyar; };
            };
            case "SBF": {
                _sbf = _p;
                if !([_p] call _gorunur) then { ["SBF", "destek noktasinin objektife arazi GORUSU YOK (ates veremez)"] call _uyar; };
                if (_d < 100) then { ["SBF", format ["objektife cok yakin (%1 m)", round _d]] call _uyar; };
                if (_d > 460) then { ["SBF", format ["tufek etkili menzili disinda (%1 m > 460 m, MCWP 3-11.2: M16 etkili menzil 460 m; MG 600-1100 m ayri)", round _d]] call _uyar; };
            };
            case "KANAT1": { _kanatNokta set [0, _p]; if (_d < 60) then { ["KANAT1", format ["objektife cok yakin (%1 m)", round _d]] call _uyar; }; };
            case "KANAT2": { _kanatNokta set [1, _p]; if (_d < 60) then { ["KANAT2", format ["objektife cok yakin (%1 m)", round _d]] call _uyar; }; };
            case "CCP": {
                _ccp = _p;
                if ([_p] call _gorunur) then { ["CCP", "yarali toplama noktasi objektiften GORUNUR"] call _uyar; };
            };
        };
        _manuel deleteAt (format ["%1|%2", _taraf, _tip2]);
        deleteMarker (format ["ELITE_MANUEL_%1_%2", _taraf, _tip2]);
        diag_log format ["[PLAN-MANUEL] %1 | %2 = MANUEL nokta kullanildi (%3, objektife %4 m)", _taraf, _tip2, mapGridPosition _p, round _d];
    };
} forEach ["RP", "ORP", "SBF", "KANAT1", "KANAT2", "CCP"];
if !("CCP" in _manuelAd) then { _ccp = _rp getPos [25, _B + 90]; };
// destek noktasi ile kanat noktasi ayni hat uzerinde ise dost atesi riski
if ("SBF" in _manuelAd || {"KANAT1" in _manuelAd} || {"KANAT2" in _manuelAd}) then {
    {
        private _kn = _x;
        if (abs ((((_obj getDir _sbf) - (_obj getDir _kn)) + 540) mod 360 - 180) < 25) then {
            ["SBF/KANAT", "destek noktasi ile kanat noktasi AYNI ates hattinda (dost atesi riski, < 25 derece)"] call _uyar;
        };
    } forEach _kanatNokta;
};

// ---------------------------------------------------------------------------
// PLAN KAYDI
// ---------------------------------------------------------------------------
if (isNil "lambs_danger_planSay") then { lambs_danger_planSay = 0; };
lambs_danger_planSay = lambs_danger_planSay + 1;
private _id = format ["P%1", lambs_danger_planSay];
private _renk = switch (_taraf) do { case west: {"ColorBLUFOR"}; case east: {"ColorOPFOR"}; default {"ColorIndependent"} };
private _isaretler = [];
{
    _x params ["_ad", "_pos", "_tur", "_metin"];
    private _m = createMarker [format ["ELITE_PLAN_%1_%2", _id, _ad], _pos];
    _m setMarkerType _tur;
    _m setMarkerColor _renk;
    _m setMarkerText _metin;
    _isaretler pushBack _m;
} forEach [
    ["OBJ", _obj, "mil_objective", format ["%1 OBJ", _id]],
    ["RP", _rp, "mil_start", format ["%1 RP", _id]],
    ["ORP", _orp, "mil_triangle", format ["%1 ORP", _id]],
    ["SBF", _sbf, "mil_dot", format ["%1 SBF (destek)", _id]],
    ["CCP", _ccp, "mil_pickup", format ["%1 CCP (yarali toplama)", _id]]
];
// yarali toplama noktasi (CCP): rally point'in yaninda; araçli medevac buraya tasir
if (isNil "lambs_danger_planCCPlar") then { lambs_danger_planCCPlar = []; };
lambs_danger_planCCPlar pushBack [_id, _taraf, _ccp];

if (_zirhG isNotEqualTo []) then {
    { _x setVariable ["lambs_danger_planAktif", true, true]; } forEach _zirhG;
    diag_log format ["[PLAN-ZIRH] %1 | zirh destek %2 grup: %3", _id, count _zirhG, _zirhG apply {groupId _x}];
};
if (_reconG isNotEqualTo []) then {
    diag_log format ["[PLAN-RECON] %1 | recon %2 grup: %3 | gozlem noktasi OP %4 (objektiften %5 m)", _id, count _reconG, _reconG apply {groupId _x}, mapGridPosition _op, round (_op distance2D _obj)];
    { _x setVariable ["lambs_danger_planAktif", true, true]; } forEach _reconG;
};
// v8.239 COKLU MEVZI: SAVUN planinda objektife <= lambs_danger_savunmaMevziYaricap (700 m) olan elle mevzi noktalari plana alinir (mevzi kayitlari plan bitince SILINMEZ; Zeus 'Plan Noktasi > MEVZI sil' ile silinir)
private _mevziler = [];
if (_tip isEqualTo 1) then {
    private _mTum = (missionNamespace getVariable ["lambs_danger_savunmaMevzi", createHashMap]) getOrDefault [str _taraf, []];
    private _mYar = missionNamespace getVariable ["lambs_danger_savunmaMevziYaricap", 700];
    _mevziler = _mTum select {((_x select 0) distance2D _obj) <= _mYar};
    if (_mTum isNotEqualTo []) then {
        diag_log format ["[PLAN-MEVZI] %1 | %2 manuel mevzi plana alindi (objektife <= %3 m; bu tarafta toplam %4 kayit)", _id, count _mevziler, _mYar, count _mTum];
    };
};
private _plan = createHashMapFromArray [
    ["id", _id], ["taraf", _taraf], ["obj", _obj], ["tip", _tip], ["hqId", _hqId], ["hqPoz", if (_hqKayit isEqualTo []) then {[]} else {+(_hqKayit select 2)}], ["hqYar", if (_hqKayit isEqualTo []) then {100} else {_hqKayit select 4}], ["gruplar", _gruplar], ["roller", _roller], ["komutan", _komutanG],
    ["rp", _rp], ["orp", _orp], ["sbf", _sbf], ["B", _B], ["kanatNokta", _kanatNokta], ["kanatGerek", _kanatGerek],
    ["ayar", _ayar], ["tempo", ([_ayar getOrDefault ["tempo", 0], 1] select (((_ayar getOrDefault ["baskin", 0]) > 0 || {(_ayar getOrDefault ["guven", 1]) isEqualTo 0}) && {(_ayar getOrDefault ["tempo", 0]) isEqualTo 0}))], ["baslaT", time + ([0, 30, 60, 120, 300, 0] select ((_ayar getOrDefault ["basla", 0]) min 5))], ["bekleOnay", (_ayar getOrDefault ["basla", 0]) isEqualTo 5],
    ["sureSn", [0, 600, 1200, 1800, 2700] select ((_ayar getOrDefault ["sure", 0]) min 4)], ["tehditB", [-1, 0, 45, 90, 135, 180, 225, 270, 315] select ((_ayar getOrDefault ["tehditY", 0]) min 8)],
    ["baskinS", [0, 300, 600] select ((_ayar getOrDefault ["baskin", 0]) min 2)], ["sivil", _ayar getOrDefault ["sivil", false]], ["agirYasak", _ayar getOrDefault ["agirYasak", false]], ["topcu", _ayar getOrDefault ["topcu", 0]], ["topcuN", _ayar getOrDefault ["topcuN", 4]], ["topcuBasit", _ayar getOrDefault ["topcuBasit", 0]],
    ["guven", _ayar getOrDefault ["guven", 1]], ["dogrulama", _ayar getOrDefault ["dogrulama", 0]], ["iddiaSayi", _ayar getOrDefault ["sayi", 0]], ["atislar", []], ["reconG", _reconG], ["zirhG", _zirhG], ["op", _op], ["reconEkNoktalar", _reconEkN], ["reconEkSonuc", []], ["faz", "KUR"], ["fazT", time], ["t0", time], ["isaretler", _isaretler], ["notlar", createHashMap], ["mevziler", _mevziler], ["uyarilar", _uyarilar], ["manuelNoktalar", _manuelAd]
];
{
    _x setVariable ["lambs_danger_planAktif", true, true];
    _x setVariable ["lambs_danger_planId", _id];
    _x setVariable ["lambs_danger_agirYasak", _ayar getOrDefault ["agirYasak", false]];
} forEach _gruplar;
lambs_danger_planlar set [_id, _plan];

missionNamespace setVariable ["lambs_danger_planZamanId", _id]; missionNamespace setVariable ["lambs_danger_planZamanT0", time];
diag_log format ["[PLAN] %1 KURULDU | %2 | %3 | objektif %4 | komutan %5 (%6) | %7 grup: %8 | RP %9 (%10 m) | ORP %11 (%12 m) | SBF %13 | yaklasma ekseni %14 | duşman: piyade:%15 zirh:%16 AT:%17 MG:%18 nisanci:%19 bina:%20 sayi:%21 | kanat gerekli:%22 | tempo:%23 | H-saati:%24 | sure sinir:%25 sn | tehdit yonu:%26 | siviller:%27 agir silah yasak:%28 | topcu:%29",
    _id, _taraf, ["ELE GECIR", "SAVUN"] select (_tip isEqualTo 1), mapGridPosition _obj, groupId _komutanG, rank (leader _komutanG), _gn,
    _gruplar apply {format ["%1=%2 (%3)", groupId _x, _roller get (groupId _x), {alive _x} count (units _x)]},
    mapGridPosition _rp, round (_rp distance2D _obj), mapGridPosition _orp, round (_orp distance2D _obj), mapGridPosition _sbf, round _B,
    _ayar getOrDefault ["piyade", true], _zirh, _atVar, _mg, _ayar getOrDefault ["nisanci", false], _bina, _sayi, _kanatGerek,
    ["dengeli", "sessiz / gizli", "hizli / agresif"] select ((_ayar getOrDefault ["tempo", 0]) min 2),
    ["hemen", "30 sn", "60 sn", "120 sn", "300 sn", "ZEUS ONAYI BEKLENIYOR"] select ((_ayar getOrDefault ["basla", 0]) min 5),
    _plan get "sureSn", [_plan get "tehditB", "bilinmiyor"] select ((_plan get "tehditB") < 0), _plan get "sivil", _plan get "agirYasak",
    ["yok", "hazirlik", "cagri", "hazirlik + cagri"] select ((_ayar getOrDefault ["topcu", 0]) min 3)];
["PLAN-KURULDU", format ["tip %1 | grup %2 | obje %3", _tip, count _gruplar, mapGridPosition _obj]] call FUNC(planZaman);
// v8.204 ORTAK RESIM: ELITE plani kurulunca KUMANDA cekirdegi (istihbarat / SPOTREP agi, takviye, kanat, feint, destek, medevac) otomatik acilir - onceki testlerde Zeus 'Kumanda' modulu konmadigi icin bu katman HIC calismiyordu ([HQ-TAHTA] / [HQ-ISTIHBARAT] satiri yok). Kapatma: lambs_danger_hqPlanOtomatikOff = true
if (!(missionNamespace getVariable ["lambs_danger_hqPlanOtomatikOff", false]) && {!(missionNamespace getVariable ["lambs_danger_hqAktif", false])}) then {
    missionNamespace setVariable ["lambs_danger_hqAktif", true, true];
    diag_log format ["[HQ-MODUL] kumanda ELITE plani (%1) ile OTOMATIK acildi (istihbarat paylasimi, takviye, kanat, feint, destek, medevac)", _id];
};
if (_zirh && {!_atVar} && {({([_x] call _destekPuan) >= 3} count _gruplar) isEqualTo 0}) then {
    diag_log format ["[PLAN] %1 UYARI: duşmanda zirh / arac var ama katilan gruplarda AT gucu zayif", _id];
};
// v8.131: topcu envanteri (kullanici: "artilleryden tik yok") — plan kurulurken tarafin topcu araclarini ve atisa uygunlugunu logla
if ((_ayar getOrDefault ["topcu", 0]) > 0) then {
    private _tAr = vehicles select {(side (group _x)) isEqualTo _taraf || {(side _x) isEqualTo _taraf}} select {(getNumber (configOf _x >> "artilleryScanner")) > 0};
    if (_tAr isEqualTo []) then {
        diag_log format ["[PLAN-TOPCU] %1 | ENVANTER: %2 tarafinda artilleryScanner'li arac YOK (topcu / havan araci eksik ya da taraf farkli; Zeus'ta tarafi kontrol edin)", _id, _taraf];
    } else {
        {
            private _v = _x;
            private _m = (getArtilleryAmmo [_v]) param [0, ""];
            diag_log format ["[PLAN-TOPCU] %1 | ENVANTER: %2 | gunner:%3 (oyuncu:%4) | yerel:%5 | canFire:%6 | mermi:%7 | hedef menzilde:%8 | Zeus:%9 | hedefe mesafe %10 m",
                _id, typeOf _v, [name (gunner _v), "YOK"] select (isNull (gunner _v)), isPlayer (gunner _v), local _v, canFire _v, _m,
                ["?", _obj inRangeOfArtillery [[_v], _m]] select (_m isNotEqualTo ""), _v getVariable ["lambs_danger_gorev", ""], round (_v distance2D _obj)];
            // v8.174 MENZIL TANISI: hedef menzil disiysa, topun hedef yonunde 500 m adimlarla hangi mesafelerin menzil ici oldugunu bul (min / maks menzil)
            if (_m isNotEqualTo "" && {!(_obj inRangeOfArtillery [[_v], _m])}) then {
                private _yonT = (getPosATL _v) getDir _obj;
                private _ici = [];
                for "_d" from 500 to 20000 step 500 do { if (((getPosATL _v) getPos [_d, _yonT]) inRangeOfArtillery [[_v], _m]) then { _ici pushBack _d; }; };
                diag_log format ["[PLAN-TOPCU] %1 | MENZIL TANISI: hedef %2 m'de MENZIL DISI | menzil ici mesafeler (500 m adim): %3 .. %4 m (%5 nokta)", _id, round (_v distance2D _obj), if (_ici isEqualTo []) then {"yok"} else {_ici select 0}, if (_ici isEqualTo []) then {"yok"} else {_ici select (count _ici - 1)}, count _ici];
                // v8.181: yer degistirme ortak fonksiyonda (fnc_topcuKonumla); atis sirasinda da cagrilir
                [_v, _obj, _id] call FUNC(topcuKonumla);
            };
        } forEach _tAr;
    };
};
if (_zirh && {_tip isEqualTo 0}) then { diag_log format ["[PLAN] %1 NOT: zirh var -> saldirida AT'li grup destek tarafina oncelik verildi (destek puani AT x3)", _id]; };

// dongu (bir kez baslar, hata olursa bekci yeniden baslatir)
if (isNil "lambs_danger_planDonguStarted") then {
    lambs_danger_planDonguStarted = true;
    private _dongu = missionNamespace getVariable ["lambs_danger_fnc_komutanPlanDongu", {}];
    [_dongu] spawn {
        params ["_fn"];
        while {true} do {
            private _h = [] spawn _fn;
            waitUntil { sleep 5; scriptDone _h };
            diag_log format ["[WATCHDOG-YENIDEN] komutanPlan dongusu sonlandi (hata?), son adim: %1", missionNamespace getVariable ["lambs_danger_planAdim", "?"]];
            sleep 5;
        };
    };
};

true

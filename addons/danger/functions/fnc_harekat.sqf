#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * HAREKAT KATMANI (v8.404; kullanici: 'harekat katmani ekle, kitaba gore oyuncuyu sisteme dahil et, task olarak gorevlendirilsin'; Zeytin Dali / Firat Kalkani tarzi FAZLI harekat). SUNUCU API'si + durum makinesi.
 *
 * HAREKAT = adi, tarafi, niyeti (komutanin niyeti), dusman durumu, H-saati, FAZLAR. Her faz bir ya da birkac OBJEKTIF PLANI (fnc_komutanPlan: ele gecir / savun) icerir; harekat bir fazin planlari BITTI
 *   olunca (ya da sure asimi) kisa bir TOPARLANMA beklemesinden sonra siradaki fazi baslatir. Yeni bir davranis yazmaz: mevcut komutan plani + HQ + botlar yurutur (hile yok: oyuncuya yalniz OPORD'da bildirilenler gosterilir).
 * OYUNCU DAHIL: (1) harekat bildirimi = ARMA GOREVLERI (BIS_fnc_taskCreate; JIP guvenli): ana gorev 'HAREKAT' (aciklamasi taslak OPORD: Durum / Gorev / Icra / Idare / Komuta), faz gorevleri, objektif gorevleri;
 *   (2) bir planin gruplarinda OYUNCU varsa o gruba ROL GOREVI (MANEVRA / DESTEK / YEDEK ve toplanma / destek / saldiri noktalari) ozel gorev olarak yazilir (lideri BOT olan grupta oyuncu ast olarak oynar);
 *   (3) haritada faz / objektif isaretleri (gri bekliyor, turuncu icrada, yesil tamam, kirmizi basarisiz). Oyuncu katilimi ZORUNLU degil: harekat oyuncusuz da yurur (izleme / Zeus kamerasi).
 * TC2 ile ilgisi: BAGIMLILIK YOK; TC2 (OPORD / WARNO / 9-line) entegrasyonu ilerleyen surumde 'lambs_danger_harekatlar' durumunu okuyarak yapilacak. OPORD metni TASLAKTIR (5 paragraf [T]).
 *
 * Islemler (arguments 0):
 *   "KUR"       [id, ad, taraf, niyet, dusman, hMod (0 otomatik / 1 elle), hDk, bekleSn, fazSureSn, sureAsimi (0 sonraki faz / 1 basarisiz), devam (true: basarisiz fazdan sonra devam), fazAdlari (dizi 1..6)] -> bool
 *   "KAYIT"     [id, fazNo, taraf, objektif, ayar (dizi: [[anahtar, deger]]), ad] -> bool       (3DEN Objektif modulu harekata bagliysa plani HEMEN kurmaz, buraya kaydeder)
 *   "OPORD"     [id]   taslak OPORD + harita isaretleri + ana gorev
 *   "BASLAT"    [id]   H-saati: ilk fazi baslat
 *   "FAZ_SONRAKI" [id] siradaki fazi baslat (ya da harekati bitir)
 *   "SONRAKI"   [id]   Zeus: mevcut fazi ATLA (planlari surer) ve siradaki fazi baslat
 *   "DURDUR"    [id]   harekati iptal et; harekatin plan fazlari IPTAL / DONUS
 *   "DURUM"     [id]   durum metni (<STRING>)
 *   "ADIM"      [id]   bekci adimi (5 sn'de bir; fnc_harekatDongu)
 * Log: [HAREKAT] / [HAREKAT-AAR]. Kapatma: lambs_danger_harekatOff = true. Sayilar [T] tasarim.
 *
 * Return Value: islemin sonucu
 * Public: No
*/

params [["_islem", "", [""]], ["_a", []]];
if (!isServer) exitWith {nil};
if (isNil "lambs_danger_harekatlar") then { lambs_danger_harekatlar = createHashMap; };
if (isNil "lambs_danger_planlar") then { lambs_danger_planlar = createHashMap; };

private _mesaj = {
    params ["_taraf", "_m"];
    diag_log format ["[HAREKAT] %1", _m];
    ["lambs_danger_harekatMesaj", [_taraf, format ["[HAREKAT] %1", _m]]] call CBA_fnc_globalEvent;
};
private _tarafAd = { params ["_t"]; switch (_t) do { case west: {"BLUFOR"}; case east: {"OPFOR"}; case independent: {"INDEP"}; default {"?"} } };
private _gid = { params ["_id", "_f", "_k"]; format ["HAR_%1_F%2_%3", _id, _f, _k] };
private _liste = {
    // Zeus modulu icin ortak liste (id, ad, durum)
    missionNamespace setVariable ["lambs_danger_harekatListe", (values lambs_danger_harekatlar) apply {[_x get "id", _x get "ad", _x get "durum"]}, true];
};
private _gorevKur = {
    params ["_sahip", "_kimlik", "_ust", "_baslik", "_acik", "_poz", "_tip"];
    private _tid = if (_ust isEqualTo "") then {_kimlik} else {[_kimlik, _ust]};
    [_sahip, _tid, [_acik, _baslik, ""], _poz, "ASSIGNED", 1, true, _tip, false] call BIS_fnc_taskCreate;
};
private _pozOk = { params ["_v", "_yedek"]; if (_v isEqualType [] && {(count _v) >= 2}) then {_v} else {_yedek} };
private _gorevDurum = { params ["_kimlik", "_durum"]; [_kimlik, _durum, true] call BIS_fnc_taskSetState; };
private _isaretRenk = { params ["_d"]; switch (_d) do { case "ICRA": {"ColorOrange"}; case "ISTENDI": {"ColorOrange"}; case "TAMAM": {"ColorGreen"}; case "BASARISIZ": {"ColorRed"}; case "SURE": {"ColorRed"}; case "ATLANDI": {"ColorYellow"}; default {"ColorGrey"} } };
private _isaretGuncelle = {
    params ["_id", "_fazNo", "_h"];
    private _mn = ["ELITE_HAR_%1_%2_%3", _id, _fazNo, _h get "k"];
    _mn = format _mn;
    if ((getMarkerPos _mn) isEqualTo [0, 0, 0]) then {
        createMarker [_mn, _h get "obj"];
        _mn setMarkerType (["mil_objective", "mil_end"] select ((_h get "tip") isEqualTo 1));
        _mn setMarkerSize [0.9, 0.9];
    };
    _mn setMarkerColor ([_h get "durum"] call _isaretRenk);
    _mn setMarkerText format ["F%1 %2 [%3]", _fazNo, _h get "ad", _h get "durum"];
};

switch (_islem) do {
    // ------------------------------------------------------------------------------------------------------------------------------------------------
    case "KUR": {
        _a params ["_id", "_ad", "_taraf", ["_niyet", ""], ["_dusman", ""], ["_hMod", 0], ["_hDk", 0], ["_bekle", 0], ["_fazSure", 0], ["_sureAsimi", 0], ["_devam", true], ["_fazAdlari", []]];
        if (missionNamespace getVariable ["lambs_danger_harekatOff", false]) exitWith {false};
        if (_id in (keys lambs_danger_harekatlar)) exitWith { diag_log format ["[HAREKAT] KUR: '%1' zaten kayitli", _id]; false };
        private _op = createHashMapFromArray [
            ["id", _id], ["ad", _ad], ["taraf", _taraf], ["niyet", _niyet], ["dusman", _dusman], ["hMod", _hMod], ["hDk", _hDk], ["bekle", _bekle], ["fazSure", _fazSure],
            ["sureAsimi", _sureAsimi], ["devam", _devam], ["fazAdlari", _fazAdlari], ["durum", "HAZIRLIK"], ["fazlar", []], ["aktif", -1], ["gecisT", -1], ["t0", time],
            ["hT", [-1, time + (((_hDk * 60) max 25))] select (_hMod isEqualTo 0)], ["opordVar", false], ["kayitT", time], ["aar", []]
        ];
        lambs_danger_harekatlar set [_id, _op];
        call _liste;
        [_taraf, format ["%1 (%2) kuruldu | H-saati %3", _ad, [_taraf] call _tarafAd, if (_hMod isEqualTo 0) then {format ["%1 dk sonra (otomatik)", (((_hDk * 60) max 25) / 60) toFixed 1]} else {"ELLE (Zeus 'ELITE Harekat Kontrol')"}]] call _mesaj;
        true
    };
    // ------------------------------------------------------------------------------------------------------------------------------------------------
    case "KAYIT": {
        _a params ["_id", "_fazNo", "_taraf", "_obj", "_ayarA", ["_ad", ""]];
        private _op = lambs_danger_harekatlar getOrDefault [_id, createHashMap];
        if (count _op isEqualTo 0) exitWith { diag_log format ["[HAREKAT] KAYIT: '%1' harekati yok (modul sirasi?)", _id]; false };
        if ((_op get "durum") isNotEqualTo "HAZIRLIK") exitWith { diag_log format ["[HAREKAT] KAYIT: '%1' icrada - gec kayit reddedildi (%2)", _id, mapGridPosition _obj]; false };
        private _fazlar = _op get "fazlar";
        private _fi = _fazlar findIf {(_x get "no") isEqualTo _fazNo};
        private _faz = if (_fi >= 0) then { _fazlar select _fi } else {
            private _adlar = _op get "fazAdlari";
            private _f = createHashMapFromArray [["no", _fazNo], ["ad", if (((count _adlar) >= _fazNo) && {_fazNo >= 1} && {(_adlar select (_fazNo - 1)) isNotEqualTo ""}) then {_adlar select (_fazNo - 1)} else {format ["Faz %1", _fazNo]}], ["hedefler", []], ["durum", "BEKLE"], ["t0", -1]];
            _fazlar pushBack _f;
            _fazlar = [_fazlar, [], {_x get "no"}, "ASCEND"] call BIS_fnc_sortBy;
            _op set ["fazlar", _fazlar];
            _f
        };
        _op set ["kayitT", time];
        private _ayar = createHashMapFromArray _ayarA;
        private _hedefler = _faz get "hedefler";
        _hedefler pushBack (createHashMapFromArray [
            ["k", count _hedefler], ["obj", +_obj], ["ayar", _ayarA], ["tip", _ayar getOrDefault ["tip", 0]], ["ad", if (_ad isNotEqualTo "") then {_ad} else {format ["%1", mapGridPosition _obj]}],
            ["durum", "BEKLE"], ["planId", ""], ["planFaz", ""], ["deneme", 0], ["istekT", -1], ["bekleT", -1], ["sonuc", -2], ["neden", ""], ["rolGorev", []]
        ]);
        diag_log format ["[HAREKAT] KAYIT: %1 | Faz %2 '%3' | objektif %4 (%5) | tip %6", _id, _fazNo, _faz get "ad", mapGridPosition _obj, _ad, ["ELE GECIR", "SAVUN"] select ((_ayar getOrDefault ["tip", 0]) isEqualTo 1)];
        true
    };
    // ------------------------------------------------------------------------------------------------------------------------------------------------
    case "OPORD": {
        _a params ["_id"];
        private _op = lambs_danger_harekatlar getOrDefault [_id, createHashMap];
        if (count _op isEqualTo 0 || {_op get "opordVar"}) exitWith {false};
        private _taraf = _op get "taraf";
        private _fazlar = _op get "fazlar";
        private _tum = [];
        { _tum append (_x get "hedefler"); } forEach _fazlar;
        private _satir = [];
        _satir pushBack format ["<t size='1.1'>1. DURUM</t><br/>Dusman: %1<br/>Dost: %2 unsurlari; bot komutanlar plani yurutur, oyuncular bagli olduklari grubun lideri komutasinda gorev alir.",
            if ((_op get "dusman") isNotEqualTo "") then {_op get "dusman"} else {"Dusman kuvvetleri ve konumlari belirsiz; kesif ve temasla netlesecek."}, [_taraf] call _tarafAd];
        private _son = if (_fazlar isEqualTo []) then {"?"} else { ((_fazlar select -1) get "ad") };
        _satir pushBack format ["<br/><t size='1.1'>2. GOREV</t><br/>%1 kuvvetleri H-saatinde %2 faz halinde harekat yurutur: %3 objektif (son faz: %4).", [_taraf] call _tarafAd, count _fazlar, count _tum, _son];
        private _icra = [format ["<br/><t size='1.1'>3. ICRA</t><br/>Komutanin niyeti: %1", if ((_op get "niyet") isNotEqualTo "") then {_op get "niyet"} else {"(belirtilmedi)"}], format ["H-saati: %1.", if ((_op get "hMod") isEqualTo 0) then {format ["harekat bildiriminden %1 dk sonra", ((_op get "hDk") max 0)]} else {"elle (komuta emriyle)"}]];
        {
            private _f = _x;
            private _hs = (_f get "hedefler") apply { format ["%1 %2 (%3)", ["ELE GECIR", "SAVUN"] select ((_x get "tip") isEqualTo 1), _x get "ad", mapGridPosition (_x get "obj")] };
            _icra pushBack format ["Faz %1 '%2': %3.", _f get "no", _f get "ad", _hs joinString "; "];
        } forEach _fazlar;
        _icra pushBack format ["Faz gecisi: fazin tum planlari bitince%1%2.", if ((_op get "bekle") > 0) then {format [" + %1 dk toparlanma", round ((_op get "bekle") / 60)]} else {""}, if ((_op get "fazSure") > 0) then {format ["; faz sure siniri %1 dk (asilirsa %2)", round ((_op get "fazSure") / 60), ["sonraki faza gecilir", "harekat basarisiz biter"] select ((_op get "sureAsimi") isEqualTo 1)]} else {""}];
        _satir pushBack (_icra joinString "<br/>");
        _satir pushBack "<br/><t size='1.1'>4. IDARE / LOJISTIK</t><br/>Saglik: grup hekimleri (TCCC / ACE). Ikmal ve tahliye talepleri: sahada TC2 uzerinden (bu surumde harekat katmani ikmal yurutmez). [T]";
        _satir pushBack "<br/><t size='1.1'>5. KOMUTA / HABERLESME</t><br/>Komuta: bot grup liderleri (oyuncu bagli oldugu grubun lideri komutasindadir). Telsiz: sahada ACRE2 / TC2 aglari. [T]<br/><t size='0.8'>(Otomatik uretilmis TASLAK OPORD; TC2 OPORD formatina uyarlanacak.)</t>";
        private _ana = format ["HAR_%1", _id];
        [_taraf, _ana, "", format ["HAREKAT: %1", _op get "ad"], _satir joinString "<br/>", objNull, "attack"] call _gorevKur;
        {
            private _f = _x;
            { [_id, _f get "no", _x] call _isaretGuncelle; } forEach (_f get "hedefler");
        } forEach _fazlar;
        _op set ["opordVar", true];
        [_taraf, format ["%1: OPORD bildirildi (%2 faz, %3 objektif) - Gorevler / harita isaretleri guncellendi", _op get "ad", count _fazlar, count _tum]] call _mesaj;
        true
    };
    // ------------------------------------------------------------------------------------------------------------------------------------------------
    case "BASLAT": {
        _a params ["_id"];
        private _op = lambs_danger_harekatlar getOrDefault [_id, createHashMap];
        if (count _op isEqualTo 0 || {(_op get "durum") isNotEqualTo "HAZIRLIK"}) exitWith {false};
        if ((_op get "fazlar") isEqualTo []) exitWith { [_op get "taraf", format ["%1: hic faz / objektif kayitli degil - baslatilamadi (Objektif modullerini Harekat modulune SYNC edin)", _op get "ad"]] call _mesaj; _op set ["durum", "IPTAL"]; call _liste; false };
        if !(_op get "opordVar") then { ["OPORD", [_id]] call FUNC(harekat); };
        _op set ["durum", "ICRA"];
        _op set ["aktif", -1];
        _op set ["tBas", time];
        [_op get "taraf", format ["%1: H-SAATI - harekat basladi", _op get "ad"]] call _mesaj;
        call _liste;
        ["FAZ_SONRAKI", [_id]] call FUNC(harekat)
    };
    // ------------------------------------------------------------------------------------------------------------------------------------------------
    case "FAZ_SONRAKI": {
        _a params ["_id"];
        private _op = lambs_danger_harekatlar getOrDefault [_id, createHashMap];
        if (count _op isEqualTo 0 || {(_op get "durum") isNotEqualTo "ICRA"}) exitWith {false};
        private _taraf = _op get "taraf";
        private _fazlar = _op get "fazlar";
        private _ni = (_op get "aktif") + 1;
        if (_ni >= count _fazlar) exitWith {
            // HAREKAT SONU
            private _tamam = {(_x get "durum") isEqualTo "TAMAM"} count _fazlar;
            private _kismi = {(_x get "durum") in ["TAMAM", "KISMI"]} count _fazlar;
            private _sonuc = if (_tamam isEqualTo (count _fazlar)) then {"BASARILI"} else { if (_kismi > 0) then {"KISMI"} else {"BASARISIZ"} };
            _op set ["durum", ["BASARISIZ", "BITTI"] select (_sonuc isNotEqualTo "BASARISIZ")];
            _op set ["sonuc", _sonuc];
            [format ["HAR_%1", _id], ["FAILED", "SUCCEEDED"] select (_sonuc isNotEqualTo "BASARISIZ")] call _gorevDurum;
            private _ozet = format ["%1: HAREKAT BITTI - %2 | sure %3 dk | fazlar: %4", _op get "ad", _sonuc, round ((time - (_op getOrDefault ["tBas", time])) / 60), _fazlar apply {format ["F%1 %2", _x get "no", _x get "durum"]} joinString ", "];
            [_taraf, _ozet] call _mesaj;
            diag_log format ["[HAREKAT-AAR] %1", _ozet];
            call _liste;
            true
        };
        private _faz = _fazlar select _ni;
        _op set ["aktif", _ni];
        _op set ["gecisT", -1];
        _faz set ["durum", "ICRA"];
        _faz set ["t0", time];
        private _fno = _faz get "no";
        private _fg = format ["HAR_%1_F%2", _id, _fno];
        [_taraf, _fg, format ["HAR_%1", _id], format ["FAZ %1: %2", _fno, _faz get "ad"], format ["Faz %1 basladi. Objektifler: %2", _fno, ((_faz get "hedefler") apply { format ["%1 %2", _x get "ad", mapGridPosition (_x get "obj")] }) joinString "; "], objNull, "attack"] call _gorevKur;
        {
            private _h = _x;
            private _hg = [_id, _fno, _h get "k"] call _gid;
            [_taraf, _hg, _fg, format ["%1: %2", ["ELE GECIR", "SAVUN"] select ((_h get "tip") isEqualTo 1), _h get "ad"], format ["%1 %2 (%3). Bot komutanlar plani yurutur; oyuncular bagli olduklari grubun lideri komutasinda rol gorevlerini izler.", ["Objektifi ele gecirin", "Objektifi savunun"] select ((_h get "tip") isEqualTo 1), _h get "ad", mapGridPosition (_h get "obj")], _h get "obj", ["attack", "defend"] select ((_h get "tip") isEqualTo 1)] call _gorevKur;
            _h set ["durum", "BEKLE"];
            _h set ["bekleT", time];
        } forEach (_faz get "hedefler");
        [_taraf, format ["%1: FAZ %2 '%3' basladi (%4 objektif)", _op get "ad", _fno, _faz get "ad", count (_faz get "hedefler")]] call _mesaj;
        true
    };
    // ------------------------------------------------------------------------------------------------------------------------------------------------
    case "SONRAKI": {
        _a params ["_id"];
        private _op = lambs_danger_harekatlar getOrDefault [_id, createHashMap];
        if (count _op isEqualTo 0) exitWith {false};
        if ((_op get "durum") isEqualTo "HAZIRLIK") exitWith { ["BASLAT", [_id]] call FUNC(harekat) };
        if ((_op get "durum") isNotEqualTo "ICRA") exitWith {false};
        private _fi = _op get "aktif";
        if (_fi >= 0 && {_fi < count (_op get "fazlar")}) then {
            private _faz = (_op get "fazlar") select _fi;
            if !((_faz get "durum") in ["TAMAM", "KISMI", "BASARISIZ", "ATLANDI"]) then {
                { if !((_x get "durum") in ["TAMAM", "BASARISIZ", "SURE", "ATLANDI"]) then { _x set ["durum", "ATLANDI"]; [_id, _faz get "no", _x] call _isaretGuncelle; }; } forEach (_faz get "hedefler");
                _faz set ["durum", "ATLANDI"];
                [format ["HAR_%1_F%2", _id, _faz get "no"], "CANCELED"] call _gorevDurum;
            };
        };
        ["FAZ_SONRAKI", [_id]] call FUNC(harekat)
    };
    // ------------------------------------------------------------------------------------------------------------------------------------------------
    case "DURDUR": {
        _a params ["_id"];
        private _op = lambs_danger_harekatlar getOrDefault [_id, createHashMap];
        if (count _op isEqualTo 0 || {(_op get "durum") in ["BITTI", "BASARISIZ", "IPTAL"]}) exitWith {false};
        private _n = 0;
        {
            private _f = _x;
            {
                private _p = lambs_danger_planlar getOrDefault [_x get "planId", createHashMap];
                if (count _p > 0 && {!((_p getOrDefault ["faz", ""]) in ["DONUS", "BITTI", "IPTAL"])}) then {
                    if ((_p getOrDefault ["hqPoz", []]) isNotEqualTo []) then { _p set ["faz", "DONUS"]; _p set ["fazT", time]; _p set ["fazBasT", time]; _p set ["donusNeden", "Harekat DURDUR"]; } else { _p set ["faz", "IPTAL"]; };
                    _n = _n + 1;
                };
                if !((_x get "durum") in ["TAMAM", "BASARISIZ", "SURE", "ATLANDI"]) then { _x set ["durum", "ATLANDI"]; [_id, _f get "no", _x] call _isaretGuncelle; };
            } forEach (_f get "hedefler");
        } forEach (_op get "fazlar");
        _op set ["durum", "IPTAL"];
        [format ["HAR_%1", _id], "CANCELED"] call _gorevDurum;
        [_op get "taraf", format ["%1: harekat DURDURULDU (%2 plan iptal / donus)", _op get "ad", _n]] call _mesaj;
        call _liste;
        true
    };
    // ------------------------------------------------------------------------------------------------------------------------------------------------
    case "DURUM": {
        _a params ["_id"];
        private _op = lambs_danger_harekatlar getOrDefault [_id, createHashMap];
        if (count _op isEqualTo 0) exitWith {"harekat yok"};
        private _m = [format ["%1 | %2 | %3", _op get "ad", _op get "durum", [_op get "taraf"] call _tarafAd]];
        {
            private _f = _x;
            _m pushBack format ["  Faz %1 '%2' [%3]: %4", _f get "no", _f get "ad", _f get "durum", ((_f get "hedefler") apply {format ["%1 [%2%3]", _x get "ad", _x get "durum", if ((_x get "planFaz") isNotEqualTo "") then {" / plan " + (_x get "planFaz")} else {""}]}) joinString "; "];
        } forEach (_op get "fazlar");
        _m joinString "\n"
    };
    // ------------------------------------------------------------------------------------------------------------------------------------------------
    case "ADIM": {
        _a params ["_id"];
        private _op = lambs_danger_harekatlar getOrDefault [_id, createHashMap];
        if (count _op isEqualTo 0 || {missionNamespace getVariable ["lambs_danger_harekatOff", false]}) exitWith {};
        private _durum = _op get "durum";
        if (_durum in ["BITTI", "BASARISIZ", "IPTAL"]) exitWith {};
        private _taraf = _op get "taraf";
        private _fazlar = _op get "fazlar";
        if (!(_op get "opordVar") && {_fazlar isNotEqualTo []} && {(time - (_op get "t0")) > 15} && {(time - (_op get "kayitT")) > 8}) then { ["OPORD", [_id]] call FUNC(harekat); };
        if (_durum isEqualTo "HAZIRLIK") exitWith {
            if ((_op get "hT") > 0 && {time >= (_op get "hT")} && {_op get "opordVar"}) then { ["BASLAT", [_id]] call FUNC(harekat); };
        };
        private _fi = _op get "aktif";
        if (_fi < 0 || {_fi >= count _fazlar}) exitWith {};
        private _faz = _fazlar select _fi;
        private _fno = _faz get "no";
        // faz bitti: toparlanma beklemesi sonrasi sonraki faz
        if ((_faz get "durum") in ["TAMAM", "KISMI", "BASARISIZ", "ATLANDI"]) exitWith {
            if ((_op get "gecisT") > 0 && {time >= (_op get "gecisT")}) then { ["FAZ_SONRAKI", [_id]] call FUNC(harekat); };
        };
        private _sureAsti = (_op get "fazSure") > 0 && {(time - (_faz get "t0")) > (_op get "fazSure")};
        private _acik = 0;
        {
            private _h = _x;
            private _hd = _h get "durum";
            private _hg = [_id, _fno, _h get "k"] call _gid;
            private _bitir = {
                params ["_yeni", "_neden"];
                _h set ["durum", _yeni];
                _h set ["neden", _neden];
                [format ["%1", _hg], ["FAILED", "SUCCEEDED"] select (_yeni isEqualTo "TAMAM")] call _gorevDurum;
                { [_x, ["FAILED", "SUCCEEDED"] select (_yeni isEqualTo "TAMAM")] call _gorevDurum; } forEach (_h get "rolGorev");
                [_id, _fno, _h] call _isaretGuncelle;
                [_taraf, format ["%1 / F%2 %3 (%4): %5%6", _op get "ad", _fno, _h get "ad", mapGridPosition (_h get "obj"), _yeni, if (_neden isNotEqualTo "") then {" - " + _neden} else {""}]] call _mesaj;
                diag_log format ["[HAREKAT-AAR] %1 | F%2 | %3 | %4 | %5 | t+%6 dk", _op get "ad", _fno, _h get "ad", _yeni, _neden, round ((time - (_faz get "t0")) / 60)];
            };
            if (_hd in ["BEKLE", "ISTENDI", "ICRA"] && {_sureAsti}) then {
                ["SURE", format ["faz sure siniri (%1 dk) asildi", round ((_op get "fazSure") / 60)]] call _bitir;
                _hd = "SURE";
            };
            if (_hd isEqualTo "BEKLE") then {
                _acik = _acik + 1;
                if (time >= (_h get "bekleT")) then {
                    _h set ["durum", "ISTENDI"];
                    _h set ["istekT", time];
                    _h set ["sonuc", -1];
                    _h set ["deneme", (_h get "deneme") + 1];
                    [_taraf, _h get "obj", _h get "ayar", _h] spawn {
                        params ["_t", "_o", "_ayarA", "_hh"];
                        private _r = [_t, _o, createHashMapFromArray _ayarA] call (missionNamespace getVariable ["lambs_danger_fnc_komutanPlan", {false}]);
                        _hh set ["neden", if (_r isEqualTo true) then {""} else {missionNamespace getVariable ["lambs_danger_planRedNeden", ""]}];
                        if (_r isNotEqualTo true) then { missionNamespace setVariable ["lambs_danger_planRedNeden", ""]; };
                        _hh set ["sonuc", [0, 1] select (_r isEqualTo true)];
                    };
                };
            };
            if (_hd isEqualTo "ISTENDI") then {
                _acik = _acik + 1;
                private _s = _h get "sonuc";
                if (_s isEqualTo 1) then {
                    private _tn = (values lambs_danger_planlar) select {
                        (_x get "taraf") isEqualTo _taraf && {((_x get "obj") distance2D (_h get "obj")) < 3} && {(_x getOrDefault ["t0", 0]) >= ((_h get "istekT") - 2)}
                    };
                    if (_tn isNotEqualTo []) then {
                        _h set ["planId", (_tn select -1) get "id"];
                        _h set ["durum", "ICRA"];
                        [_id, _fno, _h] call _isaretGuncelle;
                        [_taraf, format ["%1 / F%2 %3: plan KURULDU (%4, %5 grup)", _op get "ad", _fno, _h get "ad", _h get "planId", count ((_tn select -1) get "gruplar")]] call _mesaj;
                    } else {
                        if ((time - (_h get "istekT")) > 20) then { ["BASARISIZ", "plan kuruldu denildi ama kayit bulunamadi"] call _bitir; _acik = _acik - 1; };
                    };
                };
                if (_s isEqualTo 0) then {
                    // v8.406 (RPT 5be59146: ayni fazin iki objektifi, biri tum gruplari aldi, digeri 'baska planda' ile 3 denemede BASARISIZ sayildi): grup yokluk nedeni baska planin mesgul etmesiyse bu BASARISIZ DENEMESI SAYILMAZ; gruplar bosalana kadar 45 sn'de bir beklenir (en cok 60 bekleme = 45 dk)
                    private _mesgul = ((toLower (str (_h getOrDefault ["neden", ""]))) find "baska planda") >= 0;
                    if (_mesgul && {(_h getOrDefault ["mesgulBekle", 0]) < 60}) then {
                        _h set ["mesgulBekle", (_h getOrDefault ["mesgulBekle", 0]) + 1];
                        _h set ["deneme", ((_h get "deneme") - 1) max 0];
                        _h set ["durum", "BEKLE"];
                        _h set ["bekleT", time + 45];
                        if ((_h get "mesgulBekle") isEqualTo 1) then { [_taraf, format ["%1 / F%2 %3: gruplar baska planda mesgul - bosalana kadar beklenecek", _op get "ad", _fno, _h get "ad"]] call _mesaj; };
                        diag_log format ["[HAREKAT] %1 / F%2 %3: gruplar baska planda mesgul (%4) - bekleniyor (%5/60)", _op get "ad", _fno, _h get "ad", _h get "neden", _h get "mesgulBekle"];
                    } else {
                    if ((_h get "deneme") < 3) then {
                        _h set ["durum", "BEKLE"];
                        _h set ["bekleT", time + 45];
                        diag_log format ["[HAREKAT] %1 / F%2 %3: plan kurulamadi (%4) - deneme %5/3, 45 sn sonra tekrar", _op get "ad", _fno, _h get "ad", _h get "neden", _h get "deneme"];
                    } else {
                        ["BASARISIZ", format ["plan kurulamadi (3 deneme): %1", _h get "neden"]] call _bitir;
                        _acik = _acik - 1;
                    };
                    };
                };
                if (_s isEqualTo -1 && {(time - (_h get "istekT")) > 60}) then { ["BASARISIZ", "plan istegi zaman asimi"] call _bitir; _acik = _acik - 1; };
            };
            if (_hd isEqualTo "ICRA") then {
                private _p = lambs_danger_planlar getOrDefault [_h get "planId", createHashMap];
                if (count _p isEqualTo 0) then {
                    ["BASARISIZ", "plan kaydi yok"] call _bitir;
                } else {
                    private _pf = _p getOrDefault ["faz", ""];
                    if (_pf isNotEqualTo (_h get "planFaz")) then {
                        _h set ["planFaz", _pf];
                        if (_pf isNotEqualTo "KUR") then { [_taraf, format ["%1 / F%2 %3: plan fazi -> %4", _op get "ad", _fno, _h get "ad", _pf]] call _mesaj; };
                    };
                    if (_pf isEqualTo "BITTI") then {
                        ["TAMAM", ""] call _bitir;
                    } else {
                        if (_pf in ["IPTAL", "DONUS", "CEKILME"]) then {
                            ["BASARISIZ", format ["plan %1", _pf]] call _bitir;
                        } else {
                            _acik = _acik + 1;
                            // OYUNCU ROL GOREVLERI: planin gruplarinda oyuncu varsa o gruba ozel gorev (lideri BOT olan grupta oyuncu ast)
                            private _roller = _p getOrDefault ["roller", createHashMap];
                            {
                                private _g = _x;
                                if (!isNull _g && {(({isPlayer _x} count (units _g)) > 0)}) then {
                                    private _rg = format ["%1_%2", _hg, ((netId _g) splitString ":") joinString "_"];
                                    if !(_rg in (_h get "rolGorev")) then {
                                        private _rol = _roller getOrDefault [groupId _g, "MANEVRA"];
                                        private _tipP = _h get "tip";
                                        private _acikM = if (_tipP isEqualTo 1) then {
                                            format ["Birliginiz (%1) %2 objektifini SAVUNUR: lider (bot) mevzi noktalarini belirler; mevziye girin, sektorunuzu gozleyin, ates disiplinine uyun.", groupId _g, _h get "ad"]
                                        } else {
                                            switch (_rol) do {
                                                case "DESTEK": { format ["Birliginiz (%1) DESTEK unsurudur: destek noktasi (SBF %2) uzerinden bastirma atesiyle manevra unsurunu destekler. Liderinizi (bot) izleyin; ates hattinda dost varken ates etmeyin.", groupId _g, mapGridPosition ([_p getOrDefault ["sbf", []], _h get "obj"] call _pozOk)] };
                                                case "YEDEK": { format ["Birliginiz (%1) YEDEK unsurudur: toplanma noktasinda (RP %2) hazir bekler; komutan emriyle bosluk / takviye gorevine girer.", groupId _g, mapGridPosition ([_p getOrDefault ["rp", []], _h get "obj"] call _pozOk)] };
                                                default { format ["Birliginiz (%1) MANEVRA unsurudur: toplanma (RP %2) -> ORP (%3) -> destek ateşiyle objektife (%4) saldirir. Liderinizi (bot) izleyin; ORP'de kesif tamamlanana kadar bekleyin.", groupId _g, mapGridPosition ([_p getOrDefault ["rp", []], _h get "obj"] call _pozOk), mapGridPosition ([_p getOrDefault ["orp", []], _h get "obj"] call _pozOk), mapGridPosition (_h get "obj")] };
                                            }
                                        };
                                        private _hdf = switch (_rol) do { case "DESTEK": {[_p getOrDefault ["sbf", []], _h get "obj"] call _pozOk}; case "YEDEK": {[_p getOrDefault ["rp", []], _h get "obj"] call _pozOk}; default {_h get "obj"} };
                                        if (_tipP isEqualTo 1) then { _hdf = _h get "obj"; };
                                        [_g, _rg, _hg, format ["ROL: %1", [_rol, "SAVUNMA"] select (_tipP isEqualTo 1)], _acikM, _hdf, "attack"] call _gorevKur;
                                        (_h get "rolGorev") pushBack _rg;
                                        diag_log format ["[HAREKAT] oyuncu rol gorevi: %1 | grup %2 | rol %3 | %4", _h get "ad", groupId _g, _rol, _rg];
                                    };
                                };
                            } forEach (_p getOrDefault ["gruplar", []]);
                        };
                    };
                };
            };
        } forEach (_faz get "hedefler");

        // faz tamamlandi mi (hic acik hedef kalmadiysa)
        if (_acik <= 0 && {((_faz get "hedefler") findIf {(_x get "durum") in ["BEKLE", "ISTENDI", "ICRA"]}) < 0}) then {
            private _hh = _faz get "hedefler";
            private _tamam = {(_x get "durum") isEqualTo "TAMAM"} count _hh;
            private _fSonuc = if (_tamam isEqualTo (count _hh)) then {"TAMAM"} else { if (_tamam > 0) then {"KISMI"} else {"BASARISIZ"} };
            _faz set ["durum", _fSonuc];
            [format ["HAR_%1_F%2", _id, _fno], ["FAILED", "SUCCEEDED"] select (_fSonuc isNotEqualTo "BASARISIZ")] call _gorevDurum;
            [_taraf, format ["%1: FAZ %2 '%3' %4 (%5/%6 objektif) | sure %7 dk", _op get "ad", _fno, _faz get "ad", _fSonuc, _tamam, count _hh, round ((time - (_faz get "t0")) / 60)]] call _mesaj;
            diag_log format ["[HAREKAT-AAR] %1 | FAZ %2 | %3 | %4/%5", _op get "ad", _fno, _fSonuc, _tamam, count _hh];
            if (_fSonuc isEqualTo "BASARISIZ" && {!(_op get "devam")}) then {
                _op set ["durum", "BASARISIZ"];
                _op set ["sonuc", "BASARISIZ"];
                [format ["HAR_%1", _id], "FAILED"] call _gorevDurum;
                [_taraf, format ["%1: HAREKAT BASARISIZ - faz %2 basarisiz (devam kapali)", _op get "ad", _fno]] call _mesaj;
                call _liste;
            } else {
                if (_sureAsti && {(_op get "sureAsimi") isEqualTo 1}) then {
                    _op set ["durum", "BASARISIZ"];
                    _op set ["sonuc", "BASARISIZ"];
                    [format ["HAR_%1", _id], "FAILED"] call _gorevDurum;
                    [_taraf, format ["%1: HAREKAT BASARISIZ - faz %2 sure siniri asildi", _op get "ad", _fno]] call _mesaj;
                    call _liste;
                } else {
                    _op set ["gecisT", time + (_op get "bekle")];
                    if ((_op get "bekle") > 0 && {(_fi + 1) < count _fazlar}) then { [_taraf, format ["%1: toparlanma / yeniden tertiplenme %2 dk, sonra Faz %3", _op get "ad", round ((_op get "bekle") / 60), (_fazlar select (_fi + 1)) get "no"]] call _mesaj; };
                };
            };
        };
    };
    default { diag_log format ["[HAREKAT] bilinmeyen islem: %1", _islem]; nil };
};

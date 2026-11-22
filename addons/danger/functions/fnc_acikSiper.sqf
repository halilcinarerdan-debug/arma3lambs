#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ACIKTA KALAN ASKERI NESNE ARKASINA / BINAYA SOK (v8.303 bina; v8.305 agac / kaya / duvar arkasi; kullanici: 'arkada ev var adam acikta kaliyor ama evi siper olarak kullanmiyor').
 * Cagiran: fnc_coverHug — temasta, duran, acikta (3 yukseklikte dusmandan sert yuzey yok ya da 6 m'den uzak) asker icin.
 *   1) 28 m icindeki girilebilir binalarin (buildingPos) noktalari taranir
 *   2) aday: dusmanin gozunden o noktaya hat bina tarafindan KESILIYOR (lineIntersects) + dusmana 8 m'den fazla yaklasmaz + baska askere ayrilmis degil (1.8 m, 30 sn)
 *   3) en yakin aday: doMove, FULL hiz, 15 sn taktik kilidi (diger hareket arbitrajlari ezmesin); asker basina 25 sn'de bir
 * v8.509: sert siper yoksa CALI / FIDAN ARKASI (gizlenme, VIEW LOD) de aranir; arama yaricapi varsayilan 22 -> 32 -> v8.513: 16 m (lambs_danger_siperYaricap; 'cok uzaga siper aliyorlar').
 * ATLANIR: bounding / taktik yurutenler (hucumda ilerlemek bilincli), CBA kapatma: lambs_danger_acikSiperOff = true
 * v8.354: bina kolu ATIS POZISYONU tercih eder (dusmana pencere hatti acik, ust ortulu); pasif gizlenme yalniz son care. Log: [ACIK-SIPER]
 *
 * Arguments:
 * 0: Asker <OBJECT>
 * 1: En yakin bilinen dusman <OBJECT>
 *
 * Return Value: Yonlendirildi mi <BOOL>
 * Public: No
*/

params [["_u", objNull, [objNull]], ["_en", objNull, [objNull]], ["_maxM", -1, [0]]];   // v8.732: 3. arguman = en uzak siper (m) (on tarama: yakin siper yukseltmesi); -1 = sinir yok
if (isNull _u || {isNull _en} || {missionNamespace getVariable ["lambs_danger_acikSiperOff", false]}) exitWith {false};
if (captive _u || {_u getVariable [QGVAR(teslim), false]}) exitWith {false};   // v8.352: teslim olan / esir asker nesne arkasina gonderilmez (STOP -> MOVE salinimi)
if (time < (_u getVariable [QGVAR(acikSiperT), 0])) exitWith {false};
// v8.650 KENDI SIPERINDE KAL (kullanici: 'altisteki gibi almiyorlar'; RPT d6ee1c87: [SIPER-OTUR] oturtuldu 2.8-8.7 m, ayni asker 10-15 sn arayla yeniden secip yeniden kosuyor: coverHug CUP / A2 agacinda (FIRE LOD yok / dar) 'siperde' saymiyor -> acikta -> acikSiper 10 sn'de bir yeniden sec -> git-gel):
//   asker son 60 sn'de KENDI sectigi siper noktasinin 1.5 m icindeyse ve dusman gozunden hala GIZLIyse (VIEW LOD hatti arada nesneye carpiyor) yeniden secim YOK (baski >= 0.9 ise yine de yeniden bakar)
private _ah0 = _u getVariable [QGVAR(acikSiperHedef), []];
if (_ah0 isNotEqualTo [] && {(time - (_u getVariable [QGVAR(vurulduT), -99])) > 20} && {(time - (_ah0 select 1)) < 60} && {((getPosATL _u) distance2D (_ah0 select 0)) < 1.5} && {(getSuppression _u) < 0.9}) then {
    private _gz = (lineIntersectsSurfaces [eyePos _en, (getPosASL _u) vectorAdd [0, 0, 0.9], _en, _u, true, 1, "VIEW", "NONE"]) isNotEqualTo [];
    if (_gz || {terrainIntersectASL [eyePos _en, (getPosASL _u) vectorAdd [0, 0, 0.9]]}) exitWith {
        _u setVariable [QGVAR(acikSiperT), time + 6];
        false
    };
};
// v8.312: tekrar 25 -> 10 sn (CBA lambs_danger_siperHizli), nesne arama yaricapi CBA lambs_danger_siperYaricap (varsayilan 22 m; eskiden 14), bina _yar + 10 m (eskiden 28)
private _hizli = missionNamespace getVariable ["lambs_danger_siperHizli", true];
private _yar = [_u, "siperYaricap", 16] call FUNC(profilDeger);   // v8.738: cevre profiline gore (ORMAN / KENTSEL / ACIK)
_u setVariable [QGVAR(acikSiperT), time + (([25, 10] select _hizli) / (1 + (((missionNamespace getVariable ["lambs_danger_reaksiyonArtis", 0.3]) max 0) min 1)))];   // v8.735: karar tekrar araligi / (1 + reaksiyonArtis) (tepki / karar hizi; nisan becerisi DEGIL)
private _g = group _u;
// v8.515: eskiden bounding / taktik yurutenlerin TUM grubu atlaniyordu -> RPT 13:14 (Alpha 1-1 BOUNDING iken uyeler 140-160 m'de acikta: [SIPER-YAPIS-OZET] acikta 24 / dk, [ACIK-SIPER] 1) hic kurtarilmiyordu.
//   Simdi yalniz geri cekilen grup, KOSUCU (forceMove) ve baska emirle kilitli (taktikKilit) asker atlanir; bounding'in kapsama / bekleyen uyeleri siperden yararlanir.
private _sayAS = missionNamespace getVariable ["lambs_danger_acikSiperSay", createHashMap];
missionNamespace setVariable ["lambs_danger_acikSiperSay", _sayAS];
private _sebep = if (_g getVariable [QGVAR(isRetreating), false]) then {"geri cekilme"} else { if ((_u getVariable [QGVAR(forceMove), false]) isEqualTo true) then {"kosucu"} else { if ((_u getVariable [QGVAR(taktikKilit), 0]) > time) then {"kilitli"} else {""} } };
if (_sebep isNotEqualTo "") exitWith { _sayAS set [_sebep, (_sayAS getOrDefault [_sebep, 0]) + 1]; false };
if (isNil "lambs_danger_acikSiperOzetT") then {
    lambs_danger_acikSiperOzetT = time + 60;
};
if (time > lambs_danger_acikSiperOzetT) then {
    lambs_danger_acikSiperOzetT = time + 60;
    diag_log format ["[ACIK-SIPER-OZET] 60 sn: %1", (_sayAS toArray false) apply { format ["%1=%2", _x select 0, _x select 1] }];
    _sayAS = createHashMap;
    missionNamespace setVariable ["lambs_danger_acikSiperSay", _sayAS];
};

private _p = getPosATL _u;
private _eASL = eyePos _en;
private _mevziFn = missionNamespace getVariable ["lambs_danger_fnc_mevziPuan", {0}];   // v8.529
private _ed = _u distance2D _en;
// v8.729 YAKIN DOVUS (kullanici: 'adamlar animasyona cok giriyor, face to face'de yere yatiyorlar'; RPT 6ac64f59: dusman 14 m acikta -> 19 m'deki siper icin 4.2 sn ATESSIZ 'saf kosu' + varista DOWN; dusman 17 m -> 24 m kosu): dusman CBA siperYakinM (25 m) icinde ve GORUNUR (arada engel yok,
//   gorunurluk >= 0.4) ise asker uzak siper icin kosmaz (yalniz siperYakinKosuM = 6 m icindeki siper / bina), dovusur; varis duruşu yatik (DOWN) olmaz (comel). 0 = kapali (eski).
private _yakinM = (([_u, "siperYakinM", 25] call FUNC(profilDeger)) max 0) min 60;
private _yakinKosu = (([_u, "siperYakinKosuM", 6] call FUNC(profilDeger)) max 2) min 20;
private _yakinDovus = _yakinM > 0 && {_ed < _yakinM} && {!(lineIntersects [eyePos _u, _eASL, _u, _en])} && {([_u, "VIEW", _en] checkVisibility [eyePos _u, _eASL]) >= 0.4};
if (_yakinDovus) then { _sayAS set ["yakin_dovus", (_sayAS getOrDefault ["yakin_dovus", 0]) + 1]; };
// v8.737 ZOR DURUM (kullanici: 'zor durumda gizlensinler, onu sakin cok geriye atma oncelikte'): baski >= 0.5, yarali ya da komutan WITHDRAW / PEEL / DELAY kararinda ise GIZLENME onceligi DUSMEZ: sahte siper cezasi x0.2, karsilik verme sarti yok, yan yon cezasi x0.5 (cali / yatis dahil gizlenme serbest)
private _zor = ((getSuppression _u) >= 0.5) || {(lifeState _u) isEqualTo "INJURED"} || {((group _u) getVariable [QGVAR(cmdSonKarar), ""]) in ["WITHDRAW", "PEEL", "DELAY"]};
// v8.736 AYNI ANDA HAREKET SINIRI (kullanici: 'cover to cover daha profesyonel'): grupta son 6 sn'de siper atilisina cikmis ve hala kosan asker sayisi siperAyniAnda'ya (2) ulastiysa bu asker (baski < 0.35, yakin dovus degil) 1.5 sn bekler: biri kosar, digerleri kapsar; 6 = kapali
private _ayniA = ((missionNamespace getVariable ["lambs_danger_siperAyniAnda", 2]) max 1) min 6;
private _ertele = false;
if (_ayniA < 6 && {!_yakinDovus} && {(getSuppression _u) < 0.35}) then {
    private _kosan = ({ alive _x && {_x isNotEqualTo _u} && {(time - (_x getVariable [QGVAR(siperDoMoveT), -999])) < 6} && {(speed _x) > 2} } count (units _g));
    if (_kosan >= _ayniA) then { _ertele = true; };
};
if (_ertele) exitWith {
    _sayAS set ["ertelendi", (_sayAS getOrDefault ["ertelendi", 0]) + 1];
    _u setVariable [QGVAR(acikSiperT), time + 1.5];
    false
};
private _limAcik = _yakinDovus || {_maxM > 0};
private _lim = if (_maxM > 0) then { _maxM } else { _yakinKosu };
private _dolu = missionNamespace getVariable ["lambs_danger_acikSiperDolu", []];
_dolu = _dolu select {(time - (_x select 1)) < 30};

// v8.367 YIGILMA NEDENI #1 (RPT 20:12:10 ve 20:15:39-46: 3-4 asker AYNI nesneye - Land_PowerLine_01_wire_50m_F / Land_PowerPoleWooden_L_off - gonderildi, [DURUM] yigilma 2-3/8):
//   (a) rezerv defteri yalniz 1.5 m'de cakisan noktayi eliyordu; ayni nesnenin 3 m yanindaki ikinci nokta 'bos' sayiliyordu -> asgari aralik 4 m (CBA yigilmaAralik),
//   (b) o anda ORADA DURAN dost (ya da grubun findCover / eliteCover / bounding rezervi, coverClaims) hic hesaba katilmiyordu -> canli dost 3 m + ortak defter,
//   (c) sert yuzey testi tek isinla yapiliyordu: ince direk / tel de 'siper' sayiliyordu -> govde genisligi icin +-0.25 m yan isinlar da kapali olmali (asagida).
private _aralik = missionNamespace getVariable ["lambs_danger_yigilmaAralik", 6];
private _talepler = ((_g getVariable [QEGVAR(main,coverClaims), []]) select {(time - (_x select 1)) < 8 && {(_x select 2) isNotEqualTo _u}}) apply {_x select 0};
private _dostPoz = ((_u nearEntities ["CAManBase", _yar + 14]) select {_x isNotEqualTo _u && {alive _x} && {(side group _x) isEqualTo (side group _u)}}) apply {getPosATL _x};
private _doluMu = {
    params ["_pt", "_r"];
    ((_dolu findIf {((_x select 0) distance2D _pt) < _r}) >= 0) || {(_talepler findIf {_x distance2D _pt < _r}) >= 0} || {(_dostPoz findIf {_x distance2D _pt < (_r min (missionNamespace getVariable ["lambs_danger_siperDostAralik", 4.5]))}) >= 0}   // v8.656: canli dost araligi 3 -> 4.5 m (CBA siperDostAralik; ekran goruntusu: 6 bot birkac metrede kumeleniyor)
};
// v8.657 COKLU TEHDIT (kullanici: 'dediklerini yap / zayif olanlari yap'; egitimli asker yan ve arka acidan da korunur): en yakin dusman (_en) disinda BILINEN (>= SEZILDI) en cok 3 baska dusman (<= 250 m) icin aday siper noktasinin (1.0 m) FIRE LOD hatti ACIKSA +5 ceza / dusman (CBA siperCokluTehdit)
private _digerE = [];
if (missionNamespace getVariable ["lambs_danger_siperCokluTehdit", true]) then {
    private _esikC = ["SEZILDI"] call FUNC(bilgiEsik);
    _digerE = ((_u nearTargets 250) select {
        private _o2 = _x select 4;
        !isNull _o2 && {alive _o2} && {_o2 isNotEqualTo _en} && {_o2 isKindOf "CAManBase"} && {((side group _u) getFriend (side group _o2)) < 0.6} && {(_u knowsAbout _o2) >= _esikC}
    }) apply { eyePos (_x select 4) };
    _digerE = _digerE select [0, 5];   // v8.737: 3 -> 5 bilinen dusman
};
private _coklu = {
    params ["_pt"];
    private _pa = (AGLToASL [_pt select 0, _pt select 1, 0]) vectorAdd [0, 0, 1.0];
    ((missionNamespace getVariable ["lambs_danger_siperCokluAgirlik", 10]) max 0) * ({ ((lineIntersectsSurfaces [_x, _pa, objNull, _u, true, 1, "FIRE", "NONE"]) isEqualTo []) && {!(terrainIntersectASL [_x, _pa])} } count _digerE)   // v8.737: 5 -> CBA siperCokluAgirlik (10 m / acik dusman)
};
// v8.724 ONGORU / COKLU SENARYO (kullanici: 'botlar yapacaklari taktikleri onceden dusunsun', 'cover yerleri dusman bilinen yonune gore', 'coklu senaryo / coklu durum'): siper secimi yalniz dusmanin SU ANKI konumuna degil, tahmini konumlarina da bakar:
//   S1 ILERI: dusman hizi > 1 m/sn ise hareket yonunde ongoruSure (4 sn) sonraki konum (agirlik = ongoruAgirlik, 3 m);  S2 / S3 KANAT: dusman ayni mesafeyi koruyup gruba gore +-55 derece yana kayarsa (kanat; agirlik yarisi, CBA ongoruKanat).
//   Aday siper noktasinin (1.0 m) FIRE LOD hatti bu varsayimsal goz noktalarindan ACIKSA ilgili agirlik cezaya eklenir (mesafe / durus puani ile ayni birim: m). Bilinen konum + diger bilinen dusmanlar (v8.657) mantigi aynen korunur; yalniz NESNE ARKASI adaylarinda uygulanir.
private _senE = [];
private _ogSureG = 4;
if (missionNamespace getVariable ["lambs_danger_ongoru", true]) then {   // v8.735: yeniden tasarim (olasi siper kumesi; hiz tahmini kisa ufuk + sonumlu); v8.734'te kapatilmisti (ileri senaryo hatasi 14.1 m vs yerinde kalir 3.4 m)
    private _ogS = ((missionNamespace getVariable ["lambs_danger_ongoruSure", 2]) max 1) min 10;
    _ogSureG = _ogS;
    private _ogA = (([_u, "ongoruAgirlik", 3] call FUNC(profilDeger)) max 0) min 12;
    if (_ogA > 0) then {
        private _ep = getPosASL _en;
        private _ev = velocity _en;
        private _hizE = sqrt (((_ev select 0) ^ 2) + ((_ev select 1) ^ 2));
        private _yuk = ((_ep select 2) - (getTerrainHeightASL _ep)) max 0;
        // v8.735 1) OLASI SIPER KUMESI: dusmanin 15 m icinde bizden gizli 3 nesne arkasi (insan dusman durur / siper degistirir; hiz tahmininden daha dogru varsayim)
        {
            _senE pushBack [AGLToASL [_x select 0, _x select 1, 1.1], _ogA, "siper"];
        } forEach ([_en, getPosATL _u, 3, 15] call FUNC(dusmanSiperKumesi));
        if (_hizE > 1.5) then {
            // hiz tahmini yalniz kisa ufuk (<= 2.5 sn) ve %70 sonumlu
            private _ogK = (_ogS min 2.5) * 0.7;
            private _pp = [(_ep select 0) + ((_ev select 0) * _ogK), (_ep select 1) + ((_ev select 1) * _ogK), 0];
            _pp set [2, (getTerrainHeightASL _pp) + _yuk + 1.6];
            _senE pushBack [_pp, _ogA, "ileri"];
        };
        if (missionNamespace getVariable ["lambs_danger_ongoruKanat", false]) then {
            private _br = _u getDir _en;
            private _dm = (_ed max 20) min 150;
            {
                private _kp = (getPosATL _u) getPos [_dm, _br + _x];
                if (!surfaceIsWater _kp) then {
                    _senE pushBack [AGLToASL [_kp select 0, _kp select 1, 1.6], _ogA * 0.5, "kanat"];
                };
            } forEach [55, -55];
        };
    };
};
// v8.730 OLCUM (kullanici: 'on gorunun gercekten ise yarayip yaramayacagini olcecek sistem ekle'): secimlerin CBA ongoruKontrolOran'i (varsayilan %25) KONTROL grubudur: senaryolar hesaplanir ama ceza UYGULANMAZ (secim eski gibi);
//   sonuc fnc_ongoruKayit + fnc_ongoruOlcum ile 12 sn izlenir (gercek dusmanin goz hatti acikligi, hasar / olum) ve TEDAVI (ceza uygulandi) ile KONTROL karsilastirilir; ayrica senaryo tahmin hatasi olculur.
private _ogKontrol = (_senE isNotEqualTo []) && {(random 1) < (((missionNamespace getVariable ["lambs_danger_ongoruKontrolOran", 0.25]) max 0) min 0.9)};
// v8.735 rota riski goz noktalari: gercek dusman (agirlik 1) + olasi siper noktalari (0.5); kontrol grubunda uygulanmaz (olcum)
private _yolOn = (missionNamespace getVariable ["lambs_danger_rotaRiski", true]) && {!_ogKontrol};
private _yolAg = (([_u, "rotaRiskAgirlik", 2] call FUNC(profilDeger)) max 0) min 8;
private _gercekCezaM = ([_u, "siperGercekCezaM", 60] call FUNC(profilDeger)) max 0;   // v8.738: profile gore (bir kez / cagri)
private _yanAg = (([_u, "siperYanAgirlik", 2] call FUNC(profilDeger)) max 0) min 8;
private _yolEyes = [[_eASL, 1]] + ((_senE select {(_x param [2, ""]) isEqualTo "siper"}) apply {[_x select 0, 0.5]});
private _ongoruCeza = {
    params ["_pt"];
    if (_senE isEqualTo [] || {_ogKontrol}) exitWith {0};
    private _pa = (AGLToASL [_pt select 0, _pt select 1, 0]) vectorAdd [0, 0, 1.0];
    private _c = 0;
    {
        _x params ["_ge", "_w"];
        if (((lineIntersectsSurfaces [_ge, _pa, objNull, _u, true, 1, "FIRE", "NONE"]) isEqualTo []) && {!(terrainIntersectASL [_ge, _pa])}) then { _c = _c + _w; };
    } forEach _senE;
    if (_c > 0) then { _sayAS set ["ongoru_cezali_aday", (_sayAS getOrDefault ["ongoru_cezali_aday", 0]) + 1]; };
    _c
};
// govde genisligi testi: istenen durus yuksekliginde hedef noktanin +-0.25 m yanindan da isin nesneye carpmali
private _govdeKapali = {
    params ["_eA", "_gA", "_hh", "_enm", "_unt"];
    private _hd = _gA vectorAdd [0, 0, _hh];
    private _vv = _hd vectorDiff _eA;
    private _pp = vectorNormalized [-(_vv select 1), _vv select 0, 0];
    private _gvA = missionNamespace getVariable ["lambs_danger_siperGovde", 0.25];
    if (_hh <= 0.5) then { _gvA = _gvA * 0.7; };   // v8.552: YATIK govde (0.4 m) daha dar: ince govdeli ormanda yatarak siper (RPT: 'yalniz agac' siniflamasi 12-24 / dk)
    private _lodA = missionNamespace getVariable ["lambs_danger_siperLod", "FIRE"];
    ({(lineIntersectsSurfaces [_eA, _hd vectorAdd (_pp vectorMultiply _x), _enm, _unt, true, 1, _lodA, "NONE"]) isNotEqualTo []} count [-_gvA, _gvA]) isEqualTo 2
};
// talep: bu askerin secimi grubun ortak rezerv defterine + kendi 'hedef' degiskenine yazilir ([YIGILMA-NEDEN] ayni noktaya giden askerleri buradan adlandirir)
private _talepYaz = {
    params ["_pt", "_ad"];
    private _cl = (_g getVariable [QEGVAR(main,coverClaims), []]) select {(time - (_x select 1)) < 8};
    _cl pushBack [_pt, time, _u];
    _g setVariable [QEGVAR(main,coverClaims), _cl];
    _u setVariable [QGVAR(acikSiperHedef), [_pt, time, _ad]];
};

// v8.305 NESNENIN ARKASINA GEC (kullanici: 'siper cok guzel seciyor ama sadece yaklasiyor, siperin yanindaysa guvende saniyor, agac varsa sadece agacin yanindan gecip gidiyor'):
//   14 m icindeki sert nesneler (agac / kaya / duvar, yukseklik >= 0.7 m): dusmandan nesneye dogru yonde nesnenin 0.55 m ARKASI hesaplanir; dusmanin gozunden o noktaya (1.5 / 1.0 / 0.4 m) hat nesne
//   tarafindan kesiliyorsa aday (en yuksek korunan durus: UP > MIDDLE > DOWN); skor = mesafe + durus cezasi (0 / 2 / 5); dusmana 10 m'den fazla yaklasmaz.
// v8.521 GERI SINIRI (kullanici: 'bir one gidiyor sonra bir arkaya gidiyor'): siper dusmandan mevcut konumdan en fazla 3 m daha UZAK olabilir (ciddi baski >= 0.5 iken 10 m); eskiden sinirsiz geri (RPT 14:26: bina 16-22 m, hep geride) -> git-gel
// v8.606 AGAC GOVDE YARICAPI (kullanici: 'bu haritada neden agaclarin uzagina siper aliyorlar'; RPT 762aabfd pmc_ukraine_donetsk: t_picea3f gövde FIRE LOD 0.70 m ama bounding-box 11.0 m -> eski _r = bbox / 2 (en cok 2.5 m) + 0.55 = askerin
//   agac govdesinin ~3 m ARKASINDA durmasi): agac modelleri icin govde yaricapi FIRE LOD yanal taramayla (1.1 m yukseklik, +-3 m, 0.1 m adim, agac merkezinin 1.5 m'sindeki isabetler) modelde bir kez olculur ve onbelleklenir
//   (lambs_danger_govdeRH); FIRE LOD yoksa 0.5 m. Agac disi nesneler (kaya / duvar / konteyner) eski bbox yaricapini kullanir.
private _govdeR = {
    params ["_o", "_bbR"];
    private _m = toLower ((getModelInfo _o) select 0);
    if !(((_m find "t_") isEqualTo 0) || {(_m find "tree") >= 0} || {(_m find "picea") >= 0} || {(_m find "pinus") >= 0} || {(_m find "populus") >= 0}) exitWith { _bbR };
    // v8.643: govde yaricapi MODEL PROFILINDEN (FIRE / GEOM / VIEW olcumu, onbellekli; fnc_agacProfil)
    (([_o] call FUNC(agacProfil)) select 0)
};
private _geriMax = [3, 10] select ((getSuppression _u) >= 0.5);
// v8.664 MESAFEYE OLCEKLI BAND (RPT 5b2735f6 lythium: dusman 316-354 m, agac 22-29 m ileride / 23-28 m geride, 'mesafe bandinda 0' -> aday_yok 14; sabit band [ed - 10, ed + 3] 330 m'de 25 m'lik agaci eliyordu): dusman > 150 m ise ileri sinir ed x 0.12 (10-40 m), geri sinir +ed x 0.03 (<= 12 m)
private _ileriM = if (_ed > 150) then { ((_ed * 0.12) max 10) min 40 } else {10};
private _geriG = _geriMax + (if (_ed > 150) then { (_ed * 0.03) min 12 } else {0});
private _obj = [];
private _objS = 1e9;
private _objDurus = "";
private _objAd = "";
{
    private _o = _x;
    private _op = getPosATL _o;
    private _bb = boundingBoxReal _o;
    private _yk = ((_bb select 1) select 2) - ((_bb select 0) select 2);
    // v8.375 SAHTE SIPER ELEME (RPT 04:04: 'Land_PowerLine_01_wire_50m_F 24 m', 'Land_PowerPoleWooden_L 1 m' -> asker tel / direge kosup acikta kaldi): elektrik teli / direk / lamba / kablo / anten nesneleri siper degildir (duvar / ev etkilenmez)
    private _ad0 = toLower ([typeOf _o, (getModelInfo _o) select 0] select ((typeOf _o) isEqualTo ""));
    private _sahte = (["wire", "powerline", "powerpole", "pole", "cable", "lamp", "antenna", "pylon", "weaponholder"] findIf {(_ad0 find _x) >= 0}) >= 0;
    // v8.615 SAHTE SIPER (RPT b24f0608: 'NESNE ARKASI WeaponHolderSimulated' 5 kez = yere dusen silah / esya; 'b_pistacial1s_ep1 / b_pinusm1s_ep1' = CALI sert siper sayiliyor, UP duruslu): dusen silah / esya (weaponholder) ve cali modelleri (b_ ile baslayan model adi) SERT siper degildir;
    //   cali yalniz asagidaki BITKI / CALI ORTUSU blogunda (gizlenme, +6 ceza, comelme / yatma) degerlendirilir
    if (!_sahte && {((toLower ((getModelInfo _o) select 0)) select [0, 2]) isEqualTo "b_"}) then { _sahte = true; };
    if (!_sahte && {_yk >= 0.7} && {(_u distance2D _op) <= _yar}) then {
        private _r = [_o, (((((_bb select 1) select 0) - ((_bb select 0) select 0)) max (((_bb select 1) select 1) - ((_bb select 0) select 1))) / 2) min 2.5] call _govdeR;
        private _pos = _op getPos [_r + 0.05, _en getDir _o];   // v8.639: 0.15 -> 0.05 (3.3 kat yakin; v8.637 0.45 -> 0.15; kullanici: 'agac iyice dibine girsinler', '3.30 kat artsin')
        if (!surfaceIsWater _pos && {(_pos distance2D _en) >= (_ed - _ileriM)} && {(_pos distance2D _en) <= (_ed + _geriG)} && {!([_pos, _aralik] call _doluMu)}) then {
            private _gASL = ATLToASL [_pos select 0, _pos select 1, 0];
            private _bl = [1.5, 1.0, 0.4] apply { (lineIntersectsSurfaces [_eASL, _gASL vectorAdd [0, 0, _x], _en, _u, true, 1, (missionNamespace getVariable ["lambs_danger_siperLod", "FIRE"]), "NONE"]) isNotEqualTo [] };
            // en yuksek durus: ortadaki isin kapali VE govde genisligi (+-0.25 m) kapali (ince direk / tel siper sayilmaz)
            private _ds = ["", 99];
            {
                _x params ["_dn", "_dh", "_dc"];
                if ((_bl select _forEachIndex) && {[_eASL, _gASL, _dh, _en, _u] call _govdeKapali}) exitWith { _ds = [_dn, _dc]; };
            } forEach [["UP", 1.5, 0], ["MIDDLE", 1.0, 2], ["DOWN", 0.4, 5]];
            if ((_ds select 0) isNotEqualTo "") then {
                private _sk = (_u distance2D _pos) + (_ds select 1);
                _sk = _sk - (0.6 * ([side group _u, _pos, getPosATL _en] call _mevziFn));   // v8.529 mevzi hafizasi (puan yuksek = iyi -> maliyet duser)
                _sk = _sk + ([_pos] call _coklu);   // v8.657: diger bilinen dusmanlara acik nokta +5 / dusman
                _sk = _sk + ([_pos] call _ongoruCeza);   // v8.724: tahmini (ileri / kanat) senaryolara acik nokta + agirlik
                // v8.735 2) ROTA RISKI (bireysel): oraya KOSARKEN (hat 3 ornek) dusmanin gozunden / olasi siper noktalarindan acikta kalir miyim? risk x rotaRiskAgirlik (m)
                if (_yolOn) then { _sk = _sk + (([getPosATL _u, _pos, _yolEyes, _u] call FUNC(rotaRiski)) * _yolAg); };
                private _yumusakB = false;
                private _gorunurB = false;
                // v8.666 PENETRASYON FARKINDALIGI (siper secimi): dusmanin SU ANKI mermisi bu siperi (malzeme x kalinlik) AŞIYORSA yumusak siper: +6 m ceza (CBA siperPenetrasyon)
                if (missionNamespace getVariable ["lambs_danger_siperPenetrasyon", true]) then {
                    private _gP = [_en] call FUNC(munisyonGucu);
                    private _pP = (AGLToASL [_pos select 0, _pos select 1, 0]) vectorAdd [0, 0, 1.0];
                    private _pr = [eyePos _en, _pP, _en, _u, _gP] call FUNC(penetreGuc);
                    if ((_pr select 0) && {(_pr select 1) > 0}) then {
                        _sk = _sk + (missionNamespace getVariable ["lambs_danger_siperMermiOncelik", 8]);   // v8.667: CBA siperMermiOncelik (mermi geciren siper cezasi, m)
                        _yumusakB = true;
                        _sayAS set ["siper_yumusak", (_sayAS getOrDefault ["siper_yumusak", 0]) + 1];
                    };
                };
                // v8.657 KALINLIK (egitimli asker kalin siper secer): agac modeli govdesi (model profili FIRE / GEOM genisligi) < 0.5 m ise +4, >= 0.7 m ise -1
                if ((missionNamespace getVariable ["lambs_danger_agacProfil", true]) && {(toLower ((getModelInfo _o) select 0)) find "t_" isEqualTo 0}) then {
                    private _kp = [_o] call FUNC(agacProfil);
                    private _kw = (_kp select 1) max (_kp select 2);
                    _sk = _sk + (if (_kw < 0.5) then {4} else { if (_kw >= 0.7) then {-1} else {0} });
                };
                // v8.667 GIZLENME GEREKSINIMI (kullanici: 'cover seciminde mermi gecirmeyene oncelik versinler ama gizlenme gereksinimini de unutma'): sert siper mermiyi durdursa bile dusman gozunden (VIEW LOD) GORUNUYORSA (CUP / A2 modellerinde VIEW LOD yok / dar: t_picea2s VIEW 0.0) +siperGorunurCeza (CBA, 8 m)
                private _hh = [1.5, 1.0, 0.4] select (["UP", "MIDDLE", "DOWN"] find (_ds select 0));
                if ((lineIntersectsSurfaces [_eASL, _gASL vectorAdd [0, 0, _hh max 0.4], _en, _u, true, 1, "VIEW", "NONE"]) isEqualTo [] && {!(terrainIntersectASL [_eASL, _gASL vectorAdd [0, 0, _hh max 0.4]])}) then {
                    _sk = _sk + (missionNamespace getVariable ["lambs_danger_siperGorunurCeza", 8]);
                    _sayAS set ["siper_gorunur", (_sayAS getOrDefault ["siper_gorunur", 0]) + 1];
                    _gorunurB = true;
                };
                // v8.737 GERCEK SIPER KURALI (kullanici: 'gercekten ya goremeyelim ya da islemesin' + 'sus niyetine gizlenmesin'): mermi geciren (yumusak) VE gorunur (VIEW acik) aday = ne gizli ne korumali = SAHTE siper: siperGercekCezaM (60 m) -> pratikte elenir
                if (_yumusakB && {_gorunurB} && {missionNamespace getVariable ["lambs_danger_siperGercekCover", true]}) then {
                    _sk = _sk + (_gercekCezaM * ([1, 0.2] select _zor));
                    _sayAS set ["sahte_siper_elendi", (_sayAS getOrDefault ["sahte_siper_elendi", 0]) + 1];
                };
                // v8.737 KARSILIK VEREBILEN SIPER (kullanici: 'hem karsilik versin hem vurulmasin'): korunan durusun BIR UST kademesinde (DOWN -> 1.0 m, MIDDLE -> 1.5 m) ya da 0.9 m yanda dusmana FIRE LOD hatti ACIK ise (kalk-ates-alcal / yan adim) -3 bonus;
                //   hicbir kademede acik degilse (saf saklanma: ates edemez) +6 ceza (baski >= 0.5 haric)
                if (!_zor && {missionNamespace getVariable ["lambs_danger_siperKarsilik", true]}) then {
                    private _hNx = if (_hh < 0.5) then {1.0} else { if (_hh < 1.2) then {1.5} else {-1} };
                    private _acUst = (_hNx > 0) && {(lineIntersectsSurfaces [_eASL, _gASL vectorAdd [0, 0, _hNx], _en, _u, true, 1, "FIRE", "NONE"]) isEqualTo []} && {!(terrainIntersectASL [_eASL, _gASL vectorAdd [0, 0, _hNx]])};
                    private _prC = (vectorNormalized (_gASL vectorDiff _eASL)) vectorCrossProduct [0, 0, 1];
                    private _acYan = ([0.9, -0.9] findIf { (lineIntersectsSurfaces [_eASL, (_gASL vectorAdd [0, 0, _hh max 0.8]) vectorAdd (_prC vectorMultiply _x), _en, _u, true, 1, "FIRE", "NONE"]) isEqualTo [] }) >= 0;
                    if (_acUst || {_acYan}) then {
                        _sk = _sk - 3;
                        _sayAS set ["siper_karsilik", (_sayAS getOrDefault ["siper_karsilik", 0]) + 1];
                    } else {
                        if ((getSuppression _u) < 0.5) then { _sk = _sk + 6; _sayAS set ["siper_saf_saklanma", (_sayAS getOrDefault ["siper_saf_saklanma", 0]) + 1]; };
                    };
                };
                // v8.737 COK YONLU KAPALILIK (kullanici: 'bir yerden yemesin'): adaydan dusmana bakan eksene +-45 / +-90 derece 4 yonden (40 m, goz 1.6 m) FIRE LOD hatti ACIK mi; her acik yon x siperYanAgirlik (2 m; son 20 sn'de vurulduysa x3)
                if (missionNamespace getVariable ["lambs_danger_siperCokYonlu", true]) then {
                    private _dTE = _pos getDir _en;
                    private _tG = _gASL vectorAdd [0, 0, 1.0];
                    private _acYn = ({
                        private _fp = _pos getPos [40, _dTE + _x];
                        private _fa = AGLToASL [_fp select 0, _fp select 1, 1.6];
                        ((lineIntersectsSurfaces [_fa, _tG, objNull, _u, true, 1, "FIRE", "NONE"]) isEqualTo []) && {!(terrainIntersectASL [_fa, _tG])}
                    } count [45, -45, 90, -90]);
                    _sk = _sk + (_acYn * _yanAg * ([1, 3] select ((time - (_u getVariable [QGVAR(vurulduT), -99])) < 20)) * ([1, 0.5] select _zor));
                };
                // v8.517: haritada agaclar mermi durdurmuyorsa (kalibrasyon LOD = VIEW) agac yalniz GIZLER -> kaya / duvar / konteyner gibi gercek siperler +10 puanla (m) one gecer
                private _mdl = toLower ((getModelInfo _o) select 0);
                if ((missionNamespace getVariable ["lambs_danger_siperLod", "FIRE"]) isEqualTo "VIEW" && {((_mdl find "t_") isEqualTo 0) || {(_mdl find "tree") >= 0} || {(_mdl find "picea") >= 0}}) then { _sk = _sk + 10; };
                if (_sk < _objS) then { _objS = _sk; _obj = _pos; _objDurus = _ds select 0; _objAd = typeOf _o; if (_objAd isEqualTo "") then { _objAd = (getModelInfo _o) select 0; }; };
            };
        };
    };
} forEach ((nearestTerrainObjects [_p, ["TREE", "SMALL TREE", "ROCK", "ROCKS", "WALL", "HIDE"], _yar, false, true])
    // v8.524 SERT SIPER MENZILI x1.5 (RPT 14:10 / 14:26 [ACIKTA-SINIF-OZET]: acikta kalanlarin %71-100'unun 8-19 m'de (ort 13-17 m) kaya / duvar siperi vardi ama arama yaricapi 16 m'ydi): kaya / duvar / HIDE _yar x 1.5 (24 m)
    + ((nearestTerrainObjects [_p, ["ROCK", "ROCKS", "WALL", "HIDE"], _yar * 1.5, false, true]) select {(_x distance2D _p) > _yar})
    // v8.402 TUR-BAGIMSIZ YEDEK (kullanici: 'pmc terrain kendi objelerini kullandim, simple object falan olabilir'): arazi nesnesi turu ('TREE' / 'WALL' ...) tanimsiz / simple object / harita'ya yerlestirilmis nesneler nearestTerrainObjects'te gorunmez ->
    //   nesne turune BAKMADAN (nearestObjects, insan / arac / ev / iz haric) ayni geometri testi (yukseklik >= 0.7, FIRE LOD isin testi) uygulanir. Kapatma: lambs_danger_siperYedekOff = true.
    + (if (missionNamespace getVariable ["lambs_danger_siperYedekOff", false]) then {[]} else { ((nearestObjects [_p, [], _yar]) select {
    !(_x isKindOf "Man") && {!(_x isKindOf "AllVehicles")} && {!(_x isKindOf "House")} && {!(_x isKindOf "Logic")} && {!isObjectHidden _x}
    && {((typeOf _x) select [0, 1]) isNotEqualTo "#"} && {((getModelInfo _x) select 0) isNotEqualTo ""}
}) }));

// v8.509 BITKI / CALI ORTUSU (kullanici: 'siperden uzak kalmasinlar, agaclara en ufak bitkiyi degerlendirsinler, acikta durmasinlar'): sert siper (agac govdesi / kaya / duvar) bulunamazsa GIZLENME:
//   cali / fidan / kucuk agac (yukseklik >= 0.3 m) arkasi; mermiyi durdurmaz ama gorusu keser (VIEW LOD: dusmanin gozunden o noktaya hattin ILK carpani bitkinin kendisi olmali), comelerek / yatarak gizlenir.
//   Sert siper her zaman once; yalniz hic sert siper yoksa (+6 gizlenme cezasi: sert siper 6 m daha uzak olsa bile tercih edilir). Kapatma: lambs_danger_siperBitki = false.
private _esitG = missionNamespace getVariable ["lambs_danger_siperGizlenmeEsit", true];   // v8.622: gizlenme sert siperle ESIT oncelikli (ceza +6 -> +2)
if ((_obj isEqualTo [] || {_esitG}) && {missionNamespace getVariable ["lambs_danger_siperBitki", true]}) then {
    {
        private _o = _x;
        private _op = getPosATL _o;
        private _bb = boundingBoxReal _o;
        private _yk = ((_bb select 1) select 2) - ((_bb select 0) select 2);
        if (_yk >= 0.3 && {(_u distance2D _op) <= _yar}) then {
            private _r = (((((_bb select 1) select 0) - ((_bb select 0) select 0)) max (((_bb select 1) select 1) - ((_bb select 0) select 1))) / 2) min 2;
            // v8.621 AGAC GIZLENMESI (kullanici: 'ince agaclarda da kendilerini gizlesinler, yalniz siper icin degil gizlenmek icin'): normal AGAC (TREE sinifi, yukseklik > 4 m) da gizlenme adayi; govdeye YAKIN (yaricap <= 0.6 m, govdenin ~1.1 m arkasi)
            //   ve govde ince oldugu icin gorus hatti yalniz ortada degil +-0.2 m yanlarda da agaca carpmali (yarim acik durmasin)
            private _uzun = _yk > 4;
            if (_uzun) then { _r = _r min 0.6; };
            if (!_uzun) then { _r = _r * 0.6; };   // v8.639: cali / fidan: govdeye / yaprak ortusunun ICINE (iyice dibine) gir; gorunmezlik asagidaki VIEW LOD ile dogrulanir
            private _pos = _op getPos [_r + ([0.15, 0.05] select _uzun), _en getDir _o];   // v8.639: cali 0.5 -> 0.15 (+ yaricap x 0.6), agac 0.2 -> 0.05 (3.3 kat yakin)   // v8.637: agac gizlenmesi govdeye 0.2 m (cali 0.5 ayni)
            if (!surfaceIsWater _pos && {(_pos distance2D _en) >= (_ed - _ileriM)} && {(_pos distance2D _en) <= (_ed + _geriG)} && {!([_pos, _aralik] call _doluMu)}) then {
                private _gASL = ATLToASL [_pos select 0, _pos select 1, 0];
                private _gizli = {
                    params ["_h"];
                    private _vh = lineIntersectsSurfaces [_eASL, _gASL vectorAdd [0, 0, _h], _en, _u, true, 1, "VIEW", "NONE"];
                    private _tamam = (_vh isNotEqualTo []) && {((_vh select 0) select 2) isEqualTo _o};
                    if (_tamam && {_uzun}) then {
                        if (missionNamespace getVariable ["lambs_danger_agacProfil", true]) then {
                            // v8.643: yan isin testi (+-0.2 m) CUP / A2 agaclarinda govde / yaprak seyrek oldugu icin elenirdi; MODEL PROFILI: bu yukseklikte VIEW genisligi >= 0.3 m ise govde / ortu gercekten gizler
                            private _pr = [_o] call FUNC(agacProfil);
                            _tamam = (_pr select ([3, 4] select (_h >= 0.9))) >= 0.3;
                        } else {
                            // eski (v8.621): govde ince oldugu icin gorus hatti ortada + +-0.2 m yanlarda da agaca carpmali
                            private _pd = (_en getDir _o) + 90;
                            {
                                private _yh = lineIntersectsSurfaces [_eASL, _gASL vectorAdd [(sin _pd) * _x, (cos _pd) * _x, _h], _en, _u, true, 1, "VIEW", "NONE"];
                                if (_yh isEqualTo [] || {((_yh select 0) select 2) isNotEqualTo _o}) exitWith { _tamam = false; };
                            } forEach [-0.2, 0.2];
                        };
                    };
                    _tamam
                };
                private _ds = "";
                private _dc = 0;
                if ([1.0] call _gizli) then { _ds = "MIDDLE"; _dc = 2; } else { if ([0.4] call _gizli) then { _ds = "DOWN"; _dc = 5; }; };
                if (_ds isNotEqualTo "") then {
                    private _sk = (_u distance2D _pos) + _dc + ([6, missionNamespace getVariable ["lambs_danger_siperMermiOncelik", 8]] select _esitG);   // v8.667: gizlenme-only (mermi durdurmaz) adayi: mermi oncelikli ceza (varsayilan 8; eski 2)
                    _sk = _sk - (0.6 * ([side group _u, _pos, getPosATL _en] call _mevziFn));
                    if (_sk < _objS) then { _objS = _sk; _obj = _pos; _objDurus = _ds; _objAd = typeOf _o; if (_objAd isEqualTo "") then { _objAd = (getModelInfo _o) select 0; }; };
                };
            };
        };
    } forEach (nearestTerrainObjects [_p, ["BUSH", "SMALL TREE", "TREE"], _yar, false, true]);
};

// v8.642 AGAC GEVSEK KULLANIM (kullanici: 'agaclar var zaten agaclari kullanmiyorlar', 'cup agaclari pmc tactical ukraine'; RPT 47dde7ed: aday_yok 14-17 / dk, [AGAC-GIZLEN] 35 m'de 12 agaclik var):
//   nedenler: (1) CUP / A2 agaclarinin (t_picea / t_pinus / t_populus) cogunda FIRE LOD yok / dar -> sert siper testi ve +-0.2 m yan isin gizlenme testi gecmiyor; (2) aday nokta dusmana mesafe bandi [ed - 10, ed + 3] (geri cekilme siniri 3 m): 100 m'deki dusmana 25 m'den yanal agac bandin disinda kaliyordu.
//   Son care (hicbir nesne / bitki bulunamadiysa; CBA siperAgacGevsek): yaricap x 1.5 (30-45 m), band [ed - 15, ed + 16]; nokta govdenin dusmana GORE ARKASI (dusman -> govde dogrultusunda, govde + 0.1 m), raycast YOK (geometri: govde dusman ile asker arasinda), durus MIDDLE; en yakin agac (mevzi hafizasi / dolu nokta elenir).
private _gvS = [0, 0, 0, 0, 1e9, -999];   // v8.645 TANI: [taranan agac, uzun (> 4 m), mesafe bandinda, dolu degil, en yakin agac m, en yakin agacin bant sapmasi m]
if (_obj isEqualTo [] && {missionNamespace getVariable ["lambs_danger_siperAgacGevsek", true]}) then {
    {
        private _o = _x;
        _gvS set [0, (_gvS select 0) + 1];
        if ((_u distance2D _o) < (_gvS select 4)) then { _gvS set [4, _u distance2D _o]; _gvS set [5, ((getPosATL _o) distance2D _en) - _ed]; };
        private _op = getPosATL _o;
        private _bb = boundingBoxReal _o;
        private _yk = ((_bb select 1) select 2) - ((_bb select 0) select 2);
        if (_yk > 4) then {
            _gvS set [1, (_gvS select 1) + 1];
            private _pr = [_o] call FUNC(agacProfil);   // v8.643: model profili (CUP / A2 agac olcumu)
            // v8.654: gizleme genisligi hicbir LOD'da olculemeyen agac (kavak t_populusf2s_ep1: FIRE / GEOM / VIEW hep 0.0) gizlemez -> aday degil (CBA agacProfil acikken)
            private _gizler = !(missionNamespace getVariable ["lambs_danger_agacProfil", true]) || {(_pr select 1) >= 0.3} || {(_pr select 3) >= 0.3} || {(_pr select 4) >= 0.3} || {(_pr select 5) >= 0.3};
            if (!_gizler) then { continue };
            private _r = (_pr select 0) min 2.5;   // v8.655: genis geometrili ladin (GEOM kenari) icin 1.5 -> 2.5
            private _pos = _op getPos [_r + 0.1, _en getDir _o];
            if (!surfaceIsWater _pos && {(_pos distance2D _en) >= (_ed - (_ileriM max 15))} && {(_pos distance2D _en) <= (_ed + (_geriG max 16))}) then { _gvS set [2, (_gvS select 2) + 1]; if !([_pos, _aralik] call _doluMu) then { _gvS set [3, (_gvS select 3) + 1]; }; };
            if (!surfaceIsWater _pos && {(_pos distance2D _en) >= (_ed - (_ileriM max 15))} && {(_pos distance2D _en) <= (_ed + (_geriG max 16))} && {!([_pos, _aralik] call _doluMu)}) then {
                private _sk = (_u distance2D _pos) + 8;
                _sk = _sk - (0.6 * ([side group _u, _pos, getPosATL _en] call _mevziFn));
                if (_sk < _objS) then { _objS = _sk; _obj = _pos; _objDurus = (if (!(missionNamespace getVariable ["lambs_danger_agacProfil", true])) then {"MIDDLE"} else { if ((_pr select 5) >= 0.3) then {"UP"} else { if ((_pr select 4) >= 0.3) then {"MIDDLE"} else { if ((_pr select 3) >= 0.3) then {"DOWN"} else {"MIDDLE"} } } }); _objAd = typeOf _o; if (_objAd isEqualTo "") then { _objAd = (getModelInfo _o) select 0; }; };
            };
        };
    } forEach (nearestTerrainObjects [_p, ["TREE", "SMALL TREE"], ((_yar * 1.5) max 30) min 45, false, true]);
    if (_obj isNotEqualTo []) then { _sayAS set ["agac_gevsek", (_sayAS getOrDefault ["agac_gevsek", 0]) + 1]; };
};

// v8.516 ARAZI KIVRIMI ARKASI (RPT 13:27 chernarus_summer: agaclarin %75'inde FIRE LOD yok, gövde genisligi medyan 0.00 m; nesne siperi gorus keser ama mermi durdurmaz): nesne siperi de bulunamazsa
//   cevrede (4 / 8 / 12 m halkalarda 8 yon) dusman gozunden arazi kivrimiyle (terrainIntersectASL) gizlenen en yakin nokta: 0.4 m kapali = yat, 1.0 m kapali = comel. Kapatma: lambs_danger_siperArazi = false.
// v8.672: artik nesne bulunsa da ARAZI adaylari nesneyle YARISIR (kullanici: 'mermi engellemiyor'; Lythium'da tek nesne siper ince agac = yalniz gizlenme, mermi gecer): arazi kivrimi hem gizler hem mermiyi durdurur; sabit 8 -> 6.
if (missionNamespace getVariable ["lambs_danger_siperArazi", true]) then {
    {
        private _r = _x;
        for "_ai" from 0 to 11 do {   // v8.673: 8 -> 12 yon (cukur / yamac aramasi daha sik)
            private _pt = _p getPos [_r, (_ai * 30) + (_u getDir _en)];
            if (!surfaceIsWater _pt && {(_pt distance2D _en) >= (_ed - 10)} && {(_pt distance2D _en) <= (_ed + _geriMax)} && {!([_pt, _aralik] call _doluMu)}) then {
                private _ptASL = AGLToASL [_pt select 0, _pt select 1, 0];
                private _dn = "";
                private _dc = 0;
                if (terrainIntersectASL [_eASL, _ptASL vectorAdd [0, 0, 1.0]]) then { _dn = "MIDDLE"; _dc = 2; } else { if (terrainIntersectASL [_eASL, _ptASL vectorAdd [0, 0, 0.4]]) then { _dn = "DOWN"; _dc = 5; }; };
                if (_dn isNotEqualTo "") then {
                    private _sk = _r + _dc + 6 - ((missionNamespace getVariable ["lambs_danger_siperArazOncelik", 4]) max 0 min 12);   // v8.673: CBA siperArazOncelik (kullanici: 'cukurlara yamaclara siper alsinlar')
                    _sk = _sk - (0.6 * ([side group _u, _pt, getPosATL _en] call _mevziFn));
                    if (_sk < _objS) then { _objS = _sk; _obj = _pt; _objDurus = _dn; _objAd = "ARAZI KIVRIMI"; };
                };
            };
        };
    } forEach [4, 8, 12, 18, 25];   // v8.673: 18 / 25 m halkalari (yamac / cukur 25 m'ye kadar)
};

// v8.520 KENTSEL ONCELIK (kullanici: 'ev ici ve meskun mahalde oncelik'; RPT 14:10 Altis 'cover': 55 kurtarmanin 0'i bina, 34'u cam agaci - cevrede dukkan / ev varken): girilebilir >= 2 bina varsa (_yar + 10 m)
//   NESNE (agac / kaya / duvar) sonucu ERTELENIR, once BINA (atis pozisyonu / gizli nokta) aranir; bina bulunamazsa ertelenen nesne uygulanir. CBA lambs_danger_kentselOncelik (varsayilan acik).
private _nesneGit = {
    if (_senE isNotEqualTo [] && {missionNamespace getVariable ["lambs_danger_ongoruOlcum", true]}) then { [_u, _en, _obj, _senE, _ogKontrol, _ogSureG] call FUNC(ongoruKayit); };
    _sayAS set ["nesne", (_sayAS getOrDefault ["nesne", 0]) + 1];
    if (_objAd isEqualTo "ARAZI KIVRIMI") then { _sayAS set ["arazi_kivrimi", (_sayAS getOrDefault ["arazi_kivrimi", 0]) + 1]; };   // v8.673: arazi (cukur / yamac) secimi sayaci
    _dolu pushBack [_obj, time];
    missionNamespace setVariable ["lambs_danger_acikSiperDolu", _dolu];
    [_obj, _objAd] call _talepYaz;
    if (missionNamespace getVariable ["lambs_danger_yedekSiper", true]) then {
        private _yb = [_u, _en, _obj] call FUNC(yedekSiper);
        if (_yb isNotEqualTo []) then { _u setVariable [QGVAR(acikSiperYedek), [_yb, time]]; _sayAS set ["yedek_kuruldu", (_sayAS getOrDefault ["yedek_kuruldu", 0]) + 1]; };
    };
    _u setVariable [QGVAR(taktikKilit), time + 15];
    _u forceSpeed -1;
    _u setSpeedMode "FULL";
    _u setVariable [QGVAR(siperDoMoveT), time];   // v8.707: ters donus kaynak atfi (durumLog)
    _u doMove _obj;
    if ((_u distance2D _obj) <= 8 || {_yakinDovus}) then { _u doWatch _en; };   // v8.732: kisa siper atilisinda arkani donme (bakis dusmanda: yan / geri adim animasyonu)
    [_u, _en] call FUNC(mgDestek);   // v8.732: acikta kalanin siper atilisina MG bastirma destegi
    // v8.641 SIPER NOKTASINA OTUR (kullanici: 'arada 2 metre var', RPT 47dde7ed: [SIPER-YAPIS] YAPISTI satiri HIC yok -> coverHug kayma kolu bu askerlerde calismiyor; asker doMove toleransinda (~1-2 m) duruyor):
    //   bu dalin KENDI tamamlayicisi: hareket 1.2 sn sonra baslar, asker durdugunda (< 0.8 m/sn, 8 m icinde) ya da 12 sn sonra, hedef hala ayni siper noktasiysa 0.15-6 m kalan mesafe yumusak kayarak (ayak hatti GEOM acik) kapatilir; hat kapaliysa (govde araya girer) doMove tekrar
    [_u, _obj] spawn {
        params ["_a", "_pt0"];
        sleep 2;
        private _bit = time + 12;
        // v8.644: varis = SON siper hedefine 4 m icinde + durmus (eski: ilk hedef degisirse tamamen vazgeciyor + 8 m / 1.2 sn erken tetik: RPT 18ce6e97 4 secimden 1 [SIPER-OTUR]; acikSiper 10 sn'de bir yeniden degerlendirip hedefi degistiriyor)
        waitUntil {
            sleep 0.4;
            private _h = (_a getVariable [QGVAR(acikSiperHedef), [[], 0]]) select 0;
            !alive _a || {!((lifeState _a) in ["HEALTHY", "INJURED"])} || {time > _bit} || {_h isNotEqualTo [] && {(((getPosATL _a) distance2D _h) < 4) && {(speed _a) < 0.8}}}
        };
        if (!alive _a || {!((lifeState _a) in ["HEALTHY", "INJURED"])} || {_a getVariable ["ACE_isUnconscious", false]}) exitWith {};   // v8.653: baygin asker oturtulmaz
        if ((_a getVariable [QGVAR(forceMove), false]) || {(group _a) getVariable [QGVAR(isRetreating), false]} || {(group _a) getVariable [QGVAR(isEvading), false]} || {(group _a) getVariable [QGVAR(isBreakingContact), false]}) exitWith {};   // v8.687: geri cekilen / kosucu askeri siper noktasina geri KAYDIRMA / doMove ile cekme (RPT 6a939f32)
        private _pt = (_a getVariable [QGVAR(acikSiperHedef), [[], 0]]) select 0;
        if (_pt isEqualTo []) exitWith {};
        private _p1 = +_pt;
        _p1 set [2, (getPosATL _a) select 2];
        private _p0 = getPosATL _a;
        private _d0 = _p0 distance2D _p1;
        if (_d0 >= 0.15 && {_d0 <= 25} && {(speed _a) < 1.5} && {!surfaceIsWater _p1}) then {   // v8.649: 6 -> 25 m (yumusakKay uzak kismi yuruyerek gider)
            if ((lineIntersectsSurfaces [(getPosASL _a) vectorAdd [0, 0, 0.6], (AGLToASL _p1) vectorAdd [0, 0, 0.6], _a, objNull, true, 1, "GEOM", "NONE"]) isEqualTo []) then {
                [_a, _p1] spawn FUNC(yumusakKay);   // v8.647: yumusak (yuruyus + smoothstep), eski sabit adimli setPosATL kaldirildi
                if ((missionNamespace getVariable ["lambs_danger_siperOturLogN", 0]) < 25) then {
                    missionNamespace setVariable ["lambs_danger_siperOturLogN", (missionNamespace getVariable ["lambs_danger_siperOturLogN", 0]) + 1];
                    diag_log format ["[SIPER-OTUR] %1 | %2 | siper noktasina %3 m kaldi -> oturtuldu", groupId (group _a), name _a, _d0 toFixed 2];
                };
            } else {
                _a setVariable [QGVAR(oturDoMoveT), time];   // v8.707: siper noktasina OTUR adiminin kendi doMove'u (hat kapali: govde araya girer); ters donus kaynak atfi (durumLog)
                _a doMove _pt;
            };
        } else {
            if ((missionNamespace getVariable ["lambs_danger_siperOturLogN2", 0]) < 15) then {
                missionNamespace setVariable ["lambs_danger_siperOturLogN2", (missionNamespace getVariable ["lambs_danger_siperOturLogN2", 0]) + 1];
                diag_log format ["[SIPER-OTUR] %1 | %2 | oturtulamadi: kalan %3 m, hiz %4 km/sa", groupId (group _a), name _a, _d0 toFixed 1, round (speed _a)];
            };
        };
    };
    // v8.648 SIPERDE ALCAK DURUS (kullanici: 'asil ona bak'; RPT 949d7eff: dusman 106-190 m, secilen agac / nesne arkasi [ACIK-SIPER] 'durus UP' hep ayakta; CBA siperDusuk (kullanici 2) YALNIZ coverHug'da uygulaniyordu, acikSiper'in nesne dalinda yoktu):
    //   gizli en yuksek durus (_objDurus) CBA siperDusuk kademe (0-2) alcaltilir (UP -> MIDDLE -> DOWN), baski > 0.35 ise bir kademe daha; son durus setUnitPosWeak (ates gerekirse motor kalkar)
    private _dusukK = (round ([_u, "siperDusuk", 1] call FUNC(profilDeger)) max 0) min 2;   // v8.738: ORMAN / KENTSEL'de -1
    // v8.656 DURUS CESITLILIGI (kullanici: 'dediklerini yap'; Altis goruntuleri: HEPSI yatik; egitimli tim karisik durur): baski yoksa (<= 0.35) ve MG degilse askerlerin CBA siperDurusCesit orani (varsayilan %50) bir kademe YUKSEK (yatma -> comelme) durur; kisiye bagli sabit secim (birimId)
    private _cesit = (missionNamespace getVariable ["lambs_danger_siperDurusCesit", 0.5]) max 0 min 1;
    if ((getSuppression _u) <= 0.35 && {_dusukK > 0} && {([_u] call (missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}])) isNotEqualTo "MG"} && {(["siperDurusCesit", [_u] call FUNC(birimId)] call FUNC(rastgele)) < _cesit}) then { _dusukK = _dusukK - 1; };
    if ((getSuppression _u) > 0.35) then { _dusukK = (_dusukK + 1) min 2; };
    for "_dk" from 1 to _dusukK do { _objDurus = switch (_objDurus) do { case "UP": {"MIDDLE"}; default {"DOWN"} }; };
    if (_yakinDovus && {_objDurus isEqualTo "DOWN"}) then { _objDurus = "MIDDLE"; };   // v8.729: yakin dovusta yatma yok
    _u setUnitPos "UP";
    [_u, _obj, _en, _objDurus, true, true] call FUNC(siperZorla);   // v8.510; v8.649: riskAtla + uzakIzin (acikta kalan asker risk esigi aranmadan, 40 m'ye kadar atilisla): ates ederken doMove ertelenmesin (raycast dogrulamali atilis)
    [{ params ["_uu", "_hp"]; !alive _uu || {(_uu distance2D _hp) < 1.5} }, { params ["_uu", "_hp", "_ds"]; if (alive _uu && {!((_uu getVariable [QGVAR(forceMove), false]) || {(group _uu) getVariable [QGVAR(isRetreating), false]} || {(group _uu) getVariable [QGVAR(isEvading), false]} || {(group _uu) getVariable [QGVAR(isBreakingContact), false]})}) then { _uu setUnitPosWeak _ds; [_uu] call FUNC(siperTut); }; }, [_u, _obj, _objDurus], 12, { params ["_uu", "_hp", "_ds"]; if (alive _uu && {!((_uu getVariable [QGVAR(forceMove), false]) || {(group _uu) getVariable [QGVAR(isRetreating), false]} || {(group _uu) getVariable [QGVAR(isEvading), false]} || {(group _uu) getVariable [QGVAR(isBreakingContact), false]})}) then { _uu setUnitPos _ds; }; }] call CBA_fnc_waitUntilAndExecute;
    [{ params ["_uu"]; if (alive _uu && {!((_uu getVariable [QGVAR(forceMove), false]) || {(group _uu) getVariable [QGVAR(isRetreating), false]} || {(group _uu) getVariable [QGVAR(isEvading), false]} || {(group _uu) getVariable [QGVAR(isBreakingContact), false]})}) then { _uu setUnitPos "AUTO"; }; }, [_u], 25] call CBA_fnc_waitAndExecute;   // v8.687: gecikmeli geri cagrilar geri cekilme / temas kes / kacis / forceMove kosucusunun durusunu EZMEZ (RPT 6a939f32)
    if ((missionNamespace getVariable ["lambs_danger_acikSiperLogN", 0]) < 40) then {
        missionNamespace setVariable ["lambs_danger_acikSiperLogN", (missionNamespace getVariable ["lambs_danger_acikSiperLogN", 0]) + 1];
        diag_log format ["[ACIK-SIPER] %1 | %2 | dusman %3 m acikta -> NESNE ARKASI %4 (%5 m, durus %6, dusmandan gizli)", groupId _g, name _u, round _ed, _objAd, round (_u distance2D _obj), _objDurus];
    };
    true
};
// v8.735 3) YEDEK SIPER (iki sicramali bireysel on plan): daha once secilen yedek B (<= 60 sn) hala gizli / dolu degil / yakinsa ve secilen siperden en fazla 4 m uzaksa B'ye git (yeniden secim azalir)
if (missionNamespace getVariable ["lambs_danger_yedekSiper", true]) then {
    private _yd = _u getVariable [QGVAR(acikSiperYedek), []];
    if (_yd isNotEqualTo [] && {(time - (_yd select 1)) < 60}) then {
        private _bp = _yd select 0;
        if ((_u distance2D _bp) <= _yar && {!([_bp, _aralik] call _doluMu)} && {(_bp distance2D _en) >= (_ed - 8)} && {(!_limAcik) || {(_u distance2D _bp) <= _lim}}) then {
            private _bG = AGLToASL [_bp select 0, _bp select 1, 0];
            if (((lineIntersectsSurfaces [_eASL, _bG vectorAdd [0, 0, 1.0], _en, _u, true, 1, "FIRE", "NONE"]) isNotEqualTo []) && {_obj isEqualTo [] || {(_u distance2D _bp) <= ((_u distance2D _obj) + 4)}}) then {
                _obj = +_bp;
                _objAd = "YEDEK SIPER (on plan)";
                _objDurus = "MIDDLE";
                _sayAS set ["yedek_kullanildi", (_sayAS getOrDefault ["yedek_kullanildi", 0]) + 1];
            };
        };
        _u setVariable [QGVAR(acikSiperYedek), []];
    };
};
if (_limAcik && {_obj isNotEqualTo []} && {(_u distance2D _obj) > _lim}) then { _obj = []; _sayAS set ["yakin_dovus_uzak_red", (_sayAS getOrDefault ["yakin_dovus_uzak_red", 0]) + 1]; };
private _binalarK = (nearestObjects [_p, ["House"], _yar + 10]) select {(count (_x buildingPos -1)) >= 2};
private _kentsel = (missionNamespace getVariable ["lambs_danger_kentselOncelik", true]) && {(count _binalarK) >= 2};
if (_obj isNotEqualTo [] && {!_kentsel}) exitWith { call _nesneGit };

private _en_iyi = [];
private _enS = 1e9;
private _binaAd = "";
private _atisVar = false;
private _durusB = "AUTO";
// v8.354 BINAYI AKTIF KULLAN (kullanici: 'binalari aktif kullansinlar'; RPT 30-10: ACIK-SIPER bina kolu yalniz dusmandan GIZLI nokta seciyor -> asker binaya girip dusmani goremeyen, ates edemeyen 'pasif' noktada bekliyordu):
//   ATIS POZISYONU = dusman gozunden askerin ayakta (1.5 m) ya da comelmis (1.0 m) goz hizasina hat ACIK (pencere / kapi) ama ust ortulu (ic mekan); 5 yanal ornekten (+-0.8 m) hepsi aciksa (tamamen acik yapi) +8 ceza;
//   ust ortu yoksa +15; AT +12 (geri tepme: bina ici); keskin nisanci ust katta -6; kat farki x1.5; dusmani goremeyen gizli nokta yalniz SON CARE (+30). Kat sinirli: |dz| < 4 m (ulasilamaz ust kat yok).
//   Kapatma: lambs_danger_cqbV2 = false (eski: yalniz gizli nokta, en yakin).
private _cqbV2 = missionNamespace getVariable ["lambs_danger_cqbV2", true];
private _rolB = if (_cqbV2) then { [_u] call (missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}]) } else { "RIFLE" };
private _uZ = (getPosATL _u) select 2;
private _edir = _p getDir _en;
{
    private _b = _x;
    {
        private _bp = _x;
        private _d = _u distance2D _bp;
        if (_d <= (_yar + 10) && {!_limAcik || {_d <= _lim}} && {(_bp distance2D _en) >= (_ed - 8)} && {(_bp distance2D _en) <= (_ed + _geriMax)} && {!([_bp, (_aralik * 0.5) max 2] call _doluMu)}) then {
            private _bA = AGLToASL _bp;
            if (!_cqbV2) then {
                if (_d < _enS && {lineIntersects [_eASL, _bA vectorAdd [0, 0, 1.3], _en, _u]}) then { _enS = _d; _en_iyi = _bp; _binaAd = typeOf _b; _atisVar = false; };
            } else {
                if ((abs ((_bp select 2) - _uZ)) < 4) then {
                    private _gUp = (lineIntersects [_eASL, _bA vectorAdd [0, 0, 1.5], _en, _u]) || {terrainIntersectASL [_eASL, _bA vectorAdd [0, 0, 1.5]]};
                    private _gMid = (lineIntersects [_eASL, _bA vectorAdd [0, 0, 1.0], _en, _u]) || {terrainIntersectASL [_eASL, _bA vectorAdd [0, 0, 1.0]]};
                    private _atis = !_gUp || {!_gMid};
                    private _sk = _d;
                    _sk = _sk - (0.6 * ([side group _u, _bp, getPosATL _en] call _mevziFn));
                    private _durus = "AUTO";
                    if (_atis) then {
                        _durus = ["MIDDLE", "UP"] select (!_gUp);
                        private _perp = [cos _edir, -(sin _edir), 0];
                        private _acik = 0;
                        {
                            private _yp = (_bA vectorAdd [0, 0, 1.4]) vectorAdd (_perp vectorMultiply _x);
                            if (!((lineIntersects [_eASL, _yp, _en, _u]) || {terrainIntersectASL [_eASL, _yp]})) then { _acik = _acik + 1; };
                        } forEach [-0.8, -0.4, 0, 0.4, 0.8];
                        if (_acik >= 5) then { _sk = _sk + 8; };
                    } else {
                        _sk = _sk + 30;
                        if ((getSuppression _u) < 0.5) then { _sk = 1e9; };   // v8.521: atis pozisyonu yoksa (pasif gizlenme) yalniz ciddi baskida; aksi halde binanin icinde atissiz bekleme (git-gel / pasif) yok
                    };
                    if !(lineIntersects [_bA vectorAdd [0, 0, 1.6], _bA vectorAdd [0, 0, 25], _u]) then { _sk = _sk + 15; };
                    switch (_rolB) do {
                        case "AT": { _sk = _sk + 12; };
                        case "MARKSMAN": { if (((_bp select 2) - _uZ) > 2.2) then { _sk = _sk - 6; }; };
                        default {};
                    };
                    _sk = _sk + ((abs ((_bp select 2) - _uZ)) * 1.5);
                    if (_sk < _enS) then { _enS = _sk; _en_iyi = _bp; _binaAd = typeOf _b; _atisVar = _atis; _durusB = _durus; };
                };
            };
        };
    } forEach (_b buildingPos -1);
} forEach ((nearestObjects [_p, ["House"], _yar + 12]) select {(count (_x buildingPos -1)) > 0});

if (_en_iyi isEqualTo []) exitWith {
    if (_obj isNotEqualTo []) then { call _nesneGit } else {
        if (_ed >= 15) then { _sayAS set ["aday_yok", (_sayAS getOrDefault ["aday_yok", 0]) + 1]; } else { _sayAS set ["aday_yok_yakin", (_sayAS getOrDefault ["aday_yok_yakin", 0]) + 1]; };   // v8.651: dusman < 15 m (CQB / acikta duran test kuklasi) ayri sayilir
        // v8.645 TANI (kullanici: 'etraflarinda agac var'): aday yoksa 45 m'deki agaclar neden elendi?
        if (_ed >= 15 && {(missionNamespace getVariable ["lambs_danger_adayYokLogN", 0]) < 15}) then {
            missionNamespace setVariable ["lambs_danger_adayYokLogN", (missionNamespace getVariable ["lambs_danger_adayYokLogN", 0]) + 1];
            diag_log format ["[ACIK-SIPER-RED] %1 | %2 | dusman %3 m | 45 m'de agac %4 | uzun (> 4 m) %5 | mesafe bandinda (dusman %3 m: %6..%7) %8 | dolu degil %9 | en yakin agac %10 m (bant sapmasi %11 m) | gevsek %12 | yaricap %13 m | geriMax %14 m", groupId _g, name _u, round _ed, _gvS select 0, _gvS select 1, round (_ed - 15), round (_ed + 16), _gvS select 2, _gvS select 3, round (_gvS select 4), round (_gvS select 5), missionNamespace getVariable ["lambs_danger_siperAgacGevsek", true], _yar, _geriMax];
        };
        false
    }
};
if (_kentsel) then { _sayAS set ["kentsel_bina", (_sayAS getOrDefault ["kentsel_bina", 0]) + 1]; };

_sayAS set ["bina", (_sayAS getOrDefault ["bina", 0]) + 1];
_dolu pushBack [_en_iyi, time];
missionNamespace setVariable ["lambs_danger_acikSiperDolu", _dolu];
[_en_iyi, _binaAd] call _talepYaz;
_u setVariable [QGVAR(taktikKilit), time + 15];
_u forceSpeed -1;
_u setSpeedMode "FULL";
_u setUnitPos "AUTO";
_u setVariable [QGVAR(siperDoMoveT), time];   // v8.707: ters donus kaynak atfi (durumLog)
_u doMove _en_iyi;
if ((_u distance2D _en_iyi) <= 8 || {_yakinDovus}) then { _u doWatch _en; };   // v8.732
[_u, _en] call FUNC(mgDestek);   // v8.732
// v8.354: atis pozisyonuna varinca durus + dusmana bak (pasif beklemesin); 45 sn sonra serbest
if (_atisVar) then {
    [{ params ["_uu", "_hp"]; !alive _uu || {(_uu distance2D _hp) < 1.5} }, { params ["_uu", "_hp", "_ds", "_e"]; if (alive _uu && {!((_uu getVariable [QGVAR(forceMove), false]) || {(group _uu) getVariable [QGVAR(isRetreating), false]} || {(group _uu) getVariable [QGVAR(isEvading), false]} || {(group _uu) getVariable [QGVAR(isBreakingContact), false]})}) then { _uu setUnitPos _ds; if (!isNull _e && {alive _e}) then { _uu doWatch _e; }; [_uu] call FUNC(siperTut); }; }, [_u, _en_iyi, _durusB, _en], 14, {}] call CBA_fnc_waitUntilAndExecute;
    [{ params ["_uu"]; if (alive _uu && {!((_uu getVariable [QGVAR(forceMove), false]) || {(group _uu) getVariable [QGVAR(isRetreating), false]} || {(group _uu) getVariable [QGVAR(isEvading), false]} || {(group _uu) getVariable [QGVAR(isBreakingContact), false]})}) then { _uu setUnitPos "AUTO"; _uu doWatch objNull; }; }, [_u], 45] call CBA_fnc_waitAndExecute;
};
if ((missionNamespace getVariable ["lambs_danger_acikSiperLogN", 0]) < 40) then {
    missionNamespace setVariable ["lambs_danger_acikSiperLogN", (missionNamespace getVariable ["lambs_danger_acikSiperLogN", 0]) + 1];
    diag_log format ["[ACIK-SIPER] %1 | %2 | dusman %3 m acikta -> bina %4 (%5 m, %6, skor %7)", groupId _g, name _u, round _ed, _binaAd, round (_u distance2D _en_iyi), if (_atisVar) then {format ["ATIS POZISYONU: dusman gorunuyor, durus %1", _durusB]} else {"pasif gizlenme (atis pozisyonu yok)"}, round _enS];
};
true

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

params [["_u", objNull, [objNull]], ["_en", objNull, [objNull]]];
if (isNull _u || {isNull _en} || {missionNamespace getVariable ["lambs_danger_acikSiperOff", false]}) exitWith {false};
if (captive _u || {_u getVariable [QGVAR(teslim), false]}) exitWith {false};   // v8.352: teslim olan / esir asker nesne arkasina gonderilmez (STOP -> MOVE salinimi)
if (time < (_u getVariable [QGVAR(acikSiperT), 0])) exitWith {false};
// v8.312: tekrar 25 -> 10 sn (CBA lambs_danger_siperHizli), nesne arama yaricapi CBA lambs_danger_siperYaricap (varsayilan 22 m; eskiden 14), bina _yar + 10 m (eskiden 28)
private _hizli = missionNamespace getVariable ["lambs_danger_siperHizli", true];
private _yar = missionNamespace getVariable ["lambs_danger_siperYaricap", 16];
_u setVariable [QGVAR(acikSiperT), time + ([25, 10] select _hizli)];
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
    ((_dolu findIf {((_x select 0) distance2D _pt) < _r}) >= 0) || {(_talepler findIf {_x distance2D _pt < _r}) >= 0} || {(_dostPoz findIf {_x distance2D _pt < (_r min 3)}) >= 0}
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
private _geriMax = [3, 10] select ((getSuppression _u) >= 0.5);
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
    private _sahte = (["wire", "powerline", "powerpole", "pole", "cable", "lamp", "antenna", "pylon"] findIf {(_ad0 find _x) >= 0}) >= 0;
    if (!_sahte && {_yk >= 0.7} && {(_u distance2D _op) <= _yar}) then {
        private _r = (((((_bb select 1) select 0) - ((_bb select 0) select 0)) max (((_bb select 1) select 1) - ((_bb select 0) select 1))) / 2) min 2.5;
        private _pos = _op getPos [_r + 0.55, _en getDir _o];
        if (!surfaceIsWater _pos && {(_pos distance2D _en) >= (_ed - 10)} && {(_pos distance2D _en) <= (_ed + _geriMax)} && {!([_pos, _aralik] call _doluMu)}) then {
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
if (_obj isEqualTo [] && {missionNamespace getVariable ["lambs_danger_siperBitki", true]}) then {
    {
        private _o = _x;
        private _op = getPosATL _o;
        private _bb = boundingBoxReal _o;
        private _yk = ((_bb select 1) select 2) - ((_bb select 0) select 2);
        if (_yk >= 0.3 && {(_u distance2D _op) <= _yar}) then {
            private _r = (((((_bb select 1) select 0) - ((_bb select 0) select 0)) max (((_bb select 1) select 1) - ((_bb select 0) select 1))) / 2) min 2;
            private _pos = _op getPos [_r + 0.5, _en getDir _o];
            if (!surfaceIsWater _pos && {(_pos distance2D _en) >= (_ed - 10)} && {(_pos distance2D _en) <= (_ed + _geriMax)} && {!([_pos, _aralik] call _doluMu)}) then {
                private _gASL = ATLToASL [_pos select 0, _pos select 1, 0];
                private _gizli = {
                    params ["_h"];
                    private _vh = lineIntersectsSurfaces [_eASL, _gASL vectorAdd [0, 0, _h], _en, _u, true, 1, "VIEW", "NONE"];
                    (_vh isNotEqualTo []) && {((_vh select 0) select 2) isEqualTo _o}
                };
                private _ds = "";
                private _dc = 0;
                if ([1.0] call _gizli) then { _ds = "MIDDLE"; _dc = 2; } else { if ([0.4] call _gizli) then { _ds = "DOWN"; _dc = 5; }; };
                if (_ds isNotEqualTo "") then {
                    private _sk = (_u distance2D _pos) + _dc + 6;
                    _sk = _sk - (0.6 * ([side group _u, _pos, getPosATL _en] call _mevziFn));
                    if (_sk < _objS) then { _objS = _sk; _obj = _pos; _objDurus = _ds; _objAd = typeOf _o; if (_objAd isEqualTo "") then { _objAd = (getModelInfo _o) select 0; }; };
                };
            };
        };
    } forEach (nearestTerrainObjects [_p, ["BUSH", "SMALL TREE"], _yar, false, true]);
};

// v8.516 ARAZI KIVRIMI ARKASI (RPT 13:27 chernarus_summer: agaclarin %75'inde FIRE LOD yok, gövde genisligi medyan 0.00 m; nesne siperi gorus keser ama mermi durdurmaz): nesne siperi de bulunamazsa
//   cevrede (4 / 8 / 12 m halkalarda 8 yon) dusman gozunden arazi kivrimiyle (terrainIntersectASL) gizlenen en yakin nokta: 0.4 m kapali = yat, 1.0 m kapali = comel. Kapatma: lambs_danger_siperArazi = false.
if (_obj isEqualTo [] && {missionNamespace getVariable ["lambs_danger_siperArazi", true]}) then {
    {
        private _r = _x;
        for "_ai" from 0 to 7 do {
            private _pt = _p getPos [_r, (_ai * 45) + (_u getDir _en)];
            if (!surfaceIsWater _pt && {(_pt distance2D _en) >= (_ed - 10)} && {(_pt distance2D _en) <= (_ed + _geriMax)} && {!([_pt, _aralik] call _doluMu)}) then {
                private _ptASL = AGLToASL [_pt select 0, _pt select 1, 0];
                private _dn = "";
                private _dc = 0;
                if (terrainIntersectASL [_eASL, _ptASL vectorAdd [0, 0, 1.0]]) then { _dn = "MIDDLE"; _dc = 2; } else { if (terrainIntersectASL [_eASL, _ptASL vectorAdd [0, 0, 0.4]]) then { _dn = "DOWN"; _dc = 5; }; };
                if (_dn isNotEqualTo "") then {
                    private _sk = _r + _dc + 8;
                    _sk = _sk - (0.6 * ([side group _u, _pt, getPosATL _en] call _mevziFn));
                    if (_sk < _objS) then { _objS = _sk; _obj = _pt; _objDurus = _dn; _objAd = "ARAZI KIVRIMI"; };
                };
            };
        };
    } forEach [4, 8, 12];
};

// v8.520 KENTSEL ONCELIK (kullanici: 'ev ici ve meskun mahalde oncelik'; RPT 14:10 Altis 'cover': 55 kurtarmanin 0'i bina, 34'u cam agaci - cevrede dukkan / ev varken): girilebilir >= 2 bina varsa (_yar + 10 m)
//   NESNE (agac / kaya / duvar) sonucu ERTELENIR, once BINA (atis pozisyonu / gizli nokta) aranir; bina bulunamazsa ertelenen nesne uygulanir. CBA lambs_danger_kentselOncelik (varsayilan acik).
private _nesneGit = {
    _sayAS set ["nesne", (_sayAS getOrDefault ["nesne", 0]) + 1];
    _dolu pushBack [_obj, time];
    missionNamespace setVariable ["lambs_danger_acikSiperDolu", _dolu];
    [_obj, _objAd] call _talepYaz;
    _u setVariable [QGVAR(taktikKilit), time + 15];
    _u forceSpeed -1;
    _u setSpeedMode "FULL";
    _u doMove _obj;
    _u setUnitPos "UP";
    [_u, _obj, _en, _objDurus] call FUNC(siperZorla);   // v8.510: ates ederken doMove ertelenmesin (raycast dogrulamali atilis)
    [{ params ["_uu", "_hp"]; !alive _uu || {(_uu distance2D _hp) < 1.5} }, { params ["_uu", "_hp", "_ds"]; if (alive _uu) then { _uu setUnitPos _ds; [_uu] call FUNC(siperTut); }; }, [_u, _obj, _objDurus], 12, { params ["_uu", "_hp", "_ds"]; if (alive _uu) then { _uu setUnitPos _ds; }; }] call CBA_fnc_waitUntilAndExecute;
    [{ params ["_uu"]; if (alive _uu) then { _uu setUnitPos "AUTO"; }; }, [_u], 25] call CBA_fnc_waitAndExecute;
    if ((missionNamespace getVariable ["lambs_danger_acikSiperLogN", 0]) < 40) then {
        missionNamespace setVariable ["lambs_danger_acikSiperLogN", (missionNamespace getVariable ["lambs_danger_acikSiperLogN", 0]) + 1];
        diag_log format ["[ACIK-SIPER] %1 | %2 | dusman %3 m acikta -> NESNE ARKASI %4 (%5 m, durus %6, dusmandan gizli)", groupId _g, name _u, round _ed, _objAd, round (_u distance2D _obj), _objDurus];
    };
    true
};
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
        if (_d <= (_yar + 10) && {(_bp distance2D _en) >= (_ed - 8)} && {(_bp distance2D _en) <= (_ed + _geriMax)} && {!([_bp, (_aralik * 0.5) max 2] call _doluMu)}) then {
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
    if (_obj isNotEqualTo []) then { call _nesneGit } else { _sayAS set ["aday_yok", (_sayAS getOrDefault ["aday_yok", 0]) + 1]; false }
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
_u doMove _en_iyi;
// v8.354: atis pozisyonuna varinca durus + dusmana bak (pasif beklemesin); 45 sn sonra serbest
if (_atisVar) then {
    [{ params ["_uu", "_hp"]; !alive _uu || {(_uu distance2D _hp) < 1.5} }, { params ["_uu", "_hp", "_ds", "_e"]; if (alive _uu) then { _uu setUnitPos _ds; if (!isNull _e && {alive _e}) then { _uu doWatch _e; }; [_uu] call FUNC(siperTut); }; }, [_u, _en_iyi, _durusB, _en], 14, {}] call CBA_fnc_waitUntilAndExecute;
    [{ params ["_uu"]; if (alive _uu) then { _uu setUnitPos "AUTO"; _uu doWatch objNull; }; }, [_u], 45] call CBA_fnc_waitAndExecute;
};
if ((missionNamespace getVariable ["lambs_danger_acikSiperLogN", 0]) < 40) then {
    missionNamespace setVariable ["lambs_danger_acikSiperLogN", (missionNamespace getVariable ["lambs_danger_acikSiperLogN", 0]) + 1];
    diag_log format ["[ACIK-SIPER] %1 | %2 | dusman %3 m acikta -> bina %4 (%5 m, %6, skor %7)", groupId _g, name _u, round _ed, _binaAd, round (_u distance2D _en_iyi), if (_atisVar) then {format ["ATIS POZISYONU: dusman gorunuyor, durus %1", _durusB]} else {"pasif gizlenme (atis pozisyonu yok)"}, round _enS];
};
true

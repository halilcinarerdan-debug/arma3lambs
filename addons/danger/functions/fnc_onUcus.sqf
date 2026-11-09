#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ON UCUS (PREFLIGHT) — oyun basladiktan ~30 sn sonra TEK SEFER, RPT'ye sabit bicimli kisa bir durum dokumu ve celiski uyarilari yazar (v8.500l).
 *
 * NEDEN: bir operasyon ~1 saat suruyor; 3DEN ayari oyuna ulasmadi, arac / koltuk / gorev eksik gibi YAPILANDIRMA sorunlari ancak saatler sonra
 *   (logu atinca) anlasiliyordu. Bu blok ilk 1-2 dakikada gorulur: kisa bir duman testi (zamani hizlandirabilirsin) yapilandirma sorunlarini ayiklar,
 *   saatlik operasyon yalniz DAVRANIS dogrulamasi icin kalir.
 * KAPSAM (tek blok, sinirli satir; dongu YOK, davranis degistirmez):
 *   [ONUCUS] RUN        oturum kimligi (ayni RPT'de birden fazla oturum / yeniden baslatma ayirt edilir)
 *   [ONUCUS] MODUL      her ELITE 3DEN modulu: konum, SYNC'li obje / grup / IHA sayisi, FILTRESIZ tum degiskenler (okunan nitelikler)
 *   [ONUCUS] AYAR       onemli CBA ayarlarinin gercek degeri
 *   [ONUCUS] GRUP       her AI grubu: taraf, asker, gorev etiketi, lider, aracta mi
 *   [ONUCUS] ARAC       kara araclari: sinif, kargo koltuk sayisi, surucu grubu, gorev
 *   [ONUCUS] TOPCU / IHA   topcu araclari (mermi, gorev, sahipli grup) ve IHA'lar
 *   [ONUCUS] KAPASITE   taraf basina yaya asker ve nakil koltugu
 *   [ONUCUS] OYUNCU    oyuncu, grubu, HQ baglantisi
 *   [ONUCUS-UYARI]      celiskiler: nitelik degiskeni yok, grup adi 'recon' ama gorev bos, topcu araci var ama TOPCU grubu yok, koltuk yetmiyor ...
 * Karne: tools/rpt_ozet.py --onucus
 * Kapatma: lambs_danger_onUcusOff = true (mission init'te).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isServer) exitWith {false};
if (!isNil "lambs_danger_onUcusStarted") exitWith {false};
lambs_danger_onUcusStarted = true;

[] spawn {
    private _tSon = diag_tickTime + 120;
    waitUntil { sleep 1; (time > 25 && {!isNil "lambs_danger_planKapiStarted"}) || {diag_tickTime > _tSon} };
    sleep 5;
    if (missionNamespace getVariable ["lambs_danger_onUcusOff", false]) exitWith {};

    private _L = { diag_log ("[ONUCUS] " + _this); };
    private _uyList = [];
    private _W = { _uyList pushBack _this; diag_log ("[ONUCUS-UYARI] " + _this); };
    private _kes = { params ["_s", ["_n", 360]]; if ((count _s) > _n) then { (_s select [0, _n]) + "..." } else { _s } };
    private _ilk = { params ["_a", "_n"]; _a select [0, _n min (count _a)] };
    private _uyari = 0;
    private _t0 = diag_tickTime;

    // ---------------------------------------------------------------- 0 RUN
    (format ["RUN | %1 | harita %2 | oyun zamani %3 sn | UTC %4 | yerel sunucu:%5 | oyuncu %6 | tohum %7 (%8) | paket surumu: boot satirina bak", missionName, worldName, round time, (systemTimeUTC apply { str _x }) joinString "-", isServer, count allPlayers, missionNamespace getVariable ["lambs_danger_tohumDeger", "yok"], missionNamespace getVariable ["lambs_danger_tohumKaynak", "-"]]) call _L;

    // ---------------------------------------------------------------- 1 MODULLER
    private _moduller = (entities "Logic") select { ((toLower (typeOf _x)) find "lambs_danger_eden") isEqualTo 0 };
    private _nitelikYok = [];
    {
        private _m = _x;
        private _idx = _forEachIndex;
        private _vars = (allVariables _m) select { (_x find "lambs_danger_ed") isEqualTo 0 };
        private _sync = synchronizedObjects _m;
        private _gr = [];
        { if (!isNull (group _x)) then { _gr pushBackUnique (groupId (group _x)); }; } forEach _sync;
        private _iha = { unitIsUAV _x } count _sync;
        if (_vars isEqualTo []) then { _nitelikYok pushBack (typeOf _m); };
        if (_idx < 24) then {
            (format ["MODUL | %1 %2 | SYNC obje %3 (grup %4, IHA %5) | nitelik degiskeni %6: %7", typeOf _m, mapGridPosition _m, count _sync, _gr, _iha, count _vars, [(_vars apply { format ["%1=%2", _x, _m getVariable _x] }) joinString " ; ", 300] call _kes]) call _L;
        };
    } forEach _moduller;
    (format ["MODUL | toplam %1 ELITE 3DEN modulu", count _moduller]) call _L;
    if (_nitelikYok isNotEqualTo []) then {
        _uyari = _uyari + 1;
        (format ["%1 modulde 3DEN nitelik degiskeni YOK (%2): ayarlar oyuna ulasmiyor; yedekler / varsayilanlar kullanilir. [EDEN-IFADE] satirina bakin", count _nitelikYok, [str (_nitelikYok arrayIntersect _nitelikYok), 200] call _kes]) call _W;
    };

    // ---------------------------------------------------------------- 2 AYAR
    private _ayarAd = ["lambs_danger_nakilV2", "lambs_danger_orphanOff", "lambs_danger_fireLineOn", "lambs_danger_atisUstunlugu", "lambs_danger_ihaUcakIrtifa", "lambs_danger_ihaUcakHavadan", "lambs_danger_tasimaTutS", "lambs_danger_nakilTahminHiz", "lambs_danger_planMesafe", "lambs_danger_bastirmaYogunluk"];
    (format ["AYAR | %1", _ayarAd apply { format ["%1=%2", _x select [13, (count _x) - 13], missionNamespace getVariable [_x, "yok"]] }]) call _L;

    // ---------------------------------------------------------------- 3 GRUPLAR
    private _gruplar = allGroups select { !isNull _x && {(side _x) in [west, east, resistance]} && {({ alive _x } count (units _x)) > 0} };
    private _recon = [];
    {
        private _g = _x;
        private _idx = _forEachIndex;
        private _ld = leader _g;
        private _gv = _g getVariable ["lambs_danger_gorev", ""];
        private _veh = [];
        { private _vv = vehicle _x; if (_vv isNotEqualTo _x) then { _veh pushBackUnique (typeOf _vv); }; } forEach (units _g);
        if (_idx < 30) then {
            (format ["GRUP | %1 | %2 | asker %3 | gorev '%4' | lider %5 (oyuncu %6) | arac %7 | yerel %8", groupId _g, side _g, { alive _x } count (units _g), _gv, [name _ld, "-"] select (isNull _ld), isPlayer _ld, _veh, local _g]) call _L;
        };
        if (((toLower (groupId _g)) find "recon") >= 0 && {_gv isEqualTo ""}) then { _recon pushBack (groupId _g); };
    } forEach _gruplar;
    (format ["GRUP | toplam %1 AI grubu (ilk 30 gosterildi)", count _gruplar]) call _L;
    if (_recon isNotEqualTo []) then {
        _uyari = _uyari + 1;
        (format ["grup adi 'recon' iceriyor ama gorev bos: %1 (Gorev Ata modulu / grup adindan otomatik atama bekleniyor)", _recon]) call _W;
    };

    // ---------------------------------------------------------------- 4 ARACLAR / TOPCU / IHA
    private _araclar = vehicles select { alive _x && {_x isKindOf "LandVehicle"} && {!isNull (driver _x)} && {!(unitIsUAV _x)} && {(getNumber (configOf _x >> "artilleryScanner")) <= 0} };
    private _kapTop = createHashMap;
    private _yayaTop = createHashMap;
    {
        private _v = _x;
        private _idx = _forEachIndex;
        private _sd = side (group (driver _v));
        private _kap = count (fullCrew [_v, "cargo", true]);
        private _snf = (([_v] call FUNC(aracSinif)) select 0);
        if (_idx < 25) then {
            (format ["ARAC | %1 | %2 | sinif %3 | kargo koltuk %4 | surucu grubu %5 (%6) | gorev '%7' | %8", typeOf _v, getText (configOf _v >> "displayName"), _snf, _kap, groupId (group (driver _v)), _sd, _v getVariable ["lambs_danger_gorev", (group (driver _v)) getVariable ["lambs_danger_gorev", ""]], mapGridPosition _v]) call _L;
        };
        if (_kap >= 3 && {_snf in ["APC", "KAMYON", "IFV"]}) then { _kapTop set [str _sd, (_kapTop getOrDefault [str _sd, 0]) + _kap]; };
    } forEach _araclar;

    private _toplar = vehicles select { alive _x && {(getNumber (configOf _x >> "artilleryScanner")) > 0} };
    private _topGrupTaraf = createHashMap;
    {
        private _v = _x;
        private _g = group (driver _v);
        private _sd = side _g;
        private _gv = _v getVariable ["lambs_danger_gorev", _g getVariable ["lambs_danger_gorev", ""]];
        private _mermi = (getArtilleryAmmo [_v]) param [0, ""];
        (format ["TOPCU | %1 | grup %2 (%3) | gorev '%4' | gunner %5 | mermi '%6' | yerel %7 | %8", typeOf _v, groupId _g, _sd, _gv, !isNull (gunner _v), _mermi, local _v, mapGridPosition _v]) call _L;
        if (_gv isEqualTo "TOPCU") then { _topGrupTaraf set [str _sd, true]; };
    } forEach ([_toplar, 8] call _ilk);
    {
        private _sd = side (group (driver _x));
        if (!(_topGrupTaraf getOrDefault [str _sd, false])) then {
            if ((_x getVariable ["lambs_danger_gorev", (group (driver _x)) getVariable ["lambs_danger_gorev", ""]]) isNotEqualTo "TOPCU") then {
                _uyari = _uyari + 1;
                (format ["topcu araci %1 (%2) var ama gorevi TOPCU degil (gorev '%3'): plan topcu destegini kullanmaz", typeOf _x, _sd, _x getVariable ["lambs_danger_gorev", (group (driver _x)) getVariable ["lambs_danger_gorev", ""]]]) call _W;
            };
        };
    } forEach ([_toplar, 8] call _ilk);

    private _ihalar = vehicles select { alive _x && {unitIsUAV _x} && {_x isKindOf "Air"} };
    {
        (format ["IHA | %1 | %2 | surucu %3 | taraf %4 | gorev tur '%5' | %6", typeOf _x, getText (configOf _x >> "displayName"), !isNull (driver _x), side (group (driver _x)), _x getVariable ["lambs_danger_ihaGorevTur", ""], mapGridPosition _x]) call _L;
    } forEach ([_ihalar, 8] call _ilk);

    // ---------------------------------------------------------------- 5 KAPASITE
    {
        private _sd = _x;
        private _yaya = 0;
        { if ((side _x) isEqualTo _sd) then { { if (alive _x && {isNull objectParent _x} && {!isPlayer _x}) then { _yaya = _yaya + 1; }; } forEach (units _x); }; } forEach _gruplar;
        private _kap = _kapTop getOrDefault [str _sd, 0];
        if (_yaya > 0 || {_kap > 0}) then {
            (format ["KAPASITE | %1 | yaya AI asker %2 | nakil koltugu %3 (APC / KAMYON / IFV, surucusu olan)", _sd, _yaya, _kap]) call _L;
            if (_kap < _yaya && {_kap > 0}) then {
                _uyari = _uyari + 1;
                (format ["%1: nakil koltugu (%2) yaya asker sayisindan (%3) az: en az %4 asker yaya kalabilir", _sd, _kap, _yaya, _yaya - _kap]) call _W;
            };
        };
    } forEach [west, east, resistance];

    // ---------------------------------------------------------------- 6 OYUNCU
    {
        private _p = _x;
        (format ["OYUNCU | %1 | grup %2 | lider mi %3 | aracta %4 | HQ bagi '%5'", name _p, groupId (group _p), _p isEqualTo (leader (group _p)), !isNull objectParent _p, (group _p) getVariable ["lambs_danger_hqId", ""]]) call _L;
    } forEach ([allPlayers, 8] call _ilk);

    (format ["BITTI | uyari %1 | sure %2 sn (tek seferlik; bundan sonra bu blok tekrar etmez)", _uyari, (diag_tickTime - _t0) toFixed 2]) call _L;

    // v8.501 OYUN ICI OZET (Asama 9 araci 3): uyarilar ana bilgisayara / Zeus'a sohbet olarak da gosterilir (log beklemeden). CBA yok: lambs_danger_onUcusSohbetOff = true ile kapanir.
    if (!(missionNamespace getVariable ["lambs_danger_onUcusSohbetOff", false])) then {
        private _satirlar = if (_uyList isEqualTo []) then { [format ["[ELITE] On ucus: uyari yok (modul %1, grup %2, arac %3)", count _moduller, count _gruplar, count _araclar]] } else { [format ["[ELITE] On ucus: %1 UYARI (ayrintisi RPT [ONUCUS-UYARI]):", count _uyList]] };
        { _satirlar pushBack (format ["[ELITE] - %1", [_x, 150] call _kes]); } forEach ([_uyList, 6] call _ilk);
        if ((count _uyList) > 6) then { _satirlar pushBack (format ["[ELITE] ... ve %1 uyari daha (RPT)", (count _uyList) - 6]); };
        private _alici = ((allCurators apply { getAssignedCuratorUnit _x }) select { !isNull _x && {isPlayer _x} }) apply { owner _x };
        if (hasInterface) then { _alici = _alici - [clientOwner]; };
        if (hasInterface) then { { systemChat _x; } forEach _satirlar; };
        { [_x] remoteExec ["systemChat", _alici]; } forEach _satirlar;
    };
};

true

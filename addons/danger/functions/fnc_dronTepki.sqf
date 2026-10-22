#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DRONA KARSI TEPKI + DRON YONU (v8.280; kullanici: 'drona ates etsinler eger uygunsa ve dronun geldigi yonu dusman bilsin').
 * Fnc_havaFarkindalik'tan, grubun ilgili (bilinen) DUSMAN dronu icin cagrilir.
 *   1) IZ: dronun konumu 2 sn'de bir kaydedilir (lambs_danger_dronIz, son 14 kayit). >= 6 sn'lik iz ve >= 25 m yer degistirme varsa gelis yonu = iz dogrultusu; OPERATOR / FIRLATMA YONU = gelisin TERSI
 *      (hile yok: yalniz gorulen ucus yolundan geri cikarim). Grup ve 400 m icindeki dost yerel gruplar `lambs_danger_dronYon` = [geri yon, zaman, ilk gorulen konum] alir,
 *      `sesSonPos` (supheli dusman konumu: ilk gorulen konumdan geri yonde 700 m, +-%15 hata) ve 2 asker 12 sn o yone bakar. Log: [DRON-YON]
 *   2) ATES (uygunsa): KAMIKAZE / bomba / silahli dron (FPV-AT, FPV-AP, BOMBA, silahli) <= lambs_danger_dronAtesM (varsayilan 450 m) ve yukseklik <= 200 m ise grup ates eder:
 *      yatayda hareketsiz silahli askerler ongorulu (lead) toplu ates (doSuppressiveFire), en yakin 3 asker doTarget + doFire; combatMode en az YELLOW, behaviour SAFE / CARELESS ise AWARE. 3 sn'de bir.
 *      GOZLEM dronu: yalniz <= 100 m (ates konumu ele verir; ATP 3-01.8: once pasif onlem).
 *      Retreat / Evade / BreakContact / sniper grubu bu fonksiyona zaten hic gelmez (havaFarkindalik atlar).
 *   v8.288: kamikaze / silahli dron <= 700 m ise ayrica fnc_dronSakla (dagil + siper / yat); cagiran havaFarkindalik 25 sn boyunca eski toplu HIDE / GARRISON'u atlar.
 *   Doner: ates edildi mi <BOOL> (true ise cagiran diger pasif onlemleri - saklanma - atlar).
 * Kapatma: lambs_danger_dronTepkiOff = true.
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Dron <OBJECT>
 * 2: Yatay mesafe <NUMBER>
 *
 * Return Value: Ates edildi mi <BOOL>
 * Public: No
*/

params [["_g", grpNull, [grpNull]], ["_dr", objNull, [objNull]], ["_d", 0, [0]]];
if (isNull _g || {isNull _dr} || {!alive _dr} || {missionNamespace getVariable ["lambs_danger_dronTepkiOff", false]}) exitWith {false};
private _l = leader _g;
if (isNull _l || {!alive _l}) exitWith {false};

private _tip = [_dr] call FUNC(ihaTip);
private _silahli = ((_dr weaponsTurret [-1]) isNotEqualTo []) || {(_dr weaponsTurret [0]) isNotEqualTo []};
private _kamikaze = _silahli || {_tip in ["FPV-AT", "FPV-AP", "BOMBA"]};

// ---- 1) IZ + GELIS YONU ----
private _iz = _dr getVariable [QGVAR(dronIz), []];
if (_iz isEqualTo [] || {(time - ((_iz select (count _iz - 1)) select 0)) >= 2}) then {
    _iz pushBack [time, getPosATL _dr];
    if ((count _iz) > 14) then { _iz deleteAt 0; };
    _dr setVariable [QGVAR(dronIz), _iz];
};
if ((count _iz) >= 3 && {(time - ((_iz select 0) select 0)) >= 6}) then {
    private _p0 = (_iz select 0) select 1;
    private _p1 = (_iz select (count _iz - 1)) select 1;
    if ((_p0 distance2D _p1) >= 25 && {(time - (_g getVariable [QGVAR(dronYonT), -999])) > 15}) then {
        private _gelis = _p0 getDir _p1;
        private _geri = (_gelis + 180) mod 360;
        private _hata = (random 30) - 15;
        private _supheli = _p0 getPos [700, _geri + _hata];
        private _bilgi = [_geri, time, _p0];
        private _n = 0;
        {
            if (local _x && {!isNull (leader _x)} && {(side _x) isEqualTo (side _g)} && {((leader _x) distance2D _l) < 400}) then {
                _x setVariable [QGVAR(dronYon), _bilgi];
                _x setVariable [QGVAR(dronYonT), time];
                _x setVariable [QGVAR(sesSonZaman), time];
                _x setVariable [QGVAR(sesSonPos), _supheli];
                private _ud = (units _x) select {alive _x && {isNull objectParent _x}};
                { _x doWatch _supheli; [{ params ["_c"]; if (alive _c) then { _c doWatch objNull; }; }, [_x], 12] call CBA_fnc_waitAndExecute; } forEach (_ud select [0, 2]);
                if ((behaviour (leader _x)) in ["SAFE", "CARELESS"]) then { _x setBehaviour "AWARE"; };
                _n = _n + 1;
            };
        } forEach allGroups;
        _g setVariable [QGVAR(dronYonT), time];
        if ((time - (_dr getVariable [QGVAR(dronYonLogT), -999])) > 20) then {
            _dr setVariable [QGVAR(dronYonLogT), time];
            diag_log format ["[DRON-YON] %1 | %2 (%3) | gelis %4 derece -> operator / firlatma yonu %5 derece (700 m, hata +-15) | iz %6 m / %7 sn | haberdar edilen grup %8", groupId _g, typeOf _dr, _tip, round _gelis, round _geri, round (_p0 distance2D _p1), round (time - ((_iz select 0) select 0)), _n];
        };
    };
};

// ---- 2) ATES ----
private _menzil = if (_kamikaze) then { missionNamespace getVariable ["lambs_danger_dronAtesM", 450] } else {100};
private _egik = _l distance _dr;
// v8.288 DAGIL + SAKLAN (kullanici: 'botlar dusman dronu gorunce mesafeyi arttirsinlar ve saklansinlar'): kamikaze / silahli dron <= 700 m ise grup dagilir ve siper alir (fnc_dronSakla); ates menzilindeyse 3 nisanci yerinde kalir
// v8.295 DIK ACI (kullanici: 'adamlarin diplerine ucurdum dronu havada bekledim 20 sn hicbir sey yapmadilar'; RPT 22-10: dron 46 m yatay / 62 m yukseklik = ~53 derece, piyade silahi bu aciya cevrilemiyor, 'zorla atis' 0): yukseklik acisi > 40 derece ise
//   nisancilar yerinde BEKLEMEZ (hepsi dagilir / siper alir), > 50 derece ise ates emri verilmez (yapilamayan atis yerine kacis).
private _yatD = (_l distance2D _dr) max 1;
private _elev = atan (((((getPosATL _dr) select 2) - 1.5) max 0) / _yatD);
if (_elev > 40 && {(time - (_g getVariable [QGVAR(dronDikLogT), -99])) > 10}) then {
    _g setVariable [QGVAR(dronDikLogT), time];
    diag_log format ["[DRON-DIK] %1 | %2 | yatay %3 m yukseklik %4 m -> yukseklik acisi %5 derece (> 40: nisancilar yerinde beklemez, > 50: ates emri yok, dagilma / siper)", groupId _g, typeOf _dr, round _yatD, round ((getPosATL _dr) select 2), round _elev];
};
if (_kamikaze && {_egik <= 700} && {((getPosATL _dr) select 2) <= 200}) then { [_g, _dr, (_egik <= _menzil) && {_elev <= 40}, _egik <= 200] call FUNC(dronSakla); };
if (_egik > _menzil || {((getPosATL _dr) select 2) > 200} || {_elev > 50}) exitWith {false};
if ((time - (_g getVariable [QGVAR(dronAtesT), -99])) < 3) exitWith {true};
_g setVariable [QGVAR(dronAtesT), time];
if ((combatMode _g) in ["BLUE", "GREEN", "WHITE"]) then { _g setCombatMode "YELLOW"; };
if ((behaviour _l) in ["SAFE", "CARELESS"]) then { _g setBehaviour "AWARE"; };

private _vel = velocity _dr;
private _tp = getPosASL _dr;
private _adaylar = (units _g) select {alive _x && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {(primaryWeapon _x) isNotEqualTo ""} && {(speed _x) < ([3, 9] select (_egik < 250))}};   // v8.291: dron <= 250 m ise kosarken / yururken de ates
_g reveal [_dr, 4];
private _n = 0;
{
    private _u = _x;
    // v8.292 GERCEK ATIS SAYACI (kullanici: 'hala ayni - ateş etmediler'; [DRON-ATES] yalniz EMIR sayisiydi): Fired olayi emirden sonraki 8 sn icindeki atislari sayar
    if !(_u getVariable [QGVAR(dronAtisEH), false]) then {
        _u setVariable [QGVAR(dronAtisEH), true];
        _u addEventHandler ["Fired", { params ["_uu"]; if ((time - (_uu getVariable [QGVAR(dronEmirT), -99])) < 8) then { _uu setVariable [QGVAR(dronAtisN), (_uu getVariable [QGVAR(dronAtisN), 0]) + 1]; }; }];
    };
    _u setVariable [QGVAR(dronEmirT), time];
    private _iv = getNumber (configFile >> "CfgMagazines" >> (currentMagazine _u) >> "initSpeed");
    if (_iv <= 0) then { _iv = 800 };
    private _tof = ((_u distance _dr) / (_iv * 0.9)) min 2;
    private _lead = ASLToAGL (_tp vectorAdd (_vel vectorMultiply _tof));
    if (_n < 3) then {
        _u doTarget _dr;
        _u doFire _dr;
        // v8.293 ZORLA ATES (kullanici: 'ates etmediler'; doTarget / doFire + doSuppressiveFire AI tarafindan kucuk IHA'ya (hava hedefi) yok sayiliyor olabilir): nisan yonu (doWatch) ongorulu noktaya cevrilir,
        //   silah yonu hedefe <= 6 derece olunca forceWeaponFire ile 3'lu kisa atis (AI karar mekanizmasindan bagimsiz). 6 sn'lik dongu, 5 sn'de bir birim basina. Kapatma: lambs_danger_dronZorlaOff = true.
        if !(missionNamespace getVariable ["lambs_danger_dronZorlaOff", false]) then {
            [_u, _dr] spawn {
                params ["_u", "_dr"];
                if ((time - (_u getVariable ["lambs_danger_dronZorlaT", -99])) < 5) exitWith {};
                _u setVariable ["lambs_danger_dronZorlaT", time];
                _u setVariable ["lambs_danger_dronZorlaBas", (_u getVariable ["lambs_danger_dronZorlaBas", 0]) + 1];
                // v8.295: RPT 22-10 (sunucu 22:29): 'ates emri' var, GERCEK ATIS 0, zorla atis 0 -> (a) currentWeapon GP-25 namlusunda (40 mm el bombasi) olabilir: ANA SILAH + ana namlu secilir;
                //   (b) govde yonu yavas doner -> hedef yone setDir ile hizalanir (yalniz yatay), (c) en kucuk aci / baslama sayisi loglanir ([DRON-ATES] 'zorla dongu').
                private _w = primaryWeapon _u;
                if (_w isEqualTo "" || {(_u ammo _w) <= 0}) exitWith {};
                if ((currentWeapon _u) isNotEqualTo _w || {(currentMuzzle _u) isNotEqualTo _w}) then { _u selectWeapon _w; sleep 0.3; };
                private _bit = time + 6;
                private _zN = 0;
                private _min = 180;
                while {time < _bit && {alive _u} && {!isNull _dr} && {alive _dr} && {(_u ammo _w) > 0}} do {
                    private _iv2 = getNumber (configFile >> "CfgMagazines" >> (currentMagazine _u) >> "initSpeed");
                    if (_iv2 <= 0) then { _iv2 = 800 };
                    private _tof2 = ((_u distance _dr) / (_iv2 * 0.9)) min 2;
                    private _lead2 = ASLToAGL ((getPosASL _dr) vectorAdd ((velocity _dr) vectorMultiply _tof2));
                    _u doWatch _lead2;
                    _u doTarget _dr;
                    // govde yonu hedefe >15 derece ise dondur (AI govdesi yavas doner; yatay hizalama zararsiz)
                    private _yatay = (getPosATL _u) getDir _lead2;
                    private _fy = abs (((_yatay - (getDir _u)) + 540) mod 360 - 180);
                    if (_fy > 15) then { _u setDir _yatay; };
                    sleep 0.35;
                    private _fark = (AGLToASL _lead2) vectorDiff (eyePos _u);
                    private _wd = _u weaponDirection _w;
                    if ((vectorMagnitude _fark) > 1 && {(vectorMagnitude _wd) > 0.1}) then {
                        private _aci = acos ((((vectorNormalized _wd) vectorDotProduct (vectorNormalized _fark)) min 1) max -1);
                        if (_aci < _min) then { _min = _aci; };
                        if (_aci < 6) then {
                            for "_k" from 1 to 3 do {
                                _u forceWeaponFire [currentMuzzle _u, currentWeaponMode _u];
                                _zN = _zN + 1;
                                _u setVariable ["lambs_danger_dronZorlaN", (_u getVariable ["lambs_danger_dronZorlaN", 0]) + 1];
                                sleep 0.14;
                            };
                        };
                    };
                };
                _u doWatch objNull;
                _u setVariable ["lambs_danger_dronZorlaAci", _min];
            };
        };
    } else {
        _u doSuppressiveFire _lead;
    };
    _n = _n + 1;
} forEach ([_adaylar, [], {_x distance _dr}, "ASCEND"] call BIS_fnc_sortBy);

if ((time - (_g getVariable [QGVAR(dronAtesLogT), -999])) > 8) then {
    _g setVariable [QGVAR(dronAtesLogT), time];
    private _atisT = 0;
    { _atisT = _atisT + (_x getVariable [QGVAR(dronAtisN), 0]); } forEach (units _g);
    private _atisFark = _atisT - (_g getVariable [QGVAR(dronAtisSon), 0]);
    _g setVariable [QGVAR(dronAtisSon), _atisT];
    private _zorlaT = 0;
    { _zorlaT = _zorlaT + (_x getVariable ["lambs_danger_dronZorlaN", 0]); } forEach (units _g);
    private _basT = 0;
    private _aciMin = 180;
    { _basT = _basT + (_x getVariable ["lambs_danger_dronZorlaBas", 0]); _aciMin = _aciMin min (_x getVariable ["lambs_danger_dronZorlaAci", 180]); } forEach (units _g);
    diag_log format ["[DRON-ATES] %1 | %2 (%3) %4 m (egik) | yukseklik %5 m | ates emri %6 | GERCEK ATIS (son logdan beri) %7 | zorla atis (toplam) %8 | zorla dongu %10 | en kucuk nisan acisi %11 derece | tur %9", groupId _g, typeOf _dr, _tip, round _egik, round ((getPosATL _dr) select 2), _n, _atisFark, _zorlaT, ["GOZLEM", "KAMIKAZE / SILAHLI"] select _kamikaze, _basT, round _aciMin];
    // emir var ama gercek atis yok: ilk atici icin durum dokumu
    if (_n > 0 && {_atisFark <= 0} && {(time - (_g getVariable [QGVAR(dronAtisTaniT), -999])) > 25}) then {
        _g setVariable [QGVAR(dronAtisTaniT), time];
        private _a0 = (([_adaylar, [], {_x distance _dr}, "ASCEND"] call BIS_fnc_sortBy) param [0, objNull]);
        if (!isNull _a0) then {
            diag_log format ["[DRON-ATES] %1 | ATIS YOK (emir verildi) | atici %2 | davranis %3 combatMode %4 | durus %5 | hazir %6 komut '%7' | silah %8 mermi %9 | dron bilgisi %10 | gorus (hat acik) %11 | disableAI hedef: %12",
                groupId _g, name _a0, behaviour _a0, combatMode (group _a0), stance _a0, unitReady _a0, currentCommand _a0, currentWeapon _a0, _a0 ammo (currentWeapon _a0), (_a0 knowsAbout _dr) toFixed 2,
                !(lineIntersects [eyePos _a0, getPosASL _dr, _a0, _dr]), !(_a0 checkAIFeature "TARGET")];
        };
    };
};
_n > 0

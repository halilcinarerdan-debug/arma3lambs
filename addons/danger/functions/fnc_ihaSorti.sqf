#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * IHA GOREVI (v8.233; kullanici: FPV Drone Crocus (Workshop 3045129955), Mavic 3 + drop mod (3112310403), RHS IHA'lari) — AI IHA'yi betikle ucurur:
 *   GOZLEM : gozlem noktasi etrafinda (yaricap) 120 m'de devriye; gorulen dusman fnc_ihaGozlem ile ortak resme verilir.
 *   FPV-AT : kamikaze — zirhli (zirh >= 100 / Tank / APC) bilinen en yakin hedefe kadar alcak ucar (40 m), 220 m kala DALIS (28 m/sn, 0.1 sn adim), <= 4 m'de patlar (RPG-7 benzeri R_PG32V_F).
 *   FPV-AP : kamikaze — personel kumesi (15 m icinde en cok dusman); termobarik benzeri R_TBG32V_F.
 *   BOMBA  : Mavic benzeri — hedefin 10 m ustune gelir (30 m irtifa), 3 el bombasi (GrenadeHand) 6 sn arayla birakir, sonra kalkis noktasina doner. (Mod drop sistemi gerekmez; bombayi betik yaratir.)
 * Hedef BILINEN olmali: IHA'nin kendi algisi ya da IHA tarafinin herhangi bir grubu knowsAbout >= 0.4 (hile yok). Pil omru 600 sn (FPV: 10 dk; kaynak: Crocus aciklamasi), menzil <= verilen (varsayilan 3000 m; mod 4 km).
 * Mürettebat yoksa createVehicleCrew; AI IHA ates etmez (AUTOTARGET / TARGET kapali), CARELESS / BLUE; gorev HARIC. IHA once vurulur / dusurulurse hedefe ulasamaz (askerlerin dron tepkisi: fnc_havaFarkindalik).
 * KAYNAK (ilke): Ukrayna savasi FPV / hafif bombalayici kullanimi (acik kaynak analizleri); sayilar TASARIM degeri. Mod davranisi DOGRULANMADI — modun kendi patlama / kontrol betigine bagimli degiliz (kendi patlamamizi yaratiriz).
 * v8.268 OPERATOR BAGI (kullanici: 'dron sahibi olunce drona ne oluyor' -> 'yap'): _op (operator asker) + _opMod: 0 bagsiz (eski), 1 operator olunce dron KONTROLU KAYBEDER ve duser (gorev biter, 20 sn icinde yere / hasar 1),
 *   2 operator olunce dron HEDEFE kilitliyse (dalis / yaklasma) vurmaya devam eder, yeni hedef secmez; hedefsizse kontrol kaybi (dusme). Operator silinirse (isNull) olu sayilir. Log: [IHA-SORTI] ... OPERATOR OLDU.
 * Kapatma: lambs_danger_ihaSortiOff = true; her IHA icin gorev kaldir: mod "KALDIR".  Log: [IHA-SORTI]
 *
 * Arguments:
 * 0: IHA <OBJECT>
 * 1: Mod "SORTI" / "GOZLEM" / "KALDIR" <STRING>
 * 2: Tur ("" = otomatik, "FPV-AT", "FPV-AP", "BOMBA", "GOZLEM") <STRING>
 * 3: Taraf (mürettebat yoksa) <SIDE>
 * 4: Gozlem merkezi <ARRAY>
 * 5: Gozlem yaricapi <NUMBER>
 * 6: Menzil <NUMBER>
 * 7: Operator <OBJECT> (v8.268)
 * 8: Operator olunce: 0 bagsiz / 1 duser / 2 son hedefe dalar <NUMBER> (v8.268)
 *
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

// v8.260: CBA sunucu olayi 'call' ile (zamanlanmamis ortam) cagirir -> waitUntil / sleep 'Suspending not allowed' veriyordu, gorev hic baslamiyordu
if (!canSuspend) exitWith { _this spawn FUNC(ihaSorti); true };

params [["_uav", objNull, [objNull]], ["_mod", "SORTI", [""]], ["_turE", "", [""]], ["_tarafP", west, [west]], ["_merkez", [0, 0, 0], [[]]], ["_yar", 300, [0]], ["_men", 3000, [0]], ["_op", objNull, [objNull]], ["_opMod", 0, [0]]];
if (isNull _uav || {!alive _uav} || {missionNamespace getVariable ["lambs_danger_ihaSortiOff", false]}) exitWith {false};

private _tok = diag_tickTime;
_uav setVariable [QGVAR(ihaTok), _tok];
if (_mod isEqualTo "KALDIR") exitWith {
    _uav setVariable [QGVAR(ihaTok), -1];
    diag_log format ["[IHA-SORTI] %1 | gorev KALDIRILDI", typeOf _uav];
    true
};

if (_opMod > 0 && {!isNull _op} && {!alive _op}) exitWith { diag_log format ["[IHA-SORTI] %1 | operator zaten olu (%2): sorti baslatilmadi", typeOf _uav, name _op]; false };
if (_opMod > 0 && {!isNull _op}) then { _uav setVariable [QGVAR(ihaOperator), _op]; };

if (!local _uav) then {
    _uav setOwner 2;
    private _tw = time + 6;
    waitUntil { sleep 0.2; local _uav || {time > _tw} };
};
if (!local _uav) exitWith { diag_log format ["[IHA-SORTI] %1 | sunucuda yerel degil (setOwner basarisiz)", typeOf _uav]; false };

// v8.260: IHA'nin neden / nerede yok oldugunu kesin gormek icin (kullanici: 'atadigim gibi patladi')
if !(_uav getVariable [QGVAR(ihaKilledEH), false]) then {
    _uav setVariable [QGVAR(ihaKilledEH), true];
    _uav addEventHandler ["Killed", {
        params ["_u", "_k", "_i"];
        diag_log format ["[IHA-SORTI] %1 | YOK OLDU | yukseklik %2 m | hiz %3 m/s | konum %4 | olduren %5 | hasar %6", typeOf _u, round ((getPosATL _u) select 2), round (speed _u / 3.6), mapGridPosition _u, [typeOf _k, "yok / kendi"] select (isNull _k), damage _u toFixed 2];
    }];
    _uav addEventHandler ["Explosion", {
        params ["_u", "_d"];
        diag_log format ["[IHA-SORTI] %1 | PATLAMA ETKISI (explosion EH) | hasar %2 | yukseklik %3 m", typeOf _u, _d toFixed 2, round ((getPosATL _u) select 2)];
    }];
};

private _tur = if (_turE isNotEqualTo "") then {_turE} else { [_uav] call FUNC(ihaTip) };
if (_mod isEqualTo "GOZLEM") then { _tur = "GOZLEM"; };
_uav setVariable [QGVAR(ihaGorevTur), _tur];   // v8.343: gozlemli topcu (fnc_dronTopcu) B_Crocus_AP gibi sinifi FPV gorunen ama GOZLEM gorevinde olan dronu da gozlemci sayar
if (isNull (driver _uav)) then {
    createVehicleCrew _uav;
    if (_tarafP isNotEqualTo sideUnknown) then {
        private _gn = createGroup [_tarafP, true];
        (crew _uav) joinSilent _gn;
    };
};
private _taraf = side (group (driver _uav));
{ _x disableAI "AUTOTARGET"; _x disableAI "TARGET"; _x disableAI "SUPPRESSION"; _x setSkill 1; } forEach (crew _uav);
(group (driver _uav)) setBehaviour "CARELESS";
(group (driver _uav)) setCombatMode "BLUE";
// v8.278 SEYIR HIZI (kullanici: 'Crocus AT cok yavas, 20 ile gidiyor'): AI pilot varsayilan NORMAL hizla gidiyordu; FPV / bomba turlerinde FULL (GOZLEM devriyesi NORMAL kalir). Ek olarak asagidaki seyir hizlandirma yardimi kullanilir.
if (_tur isNotEqualTo "GOZLEM") then { (group (driver _uav)) setSpeedMode "FULL"; (driver _uav) forceSpeed -1; };
(group (driver _uav)) setVariable ["lambs_danger_gorev", "HARIC", true];
_uav setVariable ["lambs_danger_gorev", "HARIC", true];
_uav engineOn true;
diag_log format ["[IHA-SORTI] %1 (%2) | mod %3 | tur %4 | taraf %5 | menzil %6 m | gozlem yaricap %7 m", typeOf _uav, getText (configOf _uav >> "displayName"), _mod, _tur, _taraf, round _men, round _yar];

[_uav, _tok, _tur, _taraf, _merkez, _yar, _men, _op, _opMod] spawn {
    params ["_uav", "_tok", "_tur", "_taraf", "_merkez", "_yar", "_men", "_op", "_opMod"];
    private _d = driver _uav;
    private _bas = getPosATL _uav;
    private _t0 = time;
    // v8.268 OPERATOR: _opVar = operator tanimli; _opOldu = olu ya da silinmis. Mod 1: operator olunce gorev aktif sayilmaz (kontrol kaybi); mod 2: inner hedef dongusu surer, yeni hedef secilmez
    private _opVar = _opMod > 0 && {!isNull _op};
    private _opOldu = { _opVar && {isNull _op || {!alive _op}} };
    private _kontrolKaybi = {
        if (!alive _uav) exitWith {};
        diag_log format ["[IHA-SORTI] %1 | OPERATOR OLDU (%2) -> KONTROL KAYBI: dron duser (yukseklik %3 m, %4 sn ucus)", typeOf _uav, ["", name _op] select (!isNull _op), round ((getPosATL _uav) select 2), round (time - _t0)];
        _uav setVariable [QGVAR(ihaTok), -1];
        _uav engineOn false;
        _uav setFuel 0;
        private _tD = time + 20;
        while {alive _uav && {((getPosATL _uav) select 2) > 1.2} && {time < _tD}} do {
            private _vv = velocity _uav;
            _uav setVelocity [(_vv select 0) * 0.92, (_vv select 1) * 0.92, ((_vv select 2) min -6)];
            sleep 0.1;
        };
        if (alive _uav) then {
            { _x setDamage 1; } forEach (crew _uav);
            _uav setDamage 1;
            diag_log format ["[IHA-SORTI] %1 | kontrolsuz dron yere carpti / imha edildi (%2)", typeOf _uav, mapGridPosition _uav];
        };
    };
    private _aktif = { alive _uav && {alive _d} && {(_uav getVariable [QGVAR(ihaTok), -1]) isEqualTo _tok} && {(time - _t0) < ([600, 1800] select (_tur isEqualTo "BOMBA"))} && {!(_opMod isEqualTo 1 && {call _opOldu})} };   // v8.348: BOMBA (Mavic 3) yenilenerek tekrar kullanilir, toplam 1800 sn
    private _merk = if (_merkez isEqualTo [0, 0, 0]) then {_bas} else {_merkez};

    // ---- GOZLEM: devriye ----
    if (_tur isEqualTo "GOZLEM") exitWith {
        _uav flyInHeight 120;
        while _aktif do {
            private _pt = _merk getPos [random _yar, random 360];
            _d doMove _pt;
            private _bit = time + 45;
            waitUntil { sleep 2; !(call _aktif) || {(_uav distance2D _pt) < 80} || {time > _bit} };
        };
        if (alive _uav && {_opMod > 0} && {call _opOldu}) then { call _kontrolKaybi; } else {
            if (alive _uav) then { _d doMove _bas; _uav land "LAND"; };
        };
        diag_log format ["[IHA-SORTI] %1 | gozlem devriyesi bitti (%2 sn)", typeOf _uav, round (time - _t0)];
    };

    // ---- hedef secimi ----
    private _bilinen = {
        params ["_t"];
        ((_uav knowsAbout _t) >= 0.3) || {((allGroups select {(side _x) isEqualTo _taraf && {!isNull leader _x}}) findIf {_x knowsAbout _t >= 0.4}) >= 0}
    };
    // v8.327 DUMAN (kullanici: 'IHA AI lar smokedan etkilensin, spot time olarak'): kilit suresi dolmadan dalis yok; duman hattı kesiyorsa kilit sifirlanir, 22 sn'de kilitlenemezse hedef 45 sn yasaklanir
    private _yasak = [];
    private _kilitGerek = missionNamespace getVariable ["lambs_danger_ihaKilitSure", 1.2];
    private _kilit = 0;
    private _dumanT0 = -1;
    private _kilitSon = time;
    private _kilitSonuc = {
        // 0 = devam (kilit tamam / duman kapali), 1 = bekle, 2 = vazgec
        private _sonuc = 0;
        if (!(missionNamespace getVariable ["lambs_danger_ihaDumanOff", false])) then {
            private _pr = [getPosASL _uav, (getPosASL _h) vectorAdd [0, 0, 1.2]] call FUNC(dumanPerde);
            private _dt = (time - _kilitSon) min 1;
            _kilitSon = time;
            if (_pr > 0) then {
                _kilit = 0;
                if (_dumanT0 < 0) then {
                    _dumanT0 = time;
                    diag_log format ["[IHA-DUMAN] %1 (%2) | hedef %3 %4 m: gorus hatti DUMANLA kesik (%5 bulut) -> kilitlenemiyor, bekliyor", typeOf _uav, _tur, typeOf _h, round (_uav distance2D _h), _pr];
                };
                _sonuc = [1, 2] select ((time - _dumanT0) > 22);
            } else {
                if (_dumanT0 >= 0) then {
                    diag_log format ["[IHA-DUMAN] %1 | duman acildi / hat temiz (%2 sn bekledi) -> kilit suresi basliyor", typeOf _uav, round (time - _dumanT0)];
                    _dumanT0 = -1;
                };
                _kilit = _kilit + _dt;
                // v8.344: gorus kotuyse (gece termalsiz, sis, kamufle hedef) kilit daha uzun surer
                if (_kilit < (_kilitGerek / ([_uav, _h] call FUNC(ihaGorus)))) then { _sonuc = 1; };
            };
        };
        _sonuc
    };
    // v8.344 GORUS: dron kamerasinin temel tespit menzili (m) x fnc_ihaGorus katsayisi (termal / isik / hava / hedef kamuflaji). Menzil disindaki hedef 'gorulmedi' sayilir (hedef secilmez; dron 10 sn sonra tekrar bakar).
    private _gorusM = missionNamespace getVariable ["lambs_danger_ihaGorusMenzil", 2500];
    private _hedefSec = {
        private _en = objNull;
        private _enS = -1e9;
        private _yasakNesne = (_yasak select {(_x select 1) > time}) apply {_x select 0};
        if (_tur isEqualTo "FPV-AT") then {
            {
                if (alive _x && {!(_x in _yasakNesne)} && {(_taraf getFriend (side (group (driver _x)))) < 0.6} && {((getNumber (configOf _x >> "armor")) >= 100) || {_x isKindOf "Tank"} || {_x isKindOf "APC_Tracked_01_base_F"}} && {(_x distance2D _bas) <= _men} && {[_x] call _bilinen} && {(_x distance2D _uav) <= (_gorusM * ([_uav, _x] call FUNC(ihaGorus)))}) then {
                    private _s = -(_x distance2D _uav);
                    if (_s > _enS) then { _enS = _s; _en = _x; };
                };
            } forEach (vehicles select {_x isKindOf "LandVehicle" && {!isNull (driver _x)}});
        } else {
            {
                if (alive _x && {!(_x in _yasakNesne)} && {isNull objectParent _x} && {(_taraf getFriend (side _x)) < 0.6} && {(side _x) isNotEqualTo civilian} && {(_x distance2D _bas) <= _men} && {[_x] call _bilinen} && {(_x distance2D _uav) <= (_gorusM * ([_uav, _x] call FUNC(ihaGorus)))}) then {
                    private _kume = {alive _x && {(side _x) isNotEqualTo civilian} && {(_taraf getFriend (side _x)) < 0.6}} count (_x nearEntities ["CAManBase", 15]);
                    private _s = _kume * 100 - (_x distance2D _uav) * 0.05;
                    if (_s > _enS) then { _enS = _s; _en = _x; };
                };
            } forEach (allUnits select {alive _x});
        };
        _en
    };

    // v8.278 SEYIR HIZLANDIRMA: AI pilot FULL hizda bile duruk / yavas kalabiliyor (RPT 21-10: seyir ~20 km/sa); hedefe dogru yatay hiz `lambs_danger_ihaSeyirHiz` (varsayilan 17 m/sn = ~61 km/sa) altindaysa
    //   hiz vektorune hedef yonunde kucuk ivme eklenir (0.1 sn adim, en cok +2 m/sn). Yon / yatis AI pilotta kalir (v8.273'teki betik-pilot catismasi olmasin diye setVectorDir YOK). 0 = kapali.
    private _seyirHizlan = {
        params ["_hedefO", "_sure"];
        private _sey = missionNamespace getVariable ["lambs_danger_ihaSeyirHiz", 22];
        private _tE = time + _sure;
        if (_sey <= 0) exitWith { sleep _sure };
        while {time < _tE && {call _aktif} && {alive _hedefO}} do {
            private _vel = velocity _uav;
            private _hs = sqrt (((_vel select 0) ^ 2) + ((_vel select 1) ^ 2));
            if (_hs < _sey && {((getPosATL _uav) select 2) > 3}) then {
                private _fk = (getPosASL _hedefO) vectorDiff (getPosASL _uav);
                private _fkXY = [_fk select 0, _fk select 1, 0];
                private _mg = vectorMagnitude _fkXY;
                if (_mg > 1) then {
                    _uav setVelocity (_vel vectorAdd ((_fkXY vectorMultiply (1 / _mg)) vectorMultiply (2 min (_sey - _hs))));
                };
            };
            sleep 0.1;
        };
    };

    // ---- SORTI ----
    private _bitti = false;
    private _bombaSorti = 1;
    // v8.348 MAVIC 3 TEKRAR KULLANIM (kullanici: 'mavic 3 tekrar kullanilabilir bir dron olsun, tanimli personelin yanina gidince cok basit bir animasyonla birakacagi patlayici yenilensin'):
    //   3 bomba bitince dron operatore (_op) / yoksa kalkis noktasina doner, 3 m'de asili kalir; personel basit bir animasyon (MedicStart -> MedicStop, ~6 sn) oynar, bombalar yenilenir (3'e), yeni hedef aranir.
    //   En cok CBA bombaSortiMax (4) sorti, toplam 1800 sn; operator olurse / personel yoksa yenilenmez (kalkis noktasina 40 m'den yakinsa personelsiz yenilenir). Kapatma: CBA bombaYenile.
    private _bombaYenile = {
        private _pers = if (!isNull _op && {alive _op}) then {_op} else {objNull};
        private _donus = if (!isNull _pers) then {getPosATL _pers} else {_bas};
        _uav flyInHeight 15;
        private _tOut = time + 150;
        waitUntil { _d doMove _donus; sleep 3; !(call _aktif) || {(_uav distance2D _donus) < 8} || {time > _tOut} };
        private _ok = (call _aktif) && {(_uav distance2D _donus) < 14};
        if (_ok) then {
            _uav flyInHeight 3;
            _d doMove _donus;
            sleep 3;
            if (isNull _pers) then { _pers = ((_donus nearEntities ["CAManBase", 25]) select {alive _x && {(side (group _x)) isEqualTo _taraf} && {isNull objectParent _x} && {!isPlayer _x}}) param [0, objNull]; };
            if (!isNull _pers) then {
                _pers doWatch _uav;
                _pers playActionNow "MedicStart";
                sleep 6;
                _pers playActionNow "MedicStop";
                _pers doWatch objNull;
            } else { sleep 4; };
            diag_log format ["[IHA-YENILE] %1 | BOMBA yenilendi: %2. sorti, personel %3 | toplam %4 sn", typeOf _uav, _bombaSorti + 1, if (isNull _pers) then {"yok (kalkis noktasi)"} else {name _pers}, round (time - _t0)];
            _uav flyInHeight 30;
        } else {
            diag_log format ["[IHA-YENILE] %1 | yenileme BASARISIZ (donus noktasina %2 m kaldi / sure)", typeOf _uav, round (_uav distance2D _donus)];
        };
        _ok
    };
    private _modMotor = _tur in ["FPV-AT", "FPV-AP"] && {!isNil "FPV_AI_Drones_fnc_fpvLogic"} && {missionNamespace getVariable ["lambs_danger_ihaModMotoru", true]};
    if (_modMotor) then { diag_log "[IHA-SORTI] FPV_AI_Drones modu bulundu: FPV son yaklasma / patlama MOD MOTORUYLA (kapatma: lambs_danger_ihaModMotoru = false)"; };
    while {(call _aktif) && {!_bitti}} do {
        if (_opMod isEqualTo 2 && {call _opOldu}) exitWith { diag_log format ["[IHA-SORTI] %1 | operator olu: hedef kilitli degil -> yeni hedef secilmiyor", typeOf _uav]; };
        private _h = call _hedefSec;
        // ---- v8.347 GOZCU + VURUCU (kullanici: 'eger 2 farkli dron giderse 1 dron izlesin, 2. ve 3. dronlar hedefi imha etsin, ilk giden dron hic gozunu uzerinden ayirmasin'; 'tamamen gercekci') ----
        //   Gercekte kesif dronu (Mavic vb.) hedefin ustunde KALIR, FPV'ler video / hedef bilgisiyle vurur. Ilk giden FPV, bekleyen baska FPV emri ya da sortideki baska FPV varsa GOZCU olur: hedefin 140 m cevresinde 70 m'de doner,
        //   dalmaz, hedef bilgisini takima yayar (lambs_danger_ihaTim_<taraf>). Sonrakiler VURUCU: gozcunun hedefine dalar, isabet olasiligi gozcu destegiyle artar. Vurucu hic gelmezse 110 sn sonra (ya da vurucular bitince 25 sn sonra)
        //   gozcu kendisi vurur (yedek). Kapatma CBA ihaTimAktif.
        private _rol = "BIREYSEL";
        private _timK = format ["lambs_danger_ihaTim_%1", _taraf];
        private _timSt = [];
        if (_tur in ["FPV-AT", "FPV-AP"] && {missionNamespace getVariable ["lambs_danger_ihaTimAktif", true]}) then {
            isNil {
                _timSt = missionNamespace getVariable [_timK, []];
                private _gAktif = _timSt isNotEqualTo [] && {alive (_timSt select 0)} && {(_timSt select 0) isNotEqualTo _uav} && {(time - (_timSt select 2)) < 30} && {alive (_timSt select 1)};
                if (_gAktif) then { _rol = "VURUCU"; } else {
                    private _bek = {(count _x) >= 5 && {!(_x select 1)} && {(_x select 3) isEqualTo _taraf} && {(_x select 2) in ["FPV-AT", "FPV-AP"]}} count (missionNamespace getVariable ["lambs_danger_ihaBekleEmirleri", []]);
                    private _dgr = {unitIsUAV _x && {alive _x} && {_x isNotEqualTo _uav} && {(_x getVariable [QGVAR(ihaTok), -1]) >= 0} && {(_x getVariable [QGVAR(ihaGorevTur), ""]) in ["FPV-AT", "FPV-AP"]} && {(side (group (driver _x))) isEqualTo _taraf}} count vehicles;
                    if ((_bek + _dgr) >= 1 && {!isNull _h}) then { _rol = "GOZCU"; missionNamespace setVariable [_timK, [_uav, _h, time, 0]]; };
                };
            };
        };
        if (_rol isEqualTo "VURUCU" && {isNull _h || {(_timSt select 1) isNotEqualTo _h}}) then { _h = _timSt select 1; };
        if (isNull _h) then { sleep 10; continue };
        _uav setVariable [QGVAR(ihaRol), _rol];
        if (_rol isNotEqualTo "BIREYSEL") then { diag_log format ["[IHA-TIM] %1 (%2) | ROL: %3 | hedef %4 (%5) | takim: %6", typeOf _uav, _tur, _rol, typeOf _h, mapGridPosition _h, _taraf]; };
        if (_rol isEqualTo "GOZCU") then {
            _uav flyInHeight 70;
            private _gT0 = time;
            private _aci = random 360;
            private _vurucuGordu = false;
            private _sonVurucu = time;
            while {(call _aktif) && {alive _h} && {(time - _gT0) < 300}} do {
                _aci = _aci + 25;
                _d doMove ((getPosATL _h) getPos [140, _aci]);
                missionNamespace setVariable [_timK, [_uav, _h, time, 0]];
                private _vur = vehicles select {unitIsUAV _x && {alive _x} && {(_x getVariable [QGVAR(ihaRol), ""]) isEqualTo "VURUCU"} && {(side (group (driver _x))) isEqualTo _taraf}};
                if (_vur isNotEqualTo []) then { _vurucuGordu = true; _sonVurucu = time; };
                if (!_vurucuGordu && {(time - _gT0) > 110}) exitWith { _rol = "BIREYSEL"; };
                if (_vurucuGordu && {(time - _sonVurucu) > 25}) exitWith { _rol = "BIREYSEL"; };
                sleep 3;
            };
            missionNamespace setVariable [_timK, []];
            _uav setVariable [QGVAR(ihaRol), ""];
            if (_rol isEqualTo "GOZCU") then {
                diag_log format ["[IHA-TIM] %1 | gozcu gorevi bitti (hedef %2 / sure %3 sn)", typeOf _uav, ["OLDU", "SAG"] select (alive _h), round (time - _gT0)];
                continue
            };
            diag_log format ["[IHA-TIM] %1 | gozcu -> BIREYSEL (yedek): %2 sn, vurucu %3", typeOf _uav, round (time - _gT0), ["hic gelmedi", "bitti"] select _vurucuGordu];
            _uav flyInHeight ([40, 30] select (_tur isEqualTo "BOMBA"));
        };
        diag_log format ["[IHA-SORTI] %1 (%2) | hedef %3 (%4) | %5 m", typeOf _uav, _tur, typeOf _h, mapGridPosition _h, round (_uav distance2D _h)];
        _uav flyInHeight ([40, 30] select (_tur isEqualTo "BOMBA"));
        private _birakildi = 0;
        private _sonBirak = -99;
        private _dalis = false;
        private _dalisT0 = 0;
        private _dalisLogT = 0;
        _kilit = 0; _dumanT0 = -1; _kilitSon = time;
        private _sapma = [0, 0, 0];
        private _perdeT = 0;
        private _isKarar = false;
        while {(call _aktif) && {alive _h} && {!_bitti}} do {
            private _dist = _uav distance2D _h;
            if (_tur isEqualTo "BOMBA") then {
                _d doMove (getPosATL _h);
                if (_dist < 12 && {(time - _sonBirak) > 6} && {_birakildi < 3}) then {
                    _sonBirak = time;
                    _birakildi = _birakildi + 1;
                    private _g = createVehicle ["GrenadeHand", (getPosATL _uav) vectorAdd [0, 0, -0.8], [], 0, "CAN_COLLIDE"];
                    _g setVelocity [0, 0, 0];
                    diag_log format ["[IHA-SORTI] %1 | bomba %2/3 birakildi (hedefe %3 m)", typeOf _uav, _birakildi, round _dist];
                };
                if (_birakildi >= 3 && {(time - _sonBirak) > 8}) then {
                    if ((missionNamespace getVariable ["lambs_danger_bombaYenile", true]) && {_bombaSorti < (missionNamespace getVariable ["lambs_danger_bombaSortiMax", 4])} && {call _bombaYenile}) then {
                        _bombaSorti = _bombaSorti + 1;
                        _birakildi = 0;
                        _h = objNull;   // ic dongu biter, dis dongu yeni hedef secer
                    } else { _bitti = true; };
                };
                sleep 1;
            } else {
                if (_modMotor) then {
                    // v8.234 HIBRIT (slavkovsky77/Arma3-AI-FPV-Drones incelemesi): hedefi BIZ secer (bilinen, oncelikli) ve 180 m'ye kadar goturuz; son yaklasma / dalis / patlama modun test edilmis motorunda (Crocus'a ozgu tuhafliklar: bos arac, dalis, patlama yaricapi, takilma)
                    if (_dist > 180) then {
                        _d doMove (getPosATL _h);
                        [_h, 2] call _seyirHizlan;
                    } else {
                        private _ks = call _kilitSonuc;
                        if (_ks isEqualTo 1) then { _d doMove (getPosATL _uav); sleep 0.3; continue };
                        if (_ks isEqualTo 2) then {
                            _yasak pushBack [_h, time + 45];
                            diag_log format ["[IHA-DUMAN] %1 | hedef %2 icin kilit alinamadi (duman, 22 sn): hedef 45 sn birakildi", typeOf _uav, typeOf _h];
                            _h = objNull;
                            continue
                        };
                        private _kinds = if (_tur isEqualTo "FPV-AT") then {["LandVehicle", "Car", "Tank"]} else {["Man"]};
                        private _src = ["allUnits", "vehicles"] select (_tur isEqualTo "FPV-AT");
                        _uav setVariable ["FPV_AI_Drones_managed", true, true];
                        _uav setVariable ["initialized", false];
                        diag_log format ["[IHA-SORTI] %1 (%2) | hedef %3 %4 m: son yaklasma MOD MOTORUNA (FPV_AI_Drones_fnc_fpvLogic) devredildi", typeOf _uav, _tur, typeOf _h, round _dist];
                        [_uav, _kinds, _src,
                            [30, 10] select (_tur isEqualTo "FPV-AT"), [8, 3] select (_tur isEqualTo "FPV-AT"), [8, 5] select (_tur isEqualTo "FPV-AT"),
                            _tur isEqualTo "FPV-AT", ["DemoCharge_Remote_Ammo", "SatchelCharge_Remote_Ammo"] select (_tur isEqualTo "FPV-AT"),
                            250, 0.25, 15, 0.1, 5, 40, false] spawn (missionNamespace getVariable "FPV_AI_Drones_fnc_fpvLogic");
                        private _modBit = time + 90;
                        waitUntil { sleep 1; isNull _uav || {!alive _uav} || {!alive _h} || {time > _modBit} || {!(call _aktif)} };
                        diag_log format ["[IHA-SORTI] %1 | mod motoru bitti: IHA %2, hedef %3 (%4 sn)", _tur, ["YOK / patladi", "hala var"] select (!isNull _uav && {alive _uav}), ["OLDU", "SAG"] select (alive _h), round (time - _t0)];
                        _bitti = !(_opMod isEqualTo 1 && {call _opOldu} && {alive _uav});   // v8.268: operator olunce mod motoru bitirdiyse kontrol kaybi isleyicisi calissin
                    };
                } else {
                if (_dist > 220 && {!_dalis}) then {
                    _d doMove (getPosATL _h);
                    [_h, 2] call _seyirHizlan;
                } else {
                    if (!_dalis) then {
                        private _ks = call _kilitSonuc;
                        if (_ks isEqualTo 1) then { _d doMove (getPosATL _uav); sleep 0.3; continue };
                        if (_ks isEqualTo 2) then {
                            _yasak pushBack [_h, time + 45];
                            diag_log format ["[IHA-DUMAN] %1 | hedef %2 icin kilit alinamadi (duman, 22 sn): hedef 45 sn birakildi", typeOf _uav, typeOf _h];
                            _h = objNull;
                            continue
                        };
                    };
                    // v8.273 DALIS DUZELTMESI (kullanici: 'tam dalacakken havada glitchleniyor, kamikaze calismiyor'): dalis basinda AI pilotun otopilotu (irtifa 40 m + doMove) betik hiziyla SAVASIYORDU
                    //   (ani 28 m/s hiz atamasi + setVectorDir [yatis sifirlanir] her 0.1 sn). Simdi: dalis baslarken pilotun MOVE / PATH'i kapanir (doStop), hiz 8 m/s'den 28 m/s'ye 1.2 sn'de yumusakca artar,
                    //   yon setVectorDirAndUp ile (yatis sabit) 0.05 sn adimla; 5 m'de patlar. Dalis hedef olunce / iptal olunca pilot geri acilir. Log: [IHA-DALIS]
                    if (!_dalis) then {
                        _dalis = true;
                        _dalisT0 = time;
                        _d disableAI "MOVE";
                        _d disableAI "PATH";
                        doStop _d;
                        diag_log format ["[IHA-DALIS] %1 (%2) | dalis basladi: hedef %3 | mesafe %4 m | irtifa %5 m | hiz %6 km/s | AI pilot MOVE / PATH kapatildi", typeOf _uav, _tur, typeOf _h, round _dist, round ((getPosATL _uav) select 2), round (speed _uav)];
                    };
                    // v8.347 GERCEKCI ISABET (kullanici: 'tamamen gercekci; AI dron isabet oranini cok kisabilirsin'): FPV her dalista %100 vurmaz. Olasilik = taban (AT 0.45 / AP 0.50) x CBA ihaIsabetOrani; VURUCU rolunde gozcu videosu +0.20,
                    //   tek basina x0.85; hedef hizli (> 25 km/s) x0.7; yatik / comelmis piyade x0.8; gorus katsayisi (isik / hava / kamuflaj) x(0.6 + 0.4 f); en cok 0.90. Iskalarsa 6-18 m sapma ile yanindan gecip patlar.
                    //   Ayrica elektronik harp / link kaybi: dalis basinda %8 (x CBA ihaEWOrani) kontrol kaybi (dusme). Mod motoru yolu etkilenmez. Log [IHA-ISABET].
                    if (!_isKarar) then {
                        _isKarar = true;
                        private _gor = [_uav, _h] call FUNC(ihaGorus);
                        private _p = ([0.45, 0.5] select (_tur isEqualTo "FPV-AP")) * (missionNamespace getVariable ["lambs_danger_ihaIsabetOrani", 1]);
                        _p = if (_rol isEqualTo "VURUCU") then { _p + 0.2 } else { _p * 0.85 };
                        if ((speed _h) > 25) then { _p = _p * 0.7; };
                        if (_h isKindOf "CAManBase" && {(stance _h) in ["PRONE", "CROUCH"]}) then { _p = _p * 0.8; };
                        _p = (_p * (0.6 + 0.4 * _gor)) min 0.9;
                        private _ew = random 1 < (0.08 * (missionNamespace getVariable ["lambs_danger_ihaEWOrani", 1]));
                        private _iska = !_ew && {random 1 > _p};
                        diag_log format ["[IHA-ISABET] %1 (%2, rol %3) | hedef %4 %5 m | olasilik %6 (gorus %7) | sonuc: %8", typeOf _uav, _tur, _rol, typeOf _h, round _dist, _p toFixed 2, _gor toFixed 2, ["ISABET SANSI TUTTU", "ISKA (sapma)", "EW / LINK KAYBI"] select ([0, 1, 2] select ((parseNumber _iska) + (2 * (parseNumber _ew))) )];
                        if (_ew) then {
                            _bitti = true;
                            call _kontrolKaybi;
                        } else {
                            if (_iska && {_sapma isEqualTo [0, 0, 0]}) then {
                                private _sa = random 360;
                                private _sm = 6 + random 12;
                                _sapma = [(sin _sa) * _sm, (cos _sa) * _sm, 0];
                            };
                        };
                    };
                    if (time > _perdeT) then {
                        _perdeT = time + 0.4;
                        if (_sapma isEqualTo [0, 0, 0] && {!(missionNamespace getVariable ["lambs_danger_ihaDumanOff", false])} && {([getPosASL _uav, (getPosASL _h) vectorAdd [0, 0, 1.2]] call FUNC(dumanPerde)) > 0}) then {
                            private _sa = random 360;
                            private _sm = 7 + random 5;
                            _sapma = [(sin _sa) * _sm, (cos _sa) * _sm, 0];
                            diag_log format ["[IHA-DUMAN] %1 | dalista hedef dumana girdi: kor dalis, %2 m sapma", typeOf _uav, round _sm];
                        };
                    };
                    private _hedefP = ((getPosASL _h) vectorAdd [0, 0, 1.2]) vectorAdd _sapma;
                    private _fark = _hedefP vectorDiff (getPosASL _uav);
                    private _mag = (vectorMagnitude _fark) max 0.1;
                    private _yonV = _fark vectorMultiply (1 / _mag);
                    private _hz = 8 + (((missionNamespace getVariable ["lambs_danger_ihaDalisHiz", 32]) - 8) * (((time - _dalisT0) / 1.2) min 1));
                    _uav setVectorDirAndUp [_yonV, [0, 0, 1]];
                    _uav setVelocity (_yonV vectorMultiply _hz);
                    if (time > _dalisLogT) then {
                        _dalisLogT = time + 1;
                        diag_log format ["[IHA-DALIS] %1 | mesafe %2 m | hiz ayar %3 m/s gercek %4 m/s | irtifa %5 m | %6 sn", typeOf _uav, round _mag, _hz toFixed 1, round (speed _uav / 3.6), round ((getPosATL _uav) select 2), (time - _dalisT0) toFixed 1];
                    };
                    if (_mag < 5) then {
                        private _am = ["R_PG32V_F", "R_TBG32V_F"] select (_tur isEqualTo "FPV-AP");
                        // v8.329 GERCEK CARPMA (kullanici: 'tanklarin zirhi cok guclu'; RPT 40d48a79: 3 / 3 FPV-AT vurusunda tank hasari +0.00, hicbir parca > 0.3): eskiden harbi dronun 5 m yakininda havada triggerAmmo ile patlatiyorduk = yalniz
                        //   sicrama; ACE araç hasari (bilesen sistemi) mermi carpmasi ister. AT icin: dalis yonunde govde yuzeyi bulunur (lineIntersectsSurfaces), harbi yuzeyin 0.5 m onunde hedefe dogru 180 m/sn ile yaratilir -> GERCEK carpma; 0.4 sn'de patlamadiysa triggerAmmo.
                        //   Duman sapmasi varsa (iskaladi) ya da FPV-AP: eski yol (havada patlatma). Kapatma: lambs_danger_ihaGercekCarpmaOff = true. Log [IHA-ETKI].
                        private _gercek = _tur isEqualTo "FPV-AT" && {_sapma isEqualTo [0, 0, 0]} && {alive _h} && {!(missionNamespace getVariable ["lambs_danger_ihaGercekCarpmaOff", false])};
                        private _w = objNull;
                        private _ipNot = "havada patlatma";
                        if (_gercek) then {
                            private _bas = getPosASL _uav;
                            private _ip = [];
                            {
                                if ((_x select 2) isEqualTo _h || {(_x select 3) isEqualTo _h}) exitWith { _ip = _x select 0; };
                            } forEach (lineIntersectsSurfaces [_bas, _bas vectorAdd (_yonV vectorMultiply 9), _uav, objNull, true, 4, "FIRE", "GEOM"]);
                            _ipNot = "govde yuzeyi";
                            if (_ip isEqualTo []) then { _ip = (getPosASL _h) vectorAdd [0, 0, 1.2]; _ipNot = "hedef merkezi (yuzey bulunamadi)"; };
                            private _bp = _ip vectorAdd (_yonV vectorMultiply -0.5);
                            _w = createVehicle [_am, ASLToAGL _bp, [], 0, "CAN_COLLIDE"];
                            _w setPosASL _bp;
                            _w setVectorDir _yonV;
                            _w setVelocity (_yonV vectorMultiply 180);
                            [_w, _h, _am] spawn {
                                params ["_ww", "_hh", "_aa"];
                                sleep 0.4;
                                if (!isNull _ww) then { triggerAmmo _ww; };
                                sleep 1.3;
                                if (!isNull _hh) then {
                                    (getAllHitPointsDamage _hh) params [["_ad", []], "_sec", ["_dg", []]];
                                    private _hs = [];
                                    { if ((_dg select _forEachIndex) > 0.3) then { _hs pushBack format ["%1=%2", _x, (_dg select _forEachIndex) toFixed 2]; }; } forEach _ad;
                                    diag_log format ["[IHA-ETKI] %1 <- %2 | toplam hasar %3 | canMove %4 canFire %5 | yasiyor %6 | parcalar >0.3: %7", typeOf _hh, _aa, (damage _hh) toFixed 2, canMove _hh, canFire _hh, alive _hh, _hs];
                                };
                            };
                        } else {
                            _w = createVehicle [_am, getPosATL _uav, [], 0, "CAN_COLLIDE"];
                            _w setPosASL (getPosASL _uav);
                            triggerAmmo _w;
                        };
                        diag_log format ["[IHA-SORTI] %1 (%2) | HEDEFE VURDU: %3 (%4) | %5 sn ucus | dalis %6 sn | yontem: %7", typeOf _uav, _tur, typeOf _h, _am, round (time - _t0), (time - _dalisT0) toFixed 1, _ipNot];
                        _bitti = true;
                        sleep 0.3;
                        { deleteVehicle _x; } forEach (crew _uav);
                        deleteVehicle _uav;
                    } else { sleep 0.05; };
                };
                };
            };
        };
        // v8.273: dalis hedef olunce / iptal olunca (hedef baskasi tarafindan vuruldu, operator, sure) AI pilot geri acilir
        // v8.279 HATA DUZELTMESI (RPT 21-10 21:53: '[IHA-DALIS] dalis basladi ... hiz ayar 8.0 m/s ... 0.0 sn' her adimda tekrarlandi, 1493 log satiri, dalis hep 8 m/s = 29 km/sa): bu blok DONGUNUN ICINDEYDI ve ilk dalis adimindan hemen sonra
        //   dalisi iptal edip _dalisT0'i sifirliyordu; hiz rampasi (8 -> 28 m/sn) hic ilerlemiyordu. Artik yalniz dongu BITINCE (hedef oldu / iptal) calisir.
        if (_dalis && {alive _uav} && {!_bitti}) then {
            _dalis = false;
            _d enableAI "MOVE";
            _d enableAI "PATH";
            diag_log format ["[IHA-DALIS] %1 | dalis kesildi (hedef %2 / aktif %3): AI pilot geri acildi", typeOf _uav, ["OLDU", "SAG"] select (alive _h), call _aktif];
        };
    };
    if (!_bitti && {alive _uav} && {_opMod > 0} && {call _opOldu}) then { call _kontrolKaybi; } else {
        if (!_bitti && {alive _uav}) then {
            diag_log format ["[IHA-SORTI] %1 | gorev bitti (sure %2 sn, hedef yok / dusurulmus): geri donuyor", typeOf _uav, round (time - _t0)];
        };
    };
    if (_bitti && {alive _uav} && {_tur isEqualTo "BOMBA"}) then { _d doMove _bas; _uav land "LAND"; };
};
true

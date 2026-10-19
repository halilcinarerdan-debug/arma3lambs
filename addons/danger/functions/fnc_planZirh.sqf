#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * PLAN ZIRH DESTEK (v8.163) — kullanici: "tank mevzilenmedi, aptal gibi bekledi; tankta hala tik yok; piyadeler combata gecti tank awarede; secim ekraninda sadece piyade vardi".
 * Zeus 'ELITE Objektif' elle secimde secilen TANK / zirhli grup (lider kara aracinda, tasima kapasitesi yok ya da Tank) plan hashinde 'zirhG' olur ve bu fonksiyon plan dongusunde HER TURDA cagrilir:
 *   KUR / TOPLAN / TASIMA / RECON : bekler (piyade toplanir)
 *   ORP ve sonrasi (KESIF / SALDIRI / TOPLANMA / CEKILME / MEVZI / BEKLE): BIR KEZ ates pozisyonu secer (SBF'ye yakin, objektife 380-680 m, su / bina / sik agac disi, objektife gorus hatti VAR (VIEW / FIRE LOD),
 *     yol disi tercih, 500 m'ye yakin tercih) -> surucuye doMove (COMBAT, NORMAL); varinca doStop + tum murettebat objektife doWatch.
 *   Savas modu: KESIF / SALDIRI / TOPLANMA, ya da plan piyadesinden biri temasta -> COMBAT + combatMode RED; degilse COMBAT + YELLOW. Gunner objektif cevresinde BILINEN dusmani (900 m icinde) hedef alir (6 sn'de bir).
 *   Plan biterse (BITTI / IPTAL) serbest birakilir: planAktif silinir, AWARE + YELLOW + doWatch bos.
 * aracSenkron bu gruplari atlar (lambs_danger_planZirh): piyadeyi beklemek icin tankin forceSpeed 0 alinmasi engellenir. Log: [PLAN-ZIRH].
 *
 * Arguments:
 * 0: Plan <HASHMAP>
 *
 * Return Value: None
 * Public: No
*/

params ["_plan"];
private _zg = (_plan getOrDefault ["zirhG", []]) select {!isNull _x};
if (_zg isEqualTo []) exitWith {};
private _id = _plan get "id";
private _faz = _plan get "faz";
private _obj = _plan get "obj";
private _sbf = _plan get "sbf";

// ---- serbest birak ----
if (_faz in ["BITTI", "IPTAL"]) exitWith {
    {
        private _g = _x;
        if (_g getVariable ["lambs_danger_planZirh", false]) then {
            _g setVariable ["lambs_danger_planZirh", nil];
            _g setVariable ["lambs_danger_planZirhPoz", nil];
            _g setVariable ["lambs_danger_planZirhVardi", nil];
            _g setVariable ["lambs_danger_planZirhHide", nil];
            _g setVariable ["lambs_danger_planAktif", nil, true];
            _g setBehaviour "AWARE";
            _g setCombatMode "YELLOW";
            { _x doWatch objNull; } forEach (units _g);
            // v8.257: mevzi kilidi (surucu MOVE kapali) plan bitince acilir
            { private _dv = driver (vehicle _x); if (!isNull _dv && {_dv isNotEqualTo _x || {!isNull objectParent _x}}) then { _dv enableAI "MOVE"; _dv enableAI "PATH"; }; } forEach (units _g);
            _g setVariable ["lambs_danger_planZirhKilit", nil];
            _g setVariable ["lambs_danger_planZirhCapa", nil];
            diag_log format ["[PLAN-ZIRH] %1 | %2 serbest birakildi (plan %3)", _id, groupId _g, _faz];
        };
    } forEach _zg;
};

// v8.178: DONUS fazinda (HQ'ya donus) zirh destek gruplari komuta dongusunun emrinde: ates pozisyonunu tekrar atamaz
if (_faz isEqualTo "DONUS") exitWith {};
// v8.180: tank / zirh destek TOPLAN / TASIMA / RECON fazlarinda da hemen ates pozisyonuna gider (kullanici: "tanklar kipirdamiyor"; piyadeyi beklemez, destek mevzisi saldiriden ONCE kurulur); yalniz plan KUR asamasinda bekler
if (_faz isEqualTo "KUR") exitWith {};

private _piyadeTemas = ((_plan getOrDefault ["gruplar", []]) findIf {((_x getVariable ["lambs_danger_contact", 0]) > time)}) >= 0;
private _savas = (_faz in ["KESIF", "SALDIRI", "TOPLANMA", "CEKILME"]) || {_piyadeTemas};

{
    private _g = _x;
    if (!local _g || {({alive _x} count (units _g)) isEqualTo 0}) then { continue };
    private _l = leader _g;
    private _v = vehicle _l;
    // v8.252: lider YAYAYSA (murettebat indi, lider disarida kaldi; RPT f39a5919 'yayan kaldi, tank ilerledi') grubun aracli bir uyesinin araci kullanilir (eskiden grup komple atlaniyor, arac plan emri almiyordu)
    if (_v isEqualTo _l) then {
        private _au = (units _g) findIf {alive _x && {!isNull objectParent _x} && {(vehicle _x) isKindOf "LandVehicle"}};
        if (_au >= 0) then { _v = vehicle ((units _g) select _au); };
    };
    if (_v isEqualTo _l || {!alive _v}) then { continue };
    private _d = driver _v;
    if (isNull _d || {isPlayer _d}) then { continue };
    // v8.175 TANK ROLU: kargosuz tank uzaktan agir ates destegi (650 m, SALDIRI'da 450 m'ye sicrar), hedef onceligi zirh > AT > MG; ates acik alana gelince objektif alanina bastirma atesi (dost 70 m disinda)
    private _tankMi = (([_v] call FUNC(aracSinif)) select 0) isEqualTo "TANK";
    // v8.250: AT yetenegi olmayan arac (tank degil, ATGM yok) bilinen dusman tankindan kacarken (fnc_aracZirhKac) planZirh ona hedef / hareket emri vermez
    if (!_tankMi && {(time - (_v getVariable ["lambs_danger_zirhKacT", -999])) < 10}) then { continue };
    private _atYeterli = _tankMi || {([_v] call FUNC(aracSinif)) select 3};
    // v8.244 SAVUNMA MEVZISI (ATP 3-20.15 4-46..4-49, 4-69..4-78; kullanici: 'tank savunma mevzisi'): savunma planinda (tip 1) tank/IFV objektifin ONUNDE 650 m degil, piyade hattinin icinde / arkasinda
    //   (objektife 70-260 m) tehdit yonune bakan, gövde-asagi (hull-down) birincil mevziye yerlesir; tehdit yaklasana kadar birincil mevzinin 55 m ARKASINDAKI gizleme noktasinda bekler (4-76/4-77).
    //   Mesafeler TASARIM degeri (kitapta sayi YOK). Kapatma: lambs_danger_tankMevziOff = true (eski ileri ates pozisyonu).
    private _savunma = ((_plan getOrDefault ["tip", 0]) isEqualTo 1) && {!(missionNamespace getVariable ["lambs_danger_tankMevziOff", false])};
    _g setVariable ["lambs_danger_planZirh", true];
    _g setVariable ["lambs_danger_planAktif", true, true];

    // v8.174 ZIRH DOKTRINI (MCWP 3-11.1 s. 6-36: arac / zirh piyade temizledikce ileri sicrar ve etkili destegi surdurur): SALDIRI basinda ates pozisyonu bir kez 350 m civarina ilerletilir
    if (_faz isEqualTo "SALDIRI" && {!(_g getVariable ["lambs_danger_planZirhYakin", false])}) then {
        _g setVariable ["lambs_danger_planZirhYakin", true];
        _g setVariable ["lambs_danger_planZirhPoz", []];
        _g setVariable ["lambs_danger_planZirhVardi", nil];
        diag_log format ["[PLAN-ZIRH] %1 | %2 SALDIRI basladi: ates pozisyonu piyadeyle karsilikli destek icin ileri sicrayacak (~350 m)", _id, groupId _g];
    };
    // v8.174 CEKILME: zirh ates ederek RALLY POINT'e doner (piyade ile bulusma); ates pozisyonunda kalmaz
    if (_faz isEqualTo "CEKILME") then {
        if !(_g getVariable ["lambs_danger_planZirhCek", false]) then {
            _g setVariable ["lambs_danger_planZirhCek", true];
            _g setVariable ["lambs_danger_planZirhVardi", nil];
            private _rpP = (_plan get "rp") getPos [12 * (_forEachIndex + 1), (_plan get "B") + 90];
            _g setVariable ["lambs_danger_planZirhPoz", _rpP];
            _g setVariable ["lambs_danger_planZirhT", time];
            _g setBehaviour "COMBAT"; _g setCombatMode "RED"; _g setSpeedMode "FULL";
            _d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1;
            _d doMove _rpP;
            diag_log format ["[PLAN-ZIRH] %1 | %2 CEKILME: rally point'e donuyor (%3 m) - ates ederek", _id, groupId _g, round (_v distance2D _rpP)];
        };
    };
    private _yk = _g getVariable ["lambs_danger_planZirhYakin", false];
    private _merkezD = if (_savunma) then {[150, 110] select _tankMi} else { if (_tankMi) then {[650, 450] select _yk} else {[500, 350] select _yk} };
    // ---- ates pozisyonu (bir kez) ----
    private _poz = _g getVariable ["lambs_danger_planZirhPoz", []];
    if (_poz isEqualTo []) then {
        private _yon = _obj getDir _sbf;
        if (_savunma) then {
            // tehdit yonu: bilinen dusmanlarin agirlik merkezi > Zeus 'tehdit yonu' > SBF yonu
            private _tb = _plan getOrDefault ["tehditB", -1];
            if (_tb >= 0) then { _yon = _tb; };
            private _bil = (_l nearTargets 2000) select {((side _g) getFriend (_x select 2)) < 0.6 && {(_l knowsAbout (_x select 4)) > 0.3} && {alive (_x select 4)} && {[_x select 4] call FUNC(gercekHedef)}};
            if (_bil isNotEqualTo []) then {
                private _bx = 0; private _by = 0;
                { _bx = _bx + ((_x select 0) select 0); _by = _by + ((_x select 0) select 1); } forEach _bil;
                _yon = _obj getDir [_bx / (count _bil), _by / (count _bil)];
            };
        };
        private _bakNokta = _obj getPos [700, _yon];
        private _en = [];
        private _enS = -1e9;
        private _adaylar = [];
        {
            private _dist = _x;
            {
                private _a = _x;
                private _p = _obj getPos [_dist, _yon + _a];
                // v8.256: savunmada tank mevzisi piyade hendek alanlarinin <= 25 m'sine konmaz (RPT e31bd8bd: tank hendek alaninin icinde durdu, piyade 'dost arac' kurali ile hendekten itildi, tank ates cekince hendek hedef oldu)
                if (!surfaceIsWater _p && {(nearestObjects [_p, ["House"], 10]) isEqualTo []} && {(count (nearestTerrainObjects [_p, ["TREE"], 12])) < 4} && {((_plan getOrDefault ["zirhPozlar", []]) findIf {(_x distance2D _p) < 70}) < 0} && {!_savunma || {(["EN-YAKIN", _p, 25, sideUnknown] call FUNC(hendekAlani)) isEqualTo []}}) then {
                    private _e1 = (AGLToASL [_p select 0, _p select 1, 0]) vectorAdd [0, 0, 2.4];
                    private _e2 = (AGLToASL [([_obj, _bakNokta] select _savunma) select 0, ([_obj, _bakNokta] select _savunma) select 1, 0]) vectorAdd [0, 0, 1.5];
                    private _gor = (lineIntersectsSurfaces [_e1, _e2, objNull, objNull, true, 1, "VIEW", "FIRE"]) isEqualTo [];
                    private _s = [0, 100] select _gor;
                    // v8.194 HULL-DOWN (ATP 3-20.15 3-76: koruma / gizlenme + engelsiz gozlem + acik ates alani): taret yuksekliginden hedef gorunur AMA govde yuksekliginden (1.0 m) gorunmez = hull-down
                    if (_gor && {_tankMi}) then {
                        private _eH = (AGLToASL [_p select 0, _p select 1, 0]) vectorAdd [0, 0, 1.0];
                        if ((lineIntersectsSurfaces [_eH, _e2, objNull, objNull, true, 1, "VIEW", "FIRE"]) isNotEqualTo []) then { _s = _s + 25; };
                    };
                    _s = _s - (abs (_dist - _merkezD)) / 10 - (abs _a) * 0.2;
                    if (isOnRoad _p) then { _s = _s - 5; };
                    _adaylar pushBack [_s, _p];
                    if (_s > _enS) then { _enS = _s; _en = _p; };
                };
            } forEach [0, 15, -15, 30, -30, 45, -45, 60, -60];
        } forEach (if (_savunma) then {[150, 110, 190, 70, 230, 260]} else { if (_tankMi) then {[[650, 600, 700, 550, 750, 800, 500, 450], [450, 400, 500, 350, 550, 600, 300]] select _yk} else {[[500, 450, 550, 400, 600, 650], [350, 300, 400, 330, 380, 450]] select _yk} });
        if (_en isEqualTo []) then { _en = _obj getPos [_merkezD, _yon]; };
        // v8.194 YEDEK MEVZI (ATP 3-20.15 3-76: birincil ve yedek mevzi arasinda yer degistirerek kesin cati engagement'tan kacinir): en iyi mevziden >= 60 m uzakta en yuksek puanli aday
        private _alt = [];
        private _altS = -1e9;
        { if ((_x select 1) distance2D _en >= 60 && {(_x select 0) > _altS}) then { _altS = _x select 0; _alt = _x select 1; }; } forEach _adaylar;
        _g setVariable ["lambs_danger_planZirhAlt", _alt];
        _poz = _en;
        _g setVariable ["lambs_danger_planZirhBak", [_obj, _bakNokta] select _savunma];
        if (_savunma) then {
            // birincil mevzi = _en; arac once 55 m GERIDEKI gizleme noktasina gider, tetikte (dusman <= 1500 m bilinen / piyade temasi) birincile cikar
            _g setVariable ["lambs_danger_planZirhAsil", _en];
            _g setVariable ["lambs_danger_planZirhHide", true];
            private _hidePt = _en getPos [55, _yon + 180];
            if (surfaceIsWater _hidePt) then { _hidePt = _en; };
            (_plan getOrDefault ["zirhPozlar", []]) pushBack _en;
            _plan set ["zirhPozlar", _plan getOrDefault ["zirhPozlar", []]];
            _poz = _hidePt;
            diag_log format ["[PLAN-ZIRH] %1 | %2 SAVUNMA MEVZISI: birincil %3 (objektife %4 m, tehdit yonu %5), gizleme noktasi %6 (55 m geride), alternatif %7", _id, groupId _g, mapGridPosition _en, round (_en distance2D _obj), round _yon, mapGridPosition _hidePt, if (_alt isEqualTo []) then {"yok"} else {mapGridPosition _alt}];
        } else {
            (_plan getOrDefault ["zirhPozlar", []]) pushBack _poz;
        };   // v8.180: zirh araclari ayni noktaya yigilmaz (>= 70 m aralik)
        _plan set ["zirhPozlar", _plan getOrDefault ["zirhPozlar", []]];
        _g setVariable ["lambs_danger_planZirhPoz", _poz];
        _g setVariable ["lambs_danger_planZirhT", time];
        _g setVariable ["lambs_danger_planZirhMax", (240 max (((_v distance2D _poz) / 2.2) min 900))];   // v8.187: zaman asimi mesafeye gore (RPT 95be8b53: tank 1089 m kala 240 sn dolunca "mevzide" sayildi)
        _g setBehaviour "COMBAT";
        _g setCombatMode "YELLOW";
        _g setSpeedMode "NORMAL";
        _d enableAI "PATH"; _d enableAI "MOVE";
        _d forceSpeed -1;
        _d doMove _poz;
        diag_log format ["[PLAN-ZIRH] %1 | %2 | %3 -> ates pozisyonu %4 (objektife %5 m, gorus hatti %6, SBF'den %7 m) | faz %8",
            _id, groupId _g, getText (configOf _v >> "displayName"), mapGridPosition _poz, round (_poz distance2D _obj), _enS >= 50, round (_poz distance2D _sbf), _faz];
    };

    // ---- v8.244 SAVUNMA: gizleme noktasindan birincil mevziye cikis (tetik: dusman <= 1500 m bilinen ya da plan piyadesi temasta ya da savas fazi) ----
    if (_savunma && {_g getVariable ["lambs_danger_planZirhHide", false]} && {(time - (_g getVariable ["lambs_danger_planZirhTetikT", -999])) > 3}) then {
        _g setVariable ["lambs_danger_planZirhTetikT", time];
        private _tetik = _savas || {((_l nearTargets 1500) findIf {((side _g) getFriend (_x select 2)) < 0.6 && {(_l knowsAbout (_x select 4)) > 0.3} && {alive (_x select 4)} && {[_x select 4] call FUNC(gercekHedef)}}) >= 0};
        if (_tetik) then {
            private _asil = _g getVariable ["lambs_danger_planZirhAsil", _poz];
            _g setVariable ["lambs_danger_planZirhHide", false];
            _g setVariable ["lambs_danger_planZirhPoz", _asil];
            _g setVariable ["lambs_danger_planZirhVardi", nil];
            _g setVariable ["lambs_danger_planZirhT", time];
            _g setVariable ["lambs_danger_planZirhMax", 120];
            _poz = _asil;
            _g setBehaviour "COMBAT";
            _d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1;
            _d doMove _poz;
            diag_log format ["[PLAN-ZIRH] %1 | %2 TETIK: gizleme noktasindan birincil mevziye cikiyor (%3 m) | piyade temasi %4 | faz %5", _id, groupId _g, round (_v distance2D _poz), _piyadeTemas, _faz];
        };
    };

    // ---- varis ----
    private _vardi = _g getVariable ["lambs_danger_planZirhVardi", false];
    if (!_vardi && {((_v distance2D _poz) < 40) || {(time - (_g getVariable ["lambs_danger_planZirhT", time])) > (_g getVariable ["lambs_danger_planZirhMax", 240])}}) then {
        _vardi = true;
        _g setVariable ["lambs_danger_planZirhVardi", true];
        doStop _d;
        // v8.257 MEVZI KILIDI (RPT e31bd8bd + 10-18: tankin nisancisine planZirh 'doTarget / doFire' verince MOTOR 'ATTACK' komutuyla hedefe SURDU: durdu=48 sn hiz=21 surucu_komut=ATTACK beklenen_hedef=dusman konumu; 'vardi' bayragi kalinca
        //   tank mevziden 100-300 m ilerledi): ates pozisyonuna varinca surucunun MOVE'u kapanir; yeni hareket emri (TETIK / YER DEGISTIR / AT tepkisi / CEKILME / TAKILDI) 'enableAI MOVE' ile acar. Kapatma: lambs_danger_tankKilitOff = true.
        if (!(missionNamespace getVariable ["lambs_danger_tankKilitOff", false])) then {
            _d disableAI "MOVE";
            _g setVariable ["lambs_danger_planZirhKilit", true];
            diag_log format ["[PLAN-ZIRH] %1 | %2 mevzide: surucu MOVE KAPALI (nisancinin doFire'i araci ileri surmesin; hareket emri gelince acilir)", _id, groupId _g];
        };
        { _x doWatch (_g getVariable ["lambs_danger_planZirhBak", _obj]); } forEach (crew _v);
        diag_log format ["[PLAN-ZIRH] %1 | %2 mevzide%3 (%4 m kalan) | objektife %5 m", _id, groupId _g, [""," (GIZLEME NOKTASI)"] select (_g getVariable ["lambs_danger_planZirhHide", false]), round (_v distance2D _poz), round (_v distance2D _obj)];
    } else {
      // v8.251: AT atesi drilinde (fnc_aracAtTepki) yer degistiren arac 20 sn planZirh'in yeniden yonlendirme / takilma emirlerinden muaf
      if ((time - (_v getVariable ["lambs_danger_tankManevraT", -999])) > 20) then {
        // yoldayken yeniden yonlendirme (takilmasin)
        if (!_vardi && {(time - (_g getVariable ["lambs_danger_planZirhMoveT", -999])) > 20}) then {
            _g setVariable ["lambs_danger_planZirhMoveT", time];
            // v8.243 SURUCU EMRI ONARIMI (RPT c7592408: planZirh BTR'leri 'komut GET OUT' ile 2+ dk 0 km/s bekledi; nakil iptali / inis sirasinda surucunun arac atamasi kalkmis olabilir - NEDEN KESIN DEGIL):
            //   surucu emri GET OUT ya da arac atamasi yoksa once arac surucu olarak yeniden atanir, yoksa (aracin disindaysa, 30 m icinde) bindirilir. Log [PLAN-ZIRH] ... SURUCU EMRI ONARILDI (ilk 3). Kapatma: lambs_danger_zirhSurucuOnarOff = true.
            if (!(missionNamespace getVariable ["lambs_danger_zirhSurucuOnarOff", false]) && {alive _d} && {((currentCommand _d) isEqualTo "GET OUT") || {isNull (assignedVehicle _d)} || {(vehicle _d) isNotEqualTo _v}}) then {
                private _onN = _g getVariable ["lambs_danger_zirhOnarN", 0];
                if (_onN < 3) then {
                    _g setVariable ["lambs_danger_zirhOnarN", _onN + 1];
                    diag_log format ["[PLAN-ZIRH] %1 | %2 SURUCU EMRI ONARILDI: komut '%3' atama %4 aracta %5 motor %6 canMove %7 hiz %8 km/s", _id, groupId _g, currentCommand _d, typeOf (assignedVehicle _d), (vehicle _d) isEqualTo _v, isEngineOn _v, canMove _v, round (speed _v)];
                };
                if ((vehicle _d) isEqualTo _v) then { _d assignAsDriver _v; } else { if ((_d distance2D _v) < 30) then { _d assignAsDriver _v; [_d] orderGetIn true; }; };
                _d enableAI "PATH"; _d enableAI "MOVE";
            };
            _d doMove _poz;
        };
        // v8.189 YOL YURUYUSU: temas yokken ve pozisyona > 700 m varken SAFE + FULL (COMBAT / NORMAL tanki 15 km/s'te yuruyordu: RPT aee29fdd tank 4 dk'da 700 m); yaklasinca COMBAT
        if (!_vardi) then {
            private _uzak = (_v distance2D _poz) > 700 && {!_savas} && {_faz in ["TOPLAN", "RECON", "TASIMA", "KUR", "ORP"]};
            if (_uzak isNotEqualTo (_g getVariable ["lambs_danger_planZirhYol", false])) then {
                _g setVariable ["lambs_danger_planZirhYol", _uzak];
                if (_uzak) then { _g setBehaviour "SAFE"; _g setSpeedMode "FULL"; } else { _g setBehaviour "COMBAT"; _g setSpeedMode "NORMAL"; };
                _d forceSpeed -1;
                diag_log format ["[PLAN-ZIRH] %1 | %2 yol yuruyusu %3 (pozisyona %4 m)", _id, groupId _g, ["KAPALI: COMBAT / NORMAL", "ACIK: SAFE / FULL"] select _uzak, round (_v distance2D _poz)];
            };
            // takilma: 25 sn'den uzun < 1.5 km/s ise 220 m'lik (yola oturtulmus, +-50 derece) ara noktaya yonlendirilir
            if ((speed _v) < 1.5) then {
                if ((_g getVariable ["lambs_danger_planZirhDurT", -1]) < 0) then { _g setVariable ["lambs_danger_planZirhDurT", time]; };
                // v8.257: hareket edemeyen (canMove false) ya da murettebat bekleyen tank 'takildi' sayilmaz; ara nokta mesafesi hedefe kalan mesafenin %60'ini asmaz (RPT e31bd8bd: pozisyona 84 m kalmisken 240 m'lik ara nokta)
                if ((time - (_g getVariable ["lambs_danger_planZirhDurT", time])) > 25 && {(_v distance2D _poz) > 80} && {canMove _v} && {(_v getVariable ["lambs_danger_murBekleT0", -1]) < 0}) then {
                    _g setVariable ["lambs_danger_planZirhDurT", time];
                    private _ara = (getPosATL _v) getPos [(220 min (0.6 * (_v distance2D _poz))), ((getPosATL _v) getDir _poz) + (selectRandom [-50, 50, -25, 25])];
                    private _yl = _ara nearRoads 120;
                    if (_yl isNotEqualTo []) then { _ara = getPosATL (_yl select 0); };
                    if (surfaceIsWater _ara) then { _ara = _poz; };
                    // v8.191: 2. kez takildiysa kaldir + 25 m tasi (RPT bda5fbde: IFV 17 dk ayni konumda, ara nokta emri islemedi)
                    private _tkN = (_g getVariable ["lambs_danger_planZirhTakN", 0]) + 1;
                    _g setVariable ["lambs_danger_planZirhTakN", _tkN];
                    if (_tkN >= 2) then {
                        _v setVectorUp [0, 0, 1];
                        _v setPosATL ((getPosATL _v) vectorAdd [0, 0, 0.8]);
                        if (_tkN >= 3) then { _v setVehiclePosition [(getPosATL _v) getPos [25, (getPosATL _v) getDir _poz], [], 0, "NONE"]; };
                    };
                    _d action ["EngineOn", _v];
                    _d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1;
                    _d doMove _ara;
                    diag_log format ["[PLAN-ZIRH] %1 | %2 TAKILDI (<1.5 km/s, 25 sn): ara noktaya yonlendirildi (%3 m) | pozisyona %4 m | surucu komut '%5' atama %6 motor %7 canMove %8 yakit %9", _id, groupId _g, round (_v distance2D _ara), round (_v distance2D _poz), currentCommand _d, typeOf (assignedVehicle _d), isEngineOn _v, canMove _v, (fuel _v) toFixed 2];
                };
            } else { _g setVariable ["lambs_danger_planZirhDurT", -1]; };
        };
      };
    };

    // ---- v8.194 YER DEGISTIR: mevzideki tank hasar aldiysa (>= 0.08) yedek mevziye gecer (60 sn'de en fazla bir kez; eski mevzi yeni yedek olur)
    if (_vardi && {_tankMi} && {_savas}) then {
        private _hs0 = _g getVariable ["lambs_danger_planZirhHasar", -1];
        if (_hs0 < 0) then { _g setVariable ["lambs_danger_planZirhHasar", damage _v]; _hs0 = damage _v; };
        private _alt2 = _g getVariable ["lambs_danger_planZirhAlt", []];
        if ((damage _v) >= (_hs0 + 0.08) && {_alt2 isNotEqualTo []} && {(time - (_g getVariable ["lambs_danger_planZirhYerT", -999])) > 60} && {(time - (_v getVariable ["lambs_danger_tankManevraT", -999])) > 20}) then {
            _g setVariable ["lambs_danger_planZirhYerT", time];
            _g setVariable ["lambs_danger_planZirhAlt", _poz];
            _g setVariable ["lambs_danger_planZirhPoz", _alt2];
            _g setVariable ["lambs_danger_planZirhVardi", nil];
            _g setVariable ["lambs_danger_planZirhT", time];
            _g setVariable ["lambs_danger_planZirhMax", 120];
            _g setVariable ["lambs_danger_planZirhHasar", damage _v];
            _d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1;
            _d doMove _alt2;
            diag_log format ["[PLAN-ZIRH] %1 | %2 YER DEGISTIRIYOR: hasar %3 -> yedek mevzi %4 (%5 m)", _id, groupId _g, (damage _v) toFixed 2, mapGridPosition _alt2, round (_v distance2D _alt2)];
        };
    };

    // ---- v8.187 GRUBUN DIGER ARACLARI (RPT 95be8b53: 2 tankli grupta ikinci tank hic kipirdamadi - yalniz lider aracin surucusu komut aliyordu): her arac poz'a 45 m yanal aralikla gider, varinca durup objektife bakar ----
    private _digerAr = [];
    { private _xv = vehicle _x; if (_xv isNotEqualTo _x && {_xv isNotEqualTo _v} && {alive _xv}) then { _digerAr pushBackUnique _xv; }; } forEach (units _g);
    {
        private _ov = _x;
        private _od = driver _ov;
        if (!isNull _od && {!isPlayer _od} && {local _od} && {(time - (_ov getVariable ["lambs_danger_planZirhOvT", -999])) > 20}) then {
            _ov setVariable ["lambs_danger_planZirhOvT", time];
            private _op = _poz getPos [45 * (_forEachIndex + 1), (_obj getDir _poz) + 90];
            if (surfaceIsWater _op) then { _op = _poz; };
            if ((_ov distance2D _op) > 35) then {
                (group _od) setVariable ["lambs_danger_planZirh", true];
                _od enableAI "PATH"; _od enableAI "MOVE"; _od forceSpeed -1;
                _od action ["EngineOn", _ov];
                _od doMove _op;
            } else {
                doStop _od;
                if (!(missionNamespace getVariable ["lambs_danger_tankKilitOff", false])) then { _od disableAI "MOVE"; };
                { _x doWatch _obj; } forEach (crew _ov);
            };
        };
    } forEach _digerAr;

    // ---- savas modu ----
    private _modu = ["YELLOW", "RED"] select _savas;
    if ((_g getVariable ["lambs_danger_planZirhMod", ""]) isNotEqualTo _modu) then {
        _g setVariable ["lambs_danger_planZirhMod", _modu];
        _g setBehaviour "COMBAT";
        _g setCombatMode _modu;
        _d enableAI "AUTOCOMBAT";
        diag_log format ["[PLAN-ZIRH] %1 | %2 COMBAT / %3 (faz %4, piyade temasi %5)", _id, groupId _g, _modu, _faz, _piyadeTemas];
    };

    // ---- hedef: objektif cevresinde BILINEN dusman ----
    if ((_vardi || {_faz isEqualTo "CEKILME"}) && {_savas} && {(time - (_g getVariable ["lambs_danger_planZirhHedefT", -999])) > 6}) then {
        _g setVariable ["lambs_danger_planZirhHedefT", time];
        // v8.198 SAVUNMA TANKI (kullanici: "dusman tanki karsilik vermedi"; RPT 9f47fa43: savunan T-55 635 m'de mevzide COMBAT / RED, hic atis yok - saldiranlar objektife 550 m'de indi, 450 m filtresinin disinda): savunma planinda tankin KENDI menzilindeki (1100 m) bilinen dusman da hedeftir (esik 0.3)
        private _sav = (_plan getOrDefault ["tip", 0]) isEqualTo 1;
        private _hedefler = (_l nearTargets 1300) select {((side _g) getFriend (_x select 2)) < 0.6 && {(((_x select 0) distance2D _obj) < 450) || {_sav && {((_x select 0) distance2D _v) < 1100}}} && {(_l knowsAbout (_x select 4)) > ([0.5, 0.3] select _sav)} && {[_x select 4] call FUNC(gercekHedef)} && {_atYeterli || {!((_x select 4) isKindOf "Tank" && {(getNumber (configOf (_x select 4) >> "armor")) >= 300})}}};
        if (_hedefler isNotEqualTo []) then {
            _hedefler = [_hedefler, [], {(_x select 3)}, "DESCEND"] call BIS_fnc_sortBy;
            // v8.251 TANK HEDEF DAGITIMI (ATP 3-20.15 A-4 / A-5 ates kontrolu): tank icin tehdit onceligi + ates dagitimi (fnc_tankHedefSec); kapatma lambs_danger_tankHedefDagitOff
            private _dagit = _tankMi && {!(missionNamespace getVariable ["lambs_danger_tankHedefDagitOff", false])};
            private _hdE = if (_dagit) then { [_v, _hedefler] call FUNC(tankHedefSec) } else { [] };
            private _hd = if (_hdE isEqualTo []) then { (_hedefler select 0) select 4 } else { _hdE select 0 };
            if (!isNull _hd) then {
                if ((time - (_g getVariable ["lambs_danger_planZirhHedefLogT", -999])) > 20) then {
                    _g setVariable ["lambs_danger_planZirhHedefLogT", time];
                    diag_log format ["[PLAN-ZIRH] %1 | %2 HEDEF: %3 (%4 m, tank -> hedef) | savunma %5 | dagitim puani %6", _id, groupId _g, typeOf _hd, round (_v distance2D _hd), _sav, if (_hdE isEqualTo []) then {"-"} else {round (_hdE select 1)}];
                };
                private _gn = gunner _v;
                if (!isNull _gn) then { _gn doTarget _hd; _gn doFire _hd; };
                {
                    private _g2 = gunner _x;
                    if (!isNull _g2) then {
                        private _ho = _hd;
                        if (_dagit) then { private _hx = [_x, _hedefler] call FUNC(tankHedefSec); if (_hx isNotEqualTo []) then { _ho = _hx select 0; }; };
                        _g2 doTarget _ho; _g2 doFire _ho;
                    };
                } forEach _digerAr;
            };
        };
    };

    // ---- TANK: bilinen hedef yoksa objektif alanina bastirma atesi (dost piyade 70 m disinda), 12 sn'de bir ----
    if (_tankMi && {_vardi} && {_savas} && {_faz in ["SALDIRI", "KESIF", "TOPLANMA"]} && {(time - (_g getVariable ["lambs_danger_planZirhBasT", -999])) > 12}) then {
        _g setVariable ["lambs_danger_planZirhBasT", time];
        private _dost = (_obj nearEntities ["CAManBase", 70]) select {(side group _x) isEqualTo (side _g)};
        private _gn2 = gunner _v;
        if (_dost isEqualTo [] && {!isNull _gn2} && {alive _gn2}) then {
            _gn2 doSuppressiveFire (_obj getPos [random 25, random 360]);
        };
    };
} forEach _zg;

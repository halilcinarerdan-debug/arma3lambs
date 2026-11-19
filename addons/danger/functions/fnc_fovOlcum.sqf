#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * FOV / ALGI KAYNAGI OLCUMU (v8.669; v8.684'te mesafe kovalari + kaynak ayrimi eklendi; kullanici: 'askerlerin fovlarini gercekci hale getirmeyi de ekle' -> ONCE OLC, sonra karar; 'cqbde algi azaltici her sey kapaniyor, o yuzden mi'):
 * DAVRANIS DEGISTIRMEZ, yalniz RPT'ye sayi yazar.
 *
 * SORU 1: AI, bakmadigi yondeki (yan / arka) dusmani da bakiyormus gibi ayni oranda biliyor mu? Insan: net merkezi gorus dar (~+-30 derece), cevresel gorus ~+-100-120 derece, arka kor;
 *   Arma AI'sinda sert bir gorus konisi yok, 'knowsAbout' mesafe / gorunurluk / isik ile artar.
 * SORU 2 (v8.684): 'bilen' oran yuksekse NEDEN? Aday kaynaklar: (a) yakin mesafede kamuflaj / spot azaltici katmanlarin kapanmasi (fnc_yakinAlgi, CBA yakinAlgiM, varsayilan 20 m);
 *   (b) SES (dusman son 6 sn'de ates etti); (c) GRUP PAYLASIMI (grup arkadasi dusmani onde / gorus hattinda goruyor ve biliyor); (d) aciklanamayan (hicbiri: motor / 360 derece algi).
 * YONTEM (3 sn'de bir; en cok 25 asker): grubu temasli (60 sn) yerel AI piyade -> en yakin dusman (15-250 m) -> bakis acisi = |goz yonu (eyeDirection) ile dusman yonu arasi aci|;
 *   gorus hatti ACIK (arazi + nesne) ciftler MESAFE kovasina (<= yakinAlgiM: azaltici katmanlar KAPALI / yakinAlgiM-60 m / 60-250 m) ve ACI kovasina (0-30 / 30-60 / 60-90 / 90-120 / 120-180) sayilir;
 *   'bilen' = knowsAbout >= SUPHE (0.5). Arka yarida (aci >= 90) bilen ciftler kaynaga ayrilir: SES > GRUP > YAKIN (azaltici kapali) > ACIKLANAMAYAN (oncelik sirasi).
 *   Ek olarak ornek askerlerin camouflageCoef dagilimi (en dusuk / <= 0.05 sayisi) yazilir.
 * YORUM: yakin kovada arka yari ~%100 ama uzak kovalarda dusuyorsa -> neden azaltici katmanlarin yakinda kapanmasi (kullanicinin hipotezi); her mesafede ~%100 ve 'aciklanamayan' agirlikliysa -> kaynak motor algisi.
 *   Karar (FOV uygulansin mi, hangi daralma): bu olcumden sonra.
 * CBA: lambs_danger_fovOlcum (acik / kapali). Log: [FOV-OLCUM] 60 sn ozeti (en az 20 cift varsa).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_fovOlcumStarted") exitWith {false};
lambs_danger_fovOlcumStarted = true;

diag_log "[FOV-OLCUM] FOV / algi kaynagi olcumu (aci x mesafe kovalari, arka yari kaynak ayrimi, camouflageCoef dagilimi; davranis degistirmez) baslatildi (v8.684)";

[] spawn {
    private _aKova = [[0, 30], [30, 60], [60, 90], [90, 120], [120, 181]];
    // sayac matrisi: [mesafe kovasi 0..2][aci kovasi 0..4] -> [cift, bilen(suphe), bilen(tespit)]
    private _yeniM = { [0, 1, 2] apply { _aKova apply { [0, 0, 0] } } };
    private _m = call _yeniM;
    // arka yari (aci >= 90) bilen cift kaynaklari: [ses, grup, yakin, aciklanamayan]; mesafe kovasi basina
    private _kaynak = [0, 1, 2] apply { [0, 0, 0, 0] };
    private _arkaTop = [0, 1, 2] apply { 0 };
    private _kcMin = 9;
    private _kcAz = 0;
    private _kcSay = 0;
    private _ozetT = time + 60;
    while {true} do {
        sleep 3;
        if !(missionNamespace getVariable ["lambs_danger_fovOlcum", true]) then { continue };
        private _e1 = ["SUPHE"] call FUNC(bilgiEsik);
        private _e2 = ["TESPIT"] call FUNC(bilgiEsik);
        private _yM = (missionNamespace getVariable ["lambs_danger_yakinAlgiM", 20]) max 5;
        private _k = 0;
        {
            private _u = _x;
            if (_k >= 25) exitWith {};
            if (
                !local _u || {isPlayer _u} || {!alive _u} || {!isNull objectParent _u} || {!((lifeState _u) in ["HEALTHY", "INJURED"])}
                || {captive _u} || {(insideBuilding _u) > 0.5} || {((group _u) getVariable [QGVAR(contact), 0]) < (time - 60)}
            ) then { continue };
            private _e = _u findNearestEnemy _u;
            if (isNull _e || {!alive _e} || {!(_e isKindOf "CAManBase")}) then { continue };
            private _d = _u distance2D _e;
            if (_d < 12 || {_d > 250}) then { continue };
            private _eye = eyePos _u;
            private _eEye = eyePos _e;
            if ((terrainIntersectASL [_eye, _eEye]) || {lineIntersects [_eye, _eEye, _u, _e]}) then { continue };
            _k = _k + 1;
            private _kc = _u getUnitTrait "camouflageCoef";
            _kcSay = _kcSay + 1;
            _kcMin = _kcMin min _kc;
            if (_kc <= 0.05) then { _kcAz = _kcAz + 1; };
            private _ed = eyeDirection _u;
            private _gaz = (_ed select 0) atan2 (_ed select 1);
            private _ang = abs ((((_u getDir _e) - _gaz) + 540) mod 360 - 180);
            private _ai = _aKova findIf { _ang >= (_x select 0) && {_ang < (_x select 1)} };
            if (_ai < 0) then { continue };
            private _mi = if (_d <= _yM) then {0} else { if (_d <= 60) then {1} else {2} };
            private _kn = _u knowsAbout _e;
            private _h = (_m select _mi) select _ai;
            _h set [0, (_h select 0) + 1];
            if (_kn >= _e1) then { _h set [1, (_h select 1) + 1]; };
            if (_kn >= _e2) then { _h set [2, (_h select 2) + 1]; };
            // arka yarida bilen cift: kaynagi ayir
            if (_ang >= 90 && {_kn >= _e1}) then {
                _arkaTop set [_mi, (_arkaTop select _mi) + 1];
                private _src = 3;
                if ((time - (_e getVariable [QGVAR(sonAtisT), -999])) < 6) then { _src = 0; } else {
                    private _grup = (units group _u) findIf {
                        _x isNotEqualTo _u && {alive _x} && {(_x knowsAbout _e) >= _e1}
                        && {(abs ((((_x getDir _e) - (((eyeDirection _x) select 0) atan2 ((eyeDirection _x) select 1))) + 540) mod 360 - 180)) < 70}
                        && {!(terrainIntersectASL [eyePos _x, _eEye])} && {!(lineIntersects [eyePos _x, _eEye, _x, _e])}
                    };
                    if (_grup >= 0) then { _src = 1; } else { if (_mi isEqualTo 0) then { _src = 2; }; };
                };
                private _kk = _kaynak select _mi;
                _kk set [_src, (_kk select _src) + 1];
            };
        } forEach allUnits;
        if (time > _ozetT) then {
            _ozetT = time + 60;
            private _top = 0;
            { { _top = _top + (_x select 0); } forEach _x; } forEach _m;
            if (_top >= 20) then {
                private _mAd = [format ["<= %1 m (azaltici katmanlar KAPALI)", round _yM], format ["%1-60 m", round _yM], "60-250 m"];
                private _sat = [];
                {
                    private _mi = _forEachIndex;
                    private _satir = [];
                    private _c = 0;
                    {
                        private _n = _x select 0;
                        _c = _c + _n;
                        _satir pushBack format ["%1-%2: %3 cift %4 %%", (_aKova select _forEachIndex) select 0, ((_aKova select _forEachIndex) select 1) min 180, _n, (if (_n > 0) then { round (100 * (_x select 1) / _n) } else { 0 })];
                    } forEach _x;
                    private _kk = _kaynak select _mi;
                    private _at = _arkaTop select _mi;
                    _sat pushBack format ["MESAFE %1 (toplam %2): %3 | ARKA YARI (>= 90 derece) bilen %4: ses %5 / grup %6 / yakin %7 / aciklanamayan %8", _mAd select _mi, _c, _satir joinString ", ", _at, _kk select 0, _kk select 1, _kk select 2, _kk select 3];
                } forEach _m;
                diag_log format ["[FOV-OLCUM] 60 sn (hatti acik dusman 12-250 m; bilen = suphe esigi): %1", _sat joinString " || "];
                diag_log format ["[FOV-OLCUM-KAMUFLAJ] 60 sn: ornek %1 | camouflageCoef en dusuk %2 | <= 0.05 olan ornek %3", _kcSay, _kcMin toFixed 2, _kcAz];
            };
            _m = call _yeniM;
            _kaynak = [0, 1, 2] apply { [0, 0, 0, 0] };
            _arkaTop = [0, 1, 2] apply { 0 };
            _kcMin = 9; _kcAz = 0; _kcSay = 0;
        };
    };
};
true

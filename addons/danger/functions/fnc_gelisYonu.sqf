#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DUSMAN GELIS YONLERI (v8.573; kullanici: 'eger dusman spotlandiysa dusmanin gelebilecegi yonlere baksinlar, eger gorus acilari yoksa kapilar yollar').
 * Grup lideri bilinen (knowsAbout >= SEZILDI), <= 400 m dusman biliyorsa; boştaki (hareketsiz, hedefini GORMEYEN, emri / taktik kilidi / tedavi / yukleme yok) AI askerler 12 sn'de bir gozunu su sirayla yonlendirir:
 *   1) DUSMAN YONUNDE ACIK GORUS varsa (+-45 derece, fnc_bakisAcikYon 60 / 25 m) o yone;
 *   2) yoksa GELIS YOLLARI: <= 70 m'deki YOL parcalari (dusman yonune +-110 derece, 8-70 m, goz hizasinda gorus hatti acik) ve <= 30 m'deki binanin KAPILARI / CIKISLARI (buildingExit; dusman yonune +-120 derece, <= 35 m);
 *      ayni aday en cok 2 askere (dagilim: farkli gelis yollarini farkli askerler izler); en kucuk aci farkli aday once;
 *   3) o da yoksa 8 yonde 15 m isinla EN ACIK yon (>= 4.5 m).
 *   ARKA GOZCU ENTEGRASYONU (v8.573; kullanici: 'bu arkayi tutan gozcu ile entegre olsun'): fnc_rearGuard'in arka guvenlik askeri aktifse ONA ayni aday bulucu ARKA sektorde (dusman yonunun tersi) uygulanir ve sonuc birim degiskeni
 *      gelisArkaPoz / gelisArkaT (15 sn) olarak yayinlanir; fnc_rearGuard bakisini (doWatch + istasyon bakis noktasi) bundan alir. Rol istasyonlu (stationPos) askerler ve arka gozcu normal dongude atlanir.
 *   Dusman bilgisi yoksa (grup temassiz / unutuldu) izleme birakilir (doWatch objNull). Hedefini gorerek ugrasan, hareket eden, taktikte (bounding / geri cekilme / kacis / hucum) olan grup / asker atlanir; oyunculu grup, disableGroupAI /
 *   senaryo kapisi (LAMBS gorevi / kal-bekle waypoint) atlanir. CBA gelisYonu. Log: [GELIS-YONU] (ilk 20) + 60 sn ozeti.
 * SINIR: baska bakis yazicilari (sektorBakis, tehditBakis, roleStation) ayni askere doWatch verebilir (12 sn'lik sabit bakis, sonra yeniden); kapi / yol adayi dusmanin GERCEKTEN geldigi yol degil, yone gore tahmindir.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_gelisYonuStarted") exitWith {false};
lambs_danger_gelisYonuStarted = true;
diag_log "[GELIS-YONU] dusman gelis yonu bakisi (acik gorus / yol / kapi) baslatildi (v8.573)";

[] spawn {
    private _logN = 0;
    private _say = [0, 0, 0, 0, 0];   // [asker, yol, kapi, acik gorus, en acik yon]
    private _ozetT = time + 60;
    private _acF = { params ["_a", "_b"]; abs ((((_a - _b) + 540) mod 360) - 180) };
    // aday bulucu: [asker, dusman yonu, dolu haritasi] -> [hedef konum, tur] ([] = yok)
    private _adayBul = {
        params ["_u", "_teta", "_dolu"];
        private _eyeU = eyePos _u;
        private _hedef = [];
        private _tur = "";
        // 1) dusman yonunde acik gorus
        private _ay = [_u, _teta, [0, 20, -20, 40, -40], [60, 25]] call FUNC(bakisAcikYon);
        if (_ay > -900 && {([_ay, _teta] call _acF) <= 45}) then { _hedef = (getPosATL _u) getPos [40, _ay]; _tur = "ACIK GORUS"; _say set [3, (_say select 3) + 1]; };
        // 2) gelis yollari: yol / kapi
        if (_hedef isEqualTo []) then {
            private _ad = [];
            {
                private _p = getPosATL _x;
                private _f = [_u getDir _p, _teta] call _acF;
                private _dm = _u distance2D _p;
                if (_f <= 110 && {_dm >= 8} && {_dm <= 70} && {!(lineIntersects [_eyeU, (AGLToASL _p) vectorAdd [0, 0, 1.5], _u, objNull])}) then { _ad pushBack [_f, _p, "YOL"]; };
            } forEach (_u nearRoads 70);
            private _bn = nearestBuilding _u;
            if (!isNull _bn && {(_u distance _bn) <= 30}) then {
                for "_k" from 0 to 5 do {
                    private _px = _bn buildingExit _k;
                    if (_px isEqualType [] && {(count _px) >= 2} && {_px isNotEqualTo [0, 0, 0]}) then {
                        private _f = [_u getDir _px, _teta] call _acF;
                        private _dm = _u distance2D _px;
                        if (_f <= 120 && {_dm <= 35}) then { _ad pushBack [_f, _px, "KAPI"]; };
                    };
                };
            };
            _ad sort true;
            {
                _x params ["_f", "_p", "_t"];
                private _key = format ["%1_%2", round ((_p select 0) / 8), round ((_p select 1) / 8)];
                if ((_dolu getOrDefault [_key, 0]) < 2) exitWith {
                    _dolu set [_key, (_dolu getOrDefault [_key, 0]) + 1];
                    _hedef = _p;
                    _tur = _t;
                    _say set [[1, 2] select (_t isEqualTo "KAPI"), (_say select ([1, 2] select (_t isEqualTo "KAPI"))) + 1];
                };
            } forEach _ad;
        };
        // 3) en acik yon
        if (_hedef isEqualTo []) then {
            private _eb = -1;
            private _ebS = 4.5;
            for "_ky" from 0 to 7 do {
                private _yy = _ky * 45;
                private _pp = _eyeU vectorAdd [(sin _yy) * 15, (cos _yy) * 15, 0];
                private _vv = lineIntersectsSurfaces [_eyeU, _pp, _u, objNull, true, 1, "VIEW", "NONE"];
                private _mm = if (_vv isEqualTo []) then {15} else { _eyeU distance ((_vv select 0) select 0) };
                private _skor = _mm - (([_yy, _teta] call _acF) * 0.05);
                if (_mm > 4.5 && {_skor > _ebS}) then { _ebS = _skor; _eb = _yy; };
            };
            if (_eb >= 0) then { _hedef = (getPosATL _u) getPos [40, _eb]; _tur = "EN ACIK YON"; _say set [4, (_say select 4) + 1]; };
        };
        [_hedef, _tur]
    };
    while {true} do {
        sleep ([3] call FUNC(dusunSure));
        private _acik = missionNamespace getVariable ["lambs_danger_gelisYonu", true];
        private _butce = 6;
        {
            if (_butce <= 0) exitWith {};
            private _g = _x;
            if (isNull _g || {!local _g} || {(count (units _g)) < 2} || {(side _g) isEqualTo civilian}) then { continue };
            if (time < (_g getVariable [QGVAR(gelisGT), 0])) then { continue };
            if (((units _g) findIf {isPlayer _x}) > -1 || {_g getVariable [QGVAR(disableGroupAI), false]}) then { continue };
            private _l = leader _g;
            if (isNull _l || {!alive _l} || {isPlayer _l}) then { continue };
            private _e = if (_acik) then { _l findNearestEnemy _l } else { objNull };
            private _bilgi = !isNull _e && {alive _e} && {!([_e] call FUNC(teslimMi))} && {(_l distance2D _e) <= 400} && {(_l knowsAbout _e) >= (["SEZILDI"] call FUNC(bilgiEsik))};
            if (!_bilgi) then {
                // izleme birak
                { if ((_x getVariable [QGVAR(gelisBakT), 0]) > 0) then { _x setVariable [QGVAR(gelisBakT), 0]; if (alive _x && {local _x}) then { _x doWatch objNull; }; }; } forEach (units _g);
                _g setVariable [QGVAR(gelisGT), time + 5];
                continue
            };
            if ([_g, "gelisYonu", true] call FUNC(senaryoKapi)) then { continue };
            if (
                (_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]}
                || {_g getVariable [QGVAR(isBounding), false]} || {_g getVariable [QGVAR(isExecutingTactic), false]} || {_g getVariable [QGVAR(isATEngage), false]}
            ) then { continue };
            _g setVariable [QGVAR(gelisGT), time + 6];
            _butce = _butce - 1;
            private _hf = _l getHideFrom _e;
            private _ePos = if (_hf isEqualTo [] || {_hf isEqualTo [0, 0, 0]} || {((_hf distance2D _e) > 150)}) then { getPosATL _e } else { _hf };
            // ARKA GOZCU ENTEGRASYONU (fnc_rearGuard 'arkayi tutan gozcu'): gozcu aktifse onu arka sektorde (dusman yonunun tersi) ayni aday bulucuyla (acik gorus / yol / kapi) yonlendir; sonucu birim degiskenine yayinla (rearGuard okur)
            private _rg = _g getVariable [QGVAR(rearGuardU), objNull];
            private _rgAktif = !isNull _rg && {alive _rg} && {local _rg} && {(time - (_g getVariable [QGVAR(rearAktifT), -999])) < 20};
            if (_rgAktif && {time >= (_rg getVariable [QGVAR(gelisArkaT), 0]) - 3}) then {
                private _arkaB = (_l getDir _ePos) + 180;
                private _snA = [_rg, _arkaB, createHashMap] call _adayBul;
                if ((_snA select 0) isNotEqualTo []) then {
                    _rg setVariable [QGVAR(gelisArkaPoz), _snA select 0];
                    _rg setVariable [QGVAR(gelisArkaT), time + 15];
                    if (_logN < 20) then {
                        _logN = _logN + 1;
                        diag_log format ["[GELIS-YONU] %1 %2 | ARKA GOZCU %3 | arka yon %4 derece | %5 -> bakis yonu %6 derece (%7 m)", str (side _g), groupId _g, name _rg, round _arkaB, _snA select 1, round (_rg getDir (_snA select 0)), round (_rg distance2D (_snA select 0))];
                    };
                };
            };
            private _bosta = (units _g) select {
                alive _x && {local _x} && {!isPlayer _x} && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {(speed _x) < 1}
                && {(_x getVariable [QGVAR(forceMove), false]) isNotEqualTo true} && {(_x getVariable [QGVAR(taktikKilit), 0]) <= time} && {time >= (_x getVariable [QGVAR(tcccBusy), 0])}
                && {(_x getVariable [QGVAR(reloadState), []]) isEqualTo []} && {(_x getVariable [QGVAR(grState), []]) isEqualTo []} && {!(_x getVariable ["ACE_isUnconscious", false])}
                && {_x isNotEqualTo _rg} && {(_x getVariable [QGVAR(stationPos), []]) isEqualTo []}
            };
            private _dolu = createHashMap;
            {
                private _u = _x;
                if (time < (_u getVariable [QGVAR(gelisBakT), 0])) then { continue };
                private _ht = getAttackTarget _u;
                if (!isNull _ht && {([_u, "VIEW", _ht] checkVisibility [eyePos _u, eyePos _ht]) > 0.1}) then { continue };
                private _teta = _u getDir _ePos;
                private _sn = [_u, _teta, _dolu] call _adayBul;
                private _hedef = _sn select 0;
                private _tur = _sn select 1;
                if (_hedef isNotEqualTo []) then {
                    _u doWatch (_hedef vectorAdd [0, 0, 1.4]);
                    _u setVariable [QGVAR(gelisBakT), time + 12];
                    _say set [0, (_say select 0) + 1];
                    if (_logN < 20) then {
                        _logN = _logN + 1;
                        diag_log format ["[GELIS-YONU] %1 %2 | %3 | dusman yonu %4 derece (%5 m) | %6 -> bakis yonu %7 derece (%8 m)", str (side _g), groupId _g, name _u, round _teta, round (_u distance2D _ePos), _tur, round (_u getDir _hedef), round (_u distance2D _hedef)];
                    };
                };
            } forEach (_bosta select [0, 10]);
        } forEach allGroups;
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if ((_say select 0) > 0) then { diag_log format ["[GELIS-YONU-OZET] 60 sn: bakis yonlendirilen asker %1 | yol %2 | kapi %3 | acik gorus %4 | en acik yon %5", _say select 0, _say select 1, _say select 2, _say select 3, _say select 4]; };
            _say = [0, 0, 0, 0, 0];
        };
    };
};
true

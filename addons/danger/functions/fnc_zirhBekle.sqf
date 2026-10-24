#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ZIRH BEKLEME KAPISI (v8.349; kullanici: 'zirh gorus engeli cizgilerini / bogazlari piyade temizlemeden gecmesin' + 'tanklar birbirini ortsun: biri gozetlerken digeri ilerlesin'). fnc_planZirh her zirh grubu icin
 * ates pozisyonuna giderken HER TURDA cagirir; donen bos olmayan deger = 'simdi ilerleme, bekle'. Iki neden:
 *   1) GECIT / GORUS CIZGISI (fnc_zirhGecit rota analizi): arac rotadaki engele <= 150 m kala ve plan piyadesinden hic biri o engeli henuz asmadiysa (piyadenin ates pozisyonuna mesafesi <= engelin mesafesi + 10 m ve engele <= 450 m)
 *      arac durur ve piyade temizleyene kadar bekler (engel basina en cok 120 sn, sonra gecer). Savunma planinda, CEKILME'de, plan piyadesi yoksa, aracin kendisi hasar / AT tepkisi almissa devreye girmez.
 *      Kitap: MCWP 3-11.1 satir 8751-8766 (gorus engeli cizgilerini ve bogazlari once piyade temizler) [K]; sayilar [T].
 *   2) ES SICRAMA (sicramali gozetleme, bounding overwatch): iki-iki eslesen zirh gruplarinda (0-1, 2-3 ...) ikinci grup, es grup hala ates pozisyonuna giderken ve temas olasi bolgedeyse (savas fazi / piyade temasi ya da objektife <= 1400 m)
 *      yerinde durur ve gozetler; es grup mevziye varinca ilerler (en cok 150 sn). Ayni grubun ikinci araclari icin ayni kural fnc_planZirh'in 'grubun diger araclari' blogunda uygulanir.
 *      Kitap: temas olasiyken birimler sirayla ilerler, biri hareket ederken digeri ates destegi / gozetleme verir (MCWP 3-11.1 s. 6-36 zirh piyade temizledikce ileri sicrar; arac araligi: birbirini gorecek kadar yakin) [K]; 1400 m ve 150 sn [T].
 * Bekleme baslayinca doStop; bitince plan zaman sayaci (planZirhT) beklenen sure kadar ileri alinir (bekleme 'mevziye ulasamadi' sayilmasin) ve hareket emri hemen yenilenir.
 * Kapatma: CBA zirhGecitAktif / zirhSicramaAktif (ya da lambs_danger_zirhGecitOff / lambs_danger_zirhSicramaOff = true). Log: [ZIRH-GECIT], [ZIRH-SICRAMA].
 *
 * Arguments:
 * 0: Plan <HASHMAP>
 * 1: Zirh grubu <GROUP>
 * 2: Arac <OBJECT>
 * 3: Surucu <OBJECT>
 * 4: Plan fazi <STRING>
 * 5: Savas modu <BOOL>
 * 6: Planin zirh gruplari <ARRAY>
 * 7: Bu grubun listedeki sirasi <NUMBER>
 *
 * Return Value: Bekleme nedeni ("" = beklemiyor | "GECIT" | "GORUS CIZGISI" | "ES SICRAMA") <STRING>
 * Public: No
*/

params ["_plan", "_g", "_v", "_d", "_faz", "_savas", "_zg", "_idx"];

private _onceki = _g getVariable ["lambs_danger_zirhBekleNeden", ""];
private _neden = "";
private _id = _plan get "id";
private _obj = _plan get "obj";
private _vardi = _g getVariable ["lambs_danger_planZirhVardi", false];
private _gPoz = _g getVariable ["lambs_danger_planZirhPoz", []];

private _uygun = ((_plan getOrDefault ["tip", 0]) isNotEqualTo 1) && {!_vardi} && {_gPoz isNotEqualTo []} && {canMove _v} && {_faz isNotEqualTo "CEKILME"}
    && {(time - (_v getVariable ["lambs_danger_tankManevraT", -999])) > 20} && {!(_g getVariable ["lambs_danger_planZirhPiyadeTut", false])} && {!(_g getVariable ["lambs_danger_planZirhOranTut", false])};

// ---- 1) GECIT / GORUS CIZGISI ----
if (_uygun && {missionNamespace getVariable ["lambs_danger_zirhGecitAktif", true]} && {!(missionNamespace getVariable ["lambs_danger_zirhGecitOff", false])}) then {
    private _piyGrup = (_plan getOrDefault ["gruplar", []]) select {
        !isNull _x && {!(_x in _zg)} && {!(_x in (_plan getOrDefault ["reconG", []]))} && {!((_x getVariable ["lambs_danger_gorev", ""]) in ["TOPCU", "TOPCU_YOK", "MEDEVAC", "RECON", "RECON_ARAC"])} && {alive (leader _x)}
    };
    if (_piyGrup isNotEqualTo []) then {
        private _on = _g getVariable ["lambs_danger_zirhGecitL", []];
        if (_on isEqualTo [] || {((_on select 0) distance2D _gPoz) > 30}) then {
            _on = [_gPoz, [_v, _gPoz, _obj] call FUNC(zirhGecit)];
            _g setVariable ["lambs_danger_zirhGecitL", _on];
            _g setVariable ["lambs_danger_zirhGecitT0", -1];
            if (isNil "lambs_danger_zirhGecitLogN") then { lambs_danger_zirhGecitLogN = 0; };
            if (lambs_danger_zirhGecitLogN < 25) then {
                lambs_danger_zirhGecitLogN = lambs_danger_zirhGecitLogN + 1;
                diag_log format ["[ZIRH-GECIT] %1 | %2 rota analizi: ates pozisyonu %3 (%4 m) | engel %5: %6", _id, groupId _g, mapGridPosition _gPoz, round (_v distance2D _gPoz), count (_on select 1),
                    (_on select 1) apply { format ["%1 @ %2 (pozisyona %3 m)", _x select 1, mapGridPosition (_x select 0), round (_x select 2)] }];
            };
        };
        private _vKalan = _v distance2D _gPoz;
        {
            private _e = _x;
            _e params ["_ep", "_etur", "_ekalan"];
            if (_neden isEqualTo "" && {!(_e param [3, false])}) then {
                if (_vKalan <= (_ekalan + 10)) then {
                    _e set [3, true];   // arac engeli gecti
                } else {
                    if ((_v distance2D _ep) < 150) then {
                        private _temiz = (_piyGrup findIf { private _pl = vehicle (leader _x); (_pl distance2D _gPoz) <= (_ekalan + 10) && {(_pl distance2D _ep) < 450} }) >= 0;
                        private _t0 = _g getVariable ["lambs_danger_zirhGecitT0", -1];
                        if (_temiz) then {
                            _e set [3, true];
                            _g setVariable ["lambs_danger_zirhGecitT0", -1];
                            diag_log format ["[ZIRH-GECIT] %1 | %2 %3 (%4): piyade TEMIZLEDI -> zirh geciyor (%5 sn bekledi)", _id, groupId _g, _etur, mapGridPosition _ep, if (_t0 < 0) then {0} else {round (time - _t0)}];
                        } else {
                            if (_t0 < 0) then {
                                _t0 = time;
                                _g setVariable ["lambs_danger_zirhGecitT0", _t0];
                                diag_log format ["[ZIRH-GECIT] %1 | %2 %3 (%4) onunde: piyade henuz temizlemedi -> zirh BEKLIYOR (engele %5 m, objektife %6 m; kitap MCWP 3-11.1 8751-8766, en cok 120 sn)", _id, groupId _g, _etur, mapGridPosition _ep, round (_v distance2D _ep), round (_v distance2D _obj)];
                            };
                            if ((time - _t0) > 120) then {
                                _e set [3, true];
                                _g setVariable ["lambs_danger_zirhGecitT0", -1];
                                diag_log format ["[ZIRH-GECIT] %1 | %2 %3 (%4): ZAMAN ASIMI (120 sn) piyade temizlemedi -> zirh geciyor", _id, groupId _g, _etur, mapGridPosition _ep];
                            } else {
                                _neden = _etur;
                            };
                        };
                    };
                };
            };
        } forEach (_on select 1);
        _g setVariable ["lambs_danger_zirhGecitL", _on];
    };
};

// ---- 2) ES SICRAMA (iki-iki eslesen gruplar) ----
if (_neden isEqualTo "" && {_uygun} && {_idx > 0} && {(_idx mod 2) isEqualTo 1} && {missionNamespace getVariable ["lambs_danger_zirhSicramaAktif", true]} && {!(missionNamespace getVariable ["lambs_danger_zirhSicramaOff", false])}) then {
    private _es = _zg select (_idx - 1);
    private _esHareketli = false;
    if (!isNull _es && {local _es} && {_es getVariable ["lambs_danger_planZirh", false]} && {!(_es getVariable ["lambs_danger_planZirhVardi", false])} && {!(_es getVariable ["lambs_danger_planZirhOranTut", false])} && {({alive _x} count (units _es)) > 0}) then {
        private _ev = vehicle (leader _es);
        _esHareketli = canMove _ev && {_savas || {(_v distance2D _obj) < (missionNamespace getVariable ["lambs_danger_zirhSicramaMesafe", 1400])}};
    };
    if (_esHareketli) then {
        private _t0 = _g getVariable ["lambs_danger_zirhEsT0", -1];
        if (_t0 < 0) then {
            _t0 = time;
            _g setVariable ["lambs_danger_zirhEsT0", _t0];
            diag_log format ["[ZIRH-SICRAMA] %1 | %2 es grup (%3) hala ilerliyor, temas olasi bolge (objektife %4 m, savas %5): bu grup YERINDE GOZETLIYOR (sicramali gozetleme; kitap: biri ilerlerken digeri ortu verir, en cok 150 sn)", _id, groupId _g, groupId _es, round (_v distance2D _obj), _savas];
        };
        if ((time - _t0) < 150) then { _neden = "ES SICRAMA"; };
    } else {
        if ((_g getVariable ["lambs_danger_zirhEsT0", -1]) >= 0) then {
            diag_log format ["[ZIRH-SICRAMA] %1 | %2 es grup mevziye vardi / durum degisti -> bu grup ilerliyor (%3 sn gozetledi)", _id, groupId _g, round (time - (_g getVariable ["lambs_danger_zirhEsT0", time]))];
            _g setVariable ["lambs_danger_zirhEsT0", -1];
        };
    };
};

// ---- gecisler: bekleme basladi / bitti ----
if (_neden isNotEqualTo _onceki) then {
    if (_neden isNotEqualTo "" && {_onceki isEqualTo ""}) then {
        _g setVariable ["lambs_danger_zirhBekleT0", time];
        doStop _d;
        { _x doWatch (_g getVariable ["lambs_danger_planZirhBak", _obj]); } forEach (crew _v);
    };
    if (_neden isEqualTo "" && {_onceki isNotEqualTo ""}) then {
        private _sure = time - (_g getVariable ["lambs_danger_zirhBekleT0", time]);
        _g setVariable ["lambs_danger_planZirhT", (_g getVariable ["lambs_danger_planZirhT", time]) + _sure];
        _g setVariable ["lambs_danger_planZirhMoveT", -999];
        _g setVariable ["lambs_danger_planZirhDurT", -1];
        _d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1;
    };
    _g setVariable ["lambs_danger_zirhBekleNeden", _neden];
};
_neden

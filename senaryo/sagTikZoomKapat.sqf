/*
 * sagTikZoomKapat.sqf — SAG TIK YAKINLASTIRMA / NISANGAH ZOOMU KOKTEN KAPAT (her oyuncu, istemci tarafi)
 *
 * KULLANIM: bu dosyayi senaryo klasorune koy; initPlayerLocal.sqf icine su satiri ekle:
 *     execVM "sagTikZoomKapat.sqf";
 *   (ya da dosyanin icerigini dogrudan initPlayerLocal.sqf'e yapistir). Sunucuda calismaz (hasInterface sarti).
 *
 * NE YAPAR (iki katman):
 *   1) Ana ekranda (display 46) SAG TUS basma / birakma olaylarini TUKETIR (return true) -> oyun sag tik eylemini (optik / zoom) hic almaz.
 *      Ayrica 'optics', 'opticsTemp', 'zoomTemp' eylemlerine atanmis KLAVYE tuslarini da tuketir (kullanici baska tusa atamis olabilir).
 *   2) YEDEK: her karede oyuncu nisangah gorunumunde (cameraView = "GUNNER") ise gorunum ZORLA "INTERNAL"e alinir -> birinci sahis gorunum, nisangahtan bakis / optik yakinlastirma kapanir.
 *      (Birinci katman bazi surumlerde fare olayini tutamazsa bile nisangah en fazla 1 kare acik kalir.)
 *
 * AYARLAR (asagidaki degiskenler; calisirken de degistirilebilir):
 *   SAGTIK_AKTIF          true  : sistem acik
 *   SAGTIK_ARAC_DAHIL     false : true = arac / ucak / tank icinde de kapat (varsayilan: arac icinde ELLEME)
 *   SAGTIK_DURBUN_DAHIL   false : true = durbun / lazer isaretleyici zoomunu da kapat
 *   SAGTIK_TUS_DAHIL      true  : optik / zoom eylemlerine atanmis tuslari da engelle
 *
 * DEADZONE (%25) HAKKINDA: 'Aiming deadzone' Arma 3'te OYUNCUNUN kendi oyun ayaridir (Ayarlar > Oyun > Aiming deadzone). Bir betik komutu / zorluk ayari ile sunucudan
 *   sabitlenebildigine dair kaynak BULUNAMADI; bu dosya onu ZORLAYAMAZ. Asagida yalnizca katilan her oyuncuya bir kez hatirlatma gosterilir (SAGTIK_DEADZONE_HATIRLAT).
 */

if (!hasInterface) exitWith {};

waitUntil { !isNull player && {!isNull (findDisplay 46)} };

if (isNil "SAGTIK_AKTIF") then { SAGTIK_AKTIF = true; };
if (isNil "SAGTIK_ARAC_DAHIL") then { SAGTIK_ARAC_DAHIL = false; };
if (isNil "SAGTIK_DURBUN_DAHIL") then { SAGTIK_DURBUN_DAHIL = false; };
if (isNil "SAGTIK_TUS_DAHIL") then { SAGTIK_TUS_DAHIL = true; };
if (isNil "SAGTIK_DEADZONE_HATIRLAT") then { SAGTIK_DEADZONE_HATIRLAT = true; };

// ---- bu an engellenmeli mi? ----
SAGTIK_engelle = {
    if (!SAGTIK_AKTIF) exitWith {false};
    private _p = player;
    if (isNull _p || {!alive _p}) exitWith {false};
    if (visibleMap) exitWith {false};
    if (!isNull objectParent _p && {!SAGTIK_ARAC_DAHIL}) exitWith {false};
    if (!SAGTIK_DURBUN_DAHIL && {(currentWeapon _p) isKindOf ["Binocular", configFile >> "CfgWeapons"]}) exitWith {false};
    true
};

// ---- tekrar calistirilirsa eskileri temizle ----
if (!isNil "SAGTIK_EH") then {
    { (findDisplay 46) displayRemoveEventHandler [_x select 0, _x select 1]; } forEach SAGTIK_EH;
};
SAGTIK_EH = [];
if (!isNil "SAGTIK_KARE") then { removeMissionEventHandler ["EachFrame", SAGTIK_KARE]; };

// ---- 1) KATMAN: sag tus olaylarini tuket ----
{
    private _id = (findDisplay 46) displayAddEventHandler [_x, {
        params ["_d", "_dugme"];
        if (_dugme isEqualTo 1 && {call SAGTIK_engelle}) then {true} else {false}
    }];
    SAGTIK_EH pushBack [_x, _id];
} forEach ["MouseButtonDown", "MouseButtonUp"];

// ---- optik / zoom eylemlerine atanmis klavye tuslari ----
if (SAGTIK_TUS_DAHIL) then {
    SAGTIK_TUSLAR = [];
    { SAGTIK_TUSLAR append (actionKeys _x); } forEach ["optics", "opticsTemp", "opticsMode", "zoomTemp"];
    // fare tuslari (65536+) ayri katmanda; yalniz klavye kodlari
    SAGTIK_TUSLAR = SAGTIK_TUSLAR select {_x < 65536};
    private _id2 = (findDisplay 46) displayAddEventHandler ["KeyDown", {
        params ["_d", "_tus"];
        if ((_tus in SAGTIK_TUSLAR) && {call SAGTIK_engelle}) then {true} else {false}
    }];
    SAGTIK_EH pushBack ["KeyDown", _id2];
};

// ---- 2) KATMAN (yedek): nisangah gorunumundeyse zorla cik ----
SAGTIK_KARE = addMissionEventHandler ["EachFrame", {
    if !(call SAGTIK_engelle) exitWith {};
    private _arac = vehicle player;
    if (cameraOn isEqualTo _arac && {cameraView isEqualTo "GUNNER"}) then {
        _arac switchCamera "INTERNAL";
    };
}];

// ---- deadzone hatirlatmasi (zorlayamaz; bir kez) ----
if (SAGTIK_DEADZONE_HATIRLAT) then {
    SAGTIK_DEADZONE_HATIRLAT = false;
    hintC parseText "<t size='1.2' color='#ffcc00'>Nisan ayari</t><br/>Bu senaryoda <t color='#ffcc00'>sag tik zoom kapali</t>.<br/>Oyun ayarlarindan <t color='#ffcc00'>Aiming deadzone</t> degerini <t color='#ffcc00'>%25</t> yap (Ayarlar &gt; Oyun).";
};

diag_log "[SAGTIK] sag tik zoom engeli aktif (mouse olaylari + gorunum yedegi)";

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
 *   SAGTIK_TANI           false : true = ekranda gorunum / eylem tanisi goster (zoom neyle olusuyor)
 *
 * NOT (zoom turleri): Arma 3'te sag tus BASILI TUTMA = "optics temporary" (nisangahtan bakis + zoom) -> bu betigin engelledigi sey. Nisan ALMADAN calisan ayri bir "kalca zoom"u icin kaynak BULUNAMADI;
 *   varsa hangi eylemin yaptigini gormek icin SAGTIK_TANI = true yap (ekranda cameraView + optics / opticsTemp / zoomTemp eylem degerleri + FOV gorunur), zoom olurken ne yazdigini bana ilet.
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
if (isNil "SAGTIK_TANI") then { SAGTIK_TANI = false; };

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
    // v2: daha genis eylem listesi (bilinmeyen ad bos doner, zararsiz); SAGTIK_EYLEMLER ile degistirilebilir
    if (isNil "SAGTIK_EYLEMLER") then { SAGTIK_EYLEMLER = ["optics", "opticsTemp", "opticsMode", "zoomTemp", "zoomIn", "zoomOut", "zoomContinue", "zoomInTemp", "zoomOutTemp"]; };
    { SAGTIK_TUSLAR append (actionKeys _x); } forEach SAGTIK_EYLEMLER;
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

// ---- 3) KATMAN (v3): kullanici-eylem olay isleyicileri ----
// Fare olayini tuketmek motorun ESLENMIS eylemini (zoom) durdurmayabilir; eylemi adiyla yakalamayi dene.
// 'true' donusu eylemi iptal ETMEYEBILIR (dogrulanamadi) -> asagidaki 4. katman bagimsiz calisir.
if (!isNil "SAGTIK_UAEH") then {
    { removeUserActionEventHandler _x; } forEach SAGTIK_UAEH;
};
SAGTIK_UAEH = [];
if (!isNil "SAGTIK_EYLEMLER") then {
    {
        private _ad = _x;
        {
            private _id = addUserActionEventHandler [_ad, _x, {
                if (call SAGTIK_engelle) then {true} else {false}
            }];
            if (_id isEqualType 0 && {_id >= 0}) then { SAGTIK_UAEH pushBack [_ad, _x, _id]; };
        } forEach ["Activate", "Analog"];
    } forEach SAGTIK_EYLEMLER;
};

// ---- 4) KATMAN (v3): ZOOM TETIKLENIRSE ANINDA GERI AL ----
// Zoom eylemlerinden biri aktifken gorunum zorla "INTERNAL"e alinir ve olay RPT'ye yazilir.
// Nisan ALMAYAN FOV zoomunu betikle sifirlayan bir komut bulunamadi: zoom hala olursa SAGTIK_TANI = true yap, RPT'deki '[SAGTIK-EYLEM]' satirlarindan eylem adini bana ilet.
SAGTIK_ZOOM_AKTIF = false;
if (!isNil "SAGTIK_ZOOM_KARE") then { removeMissionEventHandler ["EachFrame", SAGTIK_ZOOM_KARE]; };
SAGTIK_ZOOM_KARE = addMissionEventHandler ["EachFrame", {
    if !(call SAGTIK_engelle) exitWith {};
    private _aktif = false;
    { if (inputAction _x > 0) exitWith { _aktif = true; }; } forEach ["optics", "opticsTemp", "zoomTemp", "zoomIn", "zoomOut", "zoomContinue", "zoomInTemp", "zoomOutTemp"];
    if (_aktif) then {
        private _arac = vehicle player;
        if (cameraOn isEqualTo _arac && {cameraView isNotEqualTo "INTERNAL"}) then { _arac switchCamera "INTERNAL"; };
        if (!SAGTIK_ZOOM_AKTIF) then { SAGTIK_ZOOM_AKTIF = true; diag_log format ["[SAGTIK] zoom eylemi algilandi (gorunum %1)", cameraView]; };
    } else {
        SAGTIK_ZOOM_AKTIF = false;
    };
}];

// ---- TANI (istege bagli): zoom olurken hangi eylem / gorunum aktif? ----
// v3: SAGTIK_TANI = true iken butun kullanici eylemleri (UserActionGroups) RPT'ye '[SAGTIK-EYLEM] ad' olarak yazilir
if (!isNil "SAGTIK_TANI_UAEH") then { { removeUserActionEventHandler _x; } forEach SAGTIK_TANI_UAEH; };
SAGTIK_TANI_UAEH = [];
if (SAGTIK_TANI) then {
    private _adlar = [];
    {
        _adlar append (getArray (_x >> "list"));
    } forEach ("true" configClasses (configFile >> "UserActionGroups"));
    {
        private _ad = _x;
        private _id = addUserActionEventHandler [_ad, "Activate", compile format ["diag_log '[SAGTIK-EYLEM] %1'; false", _ad]];
        if (_id isEqualType 0 && {_id >= 0}) then { SAGTIK_TANI_UAEH pushBack [_ad, "Activate", _id]; };
    } forEach (_adlar arrayIntersect _adlar);
    diag_log format ["[SAGTIK-TANI] %1 eylem izleniyor", count SAGTIK_TANI_UAEH];
};
if (!isNil "SAGTIK_TANI_KARE") then { removeMissionEventHandler ["EachFrame", SAGTIK_TANI_KARE]; SAGTIK_TANI_KARE = nil; };
if (SAGTIK_TANI) then {
    SAGTIK_TANI_KARE = addMissionEventHandler ["EachFrame", {
        hintSilent format ["gorunum: %1 | optics: %2 | opticsTemp: %3 | zoomTemp: %4 | zoomIn: %5 | zoomOut: %6 | zoomContinue: %7 | silah: %8", cameraView, inputAction "optics", inputAction "opticsTemp", inputAction "zoomTemp", inputAction "zoomIn", inputAction "zoomOut", inputAction "zoomContinue", currentWeapon player];
    }];
};

// ---- deadzone hatirlatmasi (zorlayamaz; bir kez) ----
if (SAGTIK_DEADZONE_HATIRLAT) then {
    SAGTIK_DEADZONE_HATIRLAT = false;
    // v2: hintC String ister (RPT: 'hintc: Type Text, expected String', satir 99) -> hint + parseText kullanilir
    hint parseText "<t size='1.2' color='#ffcc00'>Nisan ayari</t><br/>Bu senaryoda <t color='#ffcc00'>sag tik zoom kapali</t>.<br/>Oyun ayarlarindan <t color='#ffcc00'>Aiming deadzone</t> degerini <t color='#ffcc00'>%25</t> yap (Ayarlar &gt; Oyun).";
};

diag_log "[SAGTIK] sag tik zoom engeli aktif (mouse olaylari + gorunum yedegi)";

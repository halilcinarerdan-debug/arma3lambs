/*
 * faction_export.sqf — oyunda giydirdigin askerlerden CfgVehicles config kodu uretir (DENENMEDI; Arma ortamim yok).
 *
 * KULLANIM (Eden veya oyun ici debug konsolu, yerel calistir):
 *   1) Her rol icin bir asker koy ve Arsenal ile giydir (RHSAFRF / USAF / GREF / UFP esyalari karisabilir).
 *      Birimin kendi sinifi (typeOf) model + yuz + ses + ZEKA temeli olarak miras alinir; sadece teçhizat degisir.
 *   2) Eden: askerleri sec ve asagidaki satiri calistir:
 *         [get3DENSelected "object", "CINAR", "CINAR_Faction", 0] execVM "faction_export.sqf";
 *      Oyun/Zeus: [[a1, a2, a3], "CINAR", "CINAR_Faction", 0] execVM "faction_export.sqf";   (a1.. = birim degiskenleri)
 *      Parametreler: birim listesi, sinif oneki, faction adi, taraf (0 OPFOR, 1 BLUFOR, 2 INDEP)
 *   3) Sonuc panoya kopyalanir (copyToClipboard) ve RPT'ye yazilir; config.cpp'deki CfgVehicles icine yapistirilir.
 *
 * CIKTI: her birim icin sinif; ust sinif = birimin kendi sinifi (typeOf). Gorunum: giyilen tulumun modeli + dokulari kopyalanir.
 * Ust siniflar CfgVehicles basinda 'class rhs_...;' olarak bildirilmeli; bu betik onlari da listeler.
 */
params [["_birimler", []], ["_onek", "CINAR"], ["_faction", "CINAR_Faction"], ["_taraf", 0]];
private _tirnakli = { format ["""%1""", _this] };
private _liste = { "{" + ((_this apply { _x call _tirnakli }) joinString ", ") + "}" };

private _ciktiSinif = [];
private _ustler = [];
private _sayac = 0;
{
    private _u = _x;
    if (!(_u isKindOf "CAManBase")) then { continue };
    private _ust = typeOf _u;
    _ustler pushBackUnique _ust;
    _sayac = _sayac + 1;

    private _ad = format ["%1_%2_%3", _onek, _sayac, _ust];

    // giyilen esyalar
    private _tulum = uniform _u;
    private _yelek = vest _u;
    private _kask = headgear _u;
    private _gozluk = goggles _u;
    private _cantaC = backpack _u;
    private _bagli = [_tulum, _yelek, _kask, _gozluk] select { _x != "" };
    _bagli append (assignedItems _u);

    // silahlar: [ana, tabanca, fisek-atar, dürbün] + her biri icin ekler
    private _silahlar = [primaryWeapon _u, secondaryWeapon _u, handgunWeapon _u, binocular _u] select { _x != "" };
    private _silahlarTum = _silahlar + ["Throw", "Put"];
    private _eklentiler = (primaryWeaponItems _u) + (secondaryWeaponItems _u) + (handgunItems _u);
    _bagli append (_eklentiler select { _x != "" });

    // mühimmat: konteynerlerdeki tum sarjorler (tekrar sayisiyla), ek esyalar
    private _mermiler = magazines _u;
    private _esyalar = (items _u) select { !(_x in _bagli) };

    // gorunum: tulumun giydirdigi model + dokular
    private _tulumSinifi = if (_tulum != "") then { getText (configFile >> "CfgWeapons" >> _tulum >> "ItemInfo" >> "uniformClass") } else { "" };
    private _model = "";
    private _dokular = [];
    if (_tulumSinifi != "") then {
        private _cfg = configFile >> "CfgVehicles" >> _tulumSinifi;
        _model = getText (_cfg >> "model");
        _dokular = getArray (_cfg >> "hiddenSelectionsTextures");
    };

    private _s = [];
    _s pushBack format ["    class %1: %2 {", _ad, _ust];
    _s pushBack "        scope = 2; scopeCurator = 2;";
    _s pushBack format ["        faction = ""%1""; side = %2;", _faction, _taraf];
    _s pushBack format ["        displayName = ""%1"";", getText (configFile >> "CfgVehicles" >> _ust >> "displayName")];
    if (_tulum != "") then { _s pushBack format ["        uniformClass = ""%1"";", _tulum]; };
    if (_model != "") then { _s pushBack format ["        model = ""%1"";", _model]; };
    if (_dokular isNotEqualTo []) then { _s pushBack format ["        hiddenSelectionsTextures[] = %1;", _dokular call _liste]; };
    if (_cantaC != "") then { _s pushBack format ["        backpack = ""%1"";", _cantaC]; };
    _s pushBack format ["        weapons[] = %1;", _silahlarTum call _liste];
    _s pushBack format ["        respawnWeapons[] = %1;", _silahlarTum call _liste];
    _s pushBack format ["        magazines[] = %1;", _mermiler call _liste];
    _s pushBack format ["        respawnMagazines[] = %1;", _mermiler call _liste];
    _s pushBack format ["        items[] = %1;", _esyalar call _liste];
    _s pushBack format ["        respawnItems[] = %1;", _esyalar call _liste];
    _s pushBack format ["        linkedItems[] = %1;", _bagli call _liste];
    _s pushBack format ["        respawnLinkedItems[] = %1;", _bagli call _liste];
    _s pushBack "    };";
    _ciktiSinif pushBack (_s joinString endl);
} forEach _birimler;

private _bas = (_ustler apply { format ["    class %1;", _x] }) joinString endl;
// format 8192 karakter sinirina takilabilir -> + ile birlestir
private _cikti = "class CfgVehicles {" + endl + _bas + endl + endl + (_ciktiSinif joinString (endl + endl)) + endl + "};";
copyToClipboard _cikti;
diag_log "[FRAKSIYON-EXPORT] ---- BASLA ----";
diag_log _cikti;
diag_log "[FRAKSIYON-EXPORT] ---- BITTI ----";
hint format ["%1 birim icin config uretildi, panoya kopyalandi (RPT'de de var).", _sayac];

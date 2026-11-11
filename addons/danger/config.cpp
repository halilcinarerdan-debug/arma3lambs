#include "script_component.hpp"
class CfgPatches {
    class ADDON {
        name = COMPONENT_NAME;
        units[] = {QGVAR(SetRadio), QGVAR(DisableAI), QGVAR(ConfigureGroupAI), QGVAR(Kumanda), QGVAR(GorevAta), QGVAR(Karakol), QGVAR(KarakolGarnizon), QGVAR(GozetleAta), QGVAR(IhaGorev), QGVAR(TopcuTest), QGVAR(KarakolKaldir), QGVAR(EdenKumanda), QGVAR(EdenGorevAta), QGVAR(EdenKarakol), QGVAR(EdenGarnizon), QGVAR(EdenGozetle), QGVAR(EdenIha), QGVAR(EdenPozisyon)};   // ELITE fork: Zeus modulu listede olmazsa Zeus gostermez
        weapons[] = {};
        requiredVersion = REQUIRED_VERSION;
        requiredAddons[] = {"lambs_main"};
        author = ECSTRING(main,Team);
        VERSION_CONFIG;
    };
};

// ELITE fork (v8.362): 3DEN modul kategorisi (Eden modul agacinda "LAMBS ELITE (3DEN)")
class CfgFactionClasses {
    class NO_CATEGORY;
    class lambs_danger_elite_cat: NO_CATEGORY {
        displayName = "LAMBS ELITE (3DEN)";
        priority = 2;
        side = 7;
    };
};

#include "CfgEventHandlers.hpp"
#include "CfgVehicles.hpp"
#include "Cfg3DEN.hpp"
#include "ZEN_CfgContext.hpp"

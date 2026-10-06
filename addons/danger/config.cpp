#include "script_component.hpp"
class CfgPatches {
    class ADDON {
        name = COMPONENT_NAME;
        units[] = {QGVAR(SetRadio), QGVAR(DisableAI), QGVAR(ConfigureGroupAI), QGVAR(Kumanda), QGVAR(Objektif), QGVAR(PlanNokta), QGVAR(GorevAta)};   // ELITE fork: Zeus modulu listede olmazsa Zeus gostermez
        weapons[] = {};
        requiredVersion = REQUIRED_VERSION;
        requiredAddons[] = {"lambs_main"};
        author = ECSTRING(main,Team);
        VERSION_CONFIG;
    };
};

#include "CfgEventHandlers.hpp"
#include "CfgVehicles.hpp"
#include "Cfg3DEN.hpp"
#include "ZEN_CfgContext.hpp"

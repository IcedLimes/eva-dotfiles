// eva-blurcache: lets Rei, the moon and the vinyl record animate on the desktop
// without throwing away Hyprland's cached wallpaper blur.
//
// Hyprland keeps one blurred copy of the background and bottom layers for
// "xray" glass (the bar, terminals). Any commit from a layer down there marks
// that copy dirty (CLayerSurface::onCommit), and the next frame re-blurs the
// whole screen -- and with a terminal open, redraws the whole screen too. Rei
// commits 30 times a second, so she cost about half of the Radeon 610M.
//
// For the layers named below (Rei, the moon, the info panel, the stars, the shooting stars, the screen's frame and the record), a commit no
// longer dirties the cache. Glass in
// front of them shows them as they were at the last real refresh (wallpaper
// motion, workspace switch, ...), which under a heavy blur looks the same.
//
// Shooting stars (eva-meteor, ~/.config/quickshell/eva/Meteor.qml) are small
// layers that move every frame. Moving a layer re-arranges them all, which
// damages the whole monitor and re-runs the window layout of every workspace
// on it; and on the next animation tick Hyprland marks the blur dirty again
// for any moved layer down there. With a terminal open that cost ~85% of the
// GPU. For them, only the square they left and the one they moved to are
// redrawn, and the cached blur stays.
#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/desktop/view/LayerSurface.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/layout/LayoutManager.hpp>

#include <array>
#include <string_view>

inline HANDLE         PHANDLE = nullptr;
inline CFunctionHook* g_pCommitHook = nullptr;
inline CFunctionHook* g_pDamageMonitorHook = nullptr;
inline CFunctionHook* g_pInvalidateHook = nullptr;

static bool g_moving = false;   // inside a commit from a shooting star
inline CFunctionHook* g_pTickHook = nullptr;
static PHLMONITORREF g_movedOn;  // a shooting star moved here since the last animation tick

static constexpr std::array<std::string_view, 7> KEEP_CACHE = {"eva-rei", "eva-moon", "eva-hud", "eva-stars", "eva-meteor", "eva-frame", "vinyl-visualizer"};

typedef void (*origOnCommit)(Desktop::View::CLayerSurface*);
typedef void (*origWithMonitor)(void*, PHLMONITOR);

static void hkOnCommit(Desktop::View::CLayerSurface* ls) {
    const auto MON       = ls->m_monitor.lock();
    const bool WASDIRTY  = MON ? MON->m_blurFBDirty : true;
    const bool WASRECALC = MON ? MON->m_scheduledRecalc : true;
    const bool MOVER     = MON && ls->m_mapped && ls->m_namespace == "eva-meteor";
    const CBox BEFORE    = ls->m_geometry;

    g_moving = MOVER;
    (*(origOnCommit)g_pCommitHook->m_original)(ls);
    g_moving = false;

    if (MOVER) {
        g_movedOn = MON;
        if (!WASRECALC)
            MON->m_scheduledRecalc = false;
        g_pHyprRenderer->damageBox(BEFORE);
        g_pHyprRenderer->damageBox(ls->m_geometry);
    }

    if (MON && !WASDIRTY && std::ranges::find(KEEP_CACHE, std::string_view{ls->m_namespace}) != KEEP_CACHE.end())
        MON->m_blurFBDirty = false;
}

static void hkDamageMonitor(void* thisptr, PHLMONITOR mon) {
    if (!g_moving)
        (*(origWithMonitor)g_pDamageMonitorHook->m_original)(thisptr, mon);
}

static void hkInvalidateMonitorGeometries(void* thisptr, PHLMONITOR mon) {
    if (!g_moving)
        (*(origWithMonitor)g_pInvalidateHook->m_original)(thisptr, mon);
}

// The tick applies the move (CHyprAnimationManager::tick: a moved layer on the
// background or bottom level dirties the blur). Keep it clean when the shooting
// stars are what moved.
typedef void (*origTick)(void*);
static void hkTick(void* thisptr) {
    const auto MON      = g_movedOn.lock();
    const bool WASDIRTY = MON ? MON->m_blurFBDirty : true;

    (*(origTick)g_pTickHook->m_original)(thisptr);

    if (MON && !WASDIRTY)
        MON->m_blurFBDirty = false;
    g_movedOn.reset();
}

static CFunctionHook* hookFirst(const std::string& name, const std::string& demangledPrefix, void* fn) {
    for (auto& f : HyprlandAPI::findFunctionsByName(PHANDLE, name)) {
        if (!f.demangled.starts_with(demangledPrefix))
            continue;
        auto hook = HyprlandAPI::createFunctionHook(PHANDLE, f.address, fn);
        return hook && hook->hook() ? hook : nullptr;
    }
    return nullptr;
}

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    PHANDLE = handle;

    if (std::string{__hyprland_api_get_hash()} != std::string{__hyprland_api_get_client_hash()}) {
        HyprlandAPI::addNotification(PHANDLE, "[eva-blurcache] Version mismatch with the running Hyprland; not loaded", CHyprColor{1.0, 0.2, 0.2, 1.0}, 5000);
        throw std::runtime_error("[eva-blurcache] Version mismatch");
    }

    for (auto& fn : HyprlandAPI::findFunctionsByName(PHANDLE, "onCommit")) {
        if (fn.demangled != "Desktop::View::CLayerSurface::onCommit()")
            continue;
        g_pCommitHook = HyprlandAPI::createFunctionHook(PHANDLE, fn.address, (void*)::hkOnCommit);
        break;
    }
    if (!g_pCommitHook || !g_pCommitHook->hook()) {
        HyprlandAPI::addNotification(PHANDLE, "[eva-blurcache] Couldn't hook layer commits; Rei will cost more GPU", CHyprColor{1.0, 0.6, 0.2, 1.0}, 5000);
        return {"eva-blurcache", "Desktop decorations keep the cached wallpaper blur", "eva", "1.1"};
    }

    // All three or it still redraws everything; any missing just costs GPU.
    g_pDamageMonitorHook = hookFirst("damageMonitor", "Render::IHyprRenderer::damageMonitor(", (void*)::hkDamageMonitor);
    g_pInvalidateHook    = hookFirst("invalidateMonitorGeometries", "Layout::CLayoutManager::invalidateMonitorGeometries(", (void*)::hkInvalidateMonitorGeometries);
    g_pTickHook          = hookFirst("tick", "Animation::CHyprAnimationManager::tick(", (void*)::hkTick);
    if (!g_pDamageMonitorHook || !g_pInvalidateHook || !g_pTickHook)
        HyprlandAPI::addNotification(PHANDLE, "[eva-blurcache] Couldn't hook layer moves; shooting stars will cost more GPU", CHyprColor{1.0, 0.6, 0.2, 1.0}, 5000);

    return {"eva-blurcache", "Desktop decorations keep the cached wallpaper blur", "eva", "1.1"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    ;
}

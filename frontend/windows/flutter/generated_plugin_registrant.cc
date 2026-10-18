//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <geolocator_windows/geolocator_windows.h>
#include <quickjs_engine/quickjs_engine_plugin_c_api.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  GeolocatorWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("GeolocatorWindows"));
  QuickjsEnginePluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("QuickjsEnginePluginCApi"));
}

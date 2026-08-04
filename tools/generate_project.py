#!/usr/bin/env python3
"""Generates BeerCHILLER.xcodeproj.

Neither xcodegen nor the xcodeproj gem is available on this machine, so the
project file is emitted directly. Keeping it in a script (rather than editing
project.pbxproj by hand) means the target/file layout stays reviewable and
regenerating after a change is one command:

    python3 tools/generate_project.py

Targets
    BeerCHILLER              iOS 16.0 app          com.bierchiller.app
    BeerCHILLERWidget        widget extension       …app.widget
    BeerCHILLERWatch         watchOS 9.0 app        …app.watchkitapp
    BeerCHILLERWatchWidget   watch complications    …app.watchkitapp.widget
    BeerCHILLERTests         unit tests (host: app)
"""

import os
import shutil
import sys

# Building the iOS app for the simulator requires a matching watchOS simulator
# runtime as soon as the watch app is embedded. Pass --no-watch-embed to build
# and test the iPhone/iPad app on a machine without that runtime installed; the
# watch targets still build on their own scheme.
EMBED_WATCH = "--no-watch-embed" not in sys.argv

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT_NAME = "BeerCHILLER"
PROJECT_DIR = os.path.join(ROOT, f"{PROJECT_NAME}.xcodeproj")

APP_BUNDLE_ID = "com.bierchiller.app"
APP_GROUP = "group.com.bierchiller.app.shared"
IOS_TARGET = "16.0"
WATCH_TARGET = "9.0"

# ---------------------------------------------------------------- file layout

SHARED_CORE = [
    "Shared/CoolingModel.swift",
    "Shared/BrandMark.swift",
    "Shared/WidgetTimeline.swift",
    "Shared/ChillSession.swift",
    "Shared/SharedStore.swift",
    "Shared/AppSettings.swift",
    "Shared/Theme.swift",
    "Shared/Formatting.swift",
]
SHARED_ACTIVITY = ["Shared/ChillActivityAttributes.swift"]
SHARED_RUNTIME = ["Shared/ChillController.swift", "Shared/WatchSync.swift"]

APP_SOURCES = SHARED_CORE + SHARED_ACTIVITY + SHARED_RUNTIME + [
    "BeerChiller/BeerChillerApp.swift",
    "BeerChiller/Views/Components.swift",
    "BeerChiller/Views/RootView.swift",
    "BeerChiller/Views/SettingsView.swift",
    "BeerChiller/Views/AlarmView.swift",
    "BeerChiller/Views/InfoView.swift",
    "BeerChiller/Views/HelpView.swift",
    "BeerChiller/Views/MathFormula.swift",
]

WIDGET_SOURCES = SHARED_CORE + SHARED_ACTIVITY + [
    "BeerChillerWidget/BeerChillerWidgetBundle.swift",
    "BeerChillerWidget/ChillTimerWidget.swift",
    "BeerChillerWidget/ChillLiveActivity.swift",
]

WATCH_SOURCES = SHARED_CORE + SHARED_ACTIVITY + SHARED_RUNTIME + [
    "BeerChillerWatch/BeerChillerWatchApp.swift",
    "BeerChillerWatch/WatchRootView.swift",
]

WATCH_WIDGET_SOURCES = SHARED_CORE + [
    "BeerChillerWatchWidget/BeerChillerWatchWidgetBundle.swift",
]

TEST_SOURCES = ["Tests/CoolingModelTests.swift"]
UI_TEST_SOURCES = ["UITests/BeerChillerUITests.swift"]

HELP_FILES = sorted(
    f"BeerChiller/Help/{name}"
    for name in os.listdir(os.path.join(ROOT, "BeerChiller/Help"))
    if name.endswith(".md")
)

APP_RESOURCES = ["BeerChiller/Assets.xcassets", "BeerChiller/Localizable.xcstrings"] + HELP_FILES
WIDGET_RESOURCES = ["BeerChiller/Localizable.xcstrings"]
WATCH_RESOURCES = ["BeerChiller/Localizable.xcstrings"]
WATCH_WIDGET_RESOURCES = ["BeerChiller/Localizable.xcstrings"]

KNOWN_TYPES = {
    ".swift": "sourcecode.swift",
    ".xcassets": "folder.assetcatalog",
    ".xcstrings": "text.json.xcstrings",
    ".md": "net.daringfireball.markdown",
    ".plist": "text.plist.xml",
    ".entitlements": "text.plist.entitlements",
}

# ------------------------------------------------------------------ id minting

class Ids:
    def __init__(self):
        self.n = 0
        self.cache = {}

    def new(self, tag=None):
        self.n += 1
        value = f"BEEF{self.n:020X}"
        if tag:
            self.cache[tag] = value
        return value

    def of(self, tag):
        if tag not in self.cache:
            self.new(tag)
        return self.cache[tag]


ids = Ids()
objects = {}


def add(obj_id, body):
    objects[obj_id] = body


def quoted(value):
    text = str(value)
    if text == "":
        return '""'
    if all(c.isalnum() or c in "._/$" for c in text):
        return text
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def settings_block(settings, indent):
    pad = "\t" * indent
    lines = []
    for key in sorted(settings):
        value = settings[key]
        if isinstance(value, list):
            lines.append(f"{pad}{key} = (")
            for item in value:
                lines.append(f"{pad}\t{quoted(item)},")
            lines.append(f"{pad});")
        else:
            lines.append(f"{pad}{key} = {quoted(value)};")
    return "\n".join(lines)


# ------------------------------------------------------------- file references

file_refs = {}


def file_ref(path):
    """One PBXFileReference per source path, keyed by repo-relative path."""
    if path in file_refs:
        return file_refs[path]
    ref = ids.new(f"ref:{path}")
    ext = os.path.splitext(path)[1]
    file_type = KNOWN_TYPES.get(ext, "text")
    add(ref,
        f"{ref} /* {os.path.basename(path)} */ = {{isa = PBXFileReference; "
        f"lastKnownFileType = {file_type}; path = {quoted(os.path.basename(path))}; "
        f"sourceTree = \"<group>\"; }};")
    file_refs[path] = ref
    return ref


def build_file(path, target_tag, phase):
    """One PBXBuildFile per (file, target) pair."""
    bf = ids.new(f"bf:{phase}:{target_tag}:{path}")
    ref = file_ref(path)
    add(bf,
        f"{bf} /* {os.path.basename(path)} in {phase} */ = {{isa = PBXBuildFile; "
        f"fileRef = {ref} /* {os.path.basename(path)} */; }};")
    return bf


def product_ref(name, ext, explicit_type):
    ref = ids.new(f"product:{name}")
    add(ref,
        f"{ref} /* {name}.{ext} */ = {{isa = PBXFileReference; "
        f"explicitFileType = {explicit_type}; includeInIndex = 0; "
        f"path = {quoted(name + '.' + ext)}; sourceTree = BUILT_PRODUCTS_DIR; }};")
    return ref


# ------------------------------------------------------------------- groups

def group(name, children, path=None, tag=None):
    gid = ids.new(tag or f"group:{name}:{ids.n}")
    child_list = "\n".join(f"\t\t\t\t{c},".expandtabs(0) for c in children)
    path_line = f" path = {quoted(path)};" if path else ""
    add(gid,
        f"{gid} /* {name} */ = {{\n"
        f"\t\t\tisa = PBXGroup;\n"
        f"\t\t\tchildren = (\n"
        + "".join(f"\t\t\t\t{c},\n" for c in children) +
        f"\t\t\t);\n"
        + (f"\t\t\tname = {quoted(name)};\n" if path is None else f"\t\t\tpath = {quoted(path)};\n")
        + f"\t\t\tsourceTree = \"<group>\";\n"
        f"\t\t}};")
    return gid


# --------------------------------------------------------------- build phases

def sources_phase(paths, target_tag):
    pid = ids.new(f"sources:{target_tag}")
    files = [build_file(p, target_tag, "Sources") for p in paths]
    add(pid,
        f"{pid} /* Sources */ = {{\n"
        f"\t\t\tisa = PBXSourcesBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tfiles = (\n"
        + "".join(f"\t\t\t\t{f},\n" for f in files) +
        f"\t\t\t);\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};")
    return pid


def resources_phase(paths, target_tag):
    pid = ids.new(f"resources:{target_tag}")
    files = [build_file(p, target_tag, "Resources") for p in paths]
    add(pid,
        f"{pid} /* Resources */ = {{\n"
        f"\t\t\tisa = PBXResourcesBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tfiles = (\n"
        + "".join(f"\t\t\t\t{f},\n" for f in files) +
        f"\t\t\t);\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};")
    return pid


def frameworks_phase(target_tag):
    pid = ids.new(f"frameworks:{target_tag}")
    add(pid,
        f"{pid} /* Frameworks */ = {{\n"
        f"\t\t\tisa = PBXFrameworksBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tfiles = (\n"
        f"\t\t\t);\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};")
    return pid


def embed_phase(name, dst_path, dst_spec, product_refs, target_tag):
    """Copy-files phase used to embed extensions (PlugIns) and the watch app."""
    pid = ids.new(f"embed:{target_tag}:{name}")
    files = []
    for ref, label in product_refs:
        bf = ids.new(f"embedbf:{target_tag}:{label}")
        add(bf,
            f"{bf} /* {label} in {name} */ = {{isa = PBXBuildFile; "
            f"fileRef = {ref} /* {label} */; "
            f"settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};")
        files.append(bf)
    add(pid,
        f"{pid} /* {name} */ = {{\n"
        f"\t\t\tisa = PBXCopyFilesBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tdstPath = {quoted(dst_path)};\n"
        f"\t\t\tdstSubfolderSpec = {dst_spec};\n"
        f"\t\t\tfiles = (\n"
        + "".join(f"\t\t\t\t{f},\n" for f in files) +
        f"\t\t\t);\n"
        f"\t\t\tname = {quoted(name)};\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};")
    return pid


# ------------------------------------------------------------- configurations

def config_list(name, debug_settings, release_settings):
    debug_id = ids.new(f"cfg:{name}:Debug")
    release_id = ids.new(f"cfg:{name}:Release")
    add(debug_id,
        f"{debug_id} /* Debug */ = {{\n"
        f"\t\t\tisa = XCBuildConfiguration;\n"
        f"\t\t\tbuildSettings = {{\n"
        + settings_block(debug_settings, 4) + "\n"
        f"\t\t\t}};\n"
        f"\t\t\tname = Debug;\n"
        f"\t\t}};")
    add(release_id,
        f"{release_id} /* Release */ = {{\n"
        f"\t\t\tisa = XCBuildConfiguration;\n"
        f"\t\t\tbuildSettings = {{\n"
        + settings_block(release_settings, 4) + "\n"
        f"\t\t\t}};\n"
        f"\t\t\tname = Release;\n"
        f"\t\t}};")
    list_id = ids.new(f"cfglist:{name}")
    add(list_id,
        f"{list_id} /* Build configuration list for {name} */ = {{\n"
        f"\t\t\tisa = XCConfigurationList;\n"
        f"\t\t\tbuildConfigurations = (\n"
        f"\t\t\t\t{debug_id} /* Debug */,\n"
        f"\t\t\t\t{release_id} /* Release */,\n"
        f"\t\t\t);\n"
        f"\t\t\tdefaultConfigurationIsVisible = 0;\n"
        f"\t\t\tdefaultConfigurationName = Release;\n"
        f"\t\t}};")
    return list_id


PROJECT_COMMON = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ANALYZER_NONNULL": "YES",
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES",
    "COPY_PHASE_STRIP": "NO",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
    "GCC_C_LANGUAGE_STANDARD": "gnu17",
    "GCC_NO_COMMON_BLOCKS": "YES",
    "GCC_WARN_UNDECLARED_SELECTOR": "YES",
    "GCC_WARN_UNUSED_FUNCTION": "YES",
    "GCC_WARN_UNUSED_VARIABLE": "YES",
    "LOCALIZATION_PREFERS_STRING_CATALOGS": "YES",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "SWIFT_VERSION": "5.0",
    "IPHONEOS_DEPLOYMENT_TARGET": IOS_TARGET,
    "WATCHOS_DEPLOYMENT_TARGET": WATCH_TARGET,
    # Ad-hoc signing: this project has no development team configured, which is
    # all a simulator build needs.
    "CODE_SIGN_IDENTITY": "-",
    "CODE_SIGN_STYLE": "Automatic",
    "DEVELOPMENT_TEAM": "",
    "MARKETING_VERSION": "1.0",
    "CURRENT_PROJECT_VERSION": "1",
}

PROJECT_DEBUG = dict(PROJECT_COMMON, **{
    "DEBUG_INFORMATION_FORMAT": "dwarf",
    "ENABLE_TESTABILITY": "YES",
    "GCC_OPTIMIZATION_LEVEL": "0",
    "GCC_PREPROCESSOR_DEFINITIONS": ["DEBUG=1", "$(inherited)"],
    "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
    "ONLY_ACTIVE_ARCH": "YES",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
    "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
})

PROJECT_RELEASE = dict(PROJECT_COMMON, **{
    "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
    "ENABLE_NS_ASSERTIONS": "NO",
    "MTL_ENABLE_DEBUG_INFO": "NO",
    "SWIFT_COMPILATION_MODE": "wholemodule",
    "SWIFT_OPTIMIZATION_LEVEL": "-O",
    "VALIDATE_PRODUCT": "YES",
})


def target(name, tag, product_type, product_ext, explicit_type, sources,
           resources, settings, dependencies=(), extra_phases=()):
    tid = ids.new(f"target:{tag}")
    prod = product_ref(name, product_ext, explicit_type)
    phases = [sources_phase(sources, tag), frameworks_phase(tag)]
    if resources:
        phases.append(resources_phase(resources, tag))
    phases.extend(extra_phases)
    cfg = config_list(f'PBXNativeTarget "{name}"', dict(settings), dict(settings))
    add(tid,
        f"{tid} /* {name} */ = {{\n"
        f"\t\t\tisa = PBXNativeTarget;\n"
        f"\t\t\tbuildConfigurationList = {cfg};\n"
        f"\t\t\tbuildPhases = (\n"
        + "".join(f"\t\t\t\t{p},\n" for p in phases) +
        f"\t\t\t);\n"
        f"\t\t\tbuildRules = (\n\t\t\t);\n"
        f"\t\t\tdependencies = (\n"
        + "".join(f"\t\t\t\t{d},\n" for d in dependencies) +
        f"\t\t\t);\n"
        f"\t\t\tname = {quoted(name)};\n"
        f"\t\t\tproductName = {quoted(name)};\n"
        f"\t\t\tproductReference = {prod};\n"
        f"\t\t\tproductType = {quoted(product_type)};\n"
        f"\t\t}};")
    return tid, prod


def dependency(target_id, target_name, project_id):
    proxy = ids.new(f"proxy:{target_name}")
    add(proxy,
        f"{proxy} /* PBXContainerItemProxy */ = {{\n"
        f"\t\t\tisa = PBXContainerItemProxy;\n"
        f"\t\t\tcontainerPortal = {project_id};\n"
        f"\t\t\tproxyType = 1;\n"
        f"\t\t\tremoteGlobalIDString = {target_id};\n"
        f"\t\t\tremoteInfo = {quoted(target_name)};\n"
        f"\t\t}};")
    dep = ids.new(f"dep:{target_name}")
    add(dep,
        f"{dep} /* PBXTargetDependency */ = {{\n"
        f"\t\t\tisa = PBXTargetDependency;\n"
        f"\t\t\ttarget = {target_id} /* {target_name} */;\n"
        f"\t\t\ttargetProxy = {proxy};\n"
        f"\t\t}};")
    return dep


# =============================================================== build project

def main():
    project_id = ids.new("project")

    # ---- targets, innermost first so products exist for embedding ----

    watch_widget_settings = {
        "CODE_SIGN_ENTITLEMENTS": "BeerChillerWatchWidget/BeerChillerWatchWidget.entitlements",
        "INFOPLIST_FILE": "BeerChillerWatchWidget/Info.plist",
        "GENERATE_INFOPLIST_FILE": "NO",
        "PRODUCT_BUNDLE_IDENTIFIER": f"{APP_BUNDLE_ID}.watchkitapp.widget",
        "PRODUCT_NAME": "BeerCHILLERWatchWidget",
        "SDKROOT": "watchos",
        "SUPPORTED_PLATFORMS": "watchsimulator watchos",
        "TARGETED_DEVICE_FAMILY": "4",
        "SKIP_INSTALL": "YES",
        "WATCHOS_DEPLOYMENT_TARGET": WATCH_TARGET,
        "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks",
                                    "@executable_path/../../Frameworks"],
        "SWIFT_VERSION": "5.0",
    }
    watch_widget_id, watch_widget_prod = target(
        "BeerCHILLERWatchWidget", "watchwidget",
        "com.apple.product-type.app-extension", "appex",
        '"wrapper.app-extension"',
        WATCH_WIDGET_SOURCES, WATCH_WIDGET_RESOURCES, watch_widget_settings)

    watch_settings = {
        "CODE_SIGN_ENTITLEMENTS": "BeerChillerWatch/BeerChillerWatch.entitlements",
        "INFOPLIST_FILE": "BeerChillerWatch/Info.plist",
        "GENERATE_INFOPLIST_FILE": "NO",
        "PRODUCT_BUNDLE_IDENTIFIER": f"{APP_BUNDLE_ID}.watchkitapp",
        "PRODUCT_NAME": "BeerCHILLERWatch",
        "SDKROOT": "watchos",
        "SUPPORTED_PLATFORMS": "watchsimulator watchos",
        "TARGETED_DEVICE_FAMILY": "4",
        "SKIP_INSTALL": "YES",
        "WATCHOS_DEPLOYMENT_TARGET": WATCH_TARGET,
        "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
        "SWIFT_VERSION": "5.0",
        "ENABLE_PREVIEWS": "YES",
    }
    watch_id, watch_prod = target(
        "BeerCHILLERWatch", "watch",
        "com.apple.product-type.application", "app",
        '"wrapper.application"',
        WATCH_SOURCES, WATCH_RESOURCES, watch_settings,
        dependencies=[dependency(watch_widget_id, "BeerCHILLERWatchWidget", project_id)],
        extra_phases=[embed_phase("Embed Foundation Extensions", "", 13,
                                  [(watch_widget_prod, "BeerCHILLERWatchWidget.appex")],
                                  "watch")])

    widget_settings = {
        "CODE_SIGN_ENTITLEMENTS": "BeerChillerWidget/BeerChillerWidget.entitlements",
        "INFOPLIST_FILE": "BeerChillerWidget/Info.plist",
        "GENERATE_INFOPLIST_FILE": "NO",
        "PRODUCT_BUNDLE_IDENTIFIER": f"{APP_BUNDLE_ID}.widget",
        "PRODUCT_NAME": "BeerCHILLERWidget",
        "SDKROOT": "iphoneos",
        "SUPPORTED_PLATFORMS": "iphonesimulator iphoneos",
        "TARGETED_DEVICE_FAMILY": "1,2",
        "SKIP_INSTALL": "YES",
        "IPHONEOS_DEPLOYMENT_TARGET": IOS_TARGET,
        "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks",
                                    "@executable_path/../../Frameworks"],
        "SWIFT_VERSION": "5.0",
    }
    widget_id, widget_prod = target(
        "BeerCHILLERWidget", "widget",
        "com.apple.product-type.app-extension", "appex",
        '"wrapper.app-extension"',
        WIDGET_SOURCES, WIDGET_RESOURCES, widget_settings)

    app_settings = {
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "",
        "CODE_SIGN_ENTITLEMENTS": "BeerChiller/BeerChiller.entitlements",
        "INFOPLIST_FILE": "BeerChiller/Info.plist",
        "GENERATE_INFOPLIST_FILE": "NO",
        "PRODUCT_BUNDLE_IDENTIFIER": APP_BUNDLE_ID,
        "PRODUCT_NAME": "BeerCHILLER",
        "PRODUCT_MODULE_NAME": "BeerCHILLER",
        "SDKROOT": "iphoneos",
        "SUPPORTED_PLATFORMS": "iphonesimulator iphoneos",
        "TARGETED_DEVICE_FAMILY": "1,2",
        "IPHONEOS_DEPLOYMENT_TARGET": IOS_TARGET,
        "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
        "SWIFT_VERSION": "5.0",
        "ENABLE_PREVIEWS": "YES",
        "SWIFT_EMIT_LOC_STRINGS": "YES",
    }
    app_dependencies = [dependency(widget_id, "BeerCHILLERWidget", project_id)]
    app_phases = [embed_phase("Embed Foundation Extensions", "", 13,
                              [(widget_prod, "BeerCHILLERWidget.appex")], "app")]
    if EMBED_WATCH:
        app_dependencies.append(dependency(watch_id, "BeerCHILLERWatch", project_id))
        app_phases.append(
            embed_phase("Embed Watch Content", "$(CONTENTS_FOLDER_PATH)/Watch", 16,
                        [(watch_prod, "BeerCHILLERWatch.app")], "app"))

    app_id, app_prod = target(
        "BeerCHILLER", "app",
        "com.apple.product-type.application", "app",
        '"wrapper.application"',
        APP_SOURCES, APP_RESOURCES, app_settings,
        dependencies=app_dependencies,
        extra_phases=app_phases)

    test_settings = {
        "BUNDLE_LOADER": "$(TEST_HOST)",
        "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/BeerCHILLER.app/BeerCHILLER",
        "GENERATE_INFOPLIST_FILE": "YES",
        "PRODUCT_BUNDLE_IDENTIFIER": f"{APP_BUNDLE_ID}.tests",
        "PRODUCT_NAME": "BeerCHILLERTests",
        "SDKROOT": "iphoneos",
        "SUPPORTED_PLATFORMS": "iphonesimulator iphoneos",
        "TARGETED_DEVICE_FAMILY": "1,2",
        "IPHONEOS_DEPLOYMENT_TARGET": IOS_TARGET,
        "SWIFT_VERSION": "5.0",
        "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks",
                                    "@loader_path/Frameworks"],
    }
    test_id, test_prod = target(
        "BeerCHILLERTests", "tests",
        "com.apple.product-type.bundle.unit-test", "xctest",
        '"wrapper.cfbundle"',
        TEST_SOURCES, [], test_settings,
        dependencies=[dependency(app_id, "BeerCHILLER", project_id)])

    ui_test_settings = {
        "TEST_TARGET_NAME": "BeerCHILLER",
        "GENERATE_INFOPLIST_FILE": "YES",
        "PRODUCT_BUNDLE_IDENTIFIER": f"{APP_BUNDLE_ID}.uitests",
        "PRODUCT_NAME": "BeerCHILLERUITests",
        "SDKROOT": "iphoneos",
        "SUPPORTED_PLATFORMS": "iphonesimulator iphoneos",
        "TARGETED_DEVICE_FAMILY": "1,2",
        "IPHONEOS_DEPLOYMENT_TARGET": IOS_TARGET,
        "SWIFT_VERSION": "5.0",
        "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks",
                                    "@loader_path/Frameworks"],
    }
    ui_test_id, ui_test_prod = target(
        "BeerCHILLERUITests", "uitests",
        "com.apple.product-type.bundle.ui-testing", "xctest",
        '"wrapper.cfbundle"',
        UI_TEST_SOURCES, [], ui_test_settings,
        dependencies=[dependency(app_id, "BeerCHILLER", project_id)])

    # ---- group tree ----

    shared_group = group("Shared", [file_ref(p) for p in
                                    SHARED_CORE + SHARED_ACTIVITY + SHARED_RUNTIME],
                         path="Shared")
    views_group = group("Views", [file_ref(p) for p in APP_SOURCES
                                  if p.startswith("BeerChiller/Views/")], path="Views")
    help_group = group("Help", [file_ref(p) for p in HELP_FILES], path="Help")
    app_group_node = group("BeerChiller", [
        file_ref("BeerChiller/BeerChillerApp.swift"),
        views_group,
        help_group,
        file_ref("BeerChiller/Assets.xcassets"),
        file_ref("BeerChiller/Localizable.xcstrings"),
        file_ref("BeerChiller/Info.plist"),
        file_ref("BeerChiller/BeerChiller.entitlements"),
    ], path="BeerChiller")
    widget_group = group("BeerChillerWidget", [
        file_ref(p) for p in WIDGET_SOURCES if p.startswith("BeerChillerWidget/")
    ] + [file_ref("BeerChillerWidget/Info.plist"),
         file_ref("BeerChillerWidget/BeerChillerWidget.entitlements")],
        path="BeerChillerWidget")
    watch_group = group("BeerChillerWatch", [
        file_ref(p) for p in WATCH_SOURCES if p.startswith("BeerChillerWatch/")
    ] + [file_ref("BeerChillerWatch/Info.plist"),
         file_ref("BeerChillerWatch/BeerChillerWatch.entitlements")],
        path="BeerChillerWatch")
    watch_widget_group = group("BeerChillerWatchWidget", [
        file_ref(p) for p in WATCH_WIDGET_SOURCES if p.startswith("BeerChillerWatchWidget/")
    ] + [file_ref("BeerChillerWatchWidget/Info.plist"),
         file_ref("BeerChillerWatchWidget/BeerChillerWatchWidget.entitlements")],
        path="BeerChillerWatchWidget")
    tests_group = group("Tests", [file_ref(p) for p in TEST_SOURCES], path="Tests")
    ui_tests_group = group("UITests", [file_ref(p) for p in UI_TEST_SOURCES],
                           path="UITests")
    products_group = group("Products", [app_prod, widget_prod, watch_prod,
                                        watch_widget_prod, test_prod, ui_test_prod])
    root_group = group(PROJECT_NAME, [
        shared_group, app_group_node, widget_group, watch_group,
        watch_widget_group, tests_group, ui_tests_group, products_group,
    ])

    project_cfg = config_list(f'PBXProject "{PROJECT_NAME}"',
                              PROJECT_DEBUG, PROJECT_RELEASE)

    add(project_id,
        f"{project_id} /* Project object */ = {{\n"
        f"\t\t\tisa = PBXProject;\n"
        f"\t\t\tattributes = {{\n"
        f"\t\t\t\tBuildIndependentTargetsInParallel = 1;\n"
        f"\t\t\t\tLastSwiftUpdateCheck = 1600;\n"
        f"\t\t\t\tLastUpgradeCheck = 1600;\n"
        f"\t\t\t\tTargetAttributes = {{\n"
        f"\t\t\t\t\t{test_id} = {{TestTargetID = {app_id};}};\n"
        f"\t\t\t\t\t{ui_test_id} = {{TestTargetID = {app_id};}};\n"
        f"\t\t\t\t}};\n"
        f"\t\t\t}};\n"
        f"\t\t\tbuildConfigurationList = {project_cfg};\n"
        f"\t\t\tcompatibilityVersion = \"Xcode 14.0\";\n"
        f"\t\t\tdevelopmentRegion = en;\n"
        f"\t\t\thasScannedForEncodings = 0;\n"
        f"\t\t\tknownRegions = (\n"
        + "".join(f"\t\t\t\t{r},\n" for r in
                  ["en", "Base", "cs", "de", "es", "fr", "hr", "it", "nl", "pl", "pt"]) +
        f"\t\t\t);\n"
        f"\t\t\tmainGroup = {root_group};\n"
        f"\t\t\tproductRefGroup = {products_group} /* Products */;\n"
        f"\t\t\tprojectDirPath = \"\";\n"
        f"\t\t\tprojectRoot = \"\";\n"
        f"\t\t\ttargets = (\n"
        f"\t\t\t\t{app_id} /* BeerCHILLER */,\n"
        f"\t\t\t\t{widget_id} /* BeerCHILLERWidget */,\n"
        f"\t\t\t\t{watch_id} /* BeerCHILLERWatch */,\n"
        f"\t\t\t\t{watch_widget_id} /* BeerCHILLERWatchWidget */,\n"
        f"\t\t\t\t{test_id} /* BeerCHILLERTests */,\n"
        f"\t\t\t\t{ui_test_id} /* BeerCHILLERUITests */,\n"
        f"\t\t\t);\n"
        f"\t\t}};")

    # ---- emit ----

    if os.path.isdir(PROJECT_DIR):
        shutil.rmtree(PROJECT_DIR)
    os.makedirs(os.path.join(PROJECT_DIR, "xcshareddata", "xcschemes"))

    body = "\n".join(f"\t\t{objects[k]}" for k in sorted(objects))
    pbxproj = (
        "// !$*UTF8*$!\n"
        "{\n"
        "\tarchiveVersion = 1;\n"
        "\tclasses = {\n\t};\n"
        "\tobjectVersion = 56;\n"
        "\tobjects = {\n"
        f"{body}\n"
        "\t};\n"
        f"\trootObject = {project_id} /* Project object */;\n"
        "}\n"
    )
    with open(os.path.join(PROJECT_DIR, "project.pbxproj"), "w") as handle:
        handle.write(pbxproj)

    write_scheme("BeerCHILLER", app_id, "BeerCHILLER.app",
                 [(test_id, "BeerCHILLERTests"), (ui_test_id, "BeerCHILLERUITests")])
    write_scheme("BeerCHILLERWatch", watch_id, "BeerCHILLERWatch.app")

    print(f"wrote {PROJECT_DIR}")
    print(f"objects: {len(objects)}   file refs: {len(file_refs)}")


def write_scheme(name, target_id, product_name, test_targets=None):
    test_action_targets = ""
    for test_id, test_name in (test_targets or []):
        test_action_targets += f"""
      <TestableReference skipped = "NO">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{test_id}"
            BuildableName = "{test_name}.xctest"
            BlueprintName = "{test_name}"
            ReferencedContainer = "container:{PROJECT_NAME}.xcodeproj">
         </BuildableReference>
      </TestableReference>"""

    scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1600" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{target_id}"
               BuildableName = "{product_name}"
               BlueprintName = "{name}"
               ReferencedContainer = "container:{PROJECT_NAME}.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>{test_action_targets}
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target_id}"
            BuildableName = "{product_name}"
            BlueprintName = "{name}"
            ReferencedContainer = "container:{PROJECT_NAME}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target_id}"
            BuildableName = "{product_name}"
            BlueprintName = "{name}"
            ReferencedContainer = "container:{PROJECT_NAME}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug"></AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES"></ArchiveAction>
</Scheme>
"""
    path = os.path.join(PROJECT_DIR, "xcshareddata", "xcschemes", f"{name}.xcscheme")
    with open(path, "w") as handle:
        handle.write(scheme)


if __name__ == "__main__":
    main()

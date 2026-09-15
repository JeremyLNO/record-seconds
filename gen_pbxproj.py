#!/usr/bin/env python3
"""Generate RecordSeconds.xcodeproj/project.pbxproj.

Recursively scans RecordSeconds/ for .swift files and mirrors the directory tree as
nested PBXGroups. Deterministic UUIDs (hash of a role key) so re-runs are stable and
diff-friendly. Single app target — no unit/UI test bundles, no extensions.

Depends on two remote Swift packages: OneSignal (push) and KitSwift (the shared
CrazyBeeLicense kit, a private repo). The OneSignal App ID lives in
Notifications/OneSignalConfig.swift; set it to nil and the SDK is never initialised.
"""
import os
import hashlib

ROOT = os.path.dirname(os.path.abspath(__file__))
PROJ = "RecordSeconds"
BUNDLE_ID = "company.lno.videoonesec"
DEVELOPMENT_TEAM = "2E6D4Q69QB"
SRC_DIR = "RecordSeconds"

# Plus aucun package local : le kit de licence était référencé par un chemin
# (`../crazybee-license-kit`), ce qui obligeait la CI à le cloner à côté du dépôt et
# faisait cohabiter un package local et un package distant dans le même graphe — la
# combinaison qui fige la résolution sur les runners GitHub (cf. la fiche mémoire
# testflight_ci_pieges). Il est désormais consommé comme n'importe quelle dépendance.
LOCAL_PACKAGES = []

# (name, repository URL, exact version, [product names]). Pinned to an exact version on
# OneSignal's Stable track — a version *range* resolves to their "Current" track instead.
# Only `OneSignalFramework` is linked (no InAppMessages / Location).
REMOTE_PACKAGES = [
    ("OneSignal-XCFramework", "https://github.com/OneSignal/OneSignal-XCFramework", "5.5.1", ["OneSignalFramework"]),
    # Dépôt privé : en local, le trousseau macOS fournit l'identifiant ; en CI, le PAT
    # est injecté par un `url.<...>.insteadOf` sur https://github.com/.
    ("KitSwift", "https://github.com/JeremyLNO/KitSwift.git", "1.0.0", ["CrazyBeeLicense"]),
]


def uid(key):
    return hashlib.md5(key.encode()).hexdigest()[:24].upper()


def find_swift_files(top_dir):
    results = []
    base = os.path.join(ROOT, top_dir)
    if not os.path.isdir(base):
        return results
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames.sort()
        rel_dir = os.path.relpath(dirpath, ROOT)
        for fn in sorted(filenames):
            if fn.endswith(".swift"):
                results.append(os.path.join(rel_dir, fn).replace(os.sep, "/"))
    return results


app_swift_files = find_swift_files(SRC_DIR)
assets_path = f"{SRC_DIR}/Assets.xcassets"
# Local StoreKit configuration. It is NOT a build resource — it is attached to the
# scheme below, which is the only thing that makes StoreKit Testing pick it up.
storekit_path = "VideoOneSec.storekit"

# ---- UUID registries -----------------------------------------------------
_group_uids = {}
_fileref_uids = {}


def group_uid(path):
    key = "group:" + path
    if key not in _group_uids:
        _group_uids[key] = uid(key)
    return _group_uids[key]


def fileref_uid(path):
    key = "fileref:" + path
    if key not in _fileref_uids:
        _fileref_uids[key] = uid(key)
    return _fileref_uids[key]


def build_tree(file_list):
    tree = {"files": [], "dirs": {}}
    for relpath in file_list:
        parts = relpath.split("/")
        node = tree
        for part in parts[:-1]:
            node = node["dirs"].setdefault(part, {"files": [], "dirs": {}})
        node["files"].append(parts[-1])
    return tree


prod_ref = uid("product.app")
main_group = uid("group.main")
products_group = uid("group.Products")
app_target = uid("target.app")
project_uid = uid("project")
sources_phase = uid("phase.sources")
resources_phase = uid("phase.resources")
frameworks_phase = uid("phase.frameworks")
app_cfg_list = uid("cfglist.app")
proj_cfg_list = uid("cfglist.project")

assets_ref = fileref_uid(assets_path)
storekit_ref = fileref_uid(storekit_path)
app_build_files = {f: uid("buildfile.app.sources." + f) for f in app_swift_files}
assets_build_file = uid("buildfile.assets")

pkg_refs = {}
product_deps = {}
product_build_files = {}
for name, path, products in LOCAL_PACKAGES:
    pkg_refs[name] = uid("pkgref." + name)
    for prod in products:
        product_deps[prod] = uid("proddep." + prod)
        product_build_files[prod] = uid("buildfile.product." + prod)
for name, url, version, products in REMOTE_PACKAGES:
    pkg_refs[name] = uid("pkgref." + name)
    for prod in products:
        product_deps[prod] = uid("proddep." + prod)
        product_build_files[prod] = uid("buildfile.product." + prod)

lines = []


def L(s=""):
    lines.append(s)


# ---- Recursive group emission ---------------------------------------------
_emitted_groups = set()


def emit_group(node, path_prefix, dir_name):
    my_path = f"{path_prefix}/{dir_name}" if path_prefix else dir_name
    this_uid = group_uid(my_path)
    if my_path in _emitted_groups:
        return this_uid
    _emitted_groups.add(my_path)

    child_refs = []
    for sub_name in sorted(node["dirs"].keys()):
        sub_uid = emit_group(node["dirs"][sub_name], my_path, sub_name)
        child_refs.append((sub_uid, sub_name))
    for fname in sorted(node["files"]):
        relpath = f"{my_path}/{fname}"
        child_refs.append((fileref_uid(relpath), fname))

    L('\t\t%s /* %s */ = {' % (this_uid, dir_name))
    L('\t\t\tisa = PBXGroup;')
    L('\t\t\tchildren = (')
    for child_uid, comment in child_refs:
        L('\t\t\t\t%s /* %s */,' % (child_uid, comment))
    L('\t\t\t);')
    L('\t\t\tpath = %s;' % dir_name)
    L('\t\t\tsourceTree = "<group>";')
    L('\t\t};')
    return this_uid


def emit_top_level_group(dir_name, file_list):
    tree = build_tree(file_list)
    node = tree.get("dirs", {}).get(dir_name, {"files": [], "dirs": {}})
    return emit_group(node, "", dir_name)


# ================================================================================
L("// !$*UTF8*$!")
L("{")
L("\tarchiveVersion = 1;")
L("\tclasses = {")
L("\t};")
L("\tobjectVersion = 56;")
L("\tobjects = {")

# ---- PBXBuildFile ----------------------------------------------------------
L("\n/* Begin PBXBuildFile section */")
for f in app_swift_files:
    L('\t\t%s /* %s in Sources */ = {isa = PBXBuildFile; fileRef = %s /* %s */; };' % (app_build_files[f], os.path.basename(f), fileref_uid(f), os.path.basename(f)))
L('\t\t%s /* Assets.xcassets in Resources */ = {isa = PBXBuildFile; fileRef = %s /* Assets.xcassets */; };' % (assets_build_file, assets_ref))
for prod, bf_uid in product_build_files.items():
    L('\t\t%s /* %s in Frameworks */ = {isa = PBXBuildFile; productRef = %s /* %s */; };' % (bf_uid, prod, product_deps[prod], prod))
L("/* End PBXBuildFile section */")

# ---- PBXFileReference -------------------------------------------------------
L("\n/* Begin PBXFileReference section */")
L('\t\t%s /* %s.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "%s.app"; sourceTree = BUILT_PRODUCTS_DIR; };' % (prod_ref, PROJ, PROJ))
for f in sorted(set(app_swift_files)):
    L('\t\t%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "%s"; sourceTree = "<group>"; };' % (fileref_uid(f), os.path.basename(f), os.path.basename(f)))
L('\t\t%s /* Assets.xcassets */ = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; };' % assets_ref)
L('\t\t%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = text; path = %s; sourceTree = "<group>"; };' % (storekit_ref, storekit_path, storekit_path))
L("/* End PBXFileReference section */")

# ---- PBXFrameworksBuildPhase ------------------------------------------------
L("\n/* Begin PBXFrameworksBuildPhase section */")
L('\t\t%s /* Frameworks */ = {' % frameworks_phase)
L('\t\t\tisa = PBXFrameworksBuildPhase;')
L('\t\t\tbuildActionMask = 2147483647;')
L('\t\t\tfiles = (')
for prod, bf_uid in product_build_files.items():
    L('\t\t\t\t%s /* %s in Frameworks */,' % (bf_uid, prod))
L('\t\t\t);')
L('\t\t\trunOnlyForDeploymentPostprocessing = 0;')
L('\t\t};')
L("/* End PBXFrameworksBuildPhase section */")

# ---- PBXGroup ---------------------------------------------------------------
L("\n/* Begin PBXGroup section */")
app_group_uid = emit_top_level_group(SRC_DIR, app_swift_files + [assets_path])

L('\t\t%s /* Products */ = {' % products_group)
L('\t\t\tisa = PBXGroup;')
L('\t\t\tchildren = (')
L('\t\t\t\t%s /* %s.app */,' % (prod_ref, PROJ))
L('\t\t\t);')
L('\t\t\tname = Products;')
L('\t\t\tsourceTree = "<group>";')
L('\t\t};')

L('\t\t%s = {' % main_group)
L('\t\t\tisa = PBXGroup;')
L('\t\t\tchildren = (')
L('\t\t\t\t%s /* %s */,' % (app_group_uid, SRC_DIR))
L('\t\t\t\t%s /* %s */,' % (storekit_ref, storekit_path))
L('\t\t\t\t%s /* Products */,' % products_group)
L('\t\t\t);')
L('\t\t\tsourceTree = "<group>";')
L('\t\t};')
L("/* End PBXGroup section */")

# ---- PBXNativeTarget ---------------------------------------------------------
L("\n/* Begin PBXNativeTarget section */")
L('\t\t%s /* %s */ = {' % (app_target, PROJ))
L('\t\t\tisa = PBXNativeTarget;')
L('\t\t\tbuildConfigurationList = %s /* Build configuration list for PBXNativeTarget "%s" */;' % (app_cfg_list, PROJ))
L('\t\t\tbuildPhases = (')
L('\t\t\t\t%s /* Sources */,' % sources_phase)
L('\t\t\t\t%s /* Frameworks */,' % frameworks_phase)
L('\t\t\t\t%s /* Resources */,' % resources_phase)
L('\t\t\t);')
L('\t\t\tbuildRules = (')
L('\t\t\t);')
L('\t\t\tdependencies = (')
L('\t\t\t);')
L('\t\t\tname = %s;' % PROJ)
L('\t\t\tpackageProductDependencies = (')
for prod, dep_uid in product_deps.items():
    L('\t\t\t\t%s /* %s */,' % (dep_uid, prod))
L('\t\t\t);')
L('\t\t\tproductName = %s;' % PROJ)
L('\t\t\tproductReference = %s /* %s.app */;' % (prod_ref, PROJ))
L('\t\t\tproductType = "com.apple.product-type.application";')
L('\t\t};')
L("/* End PBXNativeTarget section */")

# ---- PBXProject ---------------------------------------------------------------
L("\n/* Begin PBXProject section */")
L('\t\t%s /* Project object */ = {' % project_uid)
L('\t\t\tisa = PBXProject;')
L('\t\t\tattributes = {')
L('\t\t\t\tBuildIndependentTargetsInParallel = 1;')
L('\t\t\t\tLastSwiftUpdateCheck = 1620;')
L('\t\t\t\tLastUpgradeCheck = 1620;')
L('\t\t\t\tTargetAttributes = {')
L('\t\t\t\t\t%s = {' % app_target)
L('\t\t\t\t\t\tCreatedOnToolsVersion = 16.2;')
L('\t\t\t\t\t};')
L('\t\t\t\t};')
L('\t\t\t};')
L('\t\t\tbuildConfigurationList = %s /* Build configuration list for PBXProject "%s" */;' % (proj_cfg_list, PROJ))
L('\t\t\tcompatibilityVersion = "Xcode 14.0";')
L('\t\t\tdevelopmentRegion = en;')
L('\t\t\thasScannedForEncodings = 0;')
L('\t\t\tknownRegions = (')
for region in ["en", "fr", "es", "de", "pt", "Base"]:
    L('\t\t\t\t%s,' % region)
L('\t\t\t);')
L('\t\t\tmainGroup = %s;' % main_group)
L('\t\t\tpackageReferences = (')
for name, path, products in LOCAL_PACKAGES:
    L('\t\t\t\t%s /* XCLocalSwiftPackageReference "%s" */,' % (pkg_refs[name], path))
for name, url, version, products in REMOTE_PACKAGES:
    L('\t\t\t\t%s /* XCRemoteSwiftPackageReference "%s" */,' % (pkg_refs[name], name))
L('\t\t\t);')
L('\t\t\tproductRefGroup = %s /* Products */;' % products_group)
L('\t\t\tprojectDirPath = "";')
L('\t\t\tprojectRoot = "";')
L('\t\t\ttargets = (')
L('\t\t\t\t%s /* %s */,' % (app_target, PROJ))
L('\t\t\t);')
L('\t\t};')
L("/* End PBXProject section */")

# ---- XCLocalSwiftPackageReference / XCSwiftPackageProductDependency ----------
if LOCAL_PACKAGES:
    L("\n/* Begin XCLocalSwiftPackageReference section */")
    for name, path, products in LOCAL_PACKAGES:
        L('\t\t%s /* XCLocalSwiftPackageReference "%s" */ = {' % (pkg_refs[name], path))
        L('\t\t\tisa = XCLocalSwiftPackageReference;')
        L('\t\t\trelativePath = "%s";' % path)
        L('\t\t};')
    L("/* End XCLocalSwiftPackageReference section */")

# Les produits des DEUX sortes de packages vivent dans la même section. Elle était
# écrite sous `if LOCAL_PACKAGES:` — le jour où la liste locale s'est vidée, la section
# a disparu avec elle et les produits distants n'étaient plus liés à la cible, alors que
# la résolution, elle, réussissait : « Unable to resolve module dependency » à la
# compilation seulement.
if LOCAL_PACKAGES or REMOTE_PACKAGES:
    L("\n/* Begin XCSwiftPackageProductDependency section */")
    for name, path, products in LOCAL_PACKAGES:
        for prod in products:
            L('\t\t%s /* %s */ = {' % (product_deps[prod], prod))
            L('\t\t\tisa = XCSwiftPackageProductDependency;')
            L('\t\t\tpackage = %s /* XCLocalSwiftPackageReference "%s" */;' % (pkg_refs[name], path))
            L('\t\t\tproductName = %s;' % prod)
            L('\t\t};')
    for name, url, version, products in REMOTE_PACKAGES:
        for prod in products:
            L('\t\t%s /* %s */ = {' % (product_deps[prod], prod))
            L('\t\t\tisa = XCSwiftPackageProductDependency;')
            L('\t\t\tpackage = %s /* XCRemoteSwiftPackageReference "%s" */;' % (pkg_refs[name], name))
            L('\t\t\tproductName = %s;' % prod)
            L('\t\t};')
    L("/* End XCSwiftPackageProductDependency section */")

if REMOTE_PACKAGES:
    L("\n/* Begin XCRemoteSwiftPackageReference section */")
    for name, url, version, products in REMOTE_PACKAGES:
        L('\t\t%s /* XCRemoteSwiftPackageReference "%s" */ = {' % (pkg_refs[name], name))
        L('\t\t\tisa = XCRemoteSwiftPackageReference;')
        L('\t\t\trepositoryURL = "%s";' % url)
        L('\t\t\trequirement = {')
        L('\t\t\t\tkind = exactVersion;')
        L('\t\t\t\tversion = %s;' % version)
        L('\t\t\t};')
        L('\t\t};')
    L("/* End XCRemoteSwiftPackageReference section */")

# ---- PBXResourcesBuildPhase ---------------------------------------------------
L("\n/* Begin PBXResourcesBuildPhase section */")
L('\t\t%s /* Resources */ = {' % resources_phase)
L('\t\t\tisa = PBXResourcesBuildPhase;')
L('\t\t\tbuildActionMask = 2147483647;')
L('\t\t\tfiles = (')
L('\t\t\t\t%s /* Assets.xcassets in Resources */,' % assets_build_file)
L('\t\t\t);')
L('\t\t\trunOnlyForDeploymentPostprocessing = 0;')
L('\t\t};')
L("/* End PBXResourcesBuildPhase section */")

# ---- PBXSourcesBuildPhase ------------------------------------------------------
L("\n/* Begin PBXSourcesBuildPhase section */")
L('\t\t%s /* Sources */ = {' % sources_phase)
L('\t\t\tisa = PBXSourcesBuildPhase;')
L('\t\t\tbuildActionMask = 2147483647;')
L('\t\t\tfiles = (')
for f in app_swift_files:
    L('\t\t\t\t%s /* %s in Sources */,' % (app_build_files[f], os.path.basename(f)))
L('\t\t\t);')
L('\t\t\trunOnlyForDeploymentPostprocessing = 0;')
L('\t\t};')
L("/* End PBXSourcesBuildPhase section */")

# ---- XCBuildConfiguration -------------------------------------------------------
def proj_common():
    return [
        'ALWAYS_SEARCH_USER_PATHS = NO;',
        'CLANG_ANALYZER_NONNULL = YES;',
        'CLANG_ENABLE_MODULES = YES;',
        'CLANG_ENABLE_OBJC_ARC = YES;',
        'ENABLE_STRICT_OBJC_MSGSEND = YES;',
        'GCC_C_LANGUAGE_STANDARD = gnu17;',
        'GCC_NO_COMMON_BLOCKS = YES;',
        'IPHONEOS_DEPLOYMENT_TARGET = 17.0;',
        'MTL_FAST_MATH = YES;',
        'SDKROOT = iphoneos;',
        'SWIFT_EMIT_LOC_STRINGS = YES;',
        'SWIFT_VERSION = 5.0;',
    ]


def app_target_common():
    return [
        'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;',
        'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;',
        'CODE_SIGN_ENTITLEMENTS = RecordSeconds/RecordSeconds.entitlements;',
        'CODE_SIGN_STYLE = Automatic;',
        'CURRENT_PROJECT_VERSION = 1;',
        'DEVELOPMENT_TEAM = %s;' % DEVELOPMENT_TEAM,
        'ENABLE_PREVIEWS = YES;',
        'GENERATE_INFOPLIST_FILE = YES;',
        'INFOPLIST_KEY_CFBundleDisplayName = "Video One Sec";',
        # The app only uses standard HTTPS/TLS, no custom crypto — declaring this up
        # front stops App Store Connect asking the App Encryption Documentation
        # question on every upload. It must live HERE and not be hand-added to the
        # generated project.pbxproj: this script rewrites that file wholesale, so an
        # edit made there is silently dropped on the next run (which is exactly how
        # the prompt came back after commit 02aef36).
        'INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;',
        'INFOPLIST_KEY_NSCameraUsageDescription = "Video One Sec uses the camera to film your one-second clips.";',
        'INFOPLIST_KEY_NSMicrophoneUsageDescription = "Video One Sec uses the microphone to record sound with your clips.";',
        'INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription = "Video One Sec saves your exported movies to Photos.";',
        'INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;',
        'INFOPLIST_KEY_UILaunchScreen_Generation = YES;',
        'INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;',
        'LD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/Frameworks");',
        'MARKETING_VERSION = 1.0;',
        'PRODUCT_BUNDLE_IDENTIFIER = %s;' % BUNDLE_ID,
        'PRODUCT_NAME = "$(TARGET_NAME)";',
        'TARGETED_DEVICE_FAMILY = 1;',
    ]


ENVIRONMENTS = ["Debug", "Release"]

L("\n/* Begin XCBuildConfiguration section */")
for env_name in ENVIRONMENTS:
    cfg_uid = uid("cfg.proj." + env_name)
    L('\t\t%s /* %s */ = {' % (cfg_uid, env_name))
    L('\t\t\tisa = XCBuildConfiguration;')
    L('\t\t\tbuildSettings = {')
    for s in proj_common():
        L('\t\t\t\t' + s)
    if env_name == "Debug":
        L('\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;')
        L('\t\t\t\tENABLE_TESTABILITY = YES;')
        L('\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;')
        L('\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = ("DEBUG=1", "$(inherited)");')
        L('\t\t\t\tONLY_ACTIVE_ARCH = YES;')
        L('\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";')
        L('\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";')
    else:
        L('\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";')
        L('\t\t\t\tENABLE_NS_ASSERTIONS = NO;')
        L('\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;')
    L('\t\t\t};')
    L('\t\t\tname = %s;' % env_name)
    L('\t\t};')

for env_name in ENVIRONMENTS:
    cfg_uid = uid("cfg.app." + env_name)
    L('\t\t%s /* %s */ = {' % (cfg_uid, env_name))
    L('\t\t\tisa = XCBuildConfiguration;')
    L('\t\t\tbuildSettings = {')
    for s in app_target_common():
        L('\t\t\t\t' + s)
    L('\t\t\t};')
    L('\t\t\tname = %s;' % env_name)
    L('\t\t};')
L("/* End XCBuildConfiguration section */")

# ---- XCConfigurationList --------------------------------------------------------
L("\n/* Begin XCConfigurationList section */")
def emit_cfg_list(list_uid, comment, prefix):
    L('\t\t%s /* %s */ = {' % (list_uid, comment))
    L('\t\t\tisa = XCConfigurationList;')
    L('\t\t\tbuildConfigurations = (')
    for env_name in ENVIRONMENTS:
        L('\t\t\t\t%s /* %s */,' % (uid(prefix + env_name), env_name))
    L('\t\t\t);')
    L('\t\t\tdefaultConfigurationIsVisible = 0;')
    L('\t\t\tdefaultConfigurationName = Release;')
    L('\t\t};')

emit_cfg_list(proj_cfg_list, 'Build configuration list for PBXProject "%s"' % PROJ, "cfg.proj.")
emit_cfg_list(app_cfg_list, 'Build configuration list for PBXNativeTarget "%s"' % PROJ, "cfg.app.")
L("/* End XCConfigurationList section */")

L("\t};")
L('\trootObject = %s /* Project object */;' % project_uid)
L("}")

out_dir = os.path.join(ROOT, "%s.xcodeproj" % PROJ)
os.makedirs(out_dir, exist_ok=True)
with open(os.path.join(out_dir, "project.pbxproj"), "w") as fh:
    fh.write("\n".join(lines) + "\n")

# ---- Shared scheme --------------------------------------------------------
def buildable_ref(blueprint_id, name):
    return (
        '            <BuildableReference\n'
        '               BuildableIdentifier = "primary"\n'
        '               BlueprintIdentifier = "%s"\n'
        '               BuildableName = "%s"\n'
        '               BlueprintName = "%s"\n'
        '               ReferencedContainer = "container:%s.xcodeproj">\n'
        '            </BuildableReference>\n'
    ) % (blueprint_id, name, name.rsplit(".", 1)[0], PROJ)


scheme_xml = (
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<Scheme LastUpgradeVersion = "1620" version = "1.7">\n'
    '   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">\n'
    '      <BuildActionEntries>\n'
    '         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">\n'
    + buildable_ref(app_target, PROJ + ".app") +
    '         </BuildActionEntry>\n'
    '      </BuildActionEntries>\n'
    '   </BuildAction>\n'
    '   <LaunchAction\n'
    '      buildConfiguration = "Debug"\n'
    '      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"\n'
    '      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"\n'
    '      launchStyle = "0"\n'
    '      useCustomWorkingDirectory = "NO"\n'
    '      ignoresPersistentStateOnLaunch = "NO"\n'
    '      debugDocumentVersioning = "YES"\n'
    '      debugServiceExtension = "internal"\n'
    '      allowLocationSimulation = "YES">\n'
    # Without this, StoreKit returns no products when running from Xcode/the Simulator:
    # the local configuration is bound to the scheme, not to the target.
    '      <StoreKitConfigurationFileReference\n'
    '         identifier = "../../../VideoOneSec.storekit">\n'
    '      </StoreKitConfigurationFileReference>\n'
    '      <BuildableProductRunnable runnableDebuggingMode = "0">\n'
    + buildable_ref(app_target, PROJ + ".app") +
    '      </BuildableProductRunnable>\n'
    '   </LaunchAction>\n'
    '   <ArchiveAction\n'
    '      buildConfiguration = "Release"\n'
    '      revealArchiveInOrganizer = "YES">\n'
    '   </ArchiveAction>\n'
    '</Scheme>\n'
)

scheme_dir = os.path.join(out_dir, "xcshareddata", "xcschemes")
os.makedirs(scheme_dir, exist_ok=True)
with open(os.path.join(scheme_dir, f"{PROJ}.xcscheme"), "w") as fh:
    fh.write(scheme_xml)

print(f"Wrote {out_dir}/project.pbxproj — {len(app_swift_files)} Swift files")

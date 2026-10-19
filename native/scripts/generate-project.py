"""Generate the dependency-free app project; SanjuCore is a local Swift package."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[1]
project = root / "Sanju.xcodeproj"
project.mkdir(exist_ok=True)
objects = {}

def uid(name):
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()

def q(value):
    return json.dumps(str(value), ensure_ascii=False)

def add(key, isa, **fields):
    ident = uid(key)
    objects[ident] = {"isa": isa, **fields}
    return ident

class Raw(str):
    pass

def serialize(value, level=0):
    if isinstance(value, Raw):
        return value
    if isinstance(value, dict):
        return "{\n" + "\n".join("\t" * (level + 1) + str(k) + " = " + serialize(v, level + 1) + ";" for k, v in value.items()) + "\n" + "\t" * level + "}"
    if isinstance(value, list):
        return "(" + ", ".join(serialize(v, level) for v in value) + ")"
    return q(value)

sources, children = [], []
for path in sorted((root / "Sanju").glob("*.swift")):
    ref = add(str(path.name), "PBXFileReference", lastKnownFileType="sourcecode.swift", path=path.name, sourceTree="<group>")
    children.append(Raw(ref))
    sources.append(Raw(add(path.name + ":build", "PBXBuildFile", fileRef=Raw(ref))))

asset = add("assets", "PBXFileReference", lastKnownFileType="folder.assetcatalog", path="Assets.xcassets", sourceTree="<group>")
children.append(Raw(asset))
children.append(Raw(add("info", "PBXFileReference", lastKnownFileType="text.plist.xml", path="Info.plist", sourceTree="<group>")))
assetbuild = add("assets:build", "PBXBuildFile", fileRef=Raw(asset))
privacyref = add("privacy", "PBXFileReference", lastKnownFileType="text.xml", path="PrivacyInfo.xcprivacy", sourceTree="<group>")
children.append(Raw(privacyref))
privacybuild = add("privacy:build", "PBXBuildFile", fileRef=Raw(privacyref))
fontbuilds = []
for path in sorted((root / "Sanju/Fonts").glob("*")):
    if not path.is_file():
        continue
    ref = add("font:" + path.name, "PBXFileReference", lastKnownFileType="file", path="Fonts/" + path.name, sourceTree="<group>")
    children.append(Raw(ref))
    fontbuilds.append(Raw(add("font:build:" + path.name, "PBXBuildFile", fileRef=Raw(ref))))
product = add("product", "PBXFileReference", explicitFileType="wrapper.application", path="Sanju.app", includeInIndex="0", sourceTree="BUILT_PRODUCTS_DIR")
sourcegroup = add("sourcegroup", "PBXGroup", path="Sanju", children=children, sourceTree="<group>")
productgroup = add("productgroup", "PBXGroup", name="Products", children=[Raw(product)], sourceTree="<group>")
localconfig = add("localconfig", "PBXFileReference", lastKnownFileType="text.xcconfig", path="Config/LocalOverrides.xcconfig", sourceTree="<group>")
main = add("main", "PBXGroup", children=[Raw(sourcegroup), Raw(productgroup), Raw(localconfig)], sourceTree="<group>")
package = add("package", "XCLocalSwiftPackageReference", relativePath="SanjuCore")
dependency = add("dependency", "XCSwiftPackageProductDependency", package=Raw(package), productName="SanjuCore")
link = add("link", "PBXBuildFile", productRef=Raw(dependency))
buildsources = add("sources", "PBXSourcesBuildPhase", buildActionMask="2147483647", files=sources, runOnlyForDeploymentPostprocessing="0")
frameworks = add("frameworks", "PBXFrameworksBuildPhase", buildActionMask="2147483647", files=[Raw(link)], runOnlyForDeploymentPostprocessing="0")
resources = add("resources", "PBXResourcesBuildPhase", buildActionMask="2147483647", files=[Raw(assetbuild), Raw(privacybuild), *fontbuilds], runOnlyForDeploymentPostprocessing="0")
configs, targetconfigs = [], []
for config in ["Debug", "Preview", "Release"]:
    flags = "DEBUG" if config == "Debug" else "SANJU_PREVIEW" if config == "Preview" else ""
    common = dict(SDKROOT="iphoneos", IPHONEOS_DEPLOYMENT_TARGET="17.0", CLANG_ENABLE_MODULES="YES", CLANG_ENABLE_OBJC_ARC="YES", SWIFT_VERSION="5.0", ONLY_ACTIVE_ARCH="YES" if config != "Release" else "NO", SWIFT_OPTIMIZATION_LEVEL="-Onone" if config == "Debug" else "-O", DEBUG_INFORMATION_FORMAT="dwarf" if config == "Debug" else "dwarf-with-dsym", ENABLE_TESTABILITY="YES" if config == "Debug" else "NO", SWIFT_ACTIVE_COMPILATION_CONDITIONS=flags)
    configs.append(Raw(add("project:" + config, "XCBuildConfiguration", buildSettings=common, baseConfigurationReference=Raw(localconfig), name=config)))
    settings = dict(ASSETCATALOG_COMPILER_APPICON_NAME="AppIcon", ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME="AccentColor", CODE_SIGN_STYLE="Automatic", CURRENT_PROJECT_VERSION="1", GENERATE_INFOPLIST_FILE="NO", INFOPLIST_FILE="Sanju/Info.plist", PRODUCT_BUNDLE_IDENTIFIER="$(SANJU_BUNDLE_ID)", PRODUCT_NAME="Sanju", TARGETED_DEVICE_FAMILY="1", MARKETING_VERSION="0.1.0", SWIFT_EMIT_LOC_STRINGS="YES", LD_RUNPATH_SEARCH_PATHS=["$(inherited)", "@executable_path/Frameworks"], SUPPORTED_PLATFORMS="iphoneos iphonesimulator", ENABLE_PREVIEWS="YES", ENABLE_DEBUG_DYLIB="NO")
    settings["SANJU_DISPLAY_NAME"] = "三句·原生预览" if config == "Preview" else "三句·原生开发" if config == "Debug" else "三句"
    targetconfigs.append(Raw(add("target:" + config, "XCBuildConfiguration", buildSettings=settings, name=config)))
configlist = add("projectconfigs", "XCConfigurationList", buildConfigurations=configs, defaultConfigurationIsVisible="0", defaultConfigurationName="Release")
targetconfiglist = add("targetconfigs", "XCConfigurationList", buildConfigurations=targetconfigs, defaultConfigurationIsVisible="0", defaultConfigurationName="Release")
target = add("target", "PBXNativeTarget", buildConfigurationList=Raw(targetconfiglist), buildPhases=[Raw(buildsources), Raw(frameworks), Raw(resources)], buildRules=[], dependencies=[], name="Sanju", productName="Sanju", productReference=Raw(product), productType="com.apple.product-type.application", packageProductDependencies=[Raw(dependency)])
testref = add("uitestfile", "PBXFileReference", lastKnownFileType="sourcecode.swift", path="CoreFlowTests.swift", sourceTree="<group>")
testgroup = add("uitestgroup", "PBXGroup", path="SanjuUITests", children=[Raw(testref)], sourceTree="<group>")
objects[main]["children"].insert(1, Raw(testgroup))
testproduct = add("uitestproduct", "PBXFileReference", explicitFileType="wrapper.cfbundle", path="SanjuUITests.xctest", sourceTree="BUILT_PRODUCTS_DIR")
objects[productgroup]["children"].append(Raw(testproduct))
testsource = add("uitestsources", "PBXSourcesBuildPhase", buildActionMask="2147483647", files=[Raw(add("uitestbuild", "PBXBuildFile", fileRef=Raw(testref)))], runOnlyForDeploymentPostprocessing="0")
testconfigs = []
for config in ["Debug", "Preview", "Release"]:
    settings = dict(GENERATE_INFOPLIST_FILE="YES", PRODUCT_BUNDLE_IDENTIFIER="$(SANJU_BUNDLE_ID).uitests", PRODUCT_NAME="$(TARGET_NAME)", TEST_TARGET_NAME="Sanju", TARGETED_DEVICE_FAMILY="1", CODE_SIGN_STYLE="Automatic")
    testconfigs.append(Raw(add("uitestconfig:" + config, "XCBuildConfiguration", buildSettings=settings, name=config)))
testconfiglist = add("uitestconfigs", "XCConfigurationList", buildConfigurations=testconfigs, defaultConfigurationIsVisible="0", defaultConfigurationName="Release")
proxy = add("uitestproxy", "PBXContainerItemProxy", containerPortal=Raw(uid("project")), proxyType="1", remoteGlobalIDString=Raw(target), remoteInfo="Sanju")
testdependency = add("uitestdependency", "PBXTargetDependency", target=Raw(target), targetProxy=Raw(proxy))
testtarget = add("uitesttarget", "PBXNativeTarget", buildConfigurationList=Raw(testconfiglist), buildPhases=[Raw(testsource)], buildRules=[], dependencies=[Raw(testdependency)], name="SanjuUITests", productName="SanjuUITests", productReference=Raw(testproduct), productType="com.apple.product-type.bundle.ui-testing")
projectid = add("project", "PBXProject", attributes={"LastUpgradeCheck": "2700", "TargetAttributes": {target: {"CreatedOnToolsVersion": "27.0", "ProvisioningStyle": "Automatic"}, testtarget: {"CreatedOnToolsVersion": "27.0", "TestTargetID": Raw(target)}}}, buildConfigurationList=Raw(configlist), compatibilityVersion="Xcode 14.0", developmentRegion="zh-Hans", knownRegions=["zh-Hans", "en", "Base"], mainGroup=Raw(main), productRefGroup=Raw(productgroup), projectDirPath="", projectRoot="", packageReferences=[Raw(package)], targets=[Raw(target), Raw(testtarget)])
document = {"archiveVersion": "1", "classes": {}, "objectVersion": "56", "objects": {Raw(k): v for k, v in objects.items()}, "rootObject": Raw(projectid)}
(project / "project.pbxproj").write_text("// !$*UTF8*$!\n" + serialize(document) + "\n")

for name, demo, config in [("Sanju", False, "Debug"), ("Sanju Demo", True, "Debug"), ("Sanju Preview", True, "Preview")]:
    folder = project / "xcshareddata" / "xcschemes"
    folder.mkdir(parents=True, exist_ok=True)
    ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="Sanju.app" BlueprintName="Sanju" ReferencedContainer="container:Sanju.xcodeproj"/>'
    debugger = "Xcode.DebuggerFoundation.Debugger.LLDB" if config == "Debug" else ""
    launcher = "Xcode.IDEFoundation.Launcher.LLDB" if config == "Debug" else "Xcode.IDEFoundation.Launcher.PosixSpawn"
    scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{testtarget}" BuildableName="SanjuUITests.xctest" BlueprintName="SanjuUITests" ReferencedContainer="container:Sanju.xcodeproj"/></TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="{config}" selectedDebuggerIdentifier="{debugger}" selectedLauncherIdentifier="{launcher}" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable><CommandLineArguments><CommandLineArgument argument="--demo" isEnabled="{'YES' if demo else 'NO'}"/></CommandLineArguments></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
    (folder / f"{name}.xcscheme").write_text(scheme)
print(project)

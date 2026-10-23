#!/usr/bin/env python3
"""Generate the dependency-free Xcode project. Run after adding app source files."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[1]
objects = {}

def uid(value):
    return hashlib.sha1(value.encode()).hexdigest()[:24].upper()

def q(value):
    return json.dumps(str(value), ensure_ascii=False)

def obj(name, text):
    ident = uid(name)
    objects[ident] = text
    return ident

def array(items):
    return '(' + ', '.join(items) + (',' if items else '') + ')'

sources = []
resources = []
refs = []
for path in sorted((root / 'Momi').rglob('*')):
    if not path.is_file() or path.suffix != '.swift':
        continue
    relative = path.relative_to(root)
    ref = obj('file:' + str(relative), f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(relative)}; sourceTree = "<group>";')
    refs.append(ref)
    sources.append(obj('build:' + str(relative), f'isa = PBXBuildFile; fileRef = {ref};'))

for name, kind in [('Momi/Resources/Assets.xcassets', 'folder.assetcatalog'), ('Momi/Resources/PrivacyInfo.xcprivacy', 'text.xml')]:
    ref = obj('file:' + name, f'isa = PBXFileReference; lastKnownFileType = {kind}; path = {q(name)}; sourceTree = "<group>";')
    refs.append(ref)
    resources.append(obj('build:' + name, f'isa = PBXBuildFile; fileRef = {ref};'))

info = obj('info', 'isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = "Momi/Info.plist"; sourceTree = "<group>";')
refs.append(info)
product = obj('product', 'isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Momi.app; sourceTree = BUILT_PRODUCTS_DIR;')
productGroup = obj('products', f'isa = PBXGroup; children = {array([product])}; name = Products; sourceTree = "<group>";')
mainGroup = obj('main', f'isa = PBXGroup; children = {array(refs + [productGroup])}; sourceTree = "<group>";')
package = obj('package', 'isa = XCLocalSwiftPackageReference; relativePath = MomiCore;')
dependency = obj('dependency', f'isa = XCSwiftPackageProductDependency; package = {package}; productName = MomiCore;')
packageBuild = obj('packageBuild', f'isa = PBXBuildFile; productRef = {dependency};')
sourcePhase = obj('sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {array(sources)}; runOnlyForDeploymentPostprocessing = 0;')
resourcePhase = obj('resources', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {array(resources)}; runOnlyForDeploymentPostprocessing = 0;')
frameworkPhase = obj('frameworks', f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = {array([packageBuild])}; runOnlyForDeploymentPostprocessing = 0;')

configs, projectConfigs = [], []
for name in ['Debug', 'Release']:
    settings = {
        'PRODUCT_NAME': '$(TARGET_NAME)', 'PRODUCT_BUNDLE_IDENTIFIER': 'com.personal.momi',
        'INFOPLIST_FILE': 'Momi/Info.plist', 'GENERATE_INFOPLIST_FILE': 'NO',
        'IPHONEOS_DEPLOYMENT_TARGET': '18.0', 'SDKROOT': 'iphoneos',
        'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator', 'TARGETED_DEVICE_FAMILY': '1',
        'SWIFT_VERSION': '6.0', 'SWIFT_STRICT_CONCURRENCY': 'complete',
        'CODE_SIGN_STYLE': 'Automatic', 'DEVELOPMENT_TEAM': '',
        'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME': 'AccentColor',
        'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon',
        'SWIFT_EMIT_LOC_STRINGS': 'YES', 'ENABLE_USER_SCRIPT_SANDBOXING': 'YES',
        'LD_RUNPATH_SEARCH_PATHS': '$(inherited) @executable_path/Frameworks',
        'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if name == 'Debug' else '-O',
    }
    if name == 'Debug':
        settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG'
        settings['ENABLE_TESTABILITY'] = 'YES'
    configs.append(obj('targetconfig:' + name, 'isa = XCBuildConfiguration; name = ' + name + '; buildSettings = {' + ''.join(f'{k} = {q(v)};' for k, v in settings.items()) + '};'))
    projectConfigs.append(obj('projectconfig:' + name, f'isa = XCBuildConfiguration; name = {name}; buildSettings = {{ CLANG_ENABLE_MODULES = YES; CLANG_ENABLE_OBJC_ARC = YES; }};'))

targetConfig = obj('targetconfigs', f'isa = XCConfigurationList; buildConfigurations = {array(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
projectConfig = obj('projectconfigs', f'isa = XCConfigurationList; buildConfigurations = {array(projectConfigs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target = obj('target', f'isa = PBXNativeTarget; buildConfigurationList = {targetConfig}; buildPhases = {array([sourcePhase, frameworkPhase, resourcePhase])}; buildRules = (); dependencies = (); name = Momi; packageProductDependencies = {array([dependency])}; productName = Momi; productReference = {product}; productType = "com.apple.product-type.application";')
project = obj('project', f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; TargetAttributes = {{ {target} = {{ CreatedOnToolsVersion = 16.0; }}; }}; }}; buildConfigurationList = {projectConfig}; compatibilityVersion = "Xcode 14.0"; developmentRegion = vi; hasScannedForEncodings = 0; knownRegions = (vi, en, Base); mainGroup = {mainGroup}; packageReferences = {array([package])}; productRefGroup = {productGroup}; projectDirPath = ""; projectRoot = ""; targets = {array([target])};')
directory = root / 'Momi.xcodeproj'
directory.mkdir(exist_ok=True)
(directory / 'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n' + '\n'.join(f'{key} = {{ {value} }};' for key, value in objects.items()) + f'\n}}; rootObject = {project}; }}\n')
schemes = directory / 'xcshareddata/xcschemes'
schemes.mkdir(parents=True, exist_ok=True)
reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="Momi.app" BlueprintName="Momi" ReferencedContainer="container:Momi.xcodeproj"/>'
(schemes / 'Momi.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables/></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print(f'Generated Momi.xcodeproj with {len(sources)} Swift app files.')

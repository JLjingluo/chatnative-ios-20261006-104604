#!/usr/bin/env python3
"""Generate a dependency-free Xcode project. No XcodeGen installation required."""
from pathlib import Path
import hashlib
import json
import plistlib
import math

ROOT = Path(__file__).resolve().parents[1]
objects = {}
def uid(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def obj(name, isa, body):
    key = uid(name)
    objects[key] = f'isa = {isa}; {body}'
    return key
def refs(values): return '(' + ', '.join(values) + (',' if values else '') + ')'
def quote(value): return json.dumps(str(value))

app_sources = sorted((ROOT / 'ChatNative').rglob('*.swift'))
test_sources = sorted((ROOT / 'ChatNativeTests').glob('*.swift'))
source_refs = []
app_build = []
test_build = []
for file in app_sources + test_sources:
    path = file.relative_to(ROOT).as_posix()
    ref = obj(path, 'PBXFileReference', f'lastKnownFileType = sourcecode.swift; path = {quote(path)}; sourceTree = SOURCE_ROOT;')
    source_refs.append(ref)
    build = obj('build:' + path, 'PBXBuildFile', f'fileRef = {ref};')
    (app_build if file in app_sources else test_build).append(build)
resources = []
for path, kind in [('ChatNative/Resources/Assets.xcassets', 'folder.assetcatalog'), ('ChatNative/Resources/PrivacyInfo.xcprivacy', 'text.xml'), ('ChatNative/Resources/ThirdPartyNotices.txt', 'text')]:
    ref = obj(path, 'PBXFileReference', f'lastKnownFileType = {kind}; path = {quote(path)}; sourceTree = SOURCE_ROOT;')
    source_refs.append(ref)
    resources.append(obj('build:' + path, 'PBXBuildFile', f'fileRef = {ref};'))
info = obj('info', 'PBXFileReference', 'lastKnownFileType = text.plist.xml; path = "ChatNative/Resources/Info.plist"; sourceTree = SOURCE_ROOT;')
source_refs.append(info)
app_product = obj('app-product', 'PBXFileReference', 'explicitFileType = wrapper.application; path = ChatNative.app; sourceTree = BUILT_PRODUCTS_DIR;')
test_product = obj('test-product', 'PBXFileReference', 'explicitFileType = wrapper.cfbundle; path = ChatNativeTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
products = obj('products', 'PBXGroup', f'children = {refs([app_product, test_product])}; name = Products; sourceTree = "<group>";')
main = obj('main', 'PBXGroup', f'children = {refs(source_refs + [products])}; sourceTree = "<group>";')
ui_package = obj('chatgptui-package', 'XCRemoteSwiftPackageReference', 'repositoryURL = "https://github.com/alfianlosari/ChatGPTUI.git"; requirement = { kind = revision; revision = 6092433201dc6a0787240b9252914fc2fe64456b; };')
markdown_package = obj('markdown-package', 'XCRemoteSwiftPackageReference', 'repositoryURL = "https://github.com/apple/swift-markdown.git"; requirement = { kind = upToNextMajorVersion; minimumVersion = 0.4.0; };')
ui_product = obj('chatgptui-product', 'XCSwiftPackageProductDependency', f'package = {ui_package}; productName = ChatGPTUI;')
markdown_product = obj('markdown-product', 'XCSwiftPackageProductDependency', f'package = {markdown_package}; productName = Markdown;')
package_builds = [obj('build-chatgptui-package', 'PBXBuildFile', f'productRef = {ui_product};'), obj('build-markdown-package', 'PBXBuildFile', f'productRef = {markdown_product};')]
app_phases = [obj('app-sources', 'PBXSourcesBuildPhase', f'buildActionMask = 2147483647; files = {refs(app_build)}; runOnlyForDeploymentPostprocessing = 0;'), obj('app-frameworks', 'PBXFrameworksBuildPhase', f'buildActionMask = 2147483647; files = {refs(package_builds)}; runOnlyForDeploymentPostprocessing = 0;'), obj('app-resources', 'PBXResourcesBuildPhase', f'buildActionMask = 2147483647; files = {refs(resources)}; runOnlyForDeploymentPostprocessing = 0;')]
test_phases = [obj('test-sources', 'PBXSourcesBuildPhase', f'buildActionMask = 2147483647; files = {refs(test_build)}; runOnlyForDeploymentPostprocessing = 0;'), obj('test-frameworks', 'PBXFrameworksBuildPhase', 'buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')]

def config_list(prefix, settings):
    configurations = []
    for mode in ['Debug', 'Release']:
        merged = dict(settings)
        merged.update({'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if mode == 'Debug' else '-O', 'DEBUG_INFORMATION_FORMAT': 'dwarf' if mode == 'Debug' else 'dwarf-with-dsym', 'ONLY_ACTIVE_ARCH': 'YES' if mode == 'Debug' else 'NO'})
        if mode == 'Debug': merged.update({'ENABLE_TESTABILITY': 'YES', 'SWIFT_ACTIVE_COMPILATION_CONDITIONS': 'DEBUG'})
        entries = ' '.join(f'{key} = {quote(value)};' for key, value in merged.items())
        configurations.append(obj(prefix + mode, 'XCBuildConfiguration', f'buildSettings = {{ {entries} }}; name = {mode};'))
    return obj(prefix + '-list', 'XCConfigurationList', f'buildConfigurations = {refs(configurations)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')

common = {'SDKROOT': 'iphoneos', 'IPHONEOS_DEPLOYMENT_TARGET': '17.0', 'SWIFT_VERSION': '5.0', 'CLANG_ENABLE_MODULES': 'YES', 'CLANG_ENABLE_OBJC_ARC': 'YES', 'SWIFT_STRICT_CONCURRENCY': 'targeted'}
project_configs = config_list('project-', common)
app_configs = config_list('app-', {'PRODUCT_NAME': '$(TARGET_NAME)', 'PRODUCT_BUNDLE_IDENTIFIER': 'app.chatnative.ios', 'INFOPLIST_FILE': 'ChatNative/Resources/Info.plist', 'GENERATE_INFOPLIST_FILE': 'NO', 'CODE_SIGN_STYLE': 'Automatic', 'TARGETED_DEVICE_FAMILY': '1,2', 'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator', 'MARKETING_VERSION': '1.1.0', 'CURRENT_PROJECT_VERSION': '2', 'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon', 'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME': 'AccentColor', 'LD_RUNPATH_SEARCH_PATHS': '$(inherited) @executable_path/Frameworks', 'SUPPORTS_MACCATALYST': 'NO'})
test_configs = config_list('test-', {'PRODUCT_NAME': '$(TARGET_NAME)', 'PRODUCT_BUNDLE_IDENTIFIER': 'app.chatnative.ios.tests', 'GENERATE_INFOPLIST_FILE': 'YES', 'CODE_SIGN_STYLE': 'Automatic', 'TARGETED_DEVICE_FAMILY': '1,2', 'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator', 'TEST_HOST': '$(BUILT_PRODUCTS_DIR)/ChatNative.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/ChatNative', 'BUNDLE_LOADER': '$(TEST_HOST)', 'LD_RUNPATH_SEARCH_PATHS': '$(inherited) @executable_path/Frameworks @loader_path/Frameworks'})
app_target = obj('app-target', 'PBXNativeTarget', f'buildConfigurationList = {app_configs}; buildPhases = {refs(app_phases)}; buildRules = (); dependencies = (); packageProductDependencies = {refs([ui_product, markdown_product])}; name = ChatNative; productName = ChatNative; productReference = {app_product}; productType = "com.apple.product-type.application";')
proxy = obj('proxy', 'PBXContainerItemProxy', f'containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {app_target}; remoteInfo = ChatNative;')
dependency = obj('dependency', 'PBXTargetDependency', f'target = {app_target}; targetProxy = {proxy};')
test_target = obj('test-target', 'PBXNativeTarget', f'buildConfigurationList = {test_configs}; buildPhases = {refs(test_phases)}; buildRules = (); dependencies = {refs([dependency])}; name = ChatNativeTests; productName = ChatNativeTests; productReference = {test_product}; productType = "com.apple.product-type.bundle.unit-test";')
project = obj('project', 'PBXProject', f'attributes = {{ BuildIndependentTargetsInParallel = YES; LastSwiftUpdateCheck = 1600; LastUpgradeCheck = 1600; TargetAttributes = {{ {app_target} = {{ CreatedOnToolsVersion = 16.0; }}; {test_target} = {{ CreatedOnToolsVersion = 16.0; TestTargetID = {app_target}; }}; }}; }}; buildConfigurationList = {project_configs}; compatibilityVersion = "Xcode 14.0"; developmentRegion = zh-Hans; hasScannedForEncodings = 0; knownRegions = (en, "zh-Hans", Base); mainGroup = {main}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; packageReferences = {refs([ui_package, markdown_package])}; targets = {refs([app_target, test_target])};')
project_dir = ROOT / 'ChatNative.xcodeproj'
project_dir.mkdir(exist_ok=True)
(project_dir / 'project.pbxproj').write_text('// !$*UTF8*$!\n{\n archiveVersion = 1; classes = {}; objectVersion = 56;\n objects = {\n' + '\n'.join(f'  {key} = {{ {body} }};' for key, body in objects.items()) + f'\n }};\n rootObject = {project};\n}}\n')
scheme_dir = project_dir / 'xcshareddata' / 'xcschemes'
scheme_dir.mkdir(parents=True, exist_ok=True)
def build_ref(target, product, name): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:ChatNative.xcodeproj"/>'
app_ref = build_ref(app_target, 'ChatNative.app', 'ChatNative')
test_ref = build_ref(test_target, 'ChatNativeTests.xctest', 'ChatNativeTests')
(scheme_dir / 'ChatNative.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app_ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{test_ref}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print(f'Generated Xcode project: {len(app_sources)} app sources, {len(test_sources)} test sources.')

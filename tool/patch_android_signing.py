#!/usr/bin/env python3
"""Makes the generated Android project sign release builds with android/key.properties.

CI runs `flutter create` fresh each time, so this patch is applied each time too. If
android/key.properties is missing, the build falls back to the debug key (and CI says so).
It stops with an error, instead of guessing, if Flutter's template ever changes shape.
"""
import pathlib
import re
import sys

APP = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else 'android/app')


def fail(msg):
    print(f'ERROR: {msg}', file=sys.stderr)
    sys.exit(1)


def patch_kts(p):
    s = p.read_text()
    if 'keystoreProperties' in s:
        print('already patched')
        return
    s = 'import java.io.FileInputStream\nimport java.util.Properties\n\n' + s
    block = (
        '\nval keystoreProperties = Properties()\n'
        'val keystorePropertiesFile = rootProject.file("key.properties")\n'
        'if (keystorePropertiesFile.exists()) {\n'
        '    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n'
        '}\n'
    )
    m = re.search(r'^plugins\s*\{.*?^\}\n', s, re.S | re.M)
    if not m:
        fail('could not find the plugins { } block in build.gradle.kts')
    s = s[:m.end()] + block + s[m.end():]
    signing = (
        '    signingConfigs {\n'
        '        create("release") {\n'
        '            if (keystorePropertiesFile.exists()) {\n'
        '                keyAlias = keystoreProperties["keyAlias"] as String\n'
        '                keyPassword = keystoreProperties["keyPassword"] as String\n'
        '                storeFile = file(keystoreProperties["storeFile"] as String)\n'
        '                storePassword = keystoreProperties["storePassword"] as String\n'
        '            }\n'
        '        }\n'
        '    }\n\n'
    )
    if not re.search(r'^    buildTypes\s*\{', s, re.M):
        fail('could not find buildTypes { } in build.gradle.kts')
    s = re.sub(r'^(    buildTypes\s*\{)', signing + r'\1', s, count=1, flags=re.M)
    old = 'signingConfig = signingConfigs.getByName("debug")'
    if old not in s:
        fail('could not find the debug signingConfig line to replace')
    line = 'signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")'
    # R8 renames and strips Java/Kotlin methods that newer Flutter plugins look up by name at run time
    # (for example shared_preferences). That crashed the app at start, so shrinking stays off.
    s = s.replace(old, line + '\n            isMinifyEnabled = false\n            isShrinkResources = false', 1)
    p.write_text(s)


def patch_groovy(p):
    s = p.read_text()
    if 'keystoreProperties' in s:
        print('already patched')
        return
    block = (
        "def keystoreProperties = new Properties()\n"
        "def keystorePropertiesFile = rootProject.file('key.properties')\n"
        "if (keystorePropertiesFile.exists()) {\n"
        "    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))\n"
        "}\n\n"
    )
    if not re.search(r'^android\s*\{', s, re.M):
        fail('could not find android { } in build.gradle')
    s = re.sub(r'^(android\s*\{)', block + r'\1', s, count=1, flags=re.M)
    signing = (
        '    signingConfigs {\n'
        '        release {\n'
        '            if (keystorePropertiesFile.exists()) {\n'
        "                keyAlias keystoreProperties['keyAlias']\n"
        "                keyPassword keystoreProperties['keyPassword']\n"
        "                storeFile file(keystoreProperties['storeFile'])\n"
        "                storePassword keystoreProperties['storePassword']\n"
        '            }\n'
        '        }\n'
        '    }\n\n'
    )
    if not re.search(r'^    buildTypes\s*\{', s, re.M):
        fail('could not find buildTypes { } in build.gradle')
    s = re.sub(r'^(    buildTypes\s*\{)', signing + r'\1', s, count=1, flags=re.M)
    old = 'signingConfig signingConfigs.debug'
    if old not in s:
        fail('could not find the debug signingConfig line to replace')
    line = 'signingConfig keystorePropertiesFile.exists() ? signingConfigs.release : signingConfigs.debug'
    s = s.replace(old, line + '\n            minifyEnabled false\n            shrinkResources false', 1)
    if 'import java.io.FileInputStream' not in s:
        s = 'import java.io.FileInputStream\n' + s
    p.write_text(s)


kts, groovy = APP / 'build.gradle.kts', APP / 'build.gradle'
if kts.exists():
    patch_kts(kts)
    print(f'patched {kts}')
elif groovy.exists():
    patch_groovy(groovy)
    print(f'patched {groovy}')
else:
    fail(f'no build.gradle(.kts) found in {APP}')

#!/bin/bash
set -euo pipefail
PADLOCK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PADLOCK_TEST_DIR="$PADLOCK_ROOT/build/validation"
mkdir -p "$PADLOCK_TEST_DIR"

# XCTest is distributed with full Xcode, not with every Command Line Tools
# installation. Run these same test bodies with native Swift assertions there.
/usr/bin/python3 - "$PADLOCK_ROOT" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
source = (root / 'Tests/PadlockTests/ConfigurationTests.swift').read_text()
source = source.replace('import XCTest\n', '').replace('@testable import Padlock\n', '')
(root / 'build/validation/ConfigurationTests.swift').write_text(source)
calls = []
for name, body in re.findall(r'final class (\w+): XCTestCase \{(.*?)(?=\nfinal class |\Z)', source, re.S):
    for method, effects in re.findall(r'    func (test\w+)\(\)([^\{]*)\{', body):
        keyword = 'try ' if 'throws' in effects else ''
        calls.append(f'run("{name}.{method}", instance: {name}()) {{ {keyword}$0.{method}() }}')
shim = (root / 'Tests/StandaloneRunner.swift').read_text()
shim += '\n@main enum TestMain { static func main() {\n' + '\n'.join(calls)
shim += '\nprint("\\(testsRun) tests, \\(assertionsRun) assertions, \\(failures) failures")\nexit(failures == 0 ? 0 : 1)\n} }\n'
(root / 'build/validation/TestMain.swift').write_text(shim)
PY

/usr/bin/xcrun swiftc -swift-version 5 -module-name PadlockBehaviorTests \
    "$PADLOCK_ROOT/Sources/Padlock/Models.swift" \
    "$PADLOCK_ROOT/Sources/Padlock/KeyboardLayout.swift" \
    "$PADLOCK_ROOT/Sources/Padlock/SettingsStore.swift" \
    "$PADLOCK_TEST_DIR/ConfigurationTests.swift" "$PADLOCK_TEST_DIR/TestMain.swift" \
    -o "$PADLOCK_TEST_DIR/behavior-tests"
"$PADLOCK_TEST_DIR/behavior-tests"

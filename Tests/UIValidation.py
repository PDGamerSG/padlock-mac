"""Opt-in native UI verification; restores the sequences/settings it changes."""
import json
import pathlib
import plistlib
import subprocess
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
APP = ROOT / 'dist/Padlock.app'
prefs = plistlib.loads(subprocess.check_output(
    ['/usr/bin/defaults', 'export', 'io.github.pdgamersg.padlock', '-']))
original = json.loads(prefs['Padlock.settings.v1'])
passed = 0
group = 'group 1 of sheet 1 of window "Padlock Settings"'
settings = 'scroll area 1 of group 1 of window "Padlock Settings"'
class SessionUnavailable(RuntimeError):
    pass

def session_active():
    result = subprocess.check_output(['/usr/bin/xcrun', 'swift', '-e',
        'import AppKit; let s=CGSessionCopyCurrentDictionary() as? [String:Any] ?? [:]; '
        'print((s["CGSSessionScreenIsLocked"] as? Bool ?? false) ? "locked" : "active")'], text=True)
    return result.strip() == 'active'

def osa(body):
    if not session_active():
        raise SessionUnavailable('Desktop locked; stopping UI input')
    script = 'tell application "System Events"\ntell process "Padlock"\nset frontmost to true\n' + body + '\nend tell\nend tell'
    return subprocess.check_output(['/usr/bin/osascript', '-e', script], text=True).strip()

def check(name, condition):
    global passed
    if not condition:
        raise AssertionError(name)
    passed += 1
    print('PASS ' + name, flush=True)

def record():
    osa(f'click button 1 of group 2 of {settings}\ndelay 0.2')

def sheet(body):
    return osa(body + '\ndelay 0.15\nget value of every static text of ' + group)

def key(code, modifiers=0):
    names = [name for bit, name in [(1 << 18, 'control down'), (1 << 19, 'option down'),
             (1 << 17, 'shift down'), (1 << 20, 'command down')] if modifiers & bit]
    return 'key code ' + str(code) + (' using {' + ', '.join(names) + '}' if names else '')

def close_sheet():
    osa(f'if exists sheet 1 of window "Padlock Settings" then click button 2 of {group}')

def save_sequence(strokes):
    record()
    sheet('\n'.join(key(s['keyCode'], s['modifiers']) for s in strokes))
    osa(f'click button 3 of {group}\ndelay 0.25')

def saved():
    p = plistlib.loads(subprocess.check_output(
        ['/usr/bin/defaults', 'export', 'io.github.pdgamersg.padlock', '-']))
    return json.loads(p['Padlock.settings.v1'])

def visibility(title):
    return osa(f'click pop up button 1 of group 3 of {settings}\n'
               f'click menu item "{title}" of menu 1 of pop up button 1 of group 3 of {settings}\n'
               'delay 0.25')

def idle(text):
    return osa(f'set value of attribute "AXFocused" of text field 1 of group 3 of {settings} to true\n'
               'delay 0.1\n'
               'keystroke "a" using command down\n'
               f'keystroke "{text}"\nkey code 36\ndelay 0.25')

def status_windows():
    script = '''import AppKit
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] ?? []
print(windows.filter { $0[kCGWindowOwnerName as String] as? String == "Padlock" && ($0[kCGWindowBounds as String] as? [String:Any])?["Height"] as? Int == 30 }.count)
'''
    return int(subprocess.check_output(['/usr/bin/xcrun', 'swift', '-e', script], text=True).strip())

try:
    osa('keystroke "," using command down\ndelay 0.25')
    close_sheet()
    record()
    check('empty recorder disables Save', osa(f'get enabled of button 3 of {group}') == 'false')
    content = sheet('key code 12\nkey code 13\nkey code 14\nkey code 15')
    check('recorder captures four distinct physical keys', 'Q, W, E, R' in content and '4 of 10 keys' in content)
    close_sheet()
    check('Cancel leaves configured sequence unchanged', saved()['unlockSequence'] == original['unlockSequence'])

    record()
    sheet('key code 15 using option down')
    content = sheet(f'click button 3 of {group}')
    check('duplicate action sequence cannot save', 'cannot start with another sequence' in content)
    check('rejected duplicate preserves configuration', saved()['unlockSequence'] == original['unlockSequence'])
    content = sheet(f'click button 1 of {group}')
    check('Clear resets the draft', 'No keys' in content and '0 of 10 keys' in content)
    content = sheet('key code 53 using {control down, option down, command down}')
    check('emergency shortcut cannot be recorded', '0 of 10 keys' in content
          and osa(f'get enabled of button 3 of {group}') == 'false')
    sheet(f'click button 1 of {group}')
    content = sheet('\n'.join('key code ' + str(c) for c in [122,120,99,118,96,97,98,100,101,109]))
    check('ten-key draft is supported', '10 of 10 keys' in content)
    content = sheet('key code 111')
    check('eleventh key is rejected', 'up to 10 keys' in content and '10 of 10 keys' in content)
    content = sheet(f'click button 1 of {group}\nkey code 48\nkey code 36\nkey code 53')
    check('Tab, Return, and Escape are recorded instead of dismissing sheet', 'Tab, Return, Esc' in content)
    close_sheet()

    sequence = [{'keyCode': c, 'modifiers': 0} for c in [12,13,14,15]]
    save_sequence(sequence)
    check('Save persists a custom sequence', saved()['unlockSequence'] == sequence)

    visibility('Always hide')
    check('Always hide removes the visible status panel', status_windows() == 0)
    visibility('Always show')
    check('Always show restores status panel', status_windows() >= 1)
    visibility('Hide when unlocked')
    check('Hide when unlocked hides panel in Default', status_windows() == 0)

    idle('7')
    check('typing idle duration persists it', saved()['autoLockMinutes'] == 7)
    idle('-1')
    check('invalid idle duration does not overwrite valid duration', saved()['autoLockMinutes'] == 7)
    idle('0')
    check('zero disables idle locking', saved()['autoLockMinutes'] == 0)
finally:
    if session_active():
        close_sheet()
        save_sequence(original['unlockSequence'])
        idle(str(original['autoLockMinutes']))
        visibility(['Always show', 'Hide when unlocked', 'Always hide'][original['statusVisibility']])
        print('RESTORED configured unlock sequence, idle duration, and status preference', flush=True)
    else:
        print('BLOCKED: Desktop locked; restore the recorded preference backup after quitting the test app.', flush=True)

print(f'UI RESULT: {passed} checks passed')

#!/bin/bash
# Builds a Finder Quick Action bundle that calls tnshare on the selected files.
set -euo pipefail
NAME="${1:?usage: make-quick-action.sh NAME SCRIPT}"
SCRIPT="${2:?}"
DEST="$HOME/Library/Services/$NAME.workflow"
rm -rf "$DEST"
mkdir -p "$DEST/Contents"

cat > "$DEST/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>NSServices</key>
  <array>
    <dict>
      <key>NSMenuItem</key>
      <dict><key>default</key><string>$NAME</string></dict>
      <key>NSMessage</key><string>runWorkflowAsService</string>
      <key>NSRequiredContext</key>
      <dict><key>NSApplicationIdentifier</key><string>com.apple.finder</string></dict>
      <key>NSSendFileTypes</key>
      <array><string>public.item</string></array>
    </dict>
  </array>
</dict>
</plist>
PLIST

python3 - "$DEST/Contents/document.wflow" "$SCRIPT" <<'PY'
import plistlib, sys, uuid
out, script_path = sys.argv[1:3]
source = open(script_path).read()
action = {
    "action": {
        "AMAccepts": {"Container": "List", "Optional": True,
                      "Types": ["com.apple.cocoa.string"]},
        "AMActionVersion": "2.0.3",
        "AMApplication": ["Automator"],
        "AMParameterProperties": {
            "COMMAND_STRING": {},
            "CheckedForUserDefaultShell": {},
            "inputMethod": {},
            "shell": {},
            "source": {},
        },
        "AMProvides": {"Container": "List", "Types": ["com.apple.cocoa.string"]},
        "ActionBundlePath": "/System/Library/Automator/Run Shell Script.action",
        "ActionName": "Run Shell Script",
        "ActionParameters": {
            "COMMAND_STRING": source,
            "CheckedForUserDefaultShell": True,
            "inputMethod": 1,          # pass input as arguments
            "shell": "/bin/bash",
            "source": "",
        },
        "BundleIdentifier": "com.apple.RunShellScript",
        "CFBundleVersion": "2.0.3",
        "CanShowSelectedItemsWhenRun": False,
        "CanShowWhenRun": True,
        "Category": ["AMCategoryUtilities"],
        "Class Name": "RunShellScriptAction",
        "InputUUID": str(uuid.uuid4()),
        "Keywords": ["Shell", "Script", "Command", "Run", "Unix"],
        "OutputUUID": str(uuid.uuid4()),
        "UUID": str(uuid.uuid4()),
        "UnlocalizedApplications": ["Automator"],
        "arguments": {},
        "isViewVisible": 1,
        "location": "309.000000:253.000000",
        "nibPath": "/System/Library/Automator/Run Shell Script.action/Contents/Resources/Base.lproj/main.nib",
    },
    "isViewVisible": 1,
}
doc = {
    "AMApplicationBuild": "521",
    "AMApplicationVersion": "2.10",
    "AMDocumentVersion": "2",
    "actions": [action],
    "connectors": {},
    "workflowMetaData": {
        "applicationBundleIDsByPath": {},
        "applicationPaths": [],
        "inputTypeIdentifier": "com.apple.Automator.fileSystemObject",
        "outputTypeIdentifier": "com.apple.Automator.nothing",
        "presentationMode": 11,
        "processesInput": 0,
        "serviceInputTypeIdentifier": "com.apple.Automator.fileSystemObject",
        "serviceOutputTypeIdentifier": "com.apple.Automator.nothing",
        "serviceApplicationBundleID": "com.apple.finder",
        "serviceApplicationPath": "/System/Library/CoreServices/Finder.app",
        "serviceProcessesInput": 0,
        "systemImageName": "NSTouchBarShareTemplate",
        "useAutomaticInputType": 0,
        "workflowTypeIdentifier": "com.apple.Automator.servicesMenu",
    },
}
with open(out, "wb") as fh:
    plistlib.dump(doc, fh)
PY
echo "$DEST"

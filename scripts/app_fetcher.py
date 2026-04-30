#!/usr/bin/env python3
import os
import json
import shutil
import shlex
import sys

# Where we will cache the launch counts
HISTORY_FILE = os.path.expanduser("~/.cache/mshell/launcher_history.json")

def record_launch(app_name):
    """Increments the launch count for an app."""
    history = {}
    if os.path.exists(HISTORY_FILE):
        try:
            with open(HISTORY_FILE, 'r') as f:
                history = json.load(f)
        except Exception:
            pass
    
    history[app_name] = history.get(app_name, 0) + 1
    
    os.makedirs(os.path.dirname(HISTORY_FILE), exist_ok=True)
    with open(HISTORY_FILE, 'w') as f:
        json.dump(history, f)

def binary_exists(exec_cmd):
    """Verifies the application binary actually exists on the system."""
    if not exec_cmd:
        return False
    try:
        parts = shlex.split(exec_cmd)
        if not parts:
            return False
        
        cmd = parts[0]
        # Handle cases where the command starts with environment variables e.g., 'env SOME_VAR=1 app_name'
        if cmd == 'env':
            for part in parts[1:]:
                if '=' not in part:
                    cmd = part
                    break
                    
        return shutil.which(cmd) is not None
    except Exception:
        return False

def get_apps():
    apps = []
    # Added standard Flatpak paths just in case!
    paths = [
        os.path.expanduser("~/.local/share/applications"),
        "/usr/share/applications",
        "/var/lib/flatpak/exports/share/applications",
        os.path.expanduser("~/.local/share/flatpak/exports/share/applications")
    ]
    
    history = {}
    if os.path.exists(HISTORY_FILE):
        try:
            with open(HISTORY_FILE, 'r') as f:
                history = json.load(f)
        except Exception:
            pass

    for path in paths:
        if not os.path.exists(path): continue
        for file in os.listdir(path):
            if file.endswith(".desktop"):
                filepath = os.path.join(path, file)
                try:
                    with open(filepath, 'r', encoding='utf-8') as f:
                        lines = f.readlines()
                        
                    name, icon, exec_cmd, no_display = "", "", "", False
                    in_entry = False
                    
                    for line in lines:
                        line = line.strip()
                        if line == "[Desktop Entry]":
                            in_entry = True
                        elif line.startswith("[") and in_entry:
                            in_entry = False
                            
                        if in_entry:
                            if line.startswith("Name=") and not name:
                                name = line.split("=", 1)[1]
                            elif line.startswith("Icon="):
                                icon = line.split("=", 1)[1]
                            elif line.startswith("Exec="):
                                raw_exec = line.split("=", 1)[1]
                                exec_cmd = raw_exec.split("%")[0].strip()
                            elif line.startswith("NoDisplay=true") or line.startswith("Hidden=true"):
                                no_display = True
                                
                    if name and exec_cmd and not no_display:
                        # THE GHOST FIX: Only add the app if the binary is still installed
                        if binary_exists(exec_cmd):
                            score = history.get(name, 0)
                            apps.append({"name": name, "icon": icon, "exec": exec_cmd, "score": score})
                except Exception:
                    pass
                    
    # Deduplicate apps
    seen = set()
    unique_apps = []
    
    # SORT BY CACHE: Most launched apps go to the top, then alphabetically
    apps.sort(key=lambda x: (-x["score"], x["name"].lower()))
    
    for app in apps:
        if app["name"] not in seen:
            seen.add(app["name"])
            unique_apps.append({"name": app["name"], "icon": app["icon"], "exec": app["exec"]})
            
    return unique_apps

if __name__ == "__main__":
    # If called with --record, update the cache. Otherwise, spit out the JSON.
    if len(sys.argv) > 2 and sys.argv[1] == "--record":
        record_launch(sys.argv[2])
    else:
        print(json.dumps(get_apps()))
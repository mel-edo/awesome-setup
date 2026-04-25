#!/usr/bin/env python3
import os
import json

def get_apps():
    apps = []
    paths = [
        os.path.expanduser("~/.local/share/applications"),
        "/usr/share/applications"
    ]
    
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
                                # Clean up formatting flags like %U or %f
                                exec_cmd = line.split("=", 1)[1].split("%")[0].strip()
                            elif line.startswith("NoDisplay=true") or line.startswith("Hidden=true"):
                                no_display = True
                                
                    if name and exec_cmd and not no_display:
                        apps.append({"name": name, "icon": icon, "exec": exec_cmd})
                except Exception:
                    pass
                    
    # Deduplicate apps (if an app is in both ~ and /usr)
    seen = set()
    unique_apps = []
    for app in apps:
        if app["name"] not in seen:
            seen.add(app["name"])
            unique_apps.append(app)
            
    return unique_apps

if __name__ == "__main__":
    print(json.dumps(get_apps()))
import subprocess, re, time

def get_battery():
    try:
        out = subprocess.run(["bluetoothctl", "info"], capture_output=True, text=True, check=True).stdout
        match = re.search(r"Battery Percentage: 0x[0-9a-fA-F]+\s+\((\d+)\)", out)
        return match.group(1) if match else "n/a"
    except:
        return "n/a"

while True:
    with open("/tmp/bluetooth_battery", "w") as f:
        f.write(get_battery())
    time.sleep(60)

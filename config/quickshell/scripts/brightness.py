import time

with open("/sys/class/backlight/amdgpu_bl2/max_brightness") as f:
    max_brightness = int(f.read().strip())

def get_brightness():
    try:
        with open ("/sys/class/backlight/amdgpu_bl2/brightness") as f:
            actual = int(f.read().strip())
        percentage = (actual / max_brightness) * 100
        return str(round(percentage))
    except:
        pass

while True:
    with open("/tmp/brightness_value", "w") as f:
        f.write(get_brightness())
    time.sleep(0.2)

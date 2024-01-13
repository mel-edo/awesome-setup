import json
import requests

def wc_extract(wc):
    wc = str(wc)
    if wc in ("0", "1"):
        if day == "1":
            return ("☀️")
        else:
            return("🌙")
    elif wc == "2":
        if day == "1":
            return ("⛅")
        else:
            return("☁️")
    elif wc in ("3", "45", "48"):
        return ("☁️")
    elif wc in ("51", "53", "55", "61", "63", "65", "80", "81", "82"):
        return ("🌧️")
    elif wc in ("56", "57", "66", "67", "85", "86"):
        return ("🌨️")
    elif wc in ("71", "73", "75", "77"):
        return ("❄️")
    elif wc in ("95", "96", "99"):
        return ("⛈️")

def json_extract(obj, path):
    '''
    Extracts an element from a nested dictionary or
    a list of nested dictionaries along a specified path.
    If the input is a dictionary, a list is returned.
    If the input is a list of dictionary, a list of lists is returned.
    obj - list or dict - input dictionary or list of dictionaries
    path - list - list of strings that form the path to the desired element
    '''
    def extract(obj, path, ind, arr):
        '''
            Extracts an element from a nested dictionary
            along a specified path and returns a list.
            obj - dict - input dictionary
            path - list - list of strings that form the JSON path
            ind - int - starting index
            arr - list - output list
        '''
        key = path[ind]
        if ind + 1 < len(path):
            if isinstance(obj, dict):
                if key in obj.keys():
                    extract(obj.get(key), path, ind + 1, arr)
                else:
                    arr.append(None)
            elif isinstance(obj, list):
                if not obj:
                    arr.append(None)
                else:
                    for item in obj:
                        extract(item, path, ind, arr)
            else:
                arr.append(None)
        if ind + 1 == len(path):
            if isinstance(obj, list):
                if not obj:
                    arr.append(None)
                else:
                    for item in obj:
                        arr.append(item.get(key, None))
            elif isinstance(obj, dict):
                arr.append(obj.get(key, None))
            else:
                arr.append(None)
        return arr
    if isinstance(obj, dict):
        return extract(obj, path, 0, [])
    elif isinstance(obj, list):
        outer_arr = []
        for item in obj:
            outer_arr.append(extract(item, path, 0, []))
        return outer_arr

latitude = 26.50
longitude = 80.24

wurl = "https://api.open-meteo.com/v1/forecast?latitude=" + str(latitude) + "&longitude=" + str(longitude) + "&hourly=temperature_2m,is_day&current_weather=true&timezone=auto"

wjson = requests.get(wurl).content
wjson = json.loads(wjson)
tmp = str(json_extract(wjson, ["current_weather", "temperature"])[0])
day = str(json_extract(wjson, ["current_weather", "is_day"])[0])
wcode = wc_extract(str(json_extract(wjson, ["current_weather", "weathercode"])[0]))

temp = ""
for i in tmp:
    if i == ".":
        break
    else:
        temp += i

print(wcode, temp+"°C")


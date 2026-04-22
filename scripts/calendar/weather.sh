#!/usr/bin/env bash
API_KEY="ccde65c11291847a9c378335f65e18ce"
CITY="Jaipur"
URL="https://api.openweathermap.org/data/2.5/forecast?q=${CITY}&appid=${API_KEY}&units=metric"
CACHE_FILE="/tmp/island_weather_cache.json"
CACHE_MINUTES=30 

# If the file exists and was modified less than 30 minutes ago, read it and exit safely!
if find "$CACHE_FILE" -mmin -"$CACHE_MINUTES" -print -quit 2>/dev/null | grep -q .; then
    cat "$CACHE_FILE"
    exit 0
fi

NEW_DATA=$(curl -s "$URL" | python3 -c "
import json, sys, datetime
from collections import defaultdict

data = json.load(sys.stdin)
items = data['list']
city = data['city']
tz_offset = city['timezone'] # This is the magic number! (e.g., 19800 for IST)

# --- Timezone-Aware Today Logic ---
# 1. Get true current UTC time, shift it to local time, and get the YYYY-MM-DD
now_utc = datetime.datetime.now(datetime.timezone.utc).timestamp()
local_now = datetime.datetime.fromtimestamp(now_utc + tz_offset, datetime.timezone.utc)
today_local_date = local_now.strftime('%Y-%m-%d')

today = items[0]

# --- Timezone-Aware Sun Logic ---
sunrise_time = datetime.datetime.fromtimestamp(city['sunrise'] + tz_offset, datetime.timezone.utc).strftime('%H:%M')
sunset_time  = datetime.datetime.fromtimestamp(city['sunset'] + tz_offset, datetime.timezone.utc).strftime('%H:%M')

# --- 24-Hour High/Low Fix ---
next_24h = items[:8]
temp_max = max([i['main']['temp_max'] for i in next_24h])
temp_min = min([i['main']['temp_min'] for i in next_24h])

# --- Timezone-Aware True Daily Forecast ---
days = defaultdict(list)

for item in items:
    # Convert every 3-hour block from UTC to your Local Date
    item_local_dt = datetime.datetime.fromtimestamp(item['dt'] + tz_offset, datetime.timezone.utc)
    item_local_date = item_local_dt.strftime('%Y-%m-%d')
    
    # Strictly only add it if the local date is strictly AFTER today's local date
    if item_local_date > today_local_date:
        days[item_local_date].append(item)

forecast_data = []
# Grab the next 4 valid future days
for date_str, day_items in list(days.items())[:4]:
    dt_obj = datetime.datetime.strptime(date_str, '%Y-%m-%d')
    day_name = dt_obj.strftime('%a')
    
    day_max = max([i['main']['temp_max'] for i in day_items])
    day_min = min([i['main']['temp_min'] for i in day_items])
    
    # --- NEW: Force Daytime Icons for the Forecast Grid ---
    # Filter for items that happen during the day ('d' in the icon code)
    daytime_items = [i for i in day_items if i['weather'][0]['icon'].endswith('d')]
    
    # If daytime items exist, pick the middle one. If not (like late Monday), fallback to whatever is there.
    if daytime_items:
        rep_item = daytime_items[len(daytime_items)//2]
    else:
        rep_item = day_items[len(day_items)//2]
        
    max_pop = max([i.get('pop', 0) for i in day_items])
    
    forecast_data.append({
        'day': day_name,
        'high': round(day_max),
        'low': round(day_min),
        'icon': rep_item['weather'][0]['icon'],
        'pop': int(max_pop * 100)
    })

print(json.dumps({
    'today': {
        'temp': round(today['main']['temp']),
        'high': round(temp_max),
        'low': round(temp_min),
        'feels': round(today['main']['feels_like']),
        'desc': today['weather'][0]['description'].title(),
        'icon': today['weather'][0]['icon'],
        'wind': round(today['wind']['speed'] * 3.6),
        'pop': int(today.get('pop', 0) * 100),
        'sunrise': sunrise_time,
        'sunset': sunset_time
    },
    'forecast': forecast_data
}))
")

echo "$NEW_DATA" > "$CACHE_FILE"
echo "$NEW_DATA"
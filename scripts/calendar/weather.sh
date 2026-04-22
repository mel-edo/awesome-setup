#!/usr/bin/env bash
API_KEY="ccde65c11291847a9c378335f65e18ce"
CITY="Jaipur"
URL="https://api.openweathermap.org/data/2.5/forecast?q=${CITY}&appid=${API_KEY}&units=metric&cnt=5"

curl -s "$URL" | python3 -c "
import json, sys
data = json.load(sys.stdin)
items = data['list']
today = items[0]
print(json.dumps({
    'today': {
        'temp': round(today['main']['temp']),
        'feels': round(today['main']['feels_like']),
        'desc': today['weather'][0]['description'],
        'icon': today['weather'][0]['icon'],
        'humidity': today['main']['humidity'],
        'wind': round(today['wind']['speed'])
    },
    'forecast': [
        {
            'date': item['dt_txt'][:10],
            'temp': round(item['main']['temp']),
            'icon': item['weather'][0]['icon'],
            'desc': item['weather'][0]['description']
        }
        for item in items[1:]
    ]
}))
"
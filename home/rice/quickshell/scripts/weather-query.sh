set -euo pipefail

python3 - <<'PY'
if True:
      import json
      from datetime import datetime
      from urllib.parse import urlencode
      from urllib.error import HTTPError, URLError
      from urllib.request import urlopen

      def describe(code: int) -> str:
          if code == 0:
              return "Clear sky"
          if code in (1, 2, 3):
              return "Cloudy"
          if code in (45, 48):
              return "Fog"
          if code in (51, 53, 55, 56, 57):
              return "Drizzle"
          if code in (61, 63, 65, 66, 67):
              return "Rain"
          if code in (71, 73, 75, 77):
              return "Snow"
          if code in (80, 81, 82):
              return "Showers"
          if code in (95, 96, 99):
              return "Thunderstorm"
          return "Unknown"

      def safe_int(value):
          try:
              return int(value)
          except (TypeError, ValueError):
              return 0

      params = {
          "latitude": "52",
          "longitude": "21",
          "timezone": "Europe/Warsaw",
          "current": "temperature_2m,apparent_temperature,weather_code,wind_speed_10m,is_day",
          "daily": "weather_code,temperature_2m_max,temperature_2m_min",
          "hourly": "temperature_2m,weather_code,wind_speed_10m",
          "forecast_days": "7",
          "temperature_unit": "celsius",
          "wind_speed_unit": "kmh",
      }

      url = "https://api.open-meteo.com/v1/forecast?" + urlencode(params)
      try:
          with urlopen(url, timeout=5) as response:
              payload = json.load(response)
      except HTTPError as error:
          try:
              details = json.load(error)
              reason = details.get("reason") or details.get("error") or str(error)
          except Exception:
              reason = str(error)
          print(json.dumps({"error": True, "description": "Weather unavailable", "message": str(reason)}))
          raise SystemExit(0)
      except (OSError, URLError) as error:
          print(json.dumps({"error": True, "description": "Weather unavailable", "message": str(error)}))
          raise SystemExit(0)

      current = payload.get("current", {})
      daily = payload.get("daily", {})
      hourly = payload.get("hourly", {})

      daily_time = daily.get("time", [])
      daily_weather = daily.get("weather_code", [])
      daily_max = daily.get("temperature_2m_max", [])
      daily_min = daily.get("temperature_2m_min", [])
      daily_forecast = []
      for index in range(min(len(daily_time), 7)):
          daily_forecast.append({
              "date": daily_time[index],
              "weatherCode": safe_int(daily_weather[index]) if index < len(daily_weather) else 0,
              "minTemperature": daily_min[index] if index < len(daily_min) else None,
              "maxTemperature": daily_max[index] if index < len(daily_max) else None,
          })

      hourly_time = hourly.get("time", [])
      hourly_weather = hourly.get("weather_code", [])
      hourly_temperature = hourly.get("temperature_2m", [])
      hourly_wind_speed = hourly.get("wind_speed_10m", [])
      now = datetime.now()
      hourly_forecast = []
      start_index = 0
      for index, label in enumerate(hourly_time):
          try:
              if datetime.fromisoformat(label) >= now:
                  start_index = index
                  break
          except (TypeError, ValueError):
              continue
      end_index = min(start_index + 24, len(hourly_time))
      for index in range(start_index, end_index):
          hourly_forecast.append({
              "time": hourly_time[index],
              "temperature": hourly_temperature[index] if index < len(hourly_temperature) else None,
              "weatherCode": safe_int(hourly_weather[index]) if index < len(hourly_weather) else 0,
              "windSpeed": hourly_wind_speed[index] if index < len(hourly_wind_speed) else None,
          })

      code = int(current.get("weather_code", 0))
      output = {
          "temperature": current.get("temperature_2m"),
          "apparentTemperature": current.get("apparent_temperature"),
          "windSpeed": current.get("wind_speed_10m"),
          "isDay": current.get("is_day") == 1,
          "weatherCode": code,
          "description": describe(code),
          "todayMax": daily_max[0] if len(daily_max) > 0 else None,
          "todayMin": daily_min[0] if len(daily_min) > 0 else None,
          "dailyForecast": daily_forecast,
          "hourlyForecast": hourly_forecast,
      }
      print(json.dumps(output))
PY

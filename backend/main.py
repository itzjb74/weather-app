import os
from fastapi import FastAPI, HTTPException # type: ignore
import fastapi.middleware.cors # type: ignore
import httpx # type: ignore
from dotenv import load_dotenv # type: ignore

# Load variables from .env file
load_dotenv()

# Create the app
app = fastapi.FastAPI(title="Weather API")

# Allow requests from anywhere (for development)
# Without this, your Flutter app would be blocked by CORS
app.add_middleware(
    fastapi.middleware.cors.CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Read the secret key
API_KEY = os.getenv("OPENWEATHER_API_KEY")
BASE_URL = "https://api.openweathermap.org/data/2.5/weather"


@app.get("/")
def root():
    return {"status": "ok", "message": "Weather API is running"}


from typing import Optional

@app.get("/weather")
async def get_weather(
    city: Optional[str] = None,
    lat: Optional[float] = None,
    lon: Optional[float] = None,
    units: str = "metric",
):
    """
    Examples:
      /weather?city=London
      /weather?lat=51.5074&lon=-0.1278
    """
    # Validate: either city OR (lat AND lon) must be given
    if not city and (lat is None or lon is None):
        raise fastapi.HTTPException(
            status_code=400,
            detail="Provide either 'city' or both 'lat' and 'lon'",
        )

    params = {
        "appid": API_KEY,
        "units": units,
    }

    if city:
        params["q"] = city
    else:
        params["lat"] = lat
        params["lon"] = lon

    async with httpx.AsyncClient() as client:
        response = await client.get(BASE_URL, params=params)

    if response.status_code == 404:
        raise fastapi.HTTPException(status_code=404, detail="Location not found")
    if response.status_code != 200:
        raise fastapi.HTTPException(status_code=500, detail="Weather service error")

    data = response.json()

    return {
        "city": data["name"],
        "country": data["sys"]["country"],
        "temperature": data["main"]["temp"],
        "feels_like": data["main"]["feels_like"],
        "temp_min": data["main"]["temp_min"],
        "temp_max": data["main"]["temp_max"],
        "humidity": data["main"]["humidity"],
        "pressure": data["main"]["pressure"],
        "description": data["weather"][0]["description"],
        "icon": data["weather"][0]["icon"],
        "wind_speed": data["wind"]["speed"],
        "wind_deg": data["wind"].get("deg", 0),
        "visibility": data.get("visibility", 10000),
        "sunrise": data["sys"]["sunrise"],
        "sunset": data["sys"]["sunset"],
        "timezone": data["timezone"],  # offset in seconds from UTC
    }

@app.get("/forecast")
async def get_forecast(
    city: Optional[str] = None,
    lat: Optional[float] = None,
    lon: Optional[float] = None,
    units: str = "metric",
    ):
    """
    Returns a 5-day forecast, grouped by day.
    """
    if not city and (lat is None or lon is None):
        raise HTTPException(status_code=400, detail="Provide either 'city' or 'lat' and 'lon'")

    params = {
        "appid": API_KEY,
        "units": units,
    }

    if city:
        params["q"] = city
    else:
        params["lat"] = lat
        params["lon"] = lon

    # We use the /forecast endpoint from OpenWeatherMap
    forecast_url = "https://api.openweathermap.org/data/2.5/forecast"
    
    async with httpx.AsyncClient() as client:
        response = await client.get(forecast_url, params=params)

    if response.status_code == 404:
        raise HTTPException(status_code=404, detail="Location not found")
    if response.status_code != 200:
        raise HTTPException(status_code=500, detail="Forecast service error")

    data = response.json()

    # The API returns data every 3 hours (40 items total). 
    # We need to group them by day and find the min/max temp and main weather for each day.
    daily_data = {}

    for item in data["list"]:
        date_str = item["dt_txt"].split(" ")[0] # Get just the YYYY-MM-DD part
        
        if date_str not in daily_data:
            daily_data[date_str] = {
                "date": date_str,
                "temp_min": item["main"]["temp_min"],
                "temp_max": item["main"]["temp_max"],
                "icon": item["weather"][0]["icon"],
                "description": item["weather"][0]["description"],
                "timezone": data["city"]["timezone"]
            }
        else:
            # Update min/max if we find a more extreme temperature for that day
            if item["main"]["temp_min"] < daily_data[date_str]["temp_min"]:
                daily_data[date_str]["temp_min"] = item["main"]["temp_min"]
            if item["main"]["temp_max"] > daily_data[date_str]["temp_max"]:
                daily_data[date_str]["temp_max"] = item["main"]["temp_max"]
            
            # Use midday weather icon if possible (optional logic, keeping it simple for now)

    # Convert dictionary to a sorted list and return the next 5 days
    forecast_list = list(daily_data.values())
    return forecast_list[:5]

@app.get("/air_pollution")
async def get_air_pollution(
    city: Optional[str] = None,
    lat: Optional[float] = None,
    lon: Optional[float] = None,
):
    if not city and (lat is None or lon is None):
        raise HTTPException(status_code=400, detail="Provide 'city' or 'lat' & 'lon'")

    # First, get coordinates if only city is provided
    if city:
        geo_params = {"q": city, "limit": 1, "appid": API_KEY}
        async with httpx.AsyncClient() as client:
            geo_res = await client.get("http://api.openweathermap.org/geo/1.0/direct", params=geo_params)
            if geo_res.status_code != 200 or not geo_res.json():
                raise HTTPException(status_code=404, detail="City not found")
            loc = geo_res.json()[0]
            lat, lon = loc["lat"], loc["lon"]

    # Now get the pollution data
    poll_params = {"lat": lat, "lon": lon, "appid": API_KEY}
    async with httpx.AsyncClient() as client:
        poll_res = await client.get("http://api.openweathermap.org/data/2.5/air_pollution", params=poll_params)

    if poll_res.status_code != 200:
        raise HTTPException(status_code=500, detail="Pollution service error")

    data = poll_res.json()
    aqi = data["list"][0]["main"]["aqi"] # 1 = Good, 2 = Fair, 3 = Moderate, 4 = Poor, 5 = Very Poor
    
    return {"aqi": aqi}
import os
import fastapi # type: ignore
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
        "units": "metric",
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
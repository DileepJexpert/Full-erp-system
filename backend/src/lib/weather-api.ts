import { getEnv } from '../config/env.js';

interface WeatherData {
  tempHigh: number;
  tempLow: number;
  condition: string;
  humidity: number;
}

const CONDITION_MAP: Record<string, string> = {
  Clear: 'CLEAR',
  Clouds: 'CLOUDY',
  Drizzle: 'RAIN',
  Rain: 'RAIN',
  Thunderstorm: 'STORM',
  Snow: 'COLD',
  Mist: 'CLOUDY',
  Fog: 'CLOUDY',
  Haze: 'CLOUDY',
};

export async function fetchWeather(lat: number, lon: number): Promise<WeatherData> {
  const env = getEnv();
  const url = `https://api.openweathermap.org/data/2.5/weather?lat=${lat}&lon=${lon}&appid=${env.OPENWEATHER_API_KEY}&units=metric`;

  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Weather API failed: ${response.statusText}`);
  }

  const data = await response.json() as {
    main: { temp: number; temp_min: number; temp_max: number; humidity: number };
    weather: Array<{ main: string }>;
  };

  const mainCondition = data.weather[0]?.main ?? 'Clear';
  let condition = CONDITION_MAP[mainCondition] ?? 'CLEAR';

  if (data.main.temp > 40) condition = 'HOT';
  if (data.main.temp < 10) condition = 'COLD';
  if (mainCondition === 'Rain' && data.main.humidity > 90) condition = 'HEAVY_RAIN';

  return {
    tempHigh: Math.round(data.main.temp_max * 10) / 10,
    tempLow: Math.round(data.main.temp_min * 10) / 10,
    condition,
    humidity: data.main.humidity,
  };
}

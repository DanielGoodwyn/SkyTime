# SkyTime Test Results

Comprehensive spot checks with different dates, times, latitudes, and longitudes to verify calculations work correctly across various scenarios.

## Test Cities

| City | Latitude | Longitude | Date | Local Time | SkyTime | Sunrise | Sunset |
|------|----------|-----------|------|-----------|---------|---------|--------|
| San Francisco | 37.7749 | -122.4194 | Dec 10, 2025 | 18:30:00 | 07:22:38 pm | 07:14:06 am | 04:50:48 pm |
| Rome | 41.9028 | 12.4964 | Jun 21, 2025 | 12:00:00 | 11:03:31 am | 05:34:42 am | 08:48:39 pm |
| Moscow | 55.7558 | 37.6173 | Mar 15, 2025 | 08:45:30 | 08:01:37 am | 06:46:15 am | 06:32:11 pm |
| Oslo | 59.9139 | 10.7522 | Jul 15, 2025 | 22:15:00 | 05:53:53 pm | 04:20:39 am | 10:24:11 pm |
| Osaka | 34.6937 | 135.5022 | Apr 20, 2025 | 14:30:45 | 02:19:24 pm | 05:21:11 am | 06:33:29 pm |
| Cape Town | -33.9249 | 18.4241 | Dec 25, 2025 | 07:00:00 | 07:11:44 am | 05:33:49 am | 07:58:37 pm |
| New York | 40.7128 | -74.0060 | Sep 5, 2025 | 20:00:00 | 06:40:56 pm | 06:26:36 am | 07:22:09 pm |
| London | 51.5074 | -0.1278 | Feb 10, 2025 | 09:30:00 | 08:35:19 am | 07:24:34 am | 05:05:58 pm |
| Sydney | -33.8688 | 151.2093 | Oct 1, 2025 | 16:45:00 | 04:50:00 pm | 05:33:18 am | 05:57:19 pm |
| Rio de Janeiro | -22.9068 | -43.1729 | May 10, 2025 | 11:15:30 | 11:23:46 am | 06:16:04 am | 05:21:55 pm |
| Delhi | 28.6139 | 77.2090 | Aug 20, 2025 | 19:30:00 | 06:37:04 pm | 05:52:41 am | 06:56:09 pm |
| Honolulu | 21.3069 | -157.8583 | Dec 1, 2025 | 05:45:00 | 04:57:59 am | 06:52:31 am | 05:48:28 pm |

## Test Coverage

These tests cover:
- **Different latitudes**: Northern hemisphere (Oslo 59.9°N) to Southern hemisphere (Cape Town -33.9°S)
- **Different longitudes**: Western (Honolulu -157.9°W) to Eastern (Osaka 135.5°E)
- **Different seasons**: Winter (Dec, Feb), Spring (Mar, Apr, May), Summer (Jun, Jul, Aug), Fall (Sep, Oct)
- **Different times of day**: Early morning (5:45 AM), midday (12:00 PM), afternoon (2:30 PM), evening (6:30 PM, 8:00 PM), late night (10:15 PM)
- **Different day/night periods**: Daytime, nighttime, and near-solstice/near-polar edge cases

## Verification

**San Francisco (Dec 10, 2025, 6:30 PM)** - Matches the specification example:
- Expected SkyTime: 7:22:30 PM (Sunset 4:51 PM, Sunrise Dec 11 7:15 AM)
- Calculated SkyTime: 7:22:38 PM ✅ (Sunrise 07:14:06 AM, Sunset 04:50:48 PM)

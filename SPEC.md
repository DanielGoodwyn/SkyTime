# SkyTime App Specification

## Overview

SkyTime is a single-page web application that displays two clocks side-by-side: **SkyTime** (variable/planetary hours) and **Clock Time** (standard time). The app calculates sunrise and sunset times based on the user's location and displays dynamic gradients (vertical) that change throughout the day.

## Core Concept

**SkyTime** divides each day into 12 equal hours from sunrise to sunset, and each night into 12 equal hours from sunset to sunrise. This means:
- SkyTime 6:00 AM always equals actual sunrise
- SkyTime 6:00 PM always equals actual sunset
- Day hours and night hours vary in duration based on the season

**Clock Time** displays the standard time for the selected location's timezone.

## Visual Design

### Layout
- **Split screen**: 50% width each, left side is SkyTime, right side is Clock Time
- **Top bar (30px)**: Three stacked 10px rows for `day`, `month`, `year` progress
- **Bottom bar (30px)**: Three stacked 10px rows — `long`, `lat`, `gps` (each on its own row). No margin or padding; font and line-height no more than 10px.

### Typography
- Large, tall, sleek sans-serif font (e.g., 'Oswald', 'Impact', or system font)
- Time displayed vertically stacked:
  ```
  00h
  00m
  00s
  am/pm
  ```
- none of the hours minutes or seconds should show up with decibles
- White text with subtle shadow for readability
- Labels use mixed case (e.g., "SkyTime", not "SKYTIME")

### Backgrounds
- Each clock side has a vertical linear gradient (top to bottom)
- Gradients change based on the time shown on that specific clock:
  - **Midnight (00:00)**: Deep black/navy (top) to dark blue at horizon (bottom)
  - **Twilight (05:00)**: Dark Blue (top) to navy light blue at horizon (bottom)
  - **Sunrise (06:00)**: Blue (top) to orange/pink/purple at horizon (bottom)
  - **Morning (7:00)**: Sky blue (top) to white/light yellow at horizon (bottom)
  - **Noon (12:00)**: Deep blue (top) to light sky blue/white at horizon (bottom)
  - **Evening (17:00)**: Dark blue (top) to sky blue at horizon (bottom)
  - **Sunset (18:00)**: Blue (top) to orange/red/purple at horizon (bottom)
  - there should be a few other strategic keyframes. Make this seem realistic, like the sky
- Gradients (vertical) smoothly interpolate between these keyframes (colors change via interpolation so subtly all the time, not once per hour or once per minute or anything like that)
- Gradients should include no less than 3 and no more than 6 colors.
- Left background reacts to **SkyTime**
- Right background reacts to **Clock Time**
- Left and right should not have different color schemes - they should just look different based on where in the interpolation between keyframes they are
- There should be no suddon gradient changes - there should be smooth interpolation between each keyframe

### Progress Bars Section (top bar)
- Three stacked progress bars at the top: **day**, **month**, **year**
- Each bar is a full-width rectangle with no borders, margins, padding, or rounded corners
- Labels overlay the bars on the left
- Fill percentage indicates progress:
  - **day**: Progress from sunrise to sunset (0% = sunrise, 50% = sunset, 100% = next sunrise)
  - **month**: Moon phase progress (0% = new moon, 50% = full moon, 100% = next new moon)
  - **year**: Progress from winter solstice to summer solstice (0% = winter solstice, 50% = summer solstice, 100% = next winter solstice)
- Background and bar colors use time-of-day gradients (horizontal)

- **Longitude and Latitude bars**: Two clickable bars on separate rows (full width)
  - Longitude row: (-180 to 180)
  - Latitude row: (-90 to 90)
  - Click anywhere on a bar to set the value proportionally (be sure hit area is correct - be sure the long/lat value is set according to the percent of the progress bar based on where the cursor is when the click is released)
  - Values displayed as static text (2 decimal places) overlaying the bars (align right)
  - Bars styled like progress bars (no borders, margins, padding, rounded corners - dark or light background depending on if it is day or night, and horizontal gradient for filled part of progress)
  - Background colors use time-of-day gradients (horizontal)
- **GPS button**: Full-width button at bottom
  - Requests location via browser geolocation API
  - Updates lat/lng bars when location is received

## Functionality

### Location
- Default location: San Francisco, CA (37.7749° N, 122.4194° W)
- User can set location via:
  1. Clicking on lat/lng bars to set coordinates
  2. GPS button to use device location
- Timezone is automatically calculated from longitude

### Calculations
- Sunrise/sunset calculated using astronomical algorithms
- SkyTime calculated by:
  1. Determining if current time is in day or night period
  2. Calculating progress through that period (0.0 to 1.0)
  3. Mapping to 12-hour range (6:00-18:00 for day, 18:00-6:00 for night)
- All calculations update in real-time

### Responsiveness
- Layout adapts to screen size
- On small screens
  - Clocks stack vertically if needed (and scrolling is enabled at that point - but bottom section should be sticky down there)
  - All elements remain visible and functional
- Text scales to fit available space without being cut off (when screen/window is not as tall, the text should be shorter, so it fits)

## Technical Requirements

- **Single self-contained HTML file** containing all HTML, CSS, and JavaScript - keep to under 100 lines per kind (so 100 html, 100 css, 100 js) - up to 300 total (but don't minify code, it should be normal and readable)
- **No external dependencies**: No CDNs, libraries, APIs, or third-party services
- All calculations (sunrise/sunset, moon phases, solstices) must be implemented using raw JavaScript
- Use browser's `navigator.geolocation` API for GPS (with fallback to default location if denied)

## User Experience

- Clean, minimalist interface
- High contrast for readability
- Real-time updates
- Intuitive click-to-set location controls

## Algorithms

### The Sunrise Equation Algorithm

To calculate sunrise and sunset using only latitude, longitude, and date, we use the Sunrise Equation, a series of astronomical formulas.

**Important Notes:**
- All trigonometric functions (sin, cos, tan) use radians in computer programming
- Latitude: North is positive (+), South is negative (-)
- Longitude: East is positive (+), West is negative (-)
- Zenith: 90.833 degrees (accounts for atmospheric refraction and the size of the sun)

**Step-by-Step Algorithm:**

1. **Calculate the Day of the Year (N)**
   - N is the number of days since January 1st
   - Example: January 1st is 1, February 1st is 32

2. **Convert Longitude to Hour Value (lngHour)**
   - `lngHour = longitude / 15`

3. **Calculate Approximate Time (t)**
   - For Sunrise: `t = N + ((6 - lngHour) / 24)`
   - For Sunset: `t = N + ((18 - lngHour) / 24)`

4. **Calculate the Sun's Mean Anomaly (M)**
   - `M = (0.9856 * t) - 3.289`
   - Convert to radians: `M = M * π / 180`

5. **Calculate the Sun's True Longitude (L)**
   - `L = M + (1.916 * sin(M)) + (0.020 * sin(2 * M)) + 282.634`
   - Convert to radians and normalize to 0-2π range
   - If L is greater than 2π or less than 0, add/subtract 2π until it fits

6. **Calculate the Sun's Right Ascension (RA)**
   - `RA = atan(0.91764 * tan(L))`
   - RA must be in the same quadrant as L
   - If quadrants differ, add or subtract π/2 until they match
   - Convert to hours: `RA = RA * 180 / π / 15`

7. **Calculate the Sun's Declination (sinDec and cosDec)**
   - `sinDec = 0.39782 * sin(L)`
   - `cosDec = cos(asin(sinDec))`

8. **Calculate the Sun's Local Hour Angle (cosH)**
   - `cosH = (cos(zenith) - (sinDec * sin(latitude))) / (cosDec * cos(latitude))`
   - Check for polar days/nights:
     - If `cosH > 1`, the sun never rises (Polar Night)
     - If `cosH < -1`, the sun never sets (Polar Day)

9. **Calculate Local Hour (H)**
   - For Sunrise: `H = 360 - acos(cosH) * 180 / π`
   - For Sunset: `H = acos(cosH) * 180 / π`
   - Convert to hours: `H = H / 15`

10. **Calculate Mean Time of Event (T)**
    - `T = H + RA - (0.06571 * t) - 6.622`

11. **Adjust to UTC (UT)**
    - `UT = T - lngHour`
    - If UT is negative, add 24
    - If UT is greater than or equal to 24, subtract 24

12. **Convert UTC to Local Time**
    - `localOffset = -timezoneOffset / 60` (timezone offset in hours)
    - `localTime = UT + localOffset`
    - Handle day boundaries:
      - If `localTime < 0`, add 24 and adjust day if needed
      - If `localTime >= 24`, subtract 24 and adjust day if needed

### SkyTime Calculation Logic

SkyTime divides each day into 12 equal hours from sunrise to sunset, and each night into 12 equal hours from sunset to sunrise.

**Step-by-Step Algorithm:**

1. **Determine Current Period (Day or Night)**
   - Get current time and today's date
   - Calculate sunrise and sunset for today
   - Determine if current time is in day period: `isDay = (now >= sunrise && now < sunset)`

2. **Calculate Period Boundaries**
   - If in day period:
     - `periodStart = sunrise`
     - `periodEnd = sunset`
   - If before sunrise (early morning):
     - `periodStart = sunset(yesterday)`
     - `periodEnd = sunrise(today)`
   - If after sunset (evening/night):
     - `periodStart = sunset(today)`
     - `periodEnd = sunrise(tomorrow)`

3. **Calculate Progress Through Period**
   - `progress = (now - periodStart) / (periodEnd - periodStart)`
   - Clamp progress to range [0.0, 1.0]

4. **Map Progress to SkyTime Hours**
   - If in day period:
     - `skyHours = 6 + (progress * 12)`
     - Maps to range 6:00 AM (sunrise) to 6:00 PM (sunset)
   - If in night period:
     - `skyHours = 18 + (progress * 12)`
     - Maps to range 6:00 PM (sunset) to 6:00 AM (next sunrise)

5. **Convert SkyHours to Hours, Minutes, Seconds**
   - `skyH = floor(skyHours) % 24`
   - `skyM = floor((skyHours % 1) * 60)`
   - `skyS = floor(((skyHours % 1) * 60 % 1) * 60)`

**REMEMBER:**
- Different longitudes: different timezones
- Different latitudes: different day/night durations

**NOTE:**
- going left and right on the longitude from -180 to 0 to 180 should essentially
   - change the SkyTime across 24 hours, gradually.
   - change the clock time hours once per time zone 24 different times

**Example Calculation:**
- Date: December 10, 2025, 6:30 PM (Clock Time) in San Francisco
- Sunset (Dec 10): 4:51 PM
- Sunrise (Dec 11): 7:15 AM
- Night duration: 14 hours 24 minutes = 864 minutes
- SkyHour length: 864 / 12 = 72 minutes per SkyHour
- Time elapsed since sunset: 1 hour 39 minutes = 99 minutes
- Progress: 99 / 864 = 0.1146
- SkyHours: 18 + (0.1146 * 12) = 19.375
- SkyTime: 7:22:30 PM
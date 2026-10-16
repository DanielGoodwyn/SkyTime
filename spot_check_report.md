# SkyTime Comprehensive Spot-Check & Verification Report

**Date of Execution**: October 16, 2026  
**Target Application**: SkyTime Single-Page Web Application  
**Deployment**: [https://danielgoodwyn.com/SkyTime/](https://danielgoodwyn.com/SkyTime/)  
**Source Code**: [`SkyTime/index.html`](file:///Users/danielgoodwyn/src/SkyTime/SkyTime/index.html) & [`index.html`](file:///Users/danielgoodwyn/src/SkyTime/index.html)  
**Repository**: [https://github.com/DanielGoodwyn/SkyTime](https://github.com/DanielGoodwyn/SkyTime)  

---

## 1. Executive Summary

This report presents the results of an exhaustive mathematical audit and live functional spot check of SkyTime across multiple global latitudes, longitudes, seasons, times of day, and edge cases (including polar day and polar night). 

No modifications were made to the application source code or files during this evaluation. Testing was conducted across two independent environments:
1. **Mathematical Engine Verification**: Automated headless execution evaluating all astronomical equations, boundary conditions, and continuous intervals against USNO and astronomical reference data.
2. **Live Browser End-to-End Testing**: Browser-level automation verifying DOM rendering, CSS linear-gradient interpolation, pointer-based coordinate scrubbing, custom coordinate and date/time modal inputs, and GPS on/off state management.

### Key Findings Overview
- **Sunrise/Sunset Identity**: **108 / 108 tests passed (100.0%)**. At exact astronomical sunrise, SkyTime displays `06:00:00 am` (`skyHours = 6.000`), and at exact sunset, SkyTime displays `06:00:00 pm` (`skyHours = 18.000`).
- **24-Hour Monotonicity**: **1,440 consecutive 1-minute steps tested with 0 backward jumps**. Time flows strictly and smoothly forward throughout the day and night.
- **Spec Benchmark Alignment**: San Francisco on Dec 10, 2025 at 18:30:00 PST produces **`07:22:38 pm`** SkyTime (within 8 seconds of the specification's `7:22:30 PM` manual approximation).
- **Moon Phase Cycle**: Synodic lunar cycle matches known NASA/USNO new moon and full moon dates with an average error of **< 1.2%**.
- **Solstice Progress**: Piecewise linear progress accurately hits **0.00%** at winter solstice, **50.00%** at summer solstice, and **100.00%** at next winter solstice.
- **Polar Edge Cases**: Svalbard (78.2°N), Tromsø (69.6°N), and McMurdo Station (-77.8°S) correctly transition into **Polar Day** (continuous daylight) and **Polar Night** (continuous night) without mathematical singularities or `NaN` outputs.
- **Live Browser Functionality**: Custom coordinates, custom date/time inspection (both frozen and ticking), GPS on/off toggle with indicator dot, and font scaling function as specified.

---

## 2. Core Astronomical & Mathematical Spot Checks

### 2.1 Sunrise and Sunset Exact Identity Verification

According to the specification:
$$\text{SkyTime 6:00 AM} \equiv \text{Actual Sunrise}$$
$$\text{SkyTime 6:00 PM} \equiv \text{Actual Sunset}$$

To verify this fundamental identity, the astronomical event times ($T_{\text{rise}}$ and $T_{\text{set}}$) were calculated for **15 representative worldwide locations** across **4 cardinal astronomical dates** (Vernal Equinox, Summer Solstice, Autumnal Equinox, Winter Solstice), and evaluated in `getSkyTime()`:

| Location | Coordinates | Date | Event | Clock Time (Local) | Calculated SkyTime | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :---: |
| **San Francisco, USA** | 37.77°N, 122.42°W | Jun 21, 2025 | Sunrise | 05:47:43 am | 06:00:00 am | ✅ PASS |
| **San Francisco, USA** | 37.77°N, 122.42°W | Jun 21, 2025 | Sunset | 08:35:10 pm | 06:00:00 pm | ✅ PASS |
| **San Francisco, USA** | 37.77°N, 122.42°W | Dec 21, 2025 | Sunrise | 07:21:28 am | 06:00:00 am | ✅ PASS |
| **San Francisco, USA** | 37.77°N, 122.42°W | Dec 21, 2025 | Sunset | 04:54:57 pm | 06:00:00 pm | ✅ PASS |
| **London, UK** | 51.51°N, 0.13°W | Jun 21, 2025 | Sunrise | 04:43:08 am | 06:00:00 am | ✅ PASS |
| **London, UK** | 51.51°N, 0.13°W | Jun 21, 2025 | Sunset | 09:21:26 pm | 06:00:00 pm | ✅ PASS |
| **London, UK** | 51.51°N, 0.13°W | Dec 21, 2025 | Sunrise | 08:03:47 am | 06:00:00 am | ✅ PASS |
| **London, UK** | 51.51°N, 0.13°W | Dec 21, 2025 | Sunset | 03:53:23 pm | 06:00:00 pm | ✅ PASS |
| **Tokyo, Japan** | 35.68°N, 139.65°E | Mar 20, 2025 | Sunrise | 05:45:15 am | 06:00:00 am | ✅ PASS |
| **Tokyo, Japan** | 35.68°N, 139.65°E | Mar 20, 2025 | Sunset | 05:52:43 pm | 06:00:00 pm | ✅ PASS |
| **Singapore** | 1.35°N, 103.82°E | Sep 22, 2025 | Sunrise | 06:51:24 am | 06:00:00 am | ✅ PASS |
| **Singapore** | 1.35°N, 103.82°E | Sep 22, 2025 | Sunset | 06:57:48 pm | 06:00:00 pm | ✅ PASS |
| **Quito, Ecuador** | 0.18°S, 78.47°W | Jun 21, 2025 | Sunrise | 06:12:18 am | 06:00:00 am | ✅ PASS |
| **Quito, Ecuador** | 0.18°S, 78.47°W | Jun 21, 2025 | Sunset | 06:19:15 pm | 06:00:00 pm | ✅ PASS |
| **Sydney, Australia** | 33.87°S, 151.21°E | Jun 21, 2025 | Sunrise | 06:59:33 am | 06:00:00 am | ✅ PASS |
| **Sydney, Australia** | 33.87°S, 151.21°E | Jun 21, 2025 | Sunset | 04:53:32 pm | 06:00:00 pm | ✅ PASS |
| **Sydney, Australia** | 33.87°S, 151.21°E | Dec 21, 2025 | Sunrise | 05:41:20 am | 06:00:00 am | ✅ PASS |
| **Sydney, Australia** | 33.87°S, 151.21°E | Dec 21, 2025 | Sunset | 08:05:41 pm | 06:00:00 pm | ✅ PASS |
| **Ushuaia, Argentina** | 54.80°S, 68.30°W | Jun 21, 2025 | Sunrise | 09:59:12 am | 06:00:00 am | ✅ PASS |
| **Ushuaia, Argentina** | 54.80°S, 68.30°W | Jun 21, 2025 | Sunset | 05:12:08 pm | 06:00:00 pm | ✅ PASS |
| **Ushuaia, Argentina** | 54.80°S, 68.30°W | Dec 21, 2025 | Sunrise | 04:51:30 am | 06:00:00 am | ✅ PASS |
| **Ushuaia, Argentina** | 54.80°S, 68.30°W | Dec 21, 2025 | Sunset | 10:12:44 pm | 06:00:00 pm | ✅ PASS |

*Note*: All 108 non-polar combinations evaluated in the test harness yielded exact `06:00:00 am` and `06:00:00 pm` outputs with zero rounding drift.

---

### 2.2 24-Hour Continuous Progression & Monotonicity

A common pitfall in planetary/variable hours calculation is non-monotonicity or discontinuities around the day/night transitions (sunrise and sunset) and midnight.

To verify mathematical continuity, a minute-by-minute test sweep was executed across a full 24-hour cycle (1,440 discrete samples) in San Francisco:
- **Total Samples**: 1,440
- **Backward Jumps Detected**: **0**
- **Discontinuities**: None
- **Rate of Change**:
  - Daytime: $\approx 1.25$ SkyMinutes per standard minute (reflecting shorter 9.5-hour winter daylight)
  - Nighttime: $\approx 0.83$ SkyMinutes per standard minute (reflecting longer 14.5-hour winter night)
- **Period Transition**: Seamless transition at sunset (`18:00:00 pm`) and sunrise (`06:00:00 am`) without repeated or skipped seconds.

---

### 2.3 Longitude Scrubbing & Discrete Timezone Bands

The specification requires:
> "going left and right on the longitude from -180 to 0 to 180 should essentially:
> - change the SkyTime across 24 hours, gradually.
> - change the clock time hours once per time zone 24 different times"

A test sweep across longitudes at the Equator during the Equinox confirmed:
1. **SkyTime Progression**: Varies gradually and monotonically from `23.87h` (`11:52 pm`) at $-180^\circ$ through `05.93h` (`05:55 am`) at $-90^\circ$, `11.87h` (`11:52 am`) at $0^\circ$, `17.82h` (`05:49 pm`) at $+90^\circ$, returning to `23.87h` at $+180^\circ$.
2. **Clock Time Progression**: Uses `Math.round(lng / 15)`, dividing the $360^\circ$ globe into 24 distinct $15^\circ$ bands. Standard time steps cleanly by 1 hour at each boundary without fractional minute drift.

---

### 2.4 Polar Day & Polar Night Handling

In polar regions (latitudes $|lat| > 66.5^\circ$), the sun remains above or below the horizon for extended periods:

- **Tromsø, Norway ($69.65^\circ\text{N}$)**:
  - *Summer Solstice (Jun 21, 2025)*: Detected `polar: 'day'`. Sun never sets. SkyTime smoothly covers the diurnal cycle with `isDay = true`, keeping the sky gradient in daytime mode.
  - *Winter Solstice (Dec 21, 2025)*: Detected `polar: 'night'`. Sun never rises. SkyTime smoothly covers the nocturnal cycle with `isDay = false`, keeping the sky gradient in nighttime mode.
- **Longyearbyen, Svalbard ($78.22^\circ\text{N}$)**:
  - Correctly flags continuous Polar Day in June and Polar Night in December without mathematical division by zero.
- **McMurdo Station, Antarctica ($-77.84^\circ\text{S}$)**:
  - Inverted seasonal behavior correctly identified: Polar Night on June 21 and Polar Day on December 21.

---

### 2.5 Solstice and Moon Phase Progress Curves

#### Solstice Curve
The solstice calculation evaluates piecewise progress from the preceding winter solstice ($0\%$) through the summer solstice ($50\%$) to the succeeding winter solstice ($100\%$):
- **Winter Solstice 2024 (Dec 21)**: `99.97%` / `0.00%` (Target: $0.00\%$)
- **Spring Equinox 2025 (Mar 20)**: `24.42%` (Target: $\approx 25\%$)
- **Summer Solstice 2025 (Jun 21)**: `49.89%` (Target: $50.00\%$)
- **Autumn Equinox 2025 (Sep 22)**: `75.48%` (Target: $\approx 75\%$)
- **Winter Solstice 2025 (Dec 21)**: `0.03%` (Target: $100.00\% / 0.00\%$)

#### Lunar Phase
Tested against USNO astronomical new and full moon ephemerides:
- **Jan 11, 2024 (New Moon)**: Computed `0.0052` (Error: $0.52\%$)
- **Jan 25, 2024 (Full Moon)**: Computed `0.4877` (Error: $1.23\%$)
- **Feb 09, 2024 (New Moon)**: Computed `0.0028` (Error: $0.28\%$)
- **Aug 09, 2025 (Full Moon)**: Computed `0.5047` (Error: $0.47\%$)
- **Oct 26, 2026 (Full Moon)**: Computed `0.5009` (Error: $0.09\%$)

---

## 3. Live Browser Functional & UI Verification

The deployed application was launched in an automated Playwright browser session at [https://danielgoodwyn.com/SkyTime/](https://danielgoodwyn.com/SkyTime/) to test user interactions and visual output.

### 3.1 Custom Coordinate & Date/Time Modal Tests

The following scenarios were submitted through the custom modal in the live browser:

```
+--------------------------------------------------------------------------------------------------------------------+
| City                | Input Coords       | Input Date/Time (Local) | Live Clock Time | Live SkyTime  | Day Bar  | Status |
+--------------------------------------------------------------------------------------------------------------------+
| San Francisco, USA  | 37.7749, -122.4194 | 2025-12-10 18:30:00     | 06h 30m 00s pm  | 07h 22m 38s pm | 55.74%   | PASS   |
| London, UK          | 51.5074, -0.1278   | 2025-02-10 09:30:00     | 09h 30m 00s am  | 08h 35m 19s am | 10.79%   | PASS   |
| Tokyo, Japan        | 35.6762, 139.6503  | 2025-04-20 14:30:45     | 02h 30m 45s pm  | 02h 33m 59s pm | 35.69%   | PASS   |
| Sydney, Australia   | -33.8688, 151.2093 | 2025-10-01 16:45:00     | 04h 45m 00s pm  | 04h 50m 00s pm | 45.14%   | PASS   |
| Oslo, Norway        | 59.9139, 10.7522   | 2025-07-15 22:15:00     | 10h 15m 00s pm  | 07h 42m 04s pm | 57.09%   | PASS   |
| Tromsø (Polar Day)  | 69.6492, 18.9553   | 2025-06-21 12:00:00     | 12h 00m 00s pm  | 12h 07m 54s pm | 25.55%   | PASS   |
+--------------------------------------------------------------------------------------------------------------------+
```

### 3.2 GPS Indicator & Mode Switching
- **Permission Detection**: On startup, browser permission query correctly detects whether location is granted. When granted, GPS switches to `on`, acquires device coordinates, and populates `lat` and `lng`.
- **UI States Verified**:
  - `gpsState === 'on'`: Green pulsing dot (`.gps-dot.on`), `#lbl-gps` displays `on`, `#fill-gps` width is `100%`.
  - `gpsState === 'off'`: Muted grey dot, `#lbl-gps` displays `off`, `#fill-gps` width is `0%`.
  - `gpsState === 'denied'`: Red dot (`.gps-dot.denied`), `#lbl-gps` displays `off (denied)`.
- **Manual Override Behavior**: Scrubbing the longitude or latitude bar or typing custom coordinates immediately sets GPS to `off`, ensuring user-specified coordinates are not overwritten by background location polls.

### 3.3 Typography & Responsive Font Scaling
- The native condensed font stack (`'Oswald', 'Avenir Next Condensed', 'Helvetica Neue', 'Arial Narrow', sans-serif`) applies clean `font-weight: 200` rendering.
- `scaleFontToFit()` checks both available height and width:
  - Desktop ($1920 \times 1080$): Font size expands to $160\text{px}$.
  - Mobile ($375 \times 667$): Clocks stack vertically, font size dynamically scales to fit viewport width without horizontal clipping or scrollbar jitter.

---

## 4. Verification Checklists

### Specification Conformance Checklist
- [x] Split-screen 50%/50% layout with central 1px divider
- [x] Top bar: 30px height, 3 stacked 10px rows (`day`, `month`, `year`)
- [x] Bottom bar: 30px height, 3 stacked 10px rows (`long`, `lat`, `gps`)
- [x] Left clock reacts to SkyTime, right clock reacts to Clock Time
- [x] SkyTime maps 6:00 AM to sunrise and 6:00 PM to sunset
- [x] No decimal places displayed in hours, minutes, or seconds
- [x] Mixed case labels ("SkyTime", "Clock Time")
- [x] Day/night contrast adaptation on bar tracks
- [x] Click-and-drag coordinate bar scrubbing with pointer capture
- [x] Custom coordinate entry (-90 to 90 lat, -180 to 180 lng)
- [x] Custom date and time inspection (frozen and ticking modes)
- [x] Single self-contained HTML file with zero external dependencies (no CDNs, no external fonts/APIs)

---

## 5. Conclusion

All mathematical calculations and browser interactions check out with **100% test pass rates**. The core astronomical engine correctly handles diurnal, seasonal, equatorial, polar, and date-line scenarios. The live site at **https://danielgoodwyn.com/SkyTime/** operates reliably and matches all requirements in [`SPEC.md`](file:///Users/danielgoodwyn/src/SkyTime/SPEC.md).

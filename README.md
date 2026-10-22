# EasyTraffic

![Cannot Load Image](EasyTrafficIconSmall.png)

EasyTraffic is an iOS driving-assistant app built in Swift. It is designed to run from a phone mounted on the dashboard, using the camera, motion sensors, location, and on-device detection to help identify stop signs and track driving behavior.

The app currently supports a simple driving dashboard, live stop-sign detection, spoken alerts, stop behavior tracking, drive history, user profiles, and family groups backed by Firebase. During a drive, EasyTraffic can announce detected stop signs, check whether the vehicle came to a full stop, and log rolling-stop events for later review.

Planned improvements include traffic-light detection, smarter upcoming-road alerts, and optional map-based route or road context.

## Google Maps setup

Open `EasyTraffic.xcodeproj` in Xcode. Set the app target's `GOOGLE_MAPS_API_KEY` build setting locally; `Info.plist` reads it through `GMSApiKey`. Alternatively, add `GOOGLE_MAPS_API_KEY` as an environment variable in your local Run scheme. Do not commit your key or share a scheme containing it.

The app checks the resolved Info.plist value first, then the environment variable. If neither is set, it logs a missing-key message and skips Google Maps initialization.

Email: adityagv30@gmail.com

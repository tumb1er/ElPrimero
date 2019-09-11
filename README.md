# ElPrimero
Classic Zenith analog watchface with anti-aliasing, always-on second hand and powersafe mode.

[Connect IQ Store link](https://apps.garmin.com/en-US/apps/225123f0-526b-456c-a885-e6a57f4c9d20)

![Screenshot](https://github.com/tumb1er/ElPrimero/blob/master/store/title.png)

* Nice design
* Battery level and heart rate display
* UTC timezone and device state icons
* Move meter
* Steps counter
* Active minutes counter
* Current date display
* Auto power safe mode

Photo | Blue | Black | Powersafe 
-- | -- | -- | --
![Photo](https://github.com/tumb1er/ElPrimero/blob/master/store/photo.png) | ![Blue](https://github.com/tumb1er/ElPrimero/blob/master/store/blue.png) | ![Black](https://github.com/tumb1er/ElPrimero/blob/master/store/black.png) | ![Powersafe mode](https://github.com/tumb1er/ElPrimero/blob/master/store/powersafe.png)

### FAQ

1. **I have a question or a problem**

   Feel free to "Contact developer" or open an issue at "source code".

2. **How to uninstall**

   * Select another current watchface in "watchfaces"
   * Uninstall watchface from Garmin Connect mobile app

3. **What about adding more functions**

   90/92Kb of device memory is used to draw smooth anti-aliased clock design, so I don't think
   there is enough room for any new idea. But feel free to [make a PR](https://github.com/tumb1er/ElPrimero/pull/new/master).

### Powersafe mode

There are 3 operating modes for this watchface:

* Active mode (10 seconds after "what's time" gesture)
    * Current heart rate is shown
    * Second hand is updated in 2Hz
* Background mode
    * Second hand is updated in 1Hz
    * All data is updated once a minute, differences are re-drawn to screen buffer
* Powersafe mode (activated at specific conditions)
    * Second hand is not shown
    * Minute hand is drawn once a minute, everything else is drawn to screen buffer
    * When hour hand moves (once in 12 minutes), all data is updated, differences are
      re-drawn in screen buffer
    * Anti-aliased custom-font hour and minute hands are replaced with vector hands

Powersafe mode is activated in a minute after entering background mode, if:
* Do-not-disturb mode is on (usually it is activated in sleep mode)
* Move bar is full (if you are too busy to make some steps, you don't look at watch)
* Heart rate data is missing (watches are not on your hand)
* Heart rate is less than 1.2x of resting heart rate (you are actually sleeping) 

### Technical details

#### Generating tiles for hands

```sh
./tiler.py --name hour_sides   --tile=24x24 --texture=96x96 elp_hour_sides.png
./tiler.py --name minute_sides --tile=32x32 --texture=160x160 elp_minute_sides.png 
./tiler.py --name gauge_sides  --tile=32x32  gauge_hand_sides.png 
```

#### Prepare production release

1. version in properties.xml and strings.xml
2. update version in manifest.xml
3. build release file 
```sh 
~/opt/ConnectIQ/bin/monkeyc -e -o out/ElPrimero-1.6.0.iq -p ~/opt/ConnectIQ/bin/projectInfo.xml -r -f monkey.jungle -y ~/.ssh/connect_iq.der 
```

### Unsupported devices

* Approach S60 - no HRM
* D2 family - JSON resources not supported
* Edge family - bike devices
* Fenix 3 family - JSON resources not supported
* Fenix 6X Pro - 280x280 screen size is too large for resources initially used with 218x218 devices
* Fenix Chronos - Not enough screen color depth - image is distorted
* Forerunner 230/235/630/735/920 - not round displays
* GPSMAP, Oregin, Rino families - navigator devices
* Venu - AMOLED display which has limitations on pixel-on duration and second hand periodic updates
* Vivoactive HR - Byte arrays not supported by device

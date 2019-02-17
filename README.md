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

```sh 
~/opt/ConnectIQ/bin/monkeyc -e -o ElPrimero-1.0.0.iq -p ~/opt/ConnectIQ/bin/projectInfo.xml -r -f monkey.jungle -y ~/.ssh/connect_iq.der 
```
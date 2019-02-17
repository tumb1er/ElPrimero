# ElPrimero
Classic Zenith analog watchface with anti-aliasing and second hand.

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

### Technical details

#### Generating tiles for hands

```sh
./tiler.py --name hour_sides   --tile=24x24 --texture=96x96 elp_hour_sides.png
./tiler.py --name minute_sides --tile=32x32 --texture=160x160 elp_minute_sides.png 
./tiler.py --name gauge_sides  --tile=32x32  gauge_hand_sides.png 
```

#### Prepare production release

```sh 
~/opt/ConnectIQ/bin/monkeyc -e -o ElPrimero-0.7.0.iq -p ~/opt/ConnectIQ/bin/projectInfo.xml -r -f monkey.jungle -y ~/.ssh/connect_iq.der 
```
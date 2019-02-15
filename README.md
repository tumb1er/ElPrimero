# ElPrimero
Watch face for Garmin Vivoactive 3

./tiler.py --name hour_sides   --tile=24x24 --texture=96x96 elp_hour_sides.png
./tiler.py --name minute_sides --tile=32x32 --texture=160x160 elp_minute_sides.png 
./tiler.py --name gauge_sides  --tile=32x32  gauge_hand_sides.png 

~/opt/ConnectIQ/bin/monkeyc -e -o ElPrimero-0.7.0.iq -p ~/opt/ConnectIQ/bin/projectInfo.xml -r -f monkey.jungle -y ~/.ssh/connect_iq.der 

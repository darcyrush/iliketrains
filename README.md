# Notify when the train is approaching

Defaults to leaving from Gland.
PRs welcome.

## Arguments
```
train_times
   		-d      [D]eparture station (without flag this defaults to Gland)
		-a      [A]rrival station
   		-n      prior [N]otification time in minutes
   		-w      [W]alk time to platform in minutes
   		-t      alert [T]ype (window manager or terminal)
               		- gnome
               		- i3
               		- console
```

## Crontab example
```
		*/3 16-23 * * 1-5 /PATH/TO/SCRIPT/train_times -a Lausanne -n 20 -w 10 -a gnome
```

## Bash alias example
```
		alias trains='/PATH/TO/SCRIPT/train_times -a Lausanne -n 20 -w 10 -a debug'
```

## Misc
Check the board JSON for the destination station names that need passed as an argument
    	http://transport.opendata.ch/v1/stationboard?station=gland&transportations=train&limit=4

Special chars may need escaped.

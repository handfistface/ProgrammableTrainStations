
# Summary
After a binge of circuit tinkering on Factorio, I realized it would be convenient to have dynamically re-namable train stops 
given an arbitrary signal. This mod aims to achieve dynamic train stop names by using signals produced from decider, arithmetic, 
or event constant combinators, basically any signal available. This functionality gives you the ability to more easily create 
multi item stations in a vanilla adjacent manner. 

Your decider circuits can count when an item is under a given quantity, and then rename the station to the icon of the requested item. An example would be
iron and copper plates for green circuits. When copper inevitably runs low, it renames the drop off station to the copper plate icon. 
If you have a train sitting at a station waiting for a copper plate station to become available, then it will automatically go to the
newly named station, dropping off your copper plates, and thus giving you the ability to have multi item stations.

By default, this programmable name behavior is turned off for every station. To enable it, open up the station interface and go to the right of the 
menu. There's a new menu titled Dynamic Name, click on the `Enable Dynamic Name` checkbox. 

# Manual Installing
The programmable-train-stations folder gets dropped into the Factorio installation mods folder. 
On my local system it is `C:\Users\John\AppData\Roaming\Factorio\mods`

# Pulling the latest debug version from your mod folder
1. Run the `./CopyFromFactorioInstall.ps1` script

# Creating a release
1. Run the ZipRelease.ps1 script, pass a parameter indicating the version you want. `./ZipRelease.ps1 2.0`
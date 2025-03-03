# red-homelesscamps 1.0.0
 
[Nobugs Scripts Discord](https://discord.gg/nobugs)

# Resource Description 

Homeless camps it contains stashes inside a tent in which you can place items and also control the weight of the stashes and the number of slots, You can also give access to whoever you want on the server.

# Dependencies
* [ox-lib](https://github.com/overextended/ox_lib)
* [ox-inventory](https://github.com/overextended/ox_inventory)
* [ox-target](https://github.com/overextended/ox_target) or [qb-target](https://github.com/qbcore-framework/qb-target)
* [bl_dialog](https://github.com/Byte-Labs-Studio/bl_dialog) 
 
# Features
* Runs at 0.00ms idle
* You can add black list items (Configurable) .
* Add / Remove access for tent manager .
* There are places where camping is allowed, and you can add more as well (Configurable) . 
* Durability system (Configurable).
* Framework Supports QBOX/QBCore
* Inventory Supports ox_inventory Only .
* Interaction Supports :  ox_target / qb-target 

# Installation

1) Drop the resource into your server files and make sure the script starts running.
2) Make sure you have dependencies.
3) Take the image and go to this path : ox_inventory/web/imagesand drop the image there
4) Add the item below to your ox_inventory

# ox_inventory

* Add to ox_inventory/data/items.lua

```lua
["homelesscamp"] = {
    label = "Homeless Camp",
    weight = 0,
    stack = true,
    close = true,
    description = "Use it and put your own stuff !",
    client = {
        export = 'red-homelesscamps.useItem'
    }
},
```

# Preview

[homelesscamps](https://streamable.com/cewpni)

# Credits

* [Red](https://github.com/RedRed123123)

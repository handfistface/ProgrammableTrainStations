-- This script is for a Factorio mod that allows train stops to have dynamic names based on circuit network signals.
-- It includes functions to get signals from train stops, check if a train stop is programmable, and update the train stop names accordingly.
-- The script also includes GUI elements for players to enable or disable the programmable name feature.
-- By: John Kirschner 
-- Creation date: 04-12-2025

-- TODO
-- * Prefer text station name & settings
-- * Test blueprint functionality
--    This is semi working, but the train stops are not being restored correctly the GUI does not populate the settings initially
-- * Add ability to only use red/green signals
-- * Shift right click does not copy the settings
-- * Copy/paste probably doesn't copy the settings
-- * Add storage for programmable stations & their last received signals, tie this into the on_tick() function to compare the last signal to the current signal and speed up update process
-- * Document storage variables at the top of storageHelper to make it easier to find information on what is stored
-- * trainHelper.get_surface_index_for_train() could be rewritten to use carriages, or front_stock to prevent more lua allocation
-- * base has an example changelog, justarandomgeek suggests setting up fmtk vscode extension for changelog validation https://wiki.factorio.com/Tutorial:Mod_changelog_format
-- * PICKUP: On blueprint copy, I think I'm missing adding the train stop settings to the collection of train stops?

utility = require("src.utility")
signalProcessing = require("src.signalProcessing")
trainHelper = require("src.trainHelper")
storageHelper = require("src.storageHelper")
scheduleHelper = require("src.scheduleHelper")
guiHelper = require("src.guiHelper")


local function signal_to_no_signal(train_stop)
    -- Handle case where no signals were found & the station is set to programmable
    local holdover_name = "No Signals"
    if train_stop.backer_name == holdover_name then
        return
    end

    local all_stations_with_name = trainHelper.get_train_stops(train_stop.backer_name, train_stop.surface_index)
    for _, station in ipairs(all_stations_with_name) do
        utility.print_debug("Signal to no signal - STATION " .. station.backer_name .. " on surface " .. game.surfaces[station.surface_index].name)
    end
    
    storageHelper.backup_trains_for_station(train_stop)
    
    if #all_stations_with_name > 1 then
        utility.print_debug("Signal to no signal - Multiple stations with the same name found. " .. train_stop.backer_name .. " on surface " .. game.surfaces[train_stop.surface_index].name)
        train_stop.backer_name = holdover_name
        return
    end
    
    utility.print_debug("Signal to no signal - Backing up trains & schedules for train stop: " .. train_stop.backer_name .. " on surface " .. game.surfaces[train_stop.surface_index].name)
    scheduleHelper.remove_station_from_schedule(train_stop, train_stop.backer_name)
    train_stop.backer_name = holdover_name
end

local function signals_found_for_train_stop(signals, train_stop)
    local signal = signals[1]
    local new_station_name = signalProcessing.create_new_name_from_signal(signal, train_stop)

    if not signal or not signal.signal or not signal.signal.signal or not signal.signal.signal.name then
        --invalid signal state
        return
    end

    local does_not_contain_arrow_in_name = string.find(train_stop.backer_name, "%[virtual%-signal=up%-arrow%]") == nil 
        and string.find(train_stop.backer_name, "%[virtual%-signal=down%-arrow%]") == nil
    if does_not_contain_arrow_in_name and train_stop.backer_name ~= "No Signals" then
        utility.print_debug("Train stop '" .. train_stop.backer_name .. "' does not contain [virtual-signal=up-arrow] or [virtual-signal=down-arrow]. Setting backer_name to " .. new_station_name)
        train_stop.backer_name = new_station_name
    end

    if train_stop.backer_name == new_station_name then
        -- No need to change the name, it's already set correctly
        return
    end
    
    local all_stations_with_name = trainHelper.get_train_stops(train_stop.backer_name, train_stop.surface_index)
    if #all_stations_with_name == 1 then
        utility.print_debug("Signals found - Only one station left with the name " .. train_stop.backer_name .. " on surface " .. game.surfaces[train_stop.surface_index].name .. ", backing up trains & schedules")
        storageHelper.backup_trains_for_station(train_stop)
        scheduleHelper.remove_station_from_schedule(train_stop, train_stop.backer_name)
    end

    -- Handle case where the station was previously set to "No Signals"
    utility.print_debug("Signals found - Restoring trains & schedules for train stop: " .. train_stop.backer_name .. " on surface " .. game.surfaces[train_stop.surface_index].name)
    train_stop.backer_name = new_station_name
    storageHelper.restore_stations_for_train_stop(new_station_name, train_stop.surface.index)
end


local function on_tick()
    -- utility.wipe_backup_train_schedule()
    -- local stops = trainHelper.get_all_train_stops()
    local stops = storageHelper.get_all_programmable_train_stops()

    for _, train_stop in pairs(stops) do
        if train_stop and train_stop.valid then
            local signals = signalProcessing.get_signals_from_train_stop(train_stop)
            local isProgrammable = trainHelper.is_train_stop_programmable(train_stop)

            if signals and #signals > 0 and isProgrammable then
                -- Handle case where signals were found & the station is set to programmable
                signals_found_for_train_stop(signals, train_stop)
            elseif #signals == 0 and isProgrammable then
                -- Handle case where no signals were found & the station is set to programmable
                signal_to_no_signal(train_stop)
            end
        end
    end
end
script.on_nth_tick(60, on_tick)

-- on_configuration_changed()
-- This function is called when the mod is loaded or configuration changes
-- It initializes the global storage for train stop data
-- and updates existing data if needed
-- If you add or remove a variable in storage,this needs incremented
script.on_configuration_changed(function(event)
    -- Initialize `storage.train_stop_data` if it doesn't exist
    storageHelper.init_storage()

    -- Optionally, update existing data ieded
    for _, trainStop in pairs(trainHelper.get_all_train_stops()) do
        if trainStop.valid and trainStop.unit_number and not storage.train_stop_data[trainStop.unit_number] then
            -- Add default states if the settings do not exist
            storage.train_stop_data[trainStop.unit_number] = { 
                enableProgrammableName = false,
                dropoff_setting = true
            }
        end
    end
end)

-- on_event()
-- Add a GUI element to the train stop GUI for the programmable name feature
script.on_event(defines.events.on_gui_opened, function(event)
    if event.entity and event.entity.type == "train-stop" then
        guiHelper.draw_train_stop_gui(event)
    end
end)

-- on_event()
-- Handle checkbox state changes for the programmable_name_checkbox
script.on_event(defines.events.on_gui_checked_state_changed, function(event)
    guiHelper.on_gui_checked_state_changed(event)
end)

-- on_init()
-- This function is called when the mod is first loaded
-- It initializes the global storage for train stop data
-- and sets up the initial state for all train stops
script.on_init(function()
    storageHelper.init_storage()

    local stops = trainHelper.get_all_train_stops()
    for _, trainStop in pairs(stops) do
        if trainStop.valid and trainStop.unit_number then
            storage.train_stop_data[trainStop.unit_number] = { enableProgrammableName = false }
        end
    end
end)

function trainHelper.find_train_stop_by_position(position, surface)
    local train_stops = surface.find_entities_filtered { type = "train-stop", position = position }
    if #train_stops > 0 then
        return train_stops[1] -- Return the first matching train stop
    end
    return nil
end

require("src.blueprinting")
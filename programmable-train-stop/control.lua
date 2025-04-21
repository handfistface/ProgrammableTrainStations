-- This script is for a Factorio mod that allows train stops to have dynamic names based on circuit network signals.
-- It includes functions to get signals from train stops, check if a train stop is programmable, and update the train stop names accordingly.
-- The script also includes GUI elements for players to enable or disable the programmable name feature.
-- By: John Kirschner 
-- Creation date: 04-12-2025

-- TODO
-- 1. Prefer text station name & settings
-- 2. Test on different planets, probably need to separate stations for different surfaces
--      train_stop.surface.index
--      game.surfaces[1]
--      get_all_train_stops() add overload to get all train stops on a surface
--      then you need to only rename the train stops on the same surface, might need selective wiping when you restore train stops
--    * At this point I've created trainHelper.filter_train_stops_by_surface()

utility = require("src.utility")
signalProcessing = require("src.signalProcessing")
trainHelper = require("src.trainHelper")
storageHelper = require("src.storageHelper")
scheduleHelper = require("src.scheduleHelper")


function signal_to_no_signal(train_stop)
    -- Handle case where no signals were found & the station is set to programmable
    holdover_name = "No Signals"
    if train_stop.backer_name ~= holdover_name then
        
        all_stations_with_name = trainHelper.get_train_stops_by_name(train_stop.backer_name)
        if #all_stations_with_name > 1 then
            utility.print_debug("Multiple stations with the same name found. Just doing rename without digging into attached trains")
            train_stop.backer_name = holdover_name
            return
        end
        
        storageHelper.backup_trains_for_station(train_stop)
        scheduleHelper.remove_station_from_schedule(train_stop, train_stop.backer_name)
        train_stop.backer_name = holdover_name
    end
end

function no_signal_to_signal(train_stop, new_station_name)
    backups_for_station = storage.backup_train_schedule[new_station_name]
    if not backups_for_station or #backups_for_station == 0 then
        utility.print_debug("No backup found for train stop: " .. train_stop.backer_name)
        return
    end

    for index, backup_of_train_and_record in ipairs(backups_for_station) do
        local new_records = {}
        for i, record in ipairs(backup_of_train_and_record.train.schedule.records) do
            table.insert(new_records, record)
        end
        
        has_record = storageHelper.does_backup_contain_train(backup_of_train_and_record.train, train_stop.backer_name)
        if not has_record then
            utility.print_debug("Restoring train stop: " .. train_stop.unit_number .. " " .. train_stop.backer_name .. "for train: " .. backup_of_train_and_record.train.id)
            table.insert(new_records, backup_of_train_and_record.train.schedule.current, backup_of_train_and_record.record)
        end

        scheduleHelper.set_train_schedule(backup_of_train_and_record.train, new_records)
        table.remove(storage.backup_train_schedule[new_station_name], index)
    end
end

function signals_found_for_train_stop(signals, train_stop)

    if #signals < 1 then
        --This should be an impossible situation since we've processed before this function hits
        utility.print_debug("No signals found for train stop: " .. train_stop.backer_name)
        return
    end

    local signal = signals[1]
    local new_station_name = signalProcessing.create_new_name_from_signal(signal, train_stop)

    if not signal or not signal.signal or not signal.signal.signal or not signal.signal.signal.name then
        utility.print_debug("Invalid signal state: " .. train_stop.backer_name)
        return
    end

    if train_stop.backer_name == new_station_name then
        -- No need to change the name, it's already set correctly
        -- utility.print_debug("Train stop name is already set to the signal name: " .. train_stop.backer_name)
        return
    end
    
    local all_stations_with_name = trainHelper.get_train_stops_by_name(train_stop.backer_name)
    if #all_stations_with_name == 1 then
        utility.print_debug("Only one station left with the name " .. train_stop.backer_name .. ", backing up trains & schedules")
        storageHelper.backup_trains_for_station(train_stop)
        scheduleHelper.remove_station_from_schedule(train_stop, train_stop.backer_name)
    end

    -- Handle case where the station was previously set to "No Signals"
    train_stop.backer_name = new_station_name
    storageHelper.restore_stations_for_train_stop(new_station_name)
end

function on_tick()

    -- wipe_backup_train_schedule()
    local stops = trainHelper.get_all_train_stops()

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
    if not storage.train_stop_data then
        storage.train_stop_data = {}
    end
    if not storage.backup_train_schedule then
        storage.backup_train_schedule = {}
    end

    -- Optionally, update existing data if needed
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
        local player = game.players[event.player_index]
        local train_stop = event.entity

        if player.gui.relative["programmable_train_stop_settings"] then
            player.gui.relative["programmable_train_stop_settings"].destroy()
        end

        -- Add a custom frame to the train stop GUI using relative GUI
        local settings_frame = player.gui.relative.add {
            type = "frame",
            name = "programmable_train_stop_settings",
            direction = "vertical",
            caption = "Dynamic Name",
            anchor = {
                gui = defines.relative_gui_type.train_stop_gui,
                position = defines.relative_gui_position.right,
                target = train_stop
            }
        }

        -- Add a checkbox for enabling/disabling programmable name
        local enableProgrammableName = trainHelper.is_train_stop_programmable(train_stop)
        settings_frame.add {
            type = "checkbox",
            name = "enable_programmable_name_checkbox",
            caption = "Enable Dynamic Name",
            state = enableProgrammableName,
        }

        -- add a radio button to identify pickup or drop off
        local dropoff_setting = storageHelper.is_dropoff_set(train_stop)
        settings_frame.add {
            type = "checkbox",
            name = "dropoff_station",
            caption = "Does this station drop items off?",
            state = dropoff_setting
        }
    end
end)

-- on_event()
-- Handle checkbox state changes for the programmable_name_checkbox
script.on_event(defines.events.on_gui_checked_state_changed, function(event)
    if event.element.name == "enable_programmable_name_checkbox" then
        local player = game.players[event.player_index]
        local train_stop = player.opened -- The currently opened train stop

        if train_stop and train_stop.valid and train_stop.type == "train-stop" then
            -- Update the global data for this train stop
            if not storage.train_stop_data[train_stop.unit_number] then
                storage.train_stop_data[train_stop.unit_number] = {}
            end
            storage.train_stop_data[train_stop.unit_number].enableProgrammableName = event.element.state

            -- Debug message
            utility.print_debug("Programmable Name set to: " .. tostring(event.element.state))
        end
    end
    if event.element.name == "dropoff_station" then
        local player = game.players[event.player_index]
        local train_stop = player.opened -- The currently opened train stop

        if train_stop and train_stop.valid and train_stop.type == "train-stop" then
            -- Update the global data for this train stop
            if not storage.train_stop_data[train_stop.unit_number] then
                storage.train_stop_data[train_stop.unit_number] = {}
            end
            storage.train_stop_data[train_stop.unit_number].dropoff_setting = event.element.state

            -- Debug message
            utility.print_debug("Drop off station set to: " .. tostring(event.element.state))
        end
    end
end)

-- on_init()
-- This function is called when the mod is first loaded
-- It initializes the global storage for train stop data
-- and sets up the initial state for all train stops
script.on_init(function()
    if not storage.train_stop_data then
        storage.train_stop_data = {}
    end
    
    if not storage.backup_train_schedule then
        storage.backup_train_schedule = {}
    end

    local stops = trainHelper.get_all_train_stops()
    for _, trainStop in pairs(stops) do
        if trainStop.valid and trainStop.unit_number then
            storage.train_stop_data[trainStop.unit_number] = { enableProgrammableName = false }
        end
    end
end)

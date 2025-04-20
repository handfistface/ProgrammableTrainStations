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

local function print_debug(message)
    debug = false
    if game and debug then
        game.print(message)
    end
end

local function get_signal_type(signal_name)
    if prototypes.item[signal_name] then
        return "item"
    elseif prototypes.fluid[signal_name] then
        return "fluid"
    elseif prototypes.virtual_signal[signal_name] then
        return "virtual-signal"
    elseif prototypes.entity[signal_name] then
        return "entity"
    elseif prototypes.recipe[signal_name] then
        return "recipe"
    else
        return nil -- Signal name not found
    end
end

local function get_signals_from_train_stop(train_stop)
    if not train_stop or not train_stop.valid then
        return nil -- Return nil if the train stop is invalid
    end

    local signals = {}

    -- Get the red circuit network
    local red_network = train_stop.get_circuit_network(defines.wire_connector_id.circuit_red)
    if red_network and red_network.signals then
        for _, signal in pairs(red_network.signals) do
            table.insert(signals, {color = "red", signal = signal})
        end
    end

    -- Get the green circuit network
    local green_network = train_stop.get_circuit_network(defines.wire_connector_id.circuit_green)
    if green_network and green_network.signals then
        for _, signal in pairs(green_network.signals) do
            table.insert(signals, {color = "green", signal = signal})
        end
    end

    return signals
end

local function get_all_train_stops()
    local trainStops = {}
    for _, surface in pairs(game.surfaces) do
        local entities = surface.find_entities_filtered{
            type = "train-stop",
        }
        for _, entity in pairs(entities) do
            table.insert(trainStops, entity)
        end
    end
    return trainStops
end

local function isTrainStopProgrammable(trainStop)
    if not trainStop or not trainStop.valid then
        return false
    end

    local programmable = storage.train_stop_data[trainStop.unit_number]
    if programmable and programmable.enableProgrammableName then
        return true
    end

    return false
end

local function is_dropoff_set(train_stop)
    if not train_stop or not train_stop.valid then
        return false
    end

    local dropoff_setting = storage.train_stop_data[train_stop.unit_number]
    if dropoff_setting and dropoff_setting.dropoff_setting then
        return dropoff_setting.dropoff_setting
    end

    return false
end

local function does_table_contain_key(table, key_to_find)
    for key, value in pairs(table) do
        if key == key_to_find then
            return true
        end
    end
    return false
end

local function create_new_name_from_signal(signal, train_stop)
    if not signal or not signal.signal or not signal.signal.signal or not signal.signal.signal.name then
        return nil -- Return nil if the signal is invalid
    end

    local signalType = get_signal_type(signal.signal.signal.name)
    if not signalType then
        return nil -- Return nil if the signal type is invalid
    end

    -- Determine if the station is a dropoff or pickup station
    local dropoff_setting = is_dropoff_set(train_stop)
    local arrow = dropoff_setting and "[virtual-signal=down-arrow]" or "[virtual-signal=up-arrow]"

    -- Append the arrow to the station name
    return "[" .. signalType .. "=" .. signal.signal.signal.name .. "]" .. arrow
end

function does_backup_contain_train_stop(train_stop)
    return does_table_contain_key(storage.backup_train_schedule, train_stop.backer_name)
end

local function get_train_stops_by_name(station_name)
    local matching_stops = {} -- Table to store matching train stops

    -- Iterate through all surfaces in the game
    for _, surface in pairs(game.surfaces) do
        -- Get all train stops on the surface
        local train_stops = surface.find_entities_filtered { type = "train-stop" }

        -- Check each train stop's backer_name
        for _, train_stop in pairs(train_stops) do
            if train_stop.backer_name == station_name then
                table.insert(matching_stops, train_stop)
            end
        end
    end

    return matching_stops
end

function get_trains_with_train_stop_name_from_backup(train_stop_name)
    return storage.backup_train_schedule[train_stop_name] or {}
end

function get_all_active_trains_with_train_stop_name(train_stop_name)
    local trains = {}

    for _, surface in pairs(game.surfaces) do
        local all_trains = {}
        local train_stops = surface.find_entities_filtered { type = "train-stop" }
        for _, train_stop in pairs(train_stops) do
            local trains = train_stop.get_train_stop_trains()
            for _, train in pairs(trains) do
                table.insert(all_trains, train)
            end
        end
        for _, train in pairs(all_trains) do
            if train and train.valid and train.schedule then
                for _, record in ipairs(train.schedule.records) do
                    if record.station == train_stop_name then
                        table.insert(trains, train)
                        break -- Exit the loop once a match is found
                    end
                end
            end
        end
    end

    return trains
end

function set_train_schedule(train, new_records)
    local schedule = train.schedule
    current_station_index = schedule.current
    if schedule.current > #new_records then
        -- If the schedule is longer than the new records, set the current index to the l               
        current_station_index = #new_records
    end
    if #new_records == 0 then
        current_station_index = 1
    end

    interrupt_cache = train.get_schedule().get_interrupts()
    -- Assign the modified schedule back to the train
    train.schedule = {
        current = current_station_index, -- Preserve the current schedule index
        records = new_records, -- Use the modified records
    }
    train.get_schedule().set_interrupts(interrupt_cache)
end

function does_backup_contain_train(train, train_stop_name)
    if not train or not train.valid then
        return false
    end

    if not does_backup_contain_train_stop(train_stop_name) then
        return false
    end

    for _, backup in pairs(storage.backup_train_schedule[train_stop_name]) do
        if backup.train and backup.train.id == train.id then
            return true
        end
    end

    return false
end

function get_record_from_schedule_by_name(train, station_name_to_find)
    if not train or not train.valid then
        return nil
    end

    local schedule = train.schedule
    if not schedule or not schedule.records then
        return nil
    end

    for _, record in ipairs(schedule.records) do
        if record.station == station_name_to_find then
            return record
        end
    end

    return nil
end

function wipe_backup_train_schedule()
    if storage.backup_train_schedule then
        storage.backup_train_schedule = {} -- Reset the table to an empty table
        print_debug("All backup train schedules have been wiped out.")
    else
        print_debug("No backup train schedules found to wipe out.")
    end
end

function backup_trains_for_station(train_stop)

    if train_stop.backer_name == "No Signals" then
        return
    end

    train_stop_exists_in_backup = does_backup_contain_train_stop(train_stop)
    if not train_stop_exists_in_backup then
        storage.backup_train_schedule[train_stop.backer_name] = {}
    end
    
    trains_at_station = train_stop.get_train_stop_trains()

    for _, train in pairs(trains_at_station) do
        if train and train.valid and train.schedule then
            if not does_backup_contain_train(train, train_stop.backer_name) then
                -- The schedule does not exist in the backup, so add it
                print_debug("Adding backup schedule for train: " .. train.id .. " " .. train_stop.backer_name)
                record_to_backup = get_record_from_schedule_by_name(train, train_stop.backer_name)
                table.insert(storage.backup_train_schedule[train_stop.backer_name],
                {
                    train = train,
                    record = record_to_backup,
                })
            end
        end
    end
end

function remove_station_from_schedule(train_stop, station_to_remove)
    local train_stop_trains = train_stop.get_train_stop_trains()
    for _, train in ipairs(train_stop_trains) do
        local new_records = {}
        for i, record in ipairs(train.schedule.records) do
            if record.station ~= station_to_remove then -- Skip the record at the specified index
                table.insert(new_records, record)
            end
        end
        set_train_schedule(train, new_records)
    end
end

function restore_stations_for_train_stop(train_stop_name_to_restore)
    if not train_stop_name_to_restore or train_stop_name_to_restore == "No Signals" then
        return
    end

    local backups_for_station = storage.backup_train_schedule[train_stop_name_to_restore]
    if not backups_for_station or #backups_for_station == 0 then
        print_debug("No backup found for train stop: " .. train_stop_name_to_restore)
        return
    end

    for index, backup in ipairs(backups_for_station) do
        local train = backup.train
        local record_to_restore = backup.record

        if train and train.valid and record_to_restore then
            -- Add the record back to the train's schedule
            local new_records = {}
            for _, record in ipairs(train.schedule.records) do
                table.insert(new_records, record)
            end
            table.insert(new_records, record_to_restore)
            set_train_schedule(train, new_records)

            print_debug("Restoring station: " .. train_stop_name_to_restore .. " for train: " .. train.id)
        end
    end

    -- Remove the backup entries since they have been restored
    storage.backup_train_schedule[train_stop_name_to_restore] = nil
end

function signal_to_no_signal(train_stop)
    -- Handle case where no signals were found & the station is set to programmable
    holdover_name = "No Signals"
    if train_stop.backer_name ~= holdover_name then
        
        all_stations_with_name = get_train_stops_by_name(train_stop.backer_name)
        if #all_stations_with_name > 1 then
            print_debug("Multiple stations with the same name found. Just doing rename without digging into attached trains")
            train_stop.backer_name = holdover_name
            return
        end
        
        backup_trains_for_station(train_stop)
        remove_station_from_schedule(train_stop, train_stop.backer_name)
        train_stop.backer_name = holdover_name
    end
end

function no_signal_to_signal(train_stop, new_station_name)
    backups_for_station = storage.backup_train_schedule[new_station_name]
    if not backups_for_station or #backups_for_station == 0 then
        print_debug("No backup found for train stop: " .. train_stop.backer_name)
        return
    end

    for index, backup_of_train_and_record in ipairs(backups_for_station) do
        local new_records = {}
        for i, record in ipairs(backup_of_train_and_record.train.schedule.records) do
            table.insert(new_records, record)
        end
        
        has_record = does_backup_contain_train(backup_of_train_and_record.train, train_stop.backer_name)
        if not has_record then
            print_debug("Restoring train stop: " .. train_stop.unit_number .. " " .. train_stop.backer_name .. "for train: " .. backup_of_train_and_record.train.id)
            table.insert(new_records, backup_of_train_and_record.train.schedule.current, backup_of_train_and_record.record)
        end

        set_train_schedule(backup_of_train_and_record.train, new_records)
        table.remove(storage.backup_train_schedule[new_station_name], index)
    end
end

function signals_found_for_train_stop(signals, train_stop)

    if #signals < 1 then
        --This should be an impossible situation since we've processed before this function hits
        print_debug("No signals found for train stop: " .. train_stop.backer_name)
        return
    end

    local signal = signals[1]
    local new_station_name = create_new_name_from_signal(signal, train_stop)

    if not signal or not signal.signal or not signal.signal.signal or not signal.signal.signal.name then
        print_debug("Invalid signal state: " .. train_stop.backer_name)
        return
    end

    if train_stop.backer_name == new_station_name then
        -- No need to change the name, it's already set correctly
        -- print_debug("Train stop name is already set to the signal name: " .. train_stop.backer_name)
        return
    end
    
    local all_stations_with_name = get_train_stops_by_name(train_stop.backer_name)
    if #all_stations_with_name == 1 then
        print_debug("Only one station left with the name " .. train_stop.backer_name .. ", backing up trains & schedules")
        backup_trains_for_station(train_stop)
        remove_station_from_schedule(train_stop, train_stop.backer_name)
    end

    -- Handle case where the station was previously set to "No Signals"
    train_stop.backer_name = new_station_name
    restore_stations_for_train_stop(new_station_name)
end

script.on_nth_tick(60, on_tick)
function on_tick()

    -- wipe_backup_train_schedule()
    local stops = get_all_train_stops()

    for _, train_stop in pairs(stops) do
        if train_stop and train_stop.valid then
            local signals = get_signals_from_train_stop(train_stop)
            local isProgrammable = isTrainStopProgrammable(train_stop)
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
    for _, trainStop in pairs(get_all_train_stops()) do
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
        local enableProgrammableName = isTrainStopProgrammable(train_stop)
        settings_frame.add {
            type = "checkbox",
            name = "enable_programmable_name_checkbox",
            caption = "Enable Dynamic Name",
            state = enableProgrammableName,
        }

        -- add a radio button to identify pickup or drop off
        local dropoff_setting = is_dropoff_set(train_stop)
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
            print_debug("Programmable Name set to: " .. tostring(event.element.state))
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
            print_debug("Drop off station set to: " .. tostring(event.element.state))
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

    local stops = get_all_train_stops()
    for _, trainStop in pairs(stops) do
        if trainStop.valid and trainStop.unit_number then
            storage.train_stop_data[trainStop.unit_number] = { enableProgrammableName = false }
        end
    end
end)

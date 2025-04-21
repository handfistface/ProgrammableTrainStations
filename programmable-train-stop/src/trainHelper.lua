trainHelper = {}

function trainHelper.get_all_train_stops()
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

function trainHelper.is_train_stop_programmable(trainStop)
    if not trainStop or not trainStop.valid then
        return false
    end

    local programmable = storage.train_stop_data[trainStop.unit_number]
    if programmable and programmable.enableProgrammableName then
        return true
    end

    return false
end

function trainHelper.get_train_stops_by_name(station_name)
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

function trainHelper.get_record_from_schedule_by_name(train, station_name_to_find)
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

function trainHelper.filter_train_stops_by_surface(train_stop_array, surface_index)
    local train_stops = {}
    for _, train_stop in pairs(train_stop_array) do
        if train_stop and train_stop.valid and train_stop.surface_index == surface_index then
            table.insert(train_stops, train_stop)
        end
    end
    return train_stops
end

return trainHelper
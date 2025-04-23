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

function trainHelper.get_train_stops(stop_name, surface_index)
    local matching_stops = {}

    surface = game.surfaces[surface_index]
    local train_stops = surface.find_entities_filtered { type = "train-stop" }

    -- Check each train stop's backer_name
    for _, train_stop in pairs(train_stops) do
        if train_stop.backer_name == stop_name then
            table.insert(matching_stops, train_stop)
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

function trainHelper.get_surface_index_for_train(train)
    if not train or not train.valid then
        return 1
    end

    local rails = train.get_rails()
    if not rails or #rails == 0 then
        return 1
    end

    local surface_index = rails[1].surface_index
    return surface_index
end

function trainHelper.get_train_stop_trains(train_stop, surface_index)
    if not train_stop or not train_stop.valid then
        return nil
    end

    local trains = {}
    for _, train in pairs(train_stop.get_train_stop_trains()) do
        local train_surface_index = trainHelper.get_surface_index_for_train(train)
        if train_surface_index == surface_index then
            table.insert(trains, train)
        end
    end

    return trains
end

return trainHelper
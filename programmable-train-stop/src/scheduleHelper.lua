scheduleHelper = {}

function scheduleHelper.set_train_schedule(train, new_records)
    local schedule = train.schedule
    local current_station_index = 1
    if schedule and schedule.current then
        -- Preserve the current schedule index if it exists
        current_station_index = schedule.current
    end
    if current_station_index > #new_records then
        -- If the schedule is longer than the new records, set the current index to the l               
        current_station_index = #new_records
    end

    local interrupt_cache = train.get_schedule().get_interrupts()
    if #new_records == 0 then
        train.schedule = nil
    else
        train.schedule = {
            current = current_station_index, -- Preserve the current schedule index
            records = new_records, -- Use the modified records
        }
    end
    train.get_schedule().set_interrupts(interrupt_cache)
end

function scheduleHelper.remove_station_from_schedule(train_stop, station_to_remove)
    local train_stop_trains = trainHelper.get_train_stop_trains(train_stop, train_stop.surface_index)
    if not train_stop_trains or #train_stop_trains == 0 then
        utility.print_debug("No trains found for the train stop " .. train_stop.backer_name)
        return
    end

    for _, train in ipairs(train_stop_trains) do
        local new_records = {}
        for i, record in ipairs(train.schedule.records) do
            if record.station ~= station_to_remove then -- Skip the record at the specified index
                table.insert(new_records, record)
            end
        end
        scheduleHelper.set_train_schedule(train, new_records)
    end
end

return scheduleHelper
scheduleHelper = {}

function scheduleHelper.set_train_schedule(train, new_records)
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

function scheduleHelper.remove_station_from_schedule(train_stop, station_to_remove)
    local train_stop_trains = train_stop.get_train_stop_trains()
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
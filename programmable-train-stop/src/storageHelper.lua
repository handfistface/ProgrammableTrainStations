storageHelper = {}

function init_programmable_train_stops()
    -- This will reinitialize the programmable_train_stops table in storage, use it while debugging when that table is wiped out
    local stops = trainHelper.get_all_train_stops()
    for _, train_stop in pairs(stops) do
        if train_stop.valid and train_stop.unit_number and storage.train_stop_data then
            -- Initialize the storage for each train stop
            if storage.train_stop_data[train_stop.unit_number] and storage.train_stop_data[train_stop.unit_number].enableProgrammableName then
                storageHelper.add_programmable_train_stop(train_stop)
            end
        end
    end
end

function storageHelper.init_storage()
    if not storage.train_stop_data then
        storage.train_stop_data = {}
    end
    if not storage.backup_train_schedule then
        storage.backup_train_schedule = {}
    end
    if not storage.programmable_train_stops then 
        storage.programmable_train_stops = {}
    end
    init_programmable_train_stops()
end

function storageHelper.is_dropoff_set(train_stop)
    if not train_stop or not train_stop.valid then
        return false
    end

    local dropoff_setting = storage.train_stop_data[train_stop.unit_number]
    if dropoff_setting and dropoff_setting.dropoff_setting then
        return dropoff_setting.dropoff_setting
    end

    return false
end

function storageHelper.does_backup_contain_train_stop(train_stop)
    backups = storage.backup_train_schedule[train_stop.backer_name]
    if backups and #backups > 0 then
        return true
    end
    return false
end


function storageHelper.does_backup_contain_train(train, train_stop_name)
    if not train or not train.valid then
        return false
    end

    if not storageHelper.does_backup_contain_train_stop(train_stop_name) then
        return false
    end

    for _, backup in pairs(storage.backup_train_schedule[train_stop_name]) do
        if backup.train and backup.train.id == train.id then
            return true
        end
    end

    return false
end

function storageHelper.backup_trains_for_station(train_stop)

    if train_stop.backer_name == "No Signals" then
        return
    end

    local train_stop_exists_in_backup = storageHelper.does_backup_contain_train_stop(train_stop)
    if not train_stop_exists_in_backup then
        storage.backup_train_schedule[train_stop.backer_name] = {}
    end
    
    local trains_at_station = trainHelper.get_train_stop_trains(train_stop, train_stop.surface_index)
    if not trains_at_station or #trains_at_station == 0 then
        utility.print_debug("backup_trains_for_station() - No trains found at station: " .. train_stop.backer_name)
        return
    end

    for _, train in pairs(trains_at_station) do
        if train and train.valid and train.schedule then
            if not storageHelper.does_backup_contain_train(train, train_stop.backer_name) then
                -- The schedule does not exist in the backup, so add it
                utility.print_debug("backup_trains_for_station() - Adding backup schedule for train: " .. train.id .. " " .. train_stop.backer_name)
                record_to_backup = trainHelper.get_record_from_schedule_by_name(train, train_stop.backer_name)
                table.insert(storage.backup_train_schedule[train_stop.backer_name],
                {
                    train = train,
                    record = record_to_backup,
                    surface_index = train_stop.surface_index
                })
            end
        end
    end
end

function storageHelper.get_stations_for_surface(train_stop_name, surface_index)
    local train_stop_backups = storage.backup_train_schedule[train_stop_name]
    if not train_stop_backups or #train_stop_backups == 0 then
        utility.print_debug("No backup found for train stop " .. train_stop_name .. " on surface index " .. surface_index)
        return nil
    end

    local filtered_train_stops = {}
    for _, train_stop_backup in pairs(train_stop_backups) do
        if train_stop_backup.surface_index == surface_index then
            table.insert(filtered_train_stops, train_stop_backup)
        end
    end
    return filtered_train_stops
end

function storageHelper.does_schedule_contain_record(train_schedule_records, record_to_find)
    if not train_schedule_records then
        return false
    end

    for _, record in ipairs(train_schedule_records) do
        if utility.deep_equals(record, record_to_find) then
            return true
        end
    end

    return false
end

function storageHelper.remove_stations_for_surface(train_stop_name, surface_index)
    local train_stop_backups = storage.backup_train_schedule[train_stop_name]
    if not train_stop_backups or #train_stop_backups == 0 then
        utility.print_debug("No backup found for train stop " .. train_stop_name .. " on surface index " .. surface_index)
        return nil
    end

    for index, train_stop_backup in pairs(train_stop_backups) do
        if train_stop_backup.surface_index == surface_index then
            table.remove(train_stop_backups, index)
            utility.print_debug("Removed backup for train stop " .. train_stop_name .. " on surface index " .. surface_index)
        end
    end
end

function storageHelper.restore_stations_for_train_stop(train_stop_name_to_restore, surface_index)
    if not train_stop_name_to_restore or train_stop_name_to_restore == "No Signals" then
        return
    end

    local backups_for_station = storageHelper.get_stations_for_surface(train_stop_name_to_restore, surface_index)
    if not backups_for_station or #backups_for_station == 0 then
        utility.print_debug("No backup found for train stop: " .. train_stop_name_to_restore)
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
            if not storageHelper.does_schedule_contain_record(new_records, record_to_restore) then
                table.insert(new_records, record_to_restore)
            end
            scheduleHelper.set_train_schedule(train, new_records)

            utility.print_debug("Restoring station: " .. train_stop_name_to_restore .. " for train: " .. train.id)
        end
    end

    -- Remove the backup entries since they have been restored
    storageHelper.remove_stations_for_surface(train_stop_name_to_restore, surface_index)
end

function storageHelper.get_all_programmable_train_stops()
    return storage.programmable_train_stops
end

function storageHelper.add_programmable_train_stop(train_stop)
    if not train_stop or not train_stop.valid then
        return
    end

    if not storage.programmable_train_stops[train_stop.unit_number] then
        storage.programmable_train_stops[train_stop.unit_number] = train_stop
    end
end

function storageHelper.remove_programmable_train_stop(train_stop)
    if not train_stop or not train_stop.valid then
        return
    end

    if storage.programmable_train_stops[train_stop.unit_number] then
        storage.programmable_train_stops[train_stop.unit_number] = nil
    end
end

return storageHelper
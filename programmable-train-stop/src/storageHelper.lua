storageHelper = {}

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
    return utility.does_table_contain_key(storage.backup_train_schedule, train_stop.backer_name)
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

    train_stop_exists_in_backup = storageHelper.does_backup_contain_train_stop(train_stop)
    if not train_stop_exists_in_backup then
        storage.backup_train_schedule[train_stop.backer_name] = {}
    end
    
    trains_at_station = train_stop.get_train_stop_trains()

    for _, train in pairs(trains_at_station) do
        if train and train.valid and train.schedule then
            if not storageHelper.does_backup_contain_train(train, train_stop.backer_name) then
                -- The schedule does not exist in the backup, so add it
                utility.print_debug("Adding backup schedule for train: " .. train.id .. " " .. train_stop.backer_name)
                record_to_backup = trainHelper.get_record_from_schedule_by_name(train, train_stop.backer_name)
                table.insert(storage.backup_train_schedule[train_stop.backer_name],
                {
                    train = train,
                    record = record_to_backup,
                })
            end
        end
    end
end

function storageHelper.restore_stations_for_train_stop(train_stop_name_to_restore)
    if not train_stop_name_to_restore or train_stop_name_to_restore == "No Signals" then
        return
    end

    local backups_for_station = storage.backup_train_schedule[train_stop_name_to_restore]
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
            table.insert(new_records, record_to_restore)
            scheduleHelper.set_train_schedule(train, new_records)

            utility.print_debug("Restoring station: " .. train_stop_name_to_restore .. " for train: " .. train.id)
        end
    end

    -- Remove the backup entries since they have been restored
    storage.backup_train_schedule[train_stop_name_to_restore] = nil
end

return storageHelper
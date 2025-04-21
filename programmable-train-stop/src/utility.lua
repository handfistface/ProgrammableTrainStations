local utility = {}

function utility.print_debug(message)
    debug = false 
    if game and debug then
        game.print(message)
    end
end

function utility.does_table_contain_key(table, key_to_find)
    for key, value in pairs(table) do
        if key == key_to_find then
            return true
        end
    end
    return false
end

function utility.wipe_backup_train_schedule()
    if storage.backup_train_schedule then
        storage.backup_train_schedule = {} -- Reset the table to an empty table
        utility.print_debug("All backup train schedules have been wiped out.")
    else
        utility.print_debug("No backup train schedules found to wipe out.")
    end
end

return utility
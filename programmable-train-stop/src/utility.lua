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

function utility.deep_equals(obj1, obj2)
    -- Check for reference equality
    if obj1 == obj2 then
        return true
    end

    -- Check if both are tables
    if type(obj1) ~= "table" or type(obj2) ~= "table" then
        return false
    end

    -- Check if both have the same set of keys and values
    for key, value in pairs(obj1) do
        if not utility.deep_equals(value, obj2[key]) then
            return false
        end
    end

    -- Check if obj2 has extra keys not in obj1
    for key, _ in pairs(obj2) do
        if obj1[key] == nil then
            return false
        end
    end

    return true
end

return utility
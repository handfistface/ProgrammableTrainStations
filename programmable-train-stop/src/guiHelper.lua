guiHelper = {}

storageHelper = require("src.storageHelper")

function guiHelper.draw_train_stop_gui(event)
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

    -- add a checkbox to identify pickup or drop off
    local dropoff_setting = storageHelper.is_dropoff_set(train_stop)
    settings_frame.add {
        type = "checkbox",
        name = "dropoff_station",
        caption = "Drop off station",
        state = dropoff_setting
    }
end

function guiHelper.on_gui_checked_state_changed(event)
    if event.element.name == "enable_programmable_name_checkbox" then
        local player = game.players[event.player_index]
        local train_stop = player.opened -- The currently opened train stop

        if train_stop and train_stop.valid and train_stop.type == "train-stop" then
            -- Update the global data for this train stop
            if not storage.train_stop_data[train_stop.unit_number] then
                storage.train_stop_data[train_stop.unit_number] = {}
            end

            if event.element.state then
                storageHelper.add_programmable_train_stop(train_stop)
            else
                storageHelper.remove_programmable_train_stop(train_stop)
            end
            
            storage.train_stop_data[train_stop.unit_number].enableProgrammableName = event.element.state
            
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

            utility.print_debug("Drop off station set to: " .. tostring(event.element.state))
        end
    end
end

return guiHelper
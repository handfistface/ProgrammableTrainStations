-- This script's job is to handle the blueprinting of train stops, 
-- including copying and pasting settings from one train stop to another, 
-- and ensuring that the settings are preserved when a train stop is built or configured in a blueprint.


script.on_event(defines.events.on_player_setup_blueprint, function(event)
    local player = game.get_player(event.player_index)
    local blueprint = player.blueprint_to_setup

    local entities = nil
    if blueprint and blueprint.valid_for_read then
        entities = blueprint.get_blueprint_entities()
        utility.print_debug("Using player.blueprint_to_setup for blueprint entities.")
    elseif player.cursor_stack and player.cursor_stack.valid_for_read then
        blueprint = player.cursor_stack
        entities = player.cursor_stack.get_blueprint_entities()
        utility.print_debug("Using cursor stack for blueprint entities.")
    else
        utility.print_debug("No valid blueprint found in player.blueprint_to_setup or player.cursor stack.")
        return
    end

    if entities then
        for entity_index, entity in pairs(entities) do
            if entity.name == "train-stop" then
                -- Use position to find the corresponding runtime entity
                local runtime_entity = trainHelper.find_train_stop_by_position(entity.position, player.surface)
                if runtime_entity and runtime_entity.valid then
                    local train_stop_data = storage.train_stop_data[runtime_entity.unit_number]
                    if train_stop_data then
                        -- Add custom tags to the blueprint
                        entity.tags = entity.tags or {}
                        entity.tags.train_stop_settings = {
                            enableProgrammableName = train_stop_data.enableProgrammableName,
                            dropoff_setting = train_stop_data.dropoff_setting
                        }
                        blueprint.set_blueprint_entity_tag(entity_index, "train_stop_settings", entity.tags.train_stop_settings)
                        utility.print_debug("Added train stop settings to blueprint for train-stop: " .. serpent.block(entity.tags))
                    end
                end
            end
        end
    end
end)

script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity}, function(event)
    local entity = event.created_entity or event.entity

    -- Ensure the entity is a train stop
    if entity and entity.valid and entity.type == "train-stop" then
        -- Check if the train stop has blueprint tags
        local blueprint_settings = event.tags and event.tags.train_stop_settings
        if blueprint_settings then
            -- Apply the blueprint settings to the new train stop
            storage.train_stop_data[entity.unit_number] = {
                enableProgrammableName = blueprint_settings.enableProgrammableName,
                dropoff_setting = blueprint_settings.dropoff_setting
            }
            if blueprint_settings.enableProgrammableName then
                storageHelper.add_programmable_train_stop(entity)
            end
            utility.print_debug("Applied blueprint settings to train stop: " .. entity.backer_name)
        else
            -- Initialize default settings for the new train stop
            storage.train_stop_data[entity.unit_number] = {
                enableProgrammableName = false,
                dropoff_setting = false
            }
            utility.print_debug("Initialized default settings for new train stop: " .. entity.backer_name)
        end
    end
end)

script.on_event(defines.events.on_entity_settings_pasted, function(event)
    local source = event.source
    local destination = event.destination

    -- Ensure both source and destination are train stops
    if source and source.valid and source.type == "train-stop" and
        destination and destination.valid and destination.type == "train-stop" then

        -- Copy settings from source to destination
        local source_settings = storage.train_stop_data[source.unit_number]
        if source_settings then
            storage.train_stop_data[destination.unit_number] = {
                enableProgrammableName = source_settings.enableProgrammableName,
                dropoff_setting = source_settings.dropoff_setting
            }
            if source_settings.enableProgrammableName then
                storageHelper.add_programmable_train_stop(destination)
            end
            utility.print_debug("Copied settings from train stop " .. source.backer_name .. " to " .. destination.backer_name)
        else
            utility.print_debug("No settings found for source train stop: " .. source.backer_name)
        end
    end
end)
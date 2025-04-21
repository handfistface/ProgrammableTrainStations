signalProcessing = {}

function signalProcessing.get_signal_type(signal_name)
    if prototypes.item[signal_name] then
        return "item"
    elseif prototypes.fluid[signal_name] then
        return "fluid"
    elseif prototypes.virtual_signal[signal_name] then
        return "virtual-signal"
    elseif prototypes.entity[signal_name] then
        return "entity"
    elseif prototypes.recipe[signal_name] then
        return "recipe"
    else
        -- Signal name not found
        return nil
    end
end

function signalProcessing.get_signals_from_train_stop(train_stop)
    if not train_stop or not train_stop.valid then
        return nil -- Return nil if the train stop is invalid
    end

    local signals = {}

    -- Get the red circuit network
    local red_network = train_stop.get_circuit_network(defines.wire_connector_id.circuit_red)
    if red_network and red_network.signals then
        for _, signal in pairs(red_network.signals) do
            table.insert(signals, {color = "red", signal = signal})
        end
    end

    -- Get the green circuit network
    local green_network = train_stop.get_circuit_network(defines.wire_connector_id.circuit_green)
    if green_network and green_network.signals then
        for _, signal in pairs(green_network.signals) do
            table.insert(signals, {color = "green", signal = signal})
        end
    end

    return signals
end

function signalProcessing.create_new_name_from_signal(signal, train_stop)
    if not signal or not signal.signal or not signal.signal.signal or not signal.signal.signal.name then
        return nil -- Return nil if the signal is invalid
    end

    local signalType = signalProcessing.get_signal_type(signal.signal.signal.name)
    if not signalType then
        return nil -- Return nil if the signal type is invalid
    end

    -- Determine if the station is a dropoff or pickup station
    local dropoff_setting = storageHelper.is_dropoff_set(train_stop)
    local arrow = dropoff_setting and "[virtual-signal=down-arrow]" or "[virtual-signal=up-arrow]"

    -- Append the arrow to the station name
    return "[" .. signalType .. "=" .. signal.signal.signal.name .. "]" .. arrow
end

return signalProcessing
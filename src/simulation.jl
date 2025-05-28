using Random
using JSON3
# using LibPQ, DBInterface
function update_asset_power!(asset::Asset)
    if asset.asset_type == "load"
        asset.power = -rand(100:200)
    elseif asset.asset_type == "source"
        asset.power = rand(0:300)
    elseif asset.asset_type == "battery"
        asset.power = 0.0
    end
end

function node_net_power(node::Node, assets::Vector{Asset})
    sum(a -> a.node_id == node.id ? a.power : 0.0, assets)
end

function write_asset_timeseries(conn, assets, timestamp, simulation_id, model_id)
    for asset in assets
        LibPQ.execute(
            conn,
            "INSERT INTO asset_timeseries (asset_id, timestamp, power, simulation_id, model_id) VALUES (\$1, \$2, \$3, \$4, \$5)",
            (asset.id, timestamp, asset.power, simulation_id, model_id)
        )
    end
end

function create_simulation(conn; model_id, name="Simulation", description="", parameters=Dict())
    result = LibPQ.execute(
        conn,
        "INSERT INTO simulation (model_id, name, description, start_time, parameters) VALUES (\$1, \$2, \$3, \$4, \$5) RETURNING id",
        (model_id, name, description, Dates.now(), JSON3.write(parameters))
    )
    id = LibPQ.fetch(result)[1, 1]
    return Int64(id)
end

"Check if a simulation exists"
function simulation_exists(conn, simulation_id::Int)
    result = LibPQ.execute(conn, "SELECT 1 FROM simulation WHERE id = \$1", (simulation_id,))
    return !isempty(result)  # Direct check on LibPQ.Result
end

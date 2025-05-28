# scripts/run_simulation.jl

using Dates
include("../src/models.jl")
include("../src/db/connection.jl")
include("../src/db/insert.jl")
include("../src/simulation.jl")

conn = get_connection()

# Insert nodes and assets if not already present

# --- Simulation ID Handling ---
if length(ARGS) == 0
    # --- Create new model, nodes, assets, and simulation ---
    model_id = insert_model(conn, "Test Model", "A simple test model with 2 households and a substation")
    println("No model_id provided. Created new model with ID $model_id")

    node1_id = insert_node(conn, model_id, "Household 1", "residence")
    node2_id = insert_node(conn, model_id, "Household 2", "residence")
    node3_id = insert_node(conn, model_id, "Substation 1", "substation")

    asset1_id = insert_asset(conn, model_id, node1_id, "Fridge", "load")
    asset2_id = insert_asset(conn, model_id, node1_id, "Solar Panel", "source")
    asset3_id = insert_asset(conn, model_id, node2_id, "Heat Pump", "load")
    asset4_id = insert_asset(conn, model_id, node2_id, "Battery", "battery")
    asset5_id = insert_asset(conn, model_id, node3_id, "Transformer", "load")

    nodes = [
        Node(node1_id, "Household 1"),
        Node(node2_id, "Household 2"),
        Node(node3_id, "Substation 1")
    ]

    assets = [
        Asset(asset1_id, node1_id, "Fridge", "load", -150.0),
        Asset(asset2_id, node1_id, "Solar Panel", "source", 200.0),
        Asset(asset3_id, node2_id, "Heat Pump", "load", -1000.0),
        Asset(asset4_id, node2_id, "Battery", "battery", 0.0),
        Asset(asset5_id, node3_id, "Transformer", "load", -50.0)
    ]

    simulation_id = create_simulation(conn; model_id=model_id, name="Auto-created", description="Started automatically", parameters=Dict())
    println("No simulation_id provided. Created new simulation with ID $simulation_id")

else
    # --- Use existing model (and possibly simulation) ---
    model_id = parse(Int, ARGS[1])
    if length(ARGS) >= 2
        simulation_id = parse(Int, ARGS[2])
        if !simulation_exists(conn, simulation_id)
            println("Simulation ID $simulation_id does not exist. Creating a new simulation for model $model_id...")
            simulation_id = create_simulation(conn; model_id=model_id, name="Auto-created", description="Started automatically", parameters=Dict())
            println("New simulation created with ID $simulation_id")
        else
            println("Resuming simulation with ID $simulation_id for model $model_id")
        end
    else
        simulation_id = create_simulation(conn; model_id=model_id, name="Auto-created", description="Started automatically", parameters=Dict())
        println("No simulation_id provided. Created new simulation with ID $simulation_id")
    end

    # --- Load nodes and assets from the database for the given model_id ---
    nodes = load_nodes(conn, model_id)
    assets = load_assets(conn, model_id)
end


# Create a new simulation run
# simulation_id = create_simulation(conn; model_id=model_id, name="My Experiment", description="Testing batteries", parameters=Dict("duration" => 10))
# simulation_id = create_simulation(conn; name="My Experiment", description="Testing batteries", parameters=Dict("duration" => 10))

# Simulation loop: 10 timesteps, 1 minute apart
start_time = Dates.now()
for step in 1:10
    timestamp = start_time + Dates.Minute(step - 1)
    for asset in assets
        update_asset_power!(asset)
    end
    write_asset_timeseries(conn, assets, timestamp, simulation_id, model_id)
    for node in nodes
        println("Node $(node.name) net power: $(node_net_power(node, assets)) W at $timestamp")
    end
end

close(conn)

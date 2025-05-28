# scripts/run_simulation.jl

using ArgParse
using Dates
using DataFrames
include("../src/models.jl")
include("../src/db/connection.jl")
include("../src/db/insert.jl")
include("../src/simulation.jl")

const SIMULATION_START_TIME = DateTime(2025, 1, 1, 0, 0, 0)


function get_resume_timestamp(conn, simulation_id, model_id)
    result = LibPQ.execute(
        conn,
        """
        SELECT MAX(timestamp) AS last_time
        FROM asset_timeseries
        WHERE simulation_id = \$1 AND model_id = \$2
        """,
        (simulation_id, model_id)
    )
    last_time = LibPQ.fetch(result)[1, 1]
    if last_time === missing
        return nothing
    else
        return last_time + Minute(1)
    end
end

# Define argument parser
function parse_args()
    s = ArgParseSettings()
    @add_arg_table s begin
        "--model"
            help = "Model ID"
            arg_type = Int
            required = false
        "--simulation"
            help = "Simulation ID"
            arg_type = Int
            required = false
    end
    return ArgParse.parse_args(ARGS, s)
end

function load_nodes(conn, model_id)
    result = LibPQ.execute(conn, "SELECT id, name FROM node WHERE model_id = \$1", (model_id,))
    return [Node(row.id, row.name) for row in LibPQ.fetch(result)]
end

function load_assets(conn, model_id)
    result = LibPQ.execute(conn, "SELECT id, node_id, name, asset_type FROM asset WHERE model_id = \$1", (model_id,))
    # You may want to also load the initial power value from another table or set a default
    return [Asset(row.id, row.node_id, row.name, row.asset_type, 0.0) for row in LibPQ.fetch(result)]
end

args = parse_args()

conn = get_connection()

# Insert nodes and assets if not already present

# --- Simulation ID Handling ---
if !haskey(args, "model") || args["model"] === nothing
    # No model provided: create new model, nodes, assets, simulation
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
    start_time = Dates.now()  # New simulation starts from current time
    steps_completed = 0

else
    # --- Use existing model (and possibly simulation) ---
    model_id = args["model"]
    start_time = Dates.now()  # Default start time
    steps_completed = 0       # Default steps completed
    
    if haskey(args, "simulation") && args["simulation"] !== nothing
        simulation_id = args["simulation"]
        if !simulation_exists(conn, simulation_id)
            println("Simulation ID $simulation_id does not exist. Creating a new simulation for model $model_id...")
            simulation_id = create_simulation(conn; model_id=model_id, name="Auto-created", description="Started automatically", parameters=Dict())
            println("New simulation created with ID $simulation_id")
        else
            println("Resuming simulation with ID $simulation_id for model $model_id")
            # Find the last timestamp for this simulation
            result = LibPQ.execute(
                conn,
                "SELECT MAX(timestamp) AS max_ts, COUNT(DISTINCT timestamp) AS ts_count FROM asset_timeseries WHERE simulation_id = \$1",
                (simulation_id,)
            ) |> DataFrame

            last_timestamp = result.max_ts[1]
            steps_completed = coalesce(result.ts_count[1], 0)
            
            if last_timestamp === missing || last_timestamp === nothing
                println("No previous data found for simulation $simulation_id. Starting fresh.")
                start_time = Dates.now()
            else
                println("Found $steps_completed previous timesteps. Last timestamp: $last_timestamp")
                # If we want to continue exactly where we left off
                start_time = last_timestamp - Dates.Minute(steps_completed - 1)
                # Or if we want to add more timesteps after the last one:
                # start_time = last_timestamp + Dates.Minute(1)
            end
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
start_time = nothing  # or use `DateTime` if you want to be explicit

if simulation_id === nothing
    # New simulation: use constant start time
    start_time = SIMULATION_START_TIME
    println("Starting new simulation at $start_time")
else
    # Provided simulation: check for last timestamp in asset_timeseries
    resume_time = get_resume_timestamp(conn, simulation_id, model_id)
    if isnothing(resume_time)
        start_time = SIMULATION_START_TIME
        println("No previous data for simulation $simulation_id. Starting at $start_time")
    else
        start_time = resume_time
        println("Resuming simulation $simulation_id at $start_time")
    end
end

println(start_time)

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

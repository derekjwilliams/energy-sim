using LibPQ

function get_connection()
    # Adjust connection string as needed
    return LibPQ.Connection("dbname=energy_sim user=postgres password=postgres host=localhost")
end
using LibPQ

function get_connection()
    # Adjust connection string as needed
    return LibPQ.Connection("dbname=postgres user=postgres password=postgres host=localhost")
end
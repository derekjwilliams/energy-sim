function insert_model(conn, name, description="")
    result = LibPQ.execute(
        conn,
        "INSERT INTO model (name, description) VALUES (\$1, \$2) RETURNING id",
        (name, description)
    )
    id = LibPQ.fetch(result)[1, 1]
    return Int64(id)
end

function insert_node(conn, model_id, name, node_type)
    result = LibPQ.execute(
        conn,
        "INSERT INTO node (model_id, name, node_type) VALUES (\$1, \$2, \$3) RETURNING id",
        (model_id, name, node_type)
    )
    id = LibPQ.fetch(result)[1, 1]
    return Int64(id)
end

function insert_asset(conn, model_id, node_id, name, asset_type)
    result = LibPQ.execute(
        conn,
        "INSERT INTO asset (model_id, node_id, name, asset_type) VALUES (\$1, \$2, \$3, \$4) RETURNING id",
        (model_id, node_id, name, asset_type)
    )
    id = LibPQ.fetch(result)[1, 1]
    return Int64(id)
end

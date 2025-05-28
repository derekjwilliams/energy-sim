mutable struct Node
    id::Int
    name::String
end

mutable struct Asset
    id::Int
    node_id::Int
    name::String
    asset_type::String
    power::Float64
end

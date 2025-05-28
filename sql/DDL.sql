-- public.account definition

-- Drop table

-- DROP TABLE public.account;

CREATE TABLE public.account (
	id serial4 NOT NULL, -- Primary key for the account
	"name" text NOT NULL, -- Name of the account (person, business, etc.)
	"type" text NOT NULL, -- Type of account: person, business, organization, or government
	CONSTRAINT account_pkey PRIMARY KEY (id),
	CONSTRAINT account_type_check CHECK ((type = ANY (ARRAY['person'::text, 'business'::text, 'organization'::text, 'government'::text])))
);
COMMENT ON TABLE public.account IS 'Financially responsible party for a node (person, business, organization, or government)';

-- Column comments

COMMENT ON COLUMN public.account.id IS 'Primary key for the account';
COMMENT ON COLUMN public.account."name" IS 'Name of the account (person, business, etc.)';
COMMENT ON COLUMN public.account."type" IS 'Type of account: person, business, organization, or government';

-- Permissions

ALTER TABLE public.account OWNER TO postgres;
GRANT ALL ON TABLE public.account TO postgres;


-- public.node definition

-- Drop table

-- DROP TABLE public.node;

CREATE TABLE public.node (
	id serial4 NOT NULL, -- Primary key for the node
	"name" text NOT NULL, -- Name of the node
	node_type text NOT NULL, -- Type of node: residence, business, substation, distribution, etc.
	"location" public.geography NULL, -- Geographic location of the node (PostGIS GEOGRAPHY type)
	metadata jsonb NULL, -- Extensible metadata for the node (JSONB)
	CONSTRAINT node_pkey PRIMARY KEY (id)
);
COMMENT ON TABLE public.node IS 'Logical point in the energy network (residence, business, substation, distribution node, etc.)';

-- Column comments

COMMENT ON COLUMN public.node.id IS 'Primary key for the node';
COMMENT ON COLUMN public.node."name" IS 'Name of the node';
COMMENT ON COLUMN public.node.node_type IS 'Type of node: residence, business, substation, distribution, etc.';
COMMENT ON COLUMN public.node."location" IS 'Geographic location of the node (PostGIS GEOGRAPHY type)';
COMMENT ON COLUMN public.node.metadata IS 'Extensible metadata for the node (JSONB)';

-- Permissions

ALTER TABLE public.node OWNER TO postgres;
GRANT ALL ON TABLE public.node TO postgres;


-- public.simulation definition

-- Drop table

-- DROP TABLE public.simulation;

CREATE TABLE public.simulation (
	id serial4 NOT NULL, -- Primary key for the simulation run.
	"name" text NOT NULL, -- Name of the simulation run.
	description text NULL, -- Description of the simulation scenario.
	start_time timestamp DEFAULT now() NOT NULL, -- Simulation start time.
	end_time timestamp NULL, -- Simulation end time (if completed).
	parameters jsonb NULL, -- Simulation parameters/settings (JSONB).
	metadata jsonb NULL, -- Extensible metadata for the simulation (JSONB).
	CONSTRAINT simulation_pkey PRIMARY KEY (id)
);
COMMENT ON TABLE public.simulation IS 'Metadata for each simulation run.';

-- Column comments

COMMENT ON COLUMN public.simulation.id IS 'Primary key for the simulation run.';
COMMENT ON COLUMN public.simulation."name" IS 'Name of the simulation run.';
COMMENT ON COLUMN public.simulation.description IS 'Description of the simulation scenario.';
COMMENT ON COLUMN public.simulation.start_time IS 'Simulation start time.';
COMMENT ON COLUMN public.simulation.end_time IS 'Simulation end time (if completed).';
COMMENT ON COLUMN public.simulation.parameters IS 'Simulation parameters/settings (JSONB).';
COMMENT ON COLUMN public.simulation.metadata IS 'Extensible metadata for the simulation (JSONB).';

-- Permissions

ALTER TABLE public.simulation OWNER TO postgres;
GRANT ALL ON TABLE public.simulation TO postgres;


-- public.account_node definition

-- Drop table

-- DROP TABLE public.account_node;

CREATE TABLE public.account_node (
	account_id int4 NOT NULL, -- Foreign key to account
	node_id int4 NOT NULL, -- Foreign key to node
	CONSTRAINT account_node_pkey PRIMARY KEY (account_id, node_id),
	CONSTRAINT account_node_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.account(id) ON DELETE CASCADE,
	CONSTRAINT account_node_node_id_fkey FOREIGN KEY (node_id) REFERENCES public.node(id) ON DELETE CASCADE
);
COMMENT ON TABLE public.account_node IS 'Many-to-many relationship between accounts and nodes';

-- Column comments

COMMENT ON COLUMN public.account_node.account_id IS 'Foreign key to account';
COMMENT ON COLUMN public.account_node.node_id IS 'Foreign key to node';

-- Permissions

ALTER TABLE public.account_node OWNER TO postgres;
GRANT ALL ON TABLE public.account_node TO postgres;


-- public.asset definition

-- Drop table

-- DROP TABLE public.asset;

CREATE TABLE public.asset (
	id serial4 NOT NULL, -- Primary key for the asset
	node_id int4 NULL, -- Foreign key to the node where the asset is located
	"name" text NULL, -- Name or description of the asset
	asset_type text NOT NULL, -- Type of asset: load, source, or battery
	CONSTRAINT asset_asset_type_check CHECK ((asset_type = ANY (ARRAY['load'::text, 'source'::text, 'battery'::text]))),
	CONSTRAINT asset_pkey PRIMARY KEY (id),
	CONSTRAINT asset_node_id_fkey FOREIGN KEY (node_id) REFERENCES public.node(id) ON DELETE CASCADE
);
COMMENT ON TABLE public.asset IS 'Base table for all assets. asset_type determines which detail table is used.';

-- Column comments

COMMENT ON COLUMN public.asset.id IS 'Primary key for the asset';
COMMENT ON COLUMN public.asset.node_id IS 'Foreign key to the node where the asset is located';
COMMENT ON COLUMN public.asset."name" IS 'Name or description of the asset';
COMMENT ON COLUMN public.asset.asset_type IS 'Type of asset: load, source, or battery';

-- Permissions

ALTER TABLE public.asset OWNER TO postgres;
GRANT ALL ON TABLE public.asset TO postgres;


-- public.asset_attribute definition

-- Drop table

-- DROP TABLE public.asset_attribute;

CREATE TABLE public.asset_attribute (
	asset_id int4 NOT NULL, -- Foreign key to the asset
	manufacturer text NULL, -- Manufacturer of the asset
	model text NULL, -- Model of the asset
	install_date date NULL, -- Installation date of the asset
	metadata jsonb NULL, -- Extensible metadata for the asset (JSONB)
	CONSTRAINT asset_attribute_pkey PRIMARY KEY (asset_id),
	CONSTRAINT asset_attribute_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES public.asset(id) ON DELETE CASCADE
);
COMMENT ON TABLE public.asset_attribute IS 'Non-power-related attributes for assets.';

-- Column comments

COMMENT ON COLUMN public.asset_attribute.asset_id IS 'Foreign key to the asset';
COMMENT ON COLUMN public.asset_attribute.manufacturer IS 'Manufacturer of the asset';
COMMENT ON COLUMN public.asset_attribute.model IS 'Model of the asset';
COMMENT ON COLUMN public.asset_attribute.install_date IS 'Installation date of the asset';
COMMENT ON COLUMN public.asset_attribute.metadata IS 'Extensible metadata for the asset (JSONB)';

-- Permissions

ALTER TABLE public.asset_attribute OWNER TO postgres;
GRANT ALL ON TABLE public.asset_attribute TO postgres;


-- public.asset_timeseries definition

-- Drop table

-- DROP TABLE public.asset_timeseries;

CREATE TABLE public.asset_timeseries (
	id bigserial NOT NULL,
	asset_id int4 NULL, -- Foreign key to the asset
	"timestamp" timestamp NOT NULL, -- Timestamp for the measurement
	power float8 NULL, -- Net power for the asset during this interval (watts). Positive = producing, Negative = consuming
	metadata jsonb NULL, -- Extensible metadata for the time series record (JSONB)
	simulation_id int4 NULL, -- Foreign key to the simulation run this record belongs to.
	model_id int8 NULL,
	CONSTRAINT asset_timeseries_pkey PRIMARY KEY (id),
	CONSTRAINT asset_timeseries_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES public.asset(id) ON DELETE CASCADE,
	CONSTRAINT asset_timeseries_simulation_id_fkey FOREIGN KEY (simulation_id) REFERENCES public.simulation(id) ON DELETE CASCADE
);
CREATE INDEX idx_asset_timeseries_asset_sim_time ON public.asset_timeseries USING btree (asset_id, simulation_id, "timestamp");
CREATE INDEX idx_asset_timeseries_asset_time ON public.asset_timeseries USING btree (asset_id, "timestamp");
COMMENT ON INDEX public.idx_asset_timeseries_asset_time IS 'Index for efficient queries by asset and timestamp in asset_timeseries';
CREATE INDEX idx_asset_timeseries_model_sim ON public.asset_timeseries USING btree (model_id, simulation_id);
CREATE INDEX idx_asset_timeseries_sim_time ON public.asset_timeseries USING btree (simulation_id, "timestamp");
COMMENT ON TABLE public.asset_timeseries IS 'Time series of net power for each asset. Positive = producing (source), Negative = consuming (load), in watts.';

-- Column comments

COMMENT ON COLUMN public.asset_timeseries.asset_id IS 'Foreign key to the asset';
COMMENT ON COLUMN public.asset_timeseries."timestamp" IS 'Timestamp for the measurement';
COMMENT ON COLUMN public.asset_timeseries.power IS 'Net power for the asset during this interval (watts). Positive = producing, Negative = consuming';
COMMENT ON COLUMN public.asset_timeseries.metadata IS 'Extensible metadata for the time series record (JSONB)';
COMMENT ON COLUMN public.asset_timeseries.simulation_id IS 'Foreign key to the simulation run this record belongs to.';

-- Permissions

ALTER TABLE public.asset_timeseries OWNER TO postgres;
GRANT ALL ON TABLE public.asset_timeseries TO postgres;


-- public.battery_asset definition

-- Drop table

-- DROP TABLE public.battery_asset;

CREATE TABLE public.battery_asset (
	asset_id int4 NOT NULL, -- Foreign key to the asset
	capacity_wh float8 NULL, -- Total energy storage capacity (watt-hours)
	max_charge_power_w float8 NULL, -- Maximum charging power (watts)
	max_discharge_power_w float8 NULL, -- Maximum discharging power (watts)
	CONSTRAINT battery_asset_pkey PRIMARY KEY (asset_id),
	CONSTRAINT battery_asset_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES public.asset(id) ON DELETE CASCADE
);
COMMENT ON TABLE public.battery_asset IS 'Attributes for battery (storage) assets.';

-- Column comments

COMMENT ON COLUMN public.battery_asset.asset_id IS 'Foreign key to the asset';
COMMENT ON COLUMN public.battery_asset.capacity_wh IS 'Total energy storage capacity (watt-hours)';
COMMENT ON COLUMN public.battery_asset.max_charge_power_w IS 'Maximum charging power (watts)';
COMMENT ON COLUMN public.battery_asset.max_discharge_power_w IS 'Maximum discharging power (watts)';

-- Permissions

ALTER TABLE public.battery_asset OWNER TO postgres;
GRANT ALL ON TABLE public.battery_asset TO postgres;


-- public.load_asset definition

-- Drop table

-- DROP TABLE public.load_asset;

CREATE TABLE public.load_asset (
	asset_id int4 NOT NULL, -- Foreign key to the asset
	power_minimum_w float8 NULL, -- Minimum power consumption (watts)
	power_maximum_w float8 NULL, -- Maximum power consumption (watts)
	CONSTRAINT load_asset_pkey PRIMARY KEY (asset_id),
	CONSTRAINT load_asset_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES public.asset(id) ON DELETE CASCADE
);
COMMENT ON TABLE public.load_asset IS 'Attributes for load assets (e.g., appliances, HVAC).';

-- Column comments

COMMENT ON COLUMN public.load_asset.asset_id IS 'Foreign key to the asset';
COMMENT ON COLUMN public.load_asset.power_minimum_w IS 'Minimum power consumption (watts)';
COMMENT ON COLUMN public.load_asset.power_maximum_w IS 'Maximum power consumption (watts)';

-- Permissions

ALTER TABLE public.load_asset OWNER TO postgres;
GRANT ALL ON TABLE public.load_asset TO postgres;


-- public.network_edge definition

-- Drop table

-- DROP TABLE public.network_edge;

CREATE TABLE public.network_edge (
	id serial4 NOT NULL, -- Primary key for the network edge
	from_node_id int4 NULL, -- Source node in the edge
	to_node_id int4 NULL, -- Destination node in the edge
	connection_type text NOT NULL, -- Type of connection: distribution, transmission, etc.
	metadata jsonb NULL, -- Extensible metadata for the edge (JSONB)
	CONSTRAINT network_edge_pkey PRIMARY KEY (id),
	CONSTRAINT network_edge_from_node_id_fkey FOREIGN KEY (from_node_id) REFERENCES public.node(id) ON DELETE CASCADE,
	CONSTRAINT network_edge_to_node_id_fkey FOREIGN KEY (to_node_id) REFERENCES public.node(id) ON DELETE CASCADE
);
COMMENT ON TABLE public.network_edge IS 'Represents an edge (connection) between two nodes in the network topology';

-- Column comments

COMMENT ON COLUMN public.network_edge.id IS 'Primary key for the network edge';
COMMENT ON COLUMN public.network_edge.from_node_id IS 'Source node in the edge';
COMMENT ON COLUMN public.network_edge.to_node_id IS 'Destination node in the edge';
COMMENT ON COLUMN public.network_edge.connection_type IS 'Type of connection: distribution, transmission, etc.';
COMMENT ON COLUMN public.network_edge.metadata IS 'Extensible metadata for the edge (JSONB)';

-- Permissions

ALTER TABLE public.network_edge OWNER TO postgres;
GRANT ALL ON TABLE public.network_edge TO postgres;


-- public.source_asset definition

-- Drop table

-- DROP TABLE public.source_asset;

CREATE TABLE public.source_asset (
	asset_id int4 NOT NULL, -- Foreign key to the asset
	power_minimum_w float8 NULL, -- Minimum power output (watts)
	power_maximum_w float8 NULL, -- Maximum power output (watts)
	CONSTRAINT source_asset_pkey PRIMARY KEY (asset_id),
	CONSTRAINT source_asset_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES public.asset(id) ON DELETE CASCADE
);
COMMENT ON TABLE public.source_asset IS 'Attributes for source assets (e.g., solar panels, wind turbines).';

-- Column comments

COMMENT ON COLUMN public.source_asset.asset_id IS 'Foreign key to the asset';
COMMENT ON COLUMN public.source_asset.power_minimum_w IS 'Minimum power output (watts)';
COMMENT ON COLUMN public.source_asset.power_maximum_w IS 'Maximum power output (watts)';

-- Permissions

ALTER TABLE public.source_asset OWNER TO postgres;
GRANT ALL ON TABLE public.source_asset TO postgres;
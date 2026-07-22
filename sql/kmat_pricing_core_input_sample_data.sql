INSERT INTO KMAT_PRICING.CORE_INPUT.CUSTOMER_MASTER
(
    CUSTOMER_ID,
    CUSTOMER_NAME,
    INDUSTRY,
    REGION,
    CUSTOMER_SEGMENT,
    PAYMENT_TERMS,
    DISCOUNT_GROUP,
    ACTIVE_FLAG
)
VALUES
(
    'CUST001',
    'ABC Motors Ltd.',
    'Automotive',
    'North',
    'Enterprise',
    'Net 30',
    'GOLD',
    TRUE
),
(
    'CUST002',
    'XYZ Logistics Pvt. Ltd.',
    'Logistics',
    'West',
    'Enterprise',
    'Net 45',
    'SILVER',
    TRUE
),
(
    'CUST003',
    'Global Construction Co.',
    'Construction',
    'South',
    'Strategic',
    'Net 60',
    'PLATINUM',
    TRUE
),
(
    'CUST004',
    'Metro Transport Services',
    'Transportation',
    'East',
    'Corporate',
    'Net 30',
    'GOLD',
    TRUE
),
(
    'CUST005',
    'Prime Infrastructure Ltd.',
    'Infrastructure',
    'Central',
    'Strategic',
    'Net 45',
    'PLATINUM',
    TRUE
),
(
    'CUST006',
    'Rapid Freight Solutions',
    'Logistics',
    'North',
    'Corporate',
    'Net 30',
    'SILVER',
    TRUE
),
(
    'CUST007',
    'Green Energy Systems',
    'Energy',
    'West',
    'Enterprise',
    'Net 60',
    'GOLD',
    TRUE
),
(
    'CUST008',
    'National Mining Corp.',
    'Mining',
    'East',
    'Strategic',
    'Advance Payment',
    'PLATINUM',
    TRUE
);

INSERT INTO KMAT_PRICING.CORE_INPUT.KMAT_PRODUCT_MASTER
(
KMAT_ID,
PRODUCT_NAME,
PRODUCT_FAMILY,
BASE_UOM,
PRODUCT_STATUS,
CREATED_AT
)
VALUES
('TRUCK001','Heavy Duty Truck','Commercial Vehicles','EA','ACTIVE',CURRENT_TIMESTAMP),
('TRUCK002','Medium Duty Truck','Commercial Vehicles','EA','ACTIVE',CURRENT_TIMESTAMP),
('TRUCK003','Cargo Van','Light Commercial','EA','ACTIVE',CURRENT_TIMESTAMP),
('BUS001','City Bus','Passenger Vehicles','EA','ACTIVE',CURRENT_TIMESTAMP);


INSERT INTO KMAT_PRICING.CORE_INPUT.CHARACTERISTIC_MASTER
(
KMAT_ID,
CHARACTERISTIC_NAME,
ALLOWED_VALUE,
DISPLAY_ORDER,
ACTIVE_FLAG
)
VALUES
('TRUCK001','ENGINE','V8',1,TRUE),
('TRUCK001','CAB','Premium',2,TRUE),
('TRUCK001','COLOR','Red',3,TRUE),
('TRUCK001','WHEELS','Offroad',4,TRUE),

('TRUCK002','ENGINE','V6',1,TRUE),
('TRUCK002','CAB','Standard',2,TRUE),
('TRUCK002','COLOR','Blue',3,TRUE),
('TRUCK002','WHEELS','Standard',4,TRUE);

INSERT INTO KMAT_PRICING.CORE_INPUT.CHARACTERISTIC_VALUES
(
SIMULATION_ID,
KMAT_ID,
CHARACTERISTIC_NAME,
SELECTED_VALUE
)
VALUES
('SIM001','TRUCK001','ENGINE','V8'),
('SIM001','TRUCK001','CAB','Premium'),
('SIM001','TRUCK001','COLOR','Red'),
('SIM001','TRUCK001','WHEELS','Offroad'),

('SIM002','TRUCK002','ENGINE','V6'),
('SIM002','TRUCK002','CAB','Standard'),
('SIM002','TRUCK002','COLOR','Blue'),
('SIM002','TRUCK002','WHEELS','Standard');

INSERT INTO KMAT_PRICING.CORE_INPUT.SIMULATION_HEADER
(
SIMULATION_ID,
KMAT_ID,
CUSTOMER_ID,
SCENARIO_NAME
)
VALUES
('SIM001','TRUCK001','CUST001','Standard Quote'),
('SIM002','TRUCK002','CUST002','Fleet Order'),
('SIM003','BUS001','CUST003','Government Tender');


INSERT INTO KMAT_PRICING.CORE_INPUT.SIMULATION_PARAMETERS
(
SIMULATION_ID,
TARGET_MARGIN_PCT,
FLOOR_MARKUP_PCT,
CEILING_MARKUP_PCT
)
VALUES
('SIM001',25,10,40),
('SIM002',22,8,35),
('SIM003',28,12,45);


-- Pilot Job Configuration

JOB_MARKER = {
    pos = { 1957.27502, -2184.02954, 12.5 },
    type = "cylinder",
    size = 1.5,
    color = { 255, 255, 0, 128 },
}

PLANE_MARKER = {
    pos = { 1985.31934, -2390.26465, 12.5 },
    type = "cylinder",
    size = 1.5,
    color = { 255, 255, 0, 128 },
}

JOB_DESCRIPTION = "Pilot Job\n\nTake a Hydra plane and deliver cargo to multiple locations.\nEarn $10,000 per delivery.\n\nClick 'Get Job' to start."

JOB_SKIN = 61
PLANE_MODEL = 520

-- Cargo delivery loop
CARGO_LOCATIONS = {
    -- Delivery 1
    { pickup = { 2023.77112, -2493.90601, 13.53912 }, delivery = { -1345.85559, -235.33437, 14.14844 }, reward = 10000 },
    -- Delivery 2
    { pickup = { -1207.77112, -146.39467, 14.14844 }, delivery = { 1564.87354, 1339.32458, 10.86610 }, reward = 10000 },
    -- Delivery 3
    { pickup = { 1585.24585, 1261.68652, 10.81250 }, delivery = { 2023.77112, -2493.90601, 13.53912 }, reward = 10000 },
}

CARGO_MARKER_SIZE = 8

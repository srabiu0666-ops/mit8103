// EkoStay MongoDB Analytics & Aggregation Pipelines
// MIT 8103 Advanced Database Systems - Portfolio 4

const dbInstance = db.getSiblingDB('ekostay_nosql');

// 1. Detect anomalous smart-lock access attempts (VPN/proxy detected, foreign IP, or denied keycard taps)
print('Pipeline 1: Smart-Lock Security & Foreign Access Surveillance');
const securityAlertPipeline = [
    {
        $match: {
            $or: [
                { 'sensor_metrics.vpn_or_proxy_detected': true },
                { 'property_location.country': { $ne: 'Nigeria' } },
                { event_type: 'KEYCARD_TAP_DENIED' }
            ]
        }
    },
    {
        $project: {
            _id: 0,
            room_number: 1,
            guest_id: 1,
            device_id: 1,
            ip_address: 1,
            event_type: 1,
            access_channel: 1,
            location: {
                $concat: ['$property_location.city', ', ', '$property_location.country']
            },
            vpn_detected: '$sensor_metrics.vpn_or_proxy_detected',
            timestamp: 1
        }
    },
    { $sort: { timestamp: -1 } }
];

const securityAlerts = dbInstance.room_iot_telemetry.aggregate(securityAlertPipeline).toArray();
printjson(securityAlerts);

// 2. Measure device & room access diversity per guest (detecting credential/key replay across rooms)
print('Pipeline 2: Guest Device & Room Access Velocity');
const guestAccessVelocityPipeline = [
    {
        $group: {
            _id: '$guest_id',
            total_telemetry_events: { $sum: 1 },
            distinct_rooms_targeted: { $addToSet: '$room_number' },
            distinct_devices: { $addToSet: '$device_id' },
            distinct_channels: { $addToSet: '$access_channel' },
            distinct_cities: { $addToSet: '$property_location.city' },
            avg_cabin_temp_c: { $avg: '$sensor_metrics.cabin_temp_celsius' },
            latest_activity: { $max: '$timestamp' }
        }
    },
    {
        $project: {
            _id: 0,
            guest_id: '$_id',
            total_telemetry_events: 1,
            rooms_count: { $size: '$distinct_rooms_targeted' },
            rooms_targeted: '$distinct_rooms_targeted',
            devices_used: '$distinct_devices',
            channels_used: '$distinct_channels',
            cities: '$distinct_cities',
            avg_cabin_temp_c: { $round: ['$avg_cabin_temp_c', 1] },
            latest_activity: 1
        }
    },
    { $sort: { rooms_count: -1, total_telemetry_events: -1 } }
];

const velocityReport = dbInstance.room_iot_telemetry.aggregate(guestAccessVelocityPipeline).toArray();
printjson(velocityReport);

// 3. Unwind concierge & security resolution actions across tickets ($unwind)
print('Pipeline 3: Concierge & Security Resolution Action Breakdown');
const resolutionBreakdownPipeline = [
    { $unwind: '$resolution_actions' },
    {
        $group: {
            _id: '$resolution_actions',
            action_count: { $sum: 1 },
            avg_priority_score: { $avg: '$priority_score' },
            associated_tickets: { $addToSet: '$ticket_id' },
            rooms_involved: { $addToSet: '$room_number' }
        }
    },
    {
        $project: {
            _id: 0,
            resolution_action: '$_id',
            frequency: '$action_count',
            avg_priority_score: { $round: ['$avg_priority_score', 1] },
            tickets: '$associated_tickets',
            rooms: '$rooms_involved'
        }
    },
    { $sort: { avg_priority_score: -1, frequency: -1 } }
];

const resolutionSummary = dbInstance.guest_concierge_requests.aggregate(resolutionBreakdownPipeline).toArray();
printjson(resolutionSummary);

// 4. Single-pass Smart Hotel Operations Dashboard using $facet
print('Pipeline 4: Multi-Faceted Smart Hotel Operations Dashboard');
const operationsDashboardPipeline = [
    {
        $facet: {
            access_channel_distribution: [
                { $group: { _id: '$access_channel', count: { $sum: 1 } } },
                { $sort: { count: -1 } }
            ],
            event_type_summary: [
                { $group: { _id: '$event_type', count: { $sum: 1 } } },
                { $sort: { count: -1 } }
            ],
            anomalous_vpn_events: [
                { $match: { 'sensor_metrics.vpn_or_proxy_detected': true } },
                { $count: 'total_vpn_attempts' }
            ]
        }
    }
];

const dashboardResult = dbInstance.room_iot_telemetry.aggregate(operationsDashboardPipeline).toArray();
printjson(dashboardResult);

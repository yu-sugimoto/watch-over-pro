import { DynamoDBClient, PutItemCommand } from '@aws-sdk/client-dynamodb';

const ddb = new DynamoDBClient({});

const FAMILIES_TABLE = process.env.FAMILIES_TABLE!;
const FAMILY_MEMBERS_TABLE = process.env.FAMILY_MEMBERS_TABLE!;
const CURRENT_LOCATIONS_TABLE = process.env.CURRENT_LOCATIONS_TABLE!;
const PAIRING_CODES_TABLE = process.env.PAIRING_CODES_TABLE!;
const ROUTE_CHUNKS_TABLE = process.env.ROUTE_CHUNKS_TABLE!;
const STOP_EVENTS_TABLE = process.env.STOP_EVENTS_TABLE!;

const DEMO_USER_ID = 'demo-tracked-user-001';

// Shibuya area route: Shibuya Station → Miyashita Park → near Yoyogi Park
const ROUTE_POINTS = [
  { lat: 35.658, lng: 139.7016 }, // Shibuya Station
  { lat: 35.6595, lng: 139.7004 }, // Shibuya Center-gai
  { lat: 35.6612, lng: 139.699 }, // Towards Miyashita Park
  { lat: 35.6625, lng: 139.6978 }, // Miyashita Park
  { lat: 35.6648, lng: 139.6955 }, // Towards Yoyogi
  { lat: 35.667, lng: 139.6935 }, // Near Yoyogi Park
];

function todayStr(): string {
  const d = new Date();
  return `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, '0')}${String(d.getDate()).padStart(2, '0')}`;
}

function ttl7Days(): number {
  return Math.floor(Date.now() / 1000) + 7 * 24 * 60 * 60;
}

export async function handler(): Promise<{ status: string }> {
  const now = new Date().toISOString();
  const today = todayStr();
  const ttl = ttl7Days();

  // 1. Family
  await ddb.send(
    new PutItemCommand({
      TableName: FAMILIES_TABLE,
      Item: {
        family_id: { S: DEMO_USER_ID },
        name: { S: 'デモ家族' },
        plan_status: { S: 'free' },
        created_at: { S: now },
      },
    }),
  );

  // 2. Family member (tracked)
  await ddb.send(
    new PutItemCommand({
      TableName: FAMILY_MEMBERS_TABLE,
      Item: {
        family_id: { S: DEMO_USER_ID },
        member_user_id: { S: DEMO_USER_ID },
        display_name: { S: '田中 太郎' },
        relationship: { S: 'child' },
        age: { N: '10' },
        color_hex: { S: 'FF9500' },
        notes: { S: '' },
        role: { S: 'tracked' },
        joined_at: { S: now },
      },
    }),
  );

  // 3. Current location (Shibuya area)
  await ddb.send(
    new PutItemCommand({
      TableName: CURRENT_LOCATIONS_TABLE,
      Item: {
        tracked_user_id: { S: DEMO_USER_ID },
        lat: { N: '35.6595' },
        lng: { N: '139.7004' },
        altitude: { N: '35' },
        accuracy: { N: '10' },
        speed: { N: '1.2' },
        heading: { N: '0' },
        battery_level: { N: '0.72' },
        is_active: { BOOL: true },
        updated_at: { S: now },
      },
    }),
  );

  // 4. Pairing code 999999 (never expires)
  await ddb.send(
    new PutItemCommand({
      TableName: PAIRING_CODES_TABLE,
      Item: {
        code: { S: '999999' },
        family_id: { S: DEMO_USER_ID },
        created_by: { S: DEMO_USER_ID },
        is_used: { BOOL: false },
        expires_at: { S: '2030-01-01T00:00:00.000Z' },
        expires_at_epoch: { N: '1893456000' },
        created_at: { S: now },
      },
    }),
  );

  // 5. Route chunks (today)
  const baseEpoch = Date.now() - 60 * 60 * 1000; // 1 hour ago
  for (let i = 0; i < ROUTE_POINTS.length; i++) {
    const chunkEpoch = baseEpoch + i * 10 * 60 * 1000; // 10 min intervals
    const pt = ROUTE_POINTS[i];
    await ddb.send(
      new PutItemCommand({
        TableName: ROUTE_CHUNKS_TABLE,
        Item: {
          tracked_user_id_date: { S: `${DEMO_USER_ID}#${today}` },
          chunk_start_epoch_ms: { N: String(chunkEpoch) },
          points: {
            L: [
              {
                M: {
                  lat: { N: String(pt.lat) },
                  lng: { N: String(pt.lng) },
                  timestamp: { S: new Date(chunkEpoch).toISOString() },
                },
              },
            ],
          },
          created_at: { S: new Date(chunkEpoch).toISOString() },
          ttl: { N: String(ttl) },
        },
      }),
    );
  }

  // 6. Stop event (15 min stop at Miyashita Park)
  const stopEpoch = baseEpoch + 30 * 60 * 1000; // 30 min ago
  await ddb.send(
    new PutItemCommand({
      TableName: STOP_EVENTS_TABLE,
      Item: {
        tracked_user_id_date: { S: `${DEMO_USER_ID}#${today}` },
        stop_start_epoch_ms: { N: String(stopEpoch) },
        lat: { N: '35.6625' },
        lng: { N: '139.6978' },
        started_at: { S: new Date(stopEpoch).toISOString() },
        duration_seconds: { N: String(15 * 60) },
        ttl: { N: String(ttl) },
      },
    }),
  );

  return { status: 'Demo data seeded successfully' };
}

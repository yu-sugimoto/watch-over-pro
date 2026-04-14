import {
  DynamoDBClient,
  UpdateItemCommand,
  QueryCommand,
  PutItemCommand,
} from '@aws-sdk/client-dynamodb';

const ddb = new DynamoDBClient({});

const CURRENT_LOCATIONS_TABLE = process.env.CURRENT_LOCATIONS_TABLE!;
const PAIRING_CODES_TABLE = process.env.PAIRING_CODES_TABLE!;
const ROUTE_CHUNKS_TABLE = process.env.ROUTE_CHUNKS_TABLE!;
const STOP_EVENTS_TABLE = process.env.STOP_EVENTS_TABLE!;

const DEMO_USER_ID = 'demo-tracked-user-001';

// Shibuya area route for daily re-seeding
const ROUTE_POINTS = [
  { lat: 35.658, lng: 139.7016 },
  { lat: 35.6595, lng: 139.7004 },
  { lat: 35.6612, lng: 139.699 },
  { lat: 35.6625, lng: 139.6978 },
  { lat: 35.6648, lng: 139.6955 },
  { lat: 35.667, lng: 139.6935 },
];

function todayStr(): string {
  const d = new Date();
  return `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, '0')}${String(d.getDate()).padStart(2, '0')}`;
}

function ttl7Days(): number {
  return Math.floor(Date.now() / 1000) + 7 * 24 * 60 * 60;
}

function randomBetween(min: number, max: number): number {
  return min + Math.random() * (max - min);
}

export async function handler(): Promise<{ status: string }> {
  const now = new Date().toISOString();
  const today = todayStr();

  // 1. Update current location: jitter lat/lng, refresh updated_at
  const latJitter = randomBetween(-0.0003, 0.0003);
  const lngJitter = randomBetween(-0.0003, 0.0003);
  const battery = randomBetween(0.65, 0.85);

  await ddb.send(
    new UpdateItemCommand({
      TableName: CURRENT_LOCATIONS_TABLE,
      Key: { tracked_user_id: { S: DEMO_USER_ID } },
      UpdateExpression:
        'SET updated_at = :now, lat = :lat, lng = :lng, battery_level = :bat, is_active = :active',
      ExpressionAttributeValues: {
        ':now': { S: now },
        ':lat': { N: String(35.6595 + latJitter) },
        ':lng': { N: String(139.7004 + lngJitter) },
        ':bat': { N: String(Number(battery.toFixed(2))) },
        ':active': { BOOL: true },
      },
    }),
  );

  // 2. Reset pairing code 999999
  await ddb.send(
    new UpdateItemCommand({
      TableName: PAIRING_CODES_TABLE,
      Key: { code: { S: '999999' } },
      UpdateExpression: 'SET is_used = :unused, expires_at = :exp',
      ExpressionAttributeValues: {
        ':unused': { BOOL: false },
        ':exp': { S: '2030-01-01T00:00:00.000Z' },
      },
    }),
  );

  // 3. Ensure today's route data exists
  const pk = `${DEMO_USER_ID}#${today}`;
  const routeResult = await ddb.send(
    new QueryCommand({
      TableName: ROUTE_CHUNKS_TABLE,
      KeyConditionExpression: 'tracked_user_id_date = :pk',
      ExpressionAttributeValues: { ':pk': { S: pk } },
      Limit: 1,
    }),
  );

  if (!routeResult.Items || routeResult.Items.length === 0) {
    const ttl = ttl7Days();
    const baseEpoch = Date.now() - 60 * 60 * 1000;

    for (let i = 0; i < ROUTE_POINTS.length; i++) {
      const chunkEpoch = baseEpoch + i * 10 * 60 * 1000;
      const pt = ROUTE_POINTS[i];
      await ddb.send(
        new PutItemCommand({
          TableName: ROUTE_CHUNKS_TABLE,
          Item: {
            tracked_user_id_date: { S: pk },
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

    // Also seed today's stop event
    const stopEpoch = baseEpoch + 30 * 60 * 1000;
    await ddb.send(
      new PutItemCommand({
        TableName: STOP_EVENTS_TABLE,
        Item: {
          tracked_user_id_date: { S: pk },
          stop_start_epoch_ms: { N: String(stopEpoch) },
          lat: { N: '35.6625' },
          lng: { N: '139.6978' },
          started_at: { S: new Date(stopEpoch).toISOString() },
          duration_seconds: { N: String(15 * 60) },
          ttl: { N: String(ttl) },
        },
      }),
    );
  }

  return { status: 'Demo location refreshed' };
}

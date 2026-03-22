import { DynamoDBClient, QueryCommand, BatchGetItemCommand, AttributeValue } from '@aws-sdk/client-dynamodb';
import { AppSyncResolverEvent } from 'aws-lambda';

const ddb = new DynamoDBClient({});
const FAMILY_MEMBERS_TABLE = process.env.FAMILY_MEMBERS_TABLE!;
const CURRENT_LOCATIONS_TABLE = process.env.CURRENT_LOCATIONS_TABLE!;

export async function handler(event: AppSyncResolverEvent<{ family_id: string }>) {
  const userId = event.identity && 'sub' in event.identity ? event.identity.sub : '';
  if (!userId) {
    throw new Error('Unauthorized');
  }

  const familyId = event.arguments.family_id;

  // 1. Query all family members
  const membersResult = await ddb.send(new QueryCommand({
    TableName: FAMILY_MEMBERS_TABLE,
    KeyConditionExpression: 'family_id = :fid',
    ExpressionAttributeValues: { ':fid': { S: familyId } },
  }));

  const members = (membersResult.Items ?? []).map((item: Record<string, AttributeValue>) => ({
    family_id: item.family_id?.S ?? '',
    member_user_id: item.member_user_id?.S ?? '',
    display_name: item.display_name?.S ?? '',
    relationship: item.relationship?.S ?? '',
    age: Number(item.age?.N ?? '0'),
    color_hex: item.color_hex?.S ?? '',
    role: item.role?.S ?? '',
    joined_at: item.joined_at?.S ?? '',
  }));

  // Verify caller is a member of this family
  const callerIsMember = members.some((m: { member_user_id: string }) => m.member_user_id === userId);
  if (!callerIsMember) {
    throw new Error('Unauthorized: caller is not a member of this family');
  }

  // 2. Get current locations for tracked members
  const trackedUserIds = members
    .filter((m: { role: string }) => m.role === 'tracked')
    .map((m: { member_user_id: string }) => m.member_user_id);

  interface LocationResult {
    tracked_user_id: string;
    lat: number;
    lng: number;
    altitude: number | null;
    accuracy: number | null;
    speed: number | null;
    heading: number | null;
    battery_level: number | null;
    is_active: boolean;
    updated_at: string;
  }

  const locations: LocationResult[] = [];

  if (trackedUserIds.length > 0) {
    // BatchGetItem supports up to 100 keys
    const keys = trackedUserIds.map((id: string) => ({ tracked_user_id: { S: id } }));
    const batchResult = await ddb.send(new BatchGetItemCommand({
      RequestItems: {
        [CURRENT_LOCATIONS_TABLE]: { Keys: keys },
      },
    }));

    const locItems = batchResult.Responses?.[CURRENT_LOCATIONS_TABLE] ?? [];
    for (const item of locItems) {
      locations.push({
        tracked_user_id: item.tracked_user_id?.S ?? '',
        lat: Number(item.lat?.N ?? '0'),
        lng: Number(item.lng?.N ?? '0'),
        altitude: item.altitude?.N ? Number(item.altitude.N) : null,
        accuracy: item.accuracy?.N ? Number(item.accuracy.N) : null,
        speed: item.speed?.N ? Number(item.speed.N) : null,
        heading: item.heading?.N ? Number(item.heading.N) : null,
        battery_level: item.battery_level?.N ? Number(item.battery_level.N) : null,
        is_active: item.is_active?.BOOL ?? true,
        updated_at: item.updated_at?.S ?? '',
      });
    }
  }

  return { members, locations };
}

import { DynamoDBClient, GetItemCommand, UpdateItemCommand, PutItemCommand } from '@aws-sdk/client-dynamodb';
import { AppSyncResolverEvent } from 'aws-lambda';

const ddb = new DynamoDBClient({});
const PAIRING_TABLE = process.env.PAIRING_CODES_TABLE!;
const MEMBERS_TABLE = process.env.FAMILY_MEMBERS_TABLE!;

export async function handler(event: AppSyncResolverEvent<{ code: string }>) {
  const code = event.arguments.code;
  const userId = event.identity && 'sub' in event.identity ? event.identity.sub : '';

  if (!userId) {
    throw new Error('Unauthorized');
  }

  // Look up pairing code
  const result = await ddb.send(new GetItemCommand({
    TableName: PAIRING_TABLE,
    Key: { code: { S: code } },
  }));

  if (!result.Item) {
    throw new Error('Invalid pairing code');
  }

  const isUsed = result.Item.is_used?.BOOL ?? false;
  const expiresAt = result.Item.expires_at?.S;

  if (isUsed) {
    throw new Error('Pairing code already used');
  }

  if (expiresAt && new Date(expiresAt) < new Date()) {
    throw new Error('Pairing code expired');
  }

  const familyId = result.Item.family_id?.S;
  if (!familyId) {
    throw new Error('Invalid pairing code data');
  }

  // Mark code as used
  await ddb.send(new UpdateItemCommand({
    TableName: PAIRING_TABLE,
    Key: { code: { S: code } },
    UpdateExpression: 'SET is_used = :used',
    ExpressionAttributeValues: { ':used': { BOOL: true } },
  }));

  // Add member to family
  const now = new Date().toISOString();
  await ddb.send(new PutItemCommand({
    TableName: MEMBERS_TABLE,
    Item: {
      family_id: { S: familyId },
      member_user_id: { S: userId },
      display_name: { S: '' },
      relationship: { S: 'other' },
      age: { N: '0' },
      color_hex: { S: '34C759' },
      role: { S: 'watcher' },
      joined_at: { S: now },
    },
  }));

  return {
    family_id: familyId,
    member_user_id: userId,
    display_name: '',
    relationship: 'other',
    age: 0,
    color_hex: '34C759',
    role: 'watcher',
    joined_at: now,
  };
}

import { DynamoDBClient, GetItemCommand, UpdateItemCommand, PutItemCommand } from '@aws-sdk/client-dynamodb';
import { AppSyncResolverEvent } from 'aws-lambda';

const ddb = new DynamoDBClient({});
const PAIRING_TABLE = process.env.PAIRING_CODES_TABLE!;
const MEMBERS_TABLE = process.env.FAMILY_MEMBERS_TABLE!;

interface ConsumePairingArgs {
  code: string;
  display_name?: string;
  relationship?: string;
  age?: number;
  color_hex?: string;
}

export async function handler(event: AppSyncResolverEvent<ConsumePairingArgs>) {
  const { code, display_name, relationship, age, color_hex } = event.arguments;
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
  const memberDisplayName = display_name ?? '';
  const memberRelationship = relationship ?? 'other';
  const memberAge = age ?? 0;
  const memberColorHex = color_hex ?? '34C759';

  await ddb.send(new PutItemCommand({
    TableName: MEMBERS_TABLE,
    Item: {
      family_id: { S: familyId },
      member_user_id: { S: userId },
      display_name: { S: memberDisplayName },
      relationship: { S: memberRelationship },
      age: { N: String(memberAge) },
      color_hex: { S: memberColorHex },
      role: { S: 'watcher' },
      joined_at: { S: now },
    },
  }));

  return {
    family_id: familyId,
    member_user_id: userId,
    display_name: memberDisplayName,
    relationship: memberRelationship,
    age: memberAge,
    color_hex: memberColorHex,
    role: 'watcher',
    joined_at: now,
  };
}

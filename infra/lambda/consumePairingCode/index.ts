import {
  DynamoDBClient,
  GetItemCommand,
  UpdateItemCommand,
  PutItemCommand,
} from '@aws-sdk/client-dynamodb';
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
  notes?: string;
}

export async function handler(event: AppSyncResolverEvent<ConsumePairingArgs>) {
  const { code, display_name, relationship, age, color_hex, notes } =
    event.arguments;
  const userId =
    event.identity && 'sub' in event.identity ? event.identity.sub : '';

  if (!userId) {
    throw new Error('Unauthorized');
  }

  // Look up pairing code
  const result = await ddb.send(
    new GetItemCommand({
      TableName: PAIRING_TABLE,
      Key: { code: { S: code } },
    }),
  );

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

  // Mark code as used (with conditional check to prevent race condition)
  try {
    await ddb.send(
      new UpdateItemCommand({
        TableName: PAIRING_TABLE,
        Key: { code: { S: code } },
        UpdateExpression: 'SET is_used = :used',
        ConditionExpression: 'is_used = :not_used',
        ExpressionAttributeValues: {
          ':used': { BOOL: true },
          ':not_used': { BOOL: false },
        },
      }),
    );
  } catch (e: unknown) {
    if (e instanceof Error && e.name === 'ConditionalCheckFailedException') {
      throw new Error('Pairing code already used');
    }
    throw e;
  }

  const now = new Date().toISOString();
  const memberDisplayName = display_name ?? '';
  const memberRelationship = relationship ?? 'other';
  const memberAge = age ?? 0;
  const memberColorHex = color_hex ?? '34C759';
  const memberNotes = notes ?? '';

  const trackedUserId = result.Item.created_by?.S;
  if (!trackedUserId) {
    throw new Error('Invalid pairing code data');
  }

  if (userId === trackedUserId) {
    throw new Error('Cannot consume own pairing code');
  }

  // Update tracked member with watcher-provided info
  await ddb.send(
    new UpdateItemCommand({
      TableName: MEMBERS_TABLE,
      Key: {
        family_id: { S: familyId },
        member_user_id: { S: trackedUserId },
      },
      UpdateExpression:
        'SET display_name = :dn, relationship = :rel, age = :age, color_hex = :ch, notes = :notes',
      ExpressionAttributeValues: {
        ':dn': { S: memberDisplayName },
        ':rel': { S: memberRelationship },
        ':age': { N: String(memberAge) },
        ':ch': { S: memberColorHex },
        ':notes': { S: memberNotes },
      },
    }),
  );

  // Add watcher to family (no display_name needed)
  await ddb.send(
    new PutItemCommand({
      TableName: MEMBERS_TABLE,
      Item: {
        family_id: { S: familyId },
        member_user_id: { S: userId },
        display_name: { S: '' },
        relationship: { S: 'self' },
        age: { N: '0' },
        color_hex: { S: '34C759' },
        notes: { S: '' },
        role: { S: 'watcher' },
        joined_at: { S: now },
      },
    }),
  );

  return {
    family_id: familyId,
    member_user_id: trackedUserId,
    display_name: memberDisplayName,
    relationship: memberRelationship,
    age: memberAge,
    color_hex: memberColorHex,
    notes: memberNotes,
    role: 'tracked',
    joined_at: now,
  };
}

import { DynamoDBClient, PutItemCommand } from '@aws-sdk/client-dynamodb';
import { AppSyncResolverEvent } from 'aws-lambda';

const ddb = new DynamoDBClient({});
const TABLE = process.env.PAIRING_CODES_TABLE!;

function generateCode(): string {
  return Array.from({ length: 6 }, () => Math.floor(Math.random() * 10)).join('');
}

export async function handler(event: AppSyncResolverEvent<{ family_id: string }>) {
  const familyId = event.arguments.family_id;
  const userId = event.identity && 'sub' in event.identity ? event.identity.sub : 'unknown';

  const code = generateCode();
  const now = new Date();
  const expiresAt = new Date(now.getTime() + 24 * 60 * 60 * 1000);
  const expiresAtEpoch = Math.floor(expiresAt.getTime() / 1000);

  await ddb.send(new PutItemCommand({
    TableName: TABLE,
    Item: {
      code: { S: code },
      family_id: { S: familyId },
      created_by: { S: userId },
      is_used: { BOOL: false },
      expires_at: { S: expiresAt.toISOString() },
      expires_at_epoch: { N: String(expiresAtEpoch) },
      created_at: { S: now.toISOString() },
    },
  }));

  return {
    code,
    family_id: familyId,
    created_by: userId,
    expires_at: expiresAt.toISOString(),
    is_used: false,
  };
}

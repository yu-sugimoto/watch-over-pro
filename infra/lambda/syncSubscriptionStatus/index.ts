import { DynamoDBClient, UpdateItemCommand } from '@aws-sdk/client-dynamodb';

const ddb = new DynamoDBClient({});
const TABLE = process.env.FAMILIES_TABLE!;

interface SyncEvent {
  familyId: string;
  status: string;
  expiresAt?: string;
}

export async function handler(event: SyncEvent) {
  const { familyId, status, expiresAt } = event;

  const updateExpr = expiresAt
    ? 'SET plan_status = :status, plan_expires_at = :exp'
    : 'SET plan_status = :status';

  const exprValues: Record<string, { S: string }> = {
    ':status': { S: status },
  };
  if (expiresAt) {
    exprValues[':exp'] = { S: expiresAt };
  }

  await ddb.send(
    new UpdateItemCommand({
      TableName: TABLE,
      Key: { family_id: { S: familyId } },
      UpdateExpression: updateExpr,
      ExpressionAttributeValues: exprValues,
    }),
  );

  return { success: true };
}

import { DynamoDBClient, UpdateItemCommand } from '@aws-sdk/client-dynamodb';
import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';

const ddb = new DynamoDBClient({});
const TABLE = process.env.FAMILIES_TABLE!;

export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    if (!event.body) {
      return { statusCode: 400, body: 'Missing body' };
    }

    const payload = JSON.parse(event.body);
    // App Store Server Notifications V2 payload
    const notificationType = payload.notificationType;
    const data = payload.data;

    if (!data?.appAccountToken || !notificationType) {
      return { statusCode: 400, body: 'Invalid payload' };
    }

    const familyId = data.appAccountToken;
    let planStatus = 'free';
    let expiresAt: string | undefined;

    switch (notificationType) {
      case 'SUBSCRIBED':
      case 'DID_RENEW':
        planStatus = 'premium';
        expiresAt = data.expiresDate;
        break;
      case 'EXPIRED':
      case 'REVOKE':
        planStatus = 'free';
        break;
      case 'GRACE_PERIOD_EXPIRED':
        planStatus = 'free';
        break;
      default:
        break;
    }

    const updateExpr = expiresAt
      ? 'SET plan_status = :status, plan_expires_at = :exp'
      : 'SET plan_status = :status';

    const exprValues: Record<string, any> = {
      ':status': { S: planStatus },
    };
    if (expiresAt) {
      exprValues[':exp'] = { S: expiresAt };
    }

    await ddb.send(new UpdateItemCommand({
      TableName: TABLE,
      Key: { family_id: { S: familyId } },
      UpdateExpression: updateExpr,
      ExpressionAttributeValues: exprValues,
    }));

    return { statusCode: 200, body: 'OK' };
  } catch (error) {
    console.error('Error processing notification:', error);
    return { statusCode: 500, body: 'Internal error' };
  }
}

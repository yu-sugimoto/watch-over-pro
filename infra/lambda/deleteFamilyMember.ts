import {
  DynamoDBClient,
  GetItemCommand,
  DeleteItemCommand,
} from '@aws-sdk/client-dynamodb';
import { AppSyncResolverEvent } from 'aws-lambda';

const ddb = new DynamoDBClient({});
const FAMILY_MEMBERS_TABLE = process.env.FAMILY_MEMBERS_TABLE!;

interface DeleteFamilyMemberArgs {
  family_id: string;
  member_user_id: string;
}

export async function handler(
  event: AppSyncResolverEvent<DeleteFamilyMemberArgs>,
) {
  const userId =
    event.identity && 'sub' in event.identity ? event.identity.sub : '';
  if (!userId) {
    throw new Error('Unauthorized');
  }

  const { family_id, member_user_id } = event.arguments;

  // Verify caller is a member of this family
  const callerResult = await ddb.send(
    new GetItemCommand({
      TableName: FAMILY_MEMBERS_TABLE,
      Key: {
        family_id: { S: family_id },
        member_user_id: { S: userId },
      },
    }),
  );

  if (!callerResult.Item) {
    throw new Error('Unauthorized: caller is not a member of this family');
  }

  // Delete the target member
  await ddb.send(
    new DeleteItemCommand({
      TableName: FAMILY_MEMBERS_TABLE,
      Key: {
        family_id: { S: family_id },
        member_user_id: { S: member_user_id },
      },
    }),
  );

  return true;
}

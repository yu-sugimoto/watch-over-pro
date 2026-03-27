import {
  DynamoDBClient,
  GetItemCommand,
  UpdateItemCommand,
  AttributeValue,
} from '@aws-sdk/client-dynamodb';
import { AppSyncResolverEvent } from 'aws-lambda';

const ddb = new DynamoDBClient({});
const FAMILY_MEMBERS_TABLE = process.env.FAMILY_MEMBERS_TABLE!;

interface UpdateFamilyMemberInput {
  family_id: string;
  member_user_id: string;
  display_name?: string;
  relationship?: string;
  age?: number;
  color_hex?: string;
  notes?: string;
}

interface UpdateFamilyMemberArgs {
  input: UpdateFamilyMemberInput;
}

export async function handler(
  event: AppSyncResolverEvent<UpdateFamilyMemberArgs>,
) {
  const userId =
    event.identity && 'sub' in event.identity ? event.identity.sub : '';
  if (!userId) {
    throw new Error('Unauthorized');
  }

  const {
    family_id,
    member_user_id,
    display_name,
    relationship,
    age,
    color_hex,
    notes,
  } = event.arguments.input;

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

  // Build update expression dynamically
  const expressionParts: string[] = [];
  const expressionValues: Record<string, AttributeValue> = {};
  const expressionNames: Record<string, string> = {};

  if (display_name !== undefined) {
    expressionParts.push('#dn = :dn');
    expressionValues[':dn'] = { S: display_name };
    expressionNames['#dn'] = 'display_name';
  }
  if (relationship !== undefined) {
    expressionParts.push('#rel = :rel');
    expressionValues[':rel'] = { S: relationship };
    expressionNames['#rel'] = 'relationship';
  }
  if (age !== undefined) {
    expressionParts.push('#age = :age');
    expressionValues[':age'] = { N: String(age) };
    expressionNames['#age'] = 'age';
  }
  if (color_hex !== undefined) {
    expressionParts.push('#ch = :ch');
    expressionValues[':ch'] = { S: color_hex };
    expressionNames['#ch'] = 'color_hex';
  }
  if (notes !== undefined) {
    expressionParts.push('#notes = :notes');
    expressionValues[':notes'] = { S: notes };
    expressionNames['#notes'] = 'notes';
  }

  if (expressionParts.length === 0) {
    // Nothing to update, fetch and return current item
    const current = await ddb.send(
      new GetItemCommand({
        TableName: FAMILY_MEMBERS_TABLE,
        Key: {
          family_id: { S: family_id },
          member_user_id: { S: member_user_id },
        },
      }),
    );

    if (!current.Item) {
      throw new Error('Member not found');
    }

    return itemToMember(current.Item);
  }

  let result;
  try {
    result = await ddb.send(
      new UpdateItemCommand({
        TableName: FAMILY_MEMBERS_TABLE,
        Key: {
          family_id: { S: family_id },
          member_user_id: { S: member_user_id },
        },
        UpdateExpression: 'SET ' + expressionParts.join(', '),
        ExpressionAttributeValues: expressionValues,
        ExpressionAttributeNames: expressionNames,
        ReturnValues: 'ALL_NEW',
        ConditionExpression:
          'attribute_exists(family_id) AND attribute_exists(member_user_id)',
      }),
    );
  } catch (err: unknown) {
    if (
      err instanceof Error &&
      err.name === 'ConditionalCheckFailedException'
    ) {
      throw new Error('Member not found');
    }
    throw err;
  }

  return itemToMember(result.Attributes!);
}

function itemToMember(item: Record<string, AttributeValue>) {
  return {
    family_id: item.family_id?.S ?? '',
    member_user_id: item.member_user_id?.S ?? '',
    display_name: item.display_name?.S ?? '',
    relationship: item.relationship?.S ?? 'other',
    age: item.age?.N ? Number(item.age.N) : 0,
    color_hex: item.color_hex?.S ?? '34C759',
    role: item.role?.S ?? 'watcher',
    joined_at: item.joined_at?.S ?? new Date().toISOString(),
    notes: item.notes?.S ?? '',
  };
}

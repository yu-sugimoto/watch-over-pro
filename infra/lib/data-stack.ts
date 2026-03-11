import * as cdk from 'aws-cdk-lib';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import { Construct } from 'constructs';

export interface DataTables {
  families: dynamodb.Table;
  familyMembers: dynamodb.Table;
  pairingCodes: dynamodb.Table;
  currentLocations: dynamodb.Table;
  routeChunks: dynamodb.Table;
  stopEvents: dynamodb.Table;
}

export class DataStack extends cdk.Stack {
  public readonly tables: DataTables;

  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const families = new dynamodb.Table(this, 'Families', {
      tableName: 'watch-over-pro-families',
      partitionKey: { name: 'family_id', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    const familyMembers = new dynamodb.Table(this, 'FamilyMembers', {
      tableName: 'watch-over-pro-family-members',
      partitionKey: { name: 'family_id', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'member_user_id', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    const pairingCodes = new dynamodb.Table(this, 'PairingCodes', {
      tableName: 'watch-over-pro-pairing-codes',
      partitionKey: { name: 'code', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      timeToLiveAttribute: 'expires_at_epoch',
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    const currentLocations = new dynamodb.Table(this, 'CurrentLocations', {
      tableName: 'watch-over-pro-current-locations',
      partitionKey: { name: 'tracked_user_id', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    const routeChunks = new dynamodb.Table(this, 'RouteChunks', {
      tableName: 'watch-over-pro-route-chunks',
      partitionKey: { name: 'tracked_user_id_date', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'chunk_start_epoch_ms', type: dynamodb.AttributeType.NUMBER },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      timeToLiveAttribute: 'ttl',
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    const stopEvents = new dynamodb.Table(this, 'StopEvents', {
      tableName: 'watch-over-pro-stop-events',
      partitionKey: { name: 'tracked_user_id_date', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'stop_start_epoch_ms', type: dynamodb.AttributeType.NUMBER },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      timeToLiveAttribute: 'ttl',
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    this.tables = {
      families,
      familyMembers,
      pairingCodes,
      currentLocations,
      routeChunks,
      stopEvents,
    };
  }
}

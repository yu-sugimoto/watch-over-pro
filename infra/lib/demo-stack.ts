import * as cdk from 'aws-cdk-lib';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as lambdaNode from 'aws-cdk-lib/aws-lambda-nodejs';
import * as events from 'aws-cdk-lib/aws-events';
import * as targets from 'aws-cdk-lib/aws-events-targets';
import * as path from 'path';
import { Construct } from 'constructs';
import { DataTables } from './data-stack';

interface DemoStackProps extends cdk.StackProps {
  tables: DataTables;
}

export class DemoStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: DemoStackProps) {
    super(scope, id, props);

    const { tables } = props;

    // Seed Lambda: one-time manual execution to populate demo data
    const seedFn = new lambdaNode.NodejsFunction(this, 'SeedDemoDataFn', {
      entry: path.join(__dirname, '../lambda/seedDemoData/index.ts'),
      handler: 'handler',
      runtime: lambda.Runtime.NODEJS_24_X,
      timeout: cdk.Duration.seconds(30),
      environment: {
        FAMILIES_TABLE: tables.families.tableName,
        FAMILY_MEMBERS_TABLE: tables.familyMembers.tableName,
        CURRENT_LOCATIONS_TABLE: tables.currentLocations.tableName,
        PAIRING_CODES_TABLE: tables.pairingCodes.tableName,
        ROUTE_CHUNKS_TABLE: tables.routeChunks.tableName,
        STOP_EVENTS_TABLE: tables.stopEvents.tableName,
      },
    });
    tables.families.grantReadWriteData(seedFn);
    tables.familyMembers.grantReadWriteData(seedFn);
    tables.currentLocations.grantReadWriteData(seedFn);
    tables.pairingCodes.grantReadWriteData(seedFn);
    tables.routeChunks.grantReadWriteData(seedFn);
    tables.stopEvents.grantReadWriteData(seedFn);

    // Refresh Lambda: runs every 3 minutes to keep demo data alive
    const refreshFn = new lambdaNode.NodejsFunction(
      this,
      'RefreshDemoLocationFn',
      {
        entry: path.join(__dirname, '../lambda/refreshDemoLocation/index.ts'),
        handler: 'handler',
        runtime: lambda.Runtime.NODEJS_24_X,
        timeout: cdk.Duration.seconds(10),
        environment: {
          CURRENT_LOCATIONS_TABLE: tables.currentLocations.tableName,
          PAIRING_CODES_TABLE: tables.pairingCodes.tableName,
          ROUTE_CHUNKS_TABLE: tables.routeChunks.tableName,
          STOP_EVENTS_TABLE: tables.stopEvents.tableName,
        },
      },
    );
    tables.currentLocations.grantReadWriteData(refreshFn);
    tables.pairingCodes.grantReadWriteData(refreshFn);
    tables.routeChunks.grantReadWriteData(refreshFn);
    tables.stopEvents.grantReadWriteData(refreshFn);

    // EventBridge: trigger refresh every 3 minutes
    new events.Rule(this, 'RefreshDemoSchedule', {
      schedule: events.Schedule.rate(cdk.Duration.minutes(3)),
      targets: [new targets.LambdaFunction(refreshFn)],
    });

    new cdk.CfnOutput(this, 'SeedDemoDataFunctionName', {
      value: seedFn.functionName,
      description:
        'Run: aws lambda invoke --function-name <this> /tmp/seed-output.json',
    });
  }
}

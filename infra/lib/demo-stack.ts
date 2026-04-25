import * as cdk from 'aws-cdk-lib';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as lambdaNode from 'aws-cdk-lib/aws-lambda-nodejs';
import * as events from 'aws-cdk-lib/aws-events';
import * as targets from 'aws-cdk-lib/aws-events-targets';
import * as cr from 'aws-cdk-lib/custom-resources';
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

    // Seed Lambda: auto-executed on deploy to populate demo data
    const seedFn = new lambdaNode.NodejsFunction(this, 'SeedDemoDataFn', {
      entry: path.join(__dirname, '../lambda/seedDemoData.ts'),
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

    // Auto-execute seed on deploy
    const seedTrigger = new cr.AwsCustomResource(this, 'SeedDemoTrigger', {
      installLatestAwsSdk: false,
      onCreate: {
        service: 'Lambda',
        action: 'invoke',
        parameters: {
          FunctionName: seedFn.functionName,
          InvocationType: 'Event',
        },
        physicalResourceId: cr.PhysicalResourceId.of('SeedDemoTrigger'),
      },
      onUpdate: {
        service: 'Lambda',
        action: 'invoke',
        parameters: {
          FunctionName: seedFn.functionName,
          InvocationType: 'Event',
        },
        physicalResourceId: cr.PhysicalResourceId.of(Date.now().toString()),
      },
      policy: cr.AwsCustomResourcePolicy.fromStatements([
        new cdk.aws_iam.PolicyStatement({
          actions: ['lambda:InvokeFunction'],
          resources: [seedFn.functionArn],
        }),
      ]),
    });
    seedTrigger.node.addDependency(seedFn);

    // Refresh Lambda: runs every 3 minutes to keep demo data alive
    const refreshFn = new lambdaNode.NodejsFunction(
      this,
      'RefreshDemoLocationFn',
      {
        entry: path.join(__dirname, '../lambda/refreshDemoLocation.ts'),
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
      description: 'Auto-executed on deploy. Manual: aws lambda invoke --function-name <this> /tmp/seed-output.json',
    });
  }
}

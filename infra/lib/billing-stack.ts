import * as cdk from 'aws-cdk-lib';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as lambdaNode from 'aws-cdk-lib/aws-lambda-nodejs';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as path from 'path';
import { Construct } from 'constructs';

interface BillingStackProps extends cdk.StackProps {
  familiesTable: dynamodb.Table;
}

export class BillingStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: BillingStackProps) {
    super(scope, id, props);

    const activateSubscriptionFn = new lambdaNode.NodejsFunction(this, 'ActivateSubscriptionFn', {
      entry: path.join(__dirname, '../lambda/activateSubscription/index.ts'),
      handler: 'handler',
      runtime: lambda.Runtime.NODEJS_24_X,
      environment: {
        FAMILIES_TABLE: props.familiesTable.tableName,
      },
      timeout: cdk.Duration.seconds(10),
    });
    props.familiesTable.grantReadWriteData(activateSubscriptionFn);

    const syncSubscriptionFn = new lambdaNode.NodejsFunction(this, 'SyncSubscriptionFn', {
      entry: path.join(__dirname, '../lambda/syncSubscriptionStatus/index.ts'),
      handler: 'handler',
      runtime: lambda.Runtime.NODEJS_24_X,
      environment: {
        FAMILIES_TABLE: props.familiesTable.tableName,
      },
      timeout: cdk.Duration.seconds(10),
    });
    props.familiesTable.grantReadWriteData(syncSubscriptionFn);

    const api = new apigateway.RestApi(this, 'BillingApi', {
      restApiName: 'watch-over-pro-billing',
      description: 'App Store Server Notifications endpoint',
    });

    const notifications = api.root.addResource('apple-notifications');
    notifications.addMethod('POST', new apigateway.LambdaIntegration(activateSubscriptionFn));

    new cdk.CfnOutput(this, 'BillingApiUrl', { value: api.url });
  }
}

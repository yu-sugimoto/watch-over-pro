#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib';
import { AuthStack } from '../lib/auth-stack';
import { DataStack } from '../lib/data-stack';
import { ApiStack } from '../lib/api-stack';
import { BillingStack } from '../lib/billing-stack';

const app = new cdk.App();

const env = {
  account: process.env.CDK_DEFAULT_ACCOUNT,
  region: process.env.CDK_DEFAULT_REGION ?? 'ap-northeast-1',
};

const authStack = new AuthStack(app, 'WatchOverPro-Auth', { env });
const dataStack = new DataStack(app, 'WatchOverPro-Data', { env });
const apiStack = new ApiStack(app, 'WatchOverPro-Api', {
  env,
  userPool: authStack.userPool,
  tables: dataStack.tables,
});
new BillingStack(app, 'WatchOverPro-Billing', {
  env,
  familiesTable: dataStack.tables.families,
});

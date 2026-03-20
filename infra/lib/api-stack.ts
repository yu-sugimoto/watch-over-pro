import * as cdk from 'aws-cdk-lib';
import * as appsync from 'aws-cdk-lib/aws-appsync';
import * as cognito from 'aws-cdk-lib/aws-cognito';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as lambdaNode from 'aws-cdk-lib/aws-lambda-nodejs';
import * as path from 'path';
import { Construct } from 'constructs';
import { DataTables } from './data-stack';

interface ApiStackProps extends cdk.StackProps {
  userPool: cognito.UserPool;
  tables: DataTables;
}

export class ApiStack extends cdk.Stack {
  public readonly api: appsync.GraphqlApi;

  constructor(scope: Construct, id: string, props: ApiStackProps) {
    super(scope, id, props);

    this.api = new appsync.GraphqlApi(this, 'Api', {
      name: 'watch-over-pro-api',
      definition: appsync.Definition.fromFile(
        path.join(__dirname, '../graphql/schema.graphql')
      ),
      authorizationConfig: {
        defaultAuthorization: {
          authorizationType: appsync.AuthorizationType.USER_POOL,
          userPoolConfig: { userPool: props.userPool },
        },
      },
      logConfig: {
        fieldLogLevel: appsync.FieldLogLevel.ERROR,
      },
    });

    // DynamoDB data sources
    const currentLocDS = this.api.addDynamoDbDataSource('CurrentLocDS', props.tables.currentLocations);
    const routeChunkDS = this.api.addDynamoDbDataSource('RouteChunkDS', props.tables.routeChunks);
    const stopEventDS = this.api.addDynamoDbDataSource('StopEventDS', props.tables.stopEvents);
    const familyDS = this.api.addDynamoDbDataSource('FamilyDS', props.tables.families);
    const familyMemberDS = this.api.addDynamoDbDataSource('FamilyMemberDS', props.tables.familyMembers);

    // Mutation: updateCurrentLocation
    currentLocDS.createResolver('UpdateCurrentLocation', {
      typeName: 'Mutation',
      fieldName: 'updateCurrentLocation',
      requestMappingTemplate: appsync.MappingTemplate.dynamoDbPutItem(
        appsync.PrimaryKey.partition('tracked_user_id').is('input.tracked_user_id'),
        appsync.Values.projecting('input')
          .attribute('updated_at').is('$util.time.nowISO8601()')
      ),
      responseMappingTemplate: appsync.MappingTemplate.dynamoDbResultItem(),
    });

    // Mutation: appendRouteChunk
    routeChunkDS.createResolver('AppendRouteChunk', {
      typeName: 'Mutation',
      fieldName: 'appendRouteChunk',
      requestMappingTemplate: appsync.MappingTemplate.dynamoDbPutItem(
        appsync.PrimaryKey
          .partition('tracked_user_id_date').is('input.tracked_user_id_date')
          .sort('chunk_start_epoch_ms').is('input.chunk_start_epoch_ms'),
        appsync.Values.projecting('input')
          .attribute('created_at').is('$util.time.nowISO8601()')
      ),
      responseMappingTemplate: appsync.MappingTemplate.dynamoDbResultItem(),
    });

    // Mutation: putStopEvent
    stopEventDS.createResolver('PutStopEvent', {
      typeName: 'Mutation',
      fieldName: 'putStopEvent',
      requestMappingTemplate: appsync.MappingTemplate.dynamoDbPutItem(
        appsync.PrimaryKey
          .partition('tracked_user_id_date').is('input.tracked_user_id_date')
          .sort('stop_start_epoch_ms').is('input.stop_start_epoch_ms'),
        appsync.Values.projecting('input')
      ),
      responseMappingTemplate: appsync.MappingTemplate.dynamoDbResultItem(),
    });

    // Query: getFamily
    familyDS.createResolver('GetFamily', {
      typeName: 'Query',
      fieldName: 'getFamily',
      requestMappingTemplate: appsync.MappingTemplate.dynamoDbGetItem('family_id', 'family_id'),
      responseMappingTemplate: appsync.MappingTemplate.dynamoDbResultItem(),
    });

    // Query: getFamilyMembers
    familyMemberDS.createResolver('GetFamilyMembers', {
      typeName: 'Query',
      fieldName: 'getFamilyMembers',
      requestMappingTemplate: appsync.MappingTemplate.dynamoDbQuery(
        appsync.KeyCondition.eq('family_id', 'family_id')
      ),
      responseMappingTemplate: appsync.MappingTemplate.dynamoDbResultList(),
    });

    // Query: getRoute24h
    routeChunkDS.createResolver('GetRoute24h', {
      typeName: 'Query',
      fieldName: 'getRoute24h',
      requestMappingTemplate: appsync.MappingTemplate.fromString(`
        {
          "version": "2017-02-28",
          "operation": "Query",
          "query": {
            "expression": "tracked_user_id_date = :pk",
            "expressionValues": {
              ":pk": $util.dynamodb.toDynamoDBJson("$ctx.args.tracked_user_id#$ctx.args.date")
            }
          }
        }
      `),
      responseMappingTemplate: appsync.MappingTemplate.dynamoDbResultList(),
    });

    // Query: getStopEvents24h
    stopEventDS.createResolver('GetStopEvents24h', {
      typeName: 'Query',
      fieldName: 'getStopEvents24h',
      requestMappingTemplate: appsync.MappingTemplate.fromString(`
        {
          "version": "2017-02-28",
          "operation": "Query",
          "query": {
            "expression": "tracked_user_id_date = :pk",
            "expressionValues": {
              ":pk": $util.dynamodb.toDynamoDBJson("$ctx.args.tracked_user_id#$ctx.args.date")
            }
          }
        }
      `),
      responseMappingTemplate: appsync.MappingTemplate.dynamoDbResultList(),
    });

    // Lambda: deleteFamilyMember
    const deleteFamilyMemberFn = new lambdaNode.NodejsFunction(this, 'DeleteFamilyMemberFn', {
      entry: path.join(__dirname, '../lambda/deleteFamilyMember/index.ts'),
      handler: 'handler',
      runtime: lambda.Runtime.NODEJS_24_X,
      environment: {
        FAMILY_MEMBERS_TABLE: props.tables.familyMembers.tableName,
      },
      timeout: cdk.Duration.seconds(10),
    });
    props.tables.familyMembers.grantReadWriteData(deleteFamilyMemberFn);

    const deleteFamilyMemberDS = this.api.addLambdaDataSource('DeleteFamilyMemberDS', deleteFamilyMemberFn);
    deleteFamilyMemberDS.createResolver('DeleteFamilyMember', {
      typeName: 'Mutation',
      fieldName: 'deleteFamilyMember',
    });

    // Lambda: createPairingCode
    const createPairingCodeFn = new lambdaNode.NodejsFunction(this, 'CreatePairingCodeFn', {
      entry: path.join(__dirname, '../lambda/createPairingCode/index.ts'),
      handler: 'handler',
      runtime: lambda.Runtime.NODEJS_24_X,
      environment: {
        PAIRING_CODES_TABLE: props.tables.pairingCodes.tableName,
        FAMILIES_TABLE: props.tables.families.tableName,
        FAMILY_MEMBERS_TABLE: props.tables.familyMembers.tableName,
      },
      timeout: cdk.Duration.seconds(10),
    });
    props.tables.pairingCodes.grantWriteData(createPairingCodeFn);
    props.tables.families.grantWriteData(createPairingCodeFn);
    props.tables.familyMembers.grantWriteData(createPairingCodeFn);

    const createPairingDS = this.api.addLambdaDataSource('CreatePairingDS', createPairingCodeFn);
    createPairingDS.createResolver('CreatePairingCode', {
      typeName: 'Mutation',
      fieldName: 'createPairingCode',
    });

    // Lambda: consumePairingCode
    const consumePairingCodeFn = new lambdaNode.NodejsFunction(this, 'ConsumePairingCodeFn', {
      entry: path.join(__dirname, '../lambda/consumePairingCode/index.ts'),
      handler: 'handler',
      runtime: lambda.Runtime.NODEJS_24_X,
      environment: {
        PAIRING_CODES_TABLE: props.tables.pairingCodes.tableName,
        FAMILY_MEMBERS_TABLE: props.tables.familyMembers.tableName,
      },
      timeout: cdk.Duration.seconds(10),
    });
    props.tables.pairingCodes.grantReadWriteData(consumePairingCodeFn);
    props.tables.familyMembers.grantWriteData(consumePairingCodeFn);

    const consumePairingDS = this.api.addLambdaDataSource('ConsumePairingDS', consumePairingCodeFn);
    consumePairingDS.createResolver('ConsumePairingCode', {
      typeName: 'Mutation',
      fieldName: 'consumePairingCode',
    });

    // Lambda: getLiveMapState
    const getLiveMapStateFn = new lambdaNode.NodejsFunction(this, 'GetLiveMapStateFn', {
      entry: path.join(__dirname, '../lambda/getLiveMapState/index.ts'),
      handler: 'handler',
      runtime: lambda.Runtime.NODEJS_24_X,
      environment: {
        FAMILY_MEMBERS_TABLE: props.tables.familyMembers.tableName,
        CURRENT_LOCATIONS_TABLE: props.tables.currentLocations.tableName,
      },
      timeout: cdk.Duration.seconds(10),
    });
    props.tables.familyMembers.grantReadData(getLiveMapStateFn);
    props.tables.currentLocations.grantReadData(getLiveMapStateFn);

    const getLiveMapStateDS = this.api.addLambdaDataSource('GetLiveMapStateDS', getLiveMapStateFn);
    getLiveMapStateDS.createResolver('GetLiveMapState', {
      typeName: 'Query',
      fieldName: 'getLiveMapState',
    });

    new cdk.CfnOutput(this, 'GraphQLEndpoint', { value: this.api.graphqlUrl });
    new cdk.CfnOutput(this, 'GraphQLApiId', { value: this.api.apiId });
  }
}

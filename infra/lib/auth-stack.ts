import * as cdk from 'aws-cdk-lib';
import * as cognito from 'aws-cdk-lib/aws-cognito';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as lambda from 'aws-cdk-lib/aws-lambda-nodejs';
import * as path from 'path';
import { Construct } from 'constructs';

export class AuthStack extends cdk.Stack {
  public readonly userPool: cognito.UserPool;
  public readonly userPoolClient: cognito.UserPoolClient;
  public readonly identityPool: cognito.CfnIdentityPool;

  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // --- Lambda triggers for Custom Auth (Apple Sign In) ---

    const defineAuthChallenge = new lambda.NodejsFunction(this, 'DefineAuthChallenge', {
      entry: path.join(__dirname, '../lambda/defineAuthChallenge/index.ts'),
      handler: 'handler',
      runtime: cdk.aws_lambda.Runtime.NODEJS_20_X,
      bundling: { minify: true },
    });

    const createAuthChallenge = new lambda.NodejsFunction(this, 'CreateAuthChallenge', {
      entry: path.join(__dirname, '../lambda/createAuthChallenge/index.ts'),
      handler: 'handler',
      runtime: cdk.aws_lambda.Runtime.NODEJS_20_X,
      bundling: { minify: true },
    });

    const verifyAuthChallenge = new lambda.NodejsFunction(this, 'VerifyAuthChallenge', {
      entry: path.join(__dirname, '../lambda/verifyAuthChallenge/index.ts'),
      handler: 'handler',
      runtime: cdk.aws_lambda.Runtime.NODEJS_20_X,
      bundling: { minify: true },
    });

    const preSignUp = new lambda.NodejsFunction(this, 'PreSignUp', {
      entry: path.join(__dirname, '../lambda/preSignUp/index.ts'),
      handler: 'handler',
      runtime: cdk.aws_lambda.Runtime.NODEJS_20_X,
      bundling: { minify: true },
    });

    // --- Cognito User Pool with Lambda triggers ---

    this.userPool = new cognito.UserPool(this, 'UserPool', {
      userPoolName: 'watch-over-pro-users',
      selfSignUpEnabled: true,
      // signInAliases removed — username is Apple user ID (arbitrary string)
      autoVerify: { email: true },
      standardAttributes: {
        email: { required: false, mutable: true },
        fullname: { required: false, mutable: true },
      },
      passwordPolicy: {
        minLength: 8,
        requireLowercase: true,
        requireUppercase: false,
        requireDigits: true,
        requireSymbols: false,
      },
      accountRecovery: cognito.AccountRecovery.EMAIL_ONLY,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      lambdaTriggers: {
        defineAuthChallenge,
        createAuthChallenge,
        verifyAuthChallengeResponse: verifyAuthChallenge,
        preSignUp,
      },
    });

    // --- User Pool Client (Custom Auth for Apple Sign In) ---

    this.userPoolClient = this.userPool.addClient('AppClient', {
      userPoolClientName: 'watch-over-pro-ios',
      authFlows: {
        userSrp: true,
        custom: true,
      },
      oAuth: {
        flows: { authorizationCodeGrant: true },
        scopes: [
          cognito.OAuthScope.OPENID,
          cognito.OAuthScope.EMAIL,
          cognito.OAuthScope.PROFILE,
        ],
        callbackUrls: ['watchoverpro://callback'],
        logoutUrls: ['watchoverpro://signout'],
      },
      supportedIdentityProviders: [
        cognito.UserPoolClientIdentityProvider.COGNITO,
      ],
    });

    // --- Cognito Identity Pool ---

    this.identityPool = new cognito.CfnIdentityPool(this, 'IdentityPool', {
      identityPoolName: 'watch_over_pro_identity_pool',
      allowUnauthenticatedIdentities: false,
      cognitoIdentityProviders: [
        {
          clientId: this.userPoolClient.userPoolClientId,
          providerName: this.userPool.userPoolProviderName,
        },
      ],
    });

    // Authenticated role — allows CloudWatch Logs for Amplify logging
    const authenticatedRole = new iam.Role(this, 'CognitoAuthRole', {
      assumedBy: new iam.FederatedPrincipal(
        'cognito-identity.amazonaws.com',
        {
          'StringEquals': {
            'cognito-identity.amazonaws.com:aud': this.identityPool.ref,
          },
          'ForAnyValue:StringLike': {
            'cognito-identity.amazonaws.com:amr': 'authenticated',
          },
        },
        'sts:AssumeRoleWithWebIdentity',
      ),
      inlinePolicies: {
        CloudWatchLogs: new iam.PolicyDocument({
          statements: [
            new iam.PolicyStatement({
              actions: [
                'logs:CreateLogGroup',
                'logs:CreateLogStream',
                'logs:DescribeLogStreams',
                'logs:PutLogEvents',
              ],
              resources: ['*'],
            }),
          ],
        }),
      },
    });

    // Attach roles to Identity Pool
    new cognito.CfnIdentityPoolRoleAttachment(this, 'IdentityPoolRoleAttachment', {
      identityPoolId: this.identityPool.ref,
      roles: {
        authenticated: authenticatedRole.roleArn,
      },
    });

    // --- Outputs ---

    new cdk.CfnOutput(this, 'UserPoolId', { value: this.userPool.userPoolId });
    new cdk.CfnOutput(this, 'UserPoolClientId', { value: this.userPoolClient.userPoolClientId });
    new cdk.CfnOutput(this, 'IdentityPoolId', { value: this.identityPool.ref });
  }
}

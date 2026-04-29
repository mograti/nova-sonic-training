// AWS Amplify Configuration for Cognito Authentication
// Configuration will be injected at build time from CDK outputs

const requiredCognitoEnv = [
  ['VITE_USER_POOL_ID', import.meta.env.VITE_USER_POOL_ID],
  ['VITE_USER_POOL_CLIENT_ID', import.meta.env.VITE_USER_POOL_CLIENT_ID],
  ['VITE_IDENTITY_POOL_ID', import.meta.env.VITE_IDENTITY_POOL_ID],
  ['VITE_USER_POOL_DOMAIN', import.meta.env.VITE_USER_POOL_DOMAIN],
] as const;

const missingCognitoEnv = requiredCognitoEnv
  .filter(([, value]) => !value)
  .map(([name]) => name);

if (missingCognitoEnv.length > 0) {
  throw new Error(
    `Missing required Cognito configuration: ${missingCognitoEnv.join(', ')}. Run deployment/deploy.sh --webui after CallCenterTraining-Web deploys successfully.`
  );
}

export const awsconfig = {
  Auth: {
    Cognito: {
      userPoolId: import.meta.env.VITE_USER_POOL_ID,
      userPoolClientId: import.meta.env.VITE_USER_POOL_CLIENT_ID,
      identityPoolId: import.meta.env.VITE_IDENTITY_POOL_ID,
      loginWith: {
        oauth: {
          domain: import.meta.env.VITE_USER_POOL_DOMAIN,
          scopes: ['openid', 'email', 'profile'],
          redirectSignIn: [window.location.origin],
          redirectSignOut: [window.location.origin],
          responseType: 'code' as const,
        },
      },
    },
  },
};

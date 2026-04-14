import { CreateAuthChallengeTriggerHandler } from 'aws-lambda';

export const handler: CreateAuthChallengeTriggerHandler = async (event) => {
  // For Apple Sign In custom auth, the challenge is simply
  // asking the client to provide the Apple identity token
  event.response.publicChallengeParameters = { type: 'APPLE_SIGN_IN' };
  event.response.privateChallengeParameters = { answer: 'apple_token' };
  event.response.challengeMetadata = 'APPLE_SIGN_IN_CHALLENGE';

  return event;
};

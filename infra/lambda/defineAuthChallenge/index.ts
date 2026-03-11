import { DefineAuthChallengeTriggerHandler } from 'aws-lambda';

export const handler: DefineAuthChallengeTriggerHandler = async (event) => {
  const sessions = event.request.session;

  if (sessions.length === 0) {
    // First attempt — issue a custom challenge
    event.response.issueTokens = false;
    event.response.failAuthentication = false;
    event.response.challengeName = 'CUSTOM_CHALLENGE';
  } else if (
    sessions.length === 1 &&
    sessions[0].challengeName === 'CUSTOM_CHALLENGE' &&
    sessions[0].challengeResult === true
  ) {
    // Challenge answered correctly — issue tokens
    event.response.issueTokens = true;
    event.response.failAuthentication = false;
  } else {
    // Unexpected state — fail
    event.response.issueTokens = false;
    event.response.failAuthentication = true;
  }

  return event;
};

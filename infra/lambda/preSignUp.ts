import { PreSignUpTriggerHandler } from 'aws-lambda';

export const handler: PreSignUpTriggerHandler = async (event) => {
  // Auto-confirm users created through Custom Auth (Apple Sign In)
  event.response.autoConfirmUser = true;

  if (event.request.userAttributes.email) {
    event.response.autoVerifyEmail = true;
  }

  return event;
};

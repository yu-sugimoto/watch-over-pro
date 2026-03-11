import {
  VerifyAuthChallengeResponseTriggerHandler,
  VerifyAuthChallengeResponseTriggerEvent,
} from 'aws-lambda';
import jwt from 'jsonwebtoken';
import jwksClient from 'jwks-rsa';

const APPLE_JWKS_URI = 'https://appleid.apple.com/auth/keys';
const APPLE_ISSUER = 'https://appleid.apple.com';
const BUNDLE_ID = 'com.watchoverpro.app';

const client = jwksClient({
  jwksUri: APPLE_JWKS_URI,
  cache: true,
  cacheMaxAge: 86400000, // 24 hours
});

function getSigningKey(kid: string): Promise<string> {
  return new Promise((resolve, reject) => {
    client.getSigningKey(kid, (err, key) => {
      if (err) {
        reject(err);
        return;
      }
      resolve(key!.getPublicKey());
    });
  });
}

export const handler: VerifyAuthChallengeResponseTriggerHandler = async (
  event: VerifyAuthChallengeResponseTriggerEvent,
) => {
  event.response.answerCorrect = false;

  try {
    const token = event.request.challengeAnswer;
    if (!token) {
      return event;
    }

    // Decode the header to get the key ID
    const decoded = jwt.decode(token, { complete: true });
    if (!decoded || typeof decoded === 'string' || !decoded.header.kid) {
      return event;
    }

    // Fetch Apple's public key
    const publicKey = await getSigningKey(decoded.header.kid);

    // Verify the JWT
    const payload = jwt.verify(token, publicKey, {
      issuer: APPLE_ISSUER,
      audience: BUNDLE_ID,
      algorithms: ['RS256'],
    }) as jwt.JwtPayload;

    // Verify the subject matches the Cognito username (Apple user ID)
    if (payload.sub === event.userName) {
      event.response.answerCorrect = true;
    }
  } catch (error) {
    console.error('Token verification failed:', error);
  }

  return event;
};

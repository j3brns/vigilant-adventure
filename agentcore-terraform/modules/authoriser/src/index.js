/**
 * AgentCore Gateway Lambda Authoriser
 * 
 * Validates incoming requests by:
 * 1. Extracting and validating the JWT token
 * 2. Verifying the audience (aud) claim matches the expected Gateway identifier
 * 3. Looking up the tenant in DynamoDB
 * 4. Returning an IAM policy allowing/denying access
 * 
 * The audience claim is critical for multi-tenant security - it ensures tokens
 * are only valid for the specific AgentCore Gateway they were issued for.
 */

const { DynamoDBClient, GetItemCommand } = require('@aws-sdk/client-dynamodb');
const { unmarshall } = require('@aws-sdk/util-dynamodb');
const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');

// Configuration from environment
const CONFIG = {
  tenantRegistryTable: process.env.TENANT_REGISTRY_TABLE,
  jwksUri: process.env.JWKS_URI,
  tokenIssuer: process.env.TOKEN_ISSUER,
  expectedAudience: process.env.EXPECTED_AUDIENCE,
  logLevel: process.env.LOG_LEVEL || 'INFO'
};

// AWS clients (reused across invocations)
const dynamodb = new DynamoDBClient({});

// JWKS client for key retrieval (with caching)
const jwks = jwksClient({
  jwksUri: CONFIG.jwksUri,
  cache: true,
  cacheMaxAge: 600000, // 10 minutes
  rateLimit: true
});

/**
 * Retrieve signing key from JWKS endpoint
 */
function getSigningKey(header, callback) {
  jwks.getSigningKey(header.kid, (err, key) => {
    if (err) {
      callback(err);
      return;
    }
    const signingKey = key.getPublicKey();
    callback(null, signingKey);
  });
}

/**
 * Verify JWT token and extract claims
 */
async function verifyToken(token) {
  return new Promise((resolve, reject) => {
    jwt.verify(
      token,
      getSigningKey,
      {
        issuer: CONFIG.tokenIssuer,
        audience: CONFIG.expectedAudience, // Critical: validates aud claim
        algorithms: ['RS256']
      },
      (err, decoded) => {
        if (err) {
          reject(err);
        } else {
          resolve(decoded);
        }
      }
    );
  });
}

/**
 * Look up tenant in DynamoDB
 */
async function getTenant(tenantId) {
  const command = new GetItemCommand({
    TableName: CONFIG.tenantRegistryTable,
    Key: {
      tenant_id: { S: tenantId }
    }
  });

  const response = await dynamodb.send(command);
  
  if (!response.Item) {
    return null;
  }

  return unmarshall(response.Item);
}

/**
 * Generate IAM policy document
 */
function generatePolicy(principalId, effect, resource, context = {}) {
  const policy = {
    principalId,
    policyDocument: {
      Version: '2012-10-17',
      Statement: [
        {
          Action: 'execute-api:Invoke',
          Effect: effect,
          Resource: resource
        }
      ]
    },
    context // Pass tenant info to downstream
  };

  return policy;
}

/**
 * Extract token from Authorization header
 */
function extractToken(authorizationHeader) {
  if (!authorizationHeader) {
    return null;
  }

  const parts = authorizationHeader.split(' ');
  
  if (parts.length !== 2 || parts[0].toLowerCase() !== 'bearer') {
    return null;
  }

  return parts[1];
}

/**
 * Lambda handler
 */
exports.handler = async (event) => {
  const log = (level, message, data = {}) => {
    const levels = ['DEBUG', 'INFO', 'WARN', 'ERROR'];
    if (levels.indexOf(level) >= levels.indexOf(CONFIG.logLevel)) {
      console.log(JSON.stringify({ level, message, ...data }));
    }
  };

  log('DEBUG', 'Authoriser invoked', { 
    methodArn: event.methodArn,
    headers: Object.keys(event.headers || {})
  });

  try {
    // Extract token
    const token = extractToken(
      event.authorizationToken || 
      event.headers?.Authorization || 
      event.headers?.authorization
    );

    if (!token) {
      log('WARN', 'No token provided');
      return generatePolicy('anonymous', 'Deny', event.methodArn);
    }

    // Verify token (includes audience validation)
    let claims;
    try {
      claims = await verifyToken(token);
    } catch (err) {
      log('WARN', 'Token verification failed', { 
        error: err.message,
        // Don't log the full error to avoid exposing details
      });
      return generatePolicy('anonymous', 'Deny', event.methodArn);
    }

    log('DEBUG', 'Token verified', { 
      sub: claims.sub,
      aud: claims.aud,
      iss: claims.iss
    });

    // Extract tenant ID from claims
    // Common patterns: custom claim, sub prefix, or dedicated field
    const tenantId = claims.tenant_id || 
                     claims['custom:tenant_id'] ||
                     claims.sub?.split(':')[0];

    if (!tenantId) {
      log('WARN', 'No tenant ID in token claims');
      return generatePolicy(claims.sub, 'Deny', event.methodArn);
    }

    // Look up tenant
    const tenant = await getTenant(tenantId);

    if (!tenant) {
      log('WARN', 'Tenant not found', { tenantId });
      return generatePolicy(claims.sub, 'Deny', event.methodArn);
    }

    if (tenant.status !== 'active') {
      log('WARN', 'Tenant not active', { tenantId, status: tenant.status });
      return generatePolicy(claims.sub, 'Deny', event.methodArn);
    }

    log('INFO', 'Request authorised', { 
      tenantId,
      tier: tenant.tier,
      sub: claims.sub
    });

    // Return Allow policy with tenant context
    // This context is passed to the downstream Lambda/integration
    return generatePolicy(claims.sub, 'Allow', event.methodArn, {
      tenantId: tenant.tenant_id,
      tenantName: tenant.tenant_name,
      tier: tenant.tier,
      executionRoleArn: tenant.execution_role_arn,
      memoryNamespace: tenant.memory_namespace,
      // Rate limiting context
      rateLimitRps: String(tenant.config?.rate_limit_rps || 10),
      concurrentSessions: String(tenant.config?.concurrent_sessions || 5)
    });

  } catch (err) {
    log('ERROR', 'Authoriser error', { 
      error: err.message,
      stack: err.stack
    });
    
    // Fail closed - deny on error
    return generatePolicy('error', 'Deny', event.methodArn);
  }
};

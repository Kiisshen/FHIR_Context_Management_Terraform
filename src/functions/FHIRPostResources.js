const { app } = require("@azure/functions");
const { SecretClient } = require("@azure/keyvault-secrets");
const { ManagedIdentityCredential } = require("@azure/identity");
const axios = require("axios");

async function getClientSecret() {
  const url = process.env.KEY_VAULT_STRING;
  const credential = new ManagedIdentityCredential();

  const { SecretClient } = require("@azure/keyvault-secrets");
  const client = new SecretClient(url, credential);
  const secret = await client.getSecret(process.env.KEY_VAULT_SECRET);
  return secret.value;
}

async function getAccessToken(clientSecret) {
  const tenantId = process.env.AZURE_TENANT_ID;
  const clientId = process.env.AZURE_CLIENT_ID;
  const resource = process.env.FHIR_SERVICE;
  const response = await axios.post(
    `https://login.microsoftonline.com/${tenantId}/oauth2/token`,
    new URLSearchParams({
      grant_type: "client_credentials",
      client_id: clientId,
      client_secret: clientSecret,
      resource: resource,
    }).toString(),
    {
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
    }
  );

  return response.data.access_token;
}

app.http("FHIRPostResources", {
  methods: ["GET", "POST"],
  authLevel: "anonymous",
  handler: async (request, context) => {
    context.log(`Http function processed request for url "${request.url}"`);

    const route = request.query.get("route");
    const reqBody = await request.json();
    const clientSecret = await getClientSecret();
    const accessToken = await getAccessToken(clientSecret);

    context.log(`${process.env.FHIR_SERVICE}${route}`);
    context.log(reqBody);

    const fhirResponse = await axios.post(
      `${process.env.FHIR_SERVICE}${route}`,
      reqBody,
      {
        headers: {
          Authorization: `Bearer ${accessToken}`,
        },
      }
    );

    return {
      status: fhirResponse.status,
      body: JSON.stringify(fhirResponse.data),
    };
  },
});

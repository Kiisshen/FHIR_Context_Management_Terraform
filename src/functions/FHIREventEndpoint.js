require("dotenv").config();
const { app, output } = require("@azure/functions");
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

// Declare SignalR output binding
const goingOutToSignalR = output.generic({
  type: "signalR",
  name: "signalR",
  hubName: "signalrfhir",
  connectionStringSetting: "SIGNALR_CONNECTION_STRING",
});

app.http("FHIREventEndpoint", {
  methods: ["GET", "POST"],
  authLevel: "anonymous",
  extraOutputs: [goingOutToSignalR],
  handler: async (request, context) => {
    context.log(`Http function processed request for url "${request.url}"`);

    try {
      const body = await request.json();

      // Handle Event Grid Validation Event
      if (
        body &&
        body[0] &&
        body[0].eventType === "Microsoft.EventGrid.SubscriptionValidationEvent"
      ) {
        const validationCode = body[0].data.validationCode;
        context.log(`Validation code received: ${validationCode}`);

        return {
          status: 200,
          body: JSON.stringify({
            validationResponse: validationCode,
          }),
          headers: {
            "Content-Type": "application/json",
          },
        };
      }

      context.log("Non-handshake request received:");
      context.log(JSON.stringify(body, null, 2));

      // Extract the FHIR resource URL from data.subject
      const fhirResourceUrl = `https://${body[0].subject}`; // Assuming data.subject is the FHIR resource URL
      context.log(`FHIR resource URL: ${fhirResourceUrl}`);

      const service = process.env.FHIR_SERVICE;

      // Fetch the full FHIR resource from the URL
      const clientSecret = await getClientSecret();
      const accessToken = await getAccessToken(clientSecret);

      const fhirResponse = await axios.get(fhirResourceUrl, {
        headers: {
          Authorization: `Bearer ${accessToken}`,
        },
      });

      const fullFhirResource = fhirResponse.data;
      let practitionerId = null;
      let patientId = null;
      let organizationId = null;
      if (
        fullFhirResource.participant &&
        Array.isArray(fullFhirResource.participant)
      ) {
        practitionerId = fullFhirResource.participant.find(
          (participant) =>
            participant.individual &&
            participant.individual.reference &&
            participant.individual.reference.startsWith("Practitioner/")
        )?.individual.reference;
      }
      if (fullFhirResource.subject && fullFhirResource.subject.reference) {
        patientId = fullFhirResource.subject.reference;
      }

      if (patientId) {
        patientId = patientId.replace("Patient/", "");
      }

      if (practitionerId) {
        practitionerId = practitionerId.replace("Practitioner/", "");
      }

      const fhirResponsePractitioner = await axios.get(
        service + "Practitioner/" + practitionerId,
        {
          headers: {
            Authorization: `Bearer ${accessToken}`,
          },
        }
      );

      const fhirResponsePatient = await axios.get(
        service + "Patient/" + patientId,
        {
          headers: {
            Authorization: `Bearer ${accessToken}`,
          },
        }
      );

      if (
        fhirResponsePatient.data.contact &&
        fhirResponsePatient.data.contact[0].organization
      ) {
        organizationId =
          fhirResponsePatient.data.contact[0].organization.reference;
      }

      if (organizationId) {
        organizationId = organizationId.replace("Organization/", "");
      }

      const fhirResponseOrganization = await axios.get(
        service + "Organization/" + organizationId,
        {
          headers: {
            Authorization: `Bearer ${accessToken}`,
          },
        }
      );

      body[1] = fullFhirResource;
      body[2] = fhirResponseOrganization.data;
      body[3] = fhirResponsePatient.data;
      body[4] = fhirResponsePractitioner.data;

      // Send SignalR messages with the Practitioner ID as target
      context.extraOutputs.set(goingOutToSignalR, {
        target: practitionerId || "123",
        arguments: [body], // Pass the Event Grid payload as the argument
      });

      return {
        status: 200,
        body: JSON.stringify({
          message: "Event data broadcasted to SignalR successfully",
          receivedEvent: body,
        }),
        headers: {
          "Content-Type": "application/json",
        },
      };
    } catch (error) {
      context.log(`Error processing request: ${error.message}`);
      return {
        status: 500,
        body: JSON.stringify({
          error: "Internal Server Error",
          message: error.message,
        }),
        headers: {
          "Content-Type": "application/json",
        },
      };
    }
  },
});

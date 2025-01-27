const { app, input } = require("@azure/functions");
const { WebPubSubServiceClient } = require("@azure/web-pubsub");

// Initialize Web PubSub Service Client
const hubName = "fhircontexttest";
const serviceClient = new WebPubSubServiceClient(
  process.env.WebPubSubConnectionString,
  hubName
);

app.http("PubSubNegotiate", {
  methods: ["GET", "POST"],
  authLevel: "anonymous",
  handler: async (request, context) => {
    try {
      const userId = request.query.get("userId") || "defaultUser";
      const tokenResponse = await serviceClient.getClientAccessToken({
        userId: userId,
      });

      return {
        status: 200,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type",
        },
        body: JSON.stringify({
          url: tokenResponse.url,
        }),
      };
    } catch (error) {
      context.log.error("Error generating connection info:", error);

      return {
        status: 500,
        body: "Failed to generate connection info.",
      };
    }
  },
});

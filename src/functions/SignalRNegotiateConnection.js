const { app, input, output } = require("@azure/functions");

// SignalR input for getting connection information
const inputSignalR = input.generic({
  type: "signalRConnectionInfo",
  name: "connectionInfo",
  hubName: "signalrfhir",
  connectionStringSetting: "SIGNALR_CONNECTION_STRING",
});

app.post("negotiate", {
  authLevel: "anonymous",
  handler: (request, context) => {
    try {
      // Return connection info to client for SignalR
      return {
        body: JSON.stringify(context.extraInputs.get(inputSignalR)),
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type",
        },
      };
    } catch (error) {
      context.log(error);
      return {
        status: 500,
        jsonBody: error,
      };
    }
  },
  route: "negotiate",
  extraInputs: [inputSignalR],
});

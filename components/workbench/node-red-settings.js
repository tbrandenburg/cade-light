module.exports = {
  uiHost: "0.0.0.0",
  uiPort: 1880,
  userDir: "/home/node/.node-red",
  // Built-in palette and user additions from config/node-red/package.json.
  nodesDir: "/opt/node-red/node_modules",
  credentialSecret: process.env.NODE_RED_CREDENTIAL_SECRET
};

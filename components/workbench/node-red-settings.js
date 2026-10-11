module.exports = {
  uiHost: "0.0.0.0",
  uiPort: 1880,
  userDir: "/home/node/.node-red",
  // Stable across container IDs. A startup deploy stages its working copy.
  flowFile: "flows.json",
  flowFilePretty: true,
  nodesDir: "/opt/node-red/node_modules",
  credentialSecret: process.env.NODE_RED_CREDENTIAL_SECRET,
  contextStorage: { default: { module: "localfilesystem" } }
};

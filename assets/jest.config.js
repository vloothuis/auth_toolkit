module.exports = {
  setupFilesAfterEnv: ["jest-prosemirror/environment"],
  testEnvironment: "jsdom",
  snapshotSerializers: ["jest-prosemirror/serializer"],
  moduleNameMapper: {
    "\\.(css|less|scss|sass)$": "<rootDir>/test/__mocks__/styleMock.js",
  },
};

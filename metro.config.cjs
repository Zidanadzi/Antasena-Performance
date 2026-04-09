const { getDefaultConfig } = require('expo/metro-config');
const path = require('path');

const config = getDefaultConfig(__dirname);

// Add support for resolving modules in the src directory
config.resolver.nodeModulesPaths = [
  path.resolve(__dirname, 'node_modules'),
];

// Ensure we handle all common extensions
config.resolver.sourceExts = [...config.resolver.sourceExts, 'cjs', 'mjs'];

// Ignore web-only files to prevent bundling issues
config.resolver.blockList = [
  /vite\.config\.ts$/,
  /index\.html$/,
  /\.github\/.*/,
];

module.exports = config;

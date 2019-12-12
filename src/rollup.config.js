const node = require('rollup-plugin-node-resolve');
const commonjs = require('rollup-plugin-commonjs');

module.exports = {
  plugins: [
    node({
      mainFields: ['browser', 'es2015', 'module', 'jsnext:main', 'main'],
    }),
    commonjs(),
  ],
  external: [
    'long',
    'protobufjs/minimal',
  ],
  output: {globals: {long: 'Long', 'protobufjs/minimal': 'protobuf'}}
};

const path = require('path');

const isDev = process.env.NODE_ENV !== 'production';

const _root = path.resolve(__dirname, '..');

function root(args) {
  args = Array.prototype.slice.call(arguments, 0);

  return path.join.apply(path, [_root].concat(args));
}

module.exports = {
  mode: 'development',

  entry: {
    polyfills: 'src/polyfills.ts',
    main: isDev ? 'src/main.dev.ts' : 'src/main.prod.ts'
  },

  resolve: {
    extensions: ['.ts', '.js', '.mjs', '.scss'],
    mainFields: ['browser', 'es2015', 'module', 'jsnext:main', 'main'],
    symlinks: false,
  },

  module: {
    rules: [
      {
        test: /\.html$/,
        loader: 'html-loader'
      },
      {
        test: /\.(scss|sass)$/,
        use: [
          { loader: 'style-loader', options: { sourceMap: isDev } },
          { loader: 'css-loader', options: { sourceMap: isDev } },
          { loader: 'sass-loader', options: { sourceMap: isDev } }
        ],
        include: root('src', 'assets')
      },
      {
        test: /\.(scss|sass)$/,
        use: [
          'to-string-loader',
          { loader: 'css-loader', options: { sourceMap: isDev } },
          { loader: 'sass-loader', options: { sourceMap: isDev } }
        ],
        include: root('src', 'app'),
      },
      {
        test: /\.mjs$/,
        // include: /node_modules/,
        type: "javascript/auto",
      }
    ]
  },

  plugins: [],
};

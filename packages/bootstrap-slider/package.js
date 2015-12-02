Package.describe({
  name: 'edemaine:bootstrap-slider',
  version: '1.0.1',
  // Brief, one-line summary of the package.
  summary: "seiyria's bootstrap-slider package",
  // URL to the Git repository containing the source code for this package.
  //git: '',
  // By default, Meteor will default to using README.md for documentation.
  // To avoid submitting documentation, set this field to null.
  documentation: 'README.md'
});

Package.onUse(function(api) {
  api.versionsFrom('1.2.1');
  api.use('ecmascript');
  api.export('Slider', 'client');
  api.addFiles(['bootstrap-slider.js', 'bootstrap-slider.css'], 'client');
});

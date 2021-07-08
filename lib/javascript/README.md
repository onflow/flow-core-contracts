# Important Notice

Please, do NOT edit or commit files in `generated` folder. All files in that folder will be deleted
by generator on next run, meaning your work will be lost. If you want to introduce changes to those
files - edit Handlebars templates or generator code.

# Development

## First steps

- Run `yarn precompile-handlebars` to precompile Handlebars templates
- Run `yarn generate-cadence-code` to generate Javascript files, which would export Cadence code
  together with other template information

## Publish

Package will be automatically published via CD/CI tools, when new changes are merged into `master`
branch, no need to do extra steps.

[![Gem Version](https://img.shields.io/gem/v/jekyll-manager.svg)](https://rubygems.org/gems/jekyll-manager)
[![Build Status](https://travis-ci.org/ashmaroli/jekyll-manager.svg?branch=master)](https://travis-ci.org/ashmaroli/jekyll-manager)
[![Build status](https://ci.appveyor.com/api/projects/status/biop1r6ae524xlm2/branch/master?svg=true)](https://ci.appveyor.com/project/ashmaroli/jekyll-manager/branch/master)
[![Coverage Status](https://coveralls.io/repos/github/ashmaroli/jekyll-manager/badge.svg?branch=master)](https://coveralls.io/github/ashmaroli/jekyll-manager?branch=master)
[![NPM Dependencies](https://david-dm.org/ashmaroli/jekyll-manager.svg)](https://david-dm.org/ashmaroli/jekyll-manager)

Forked from the official Jekyll plugin [Jekyll Admin](https://github.com/jekyll/jekyll-admin), Jekyll Manager provides users with a traditional CMS-style graphical interface to author content and administer Jekyll sites.<br/>
The project is divided into two parts. A Ruby-based HTTP API that handles Jekyll and filesystem operations, and a Javascript-based front end, built on that API.

![screenshot of Jekyll Manager](/screenshot.png)

## Installation

Refer to the [installing plugins](https://jekyllrb.com/docs/plugins/#installing-a-plugin) section of Jekyll's documentation and install the `jekyll-manager` plugin as you would any other plugin. Here's the short version:

1. Add the following to your site's Gemfile:

    ```ruby
    gem 'jekyll-manager', group: :jekyll_plugins
    ```

2. Run `bundle install`

## Usage

1. Start Jekyll as you would normally (`bundle exec jekyll serve`)
2. Navigate to `http://localhost:4000/admin` to access the administrative interface


## Divergence

Jekyll Manager is an open source project, forked from the official Jekyll plugin [Jekyll Admin](https://github.com/jekyll/jekyll-admin), and repackaged with some alterations and additions, a few of which, may eventually be included in the official version.

### Notable alterations:

  * Sidebar routes cannot be manually hidden. They're rendered based on whether Jekyll has read-in at least one file of the concerned type.
  * Routes to Collections other than Posts are hidden within a collapsed list-item by default.
  * Metadata fields for front matter are hidden with a collapsed section by default.
  * Input path fields show / require the full `relative_path` of the requested file.
  * Minor style changes.
  * Other miscellaneous changes.

### Additional Features:

  * A basic dashboard that provides insight on the current site and a means to add files to cetain empty content types (*Pages, Posts, Data Files, Static Files*).
  * Draft posts can be created and edited via the admin interface provided your config file has `show_drafts: true`
  * Template files (files within `_layouts`, `_includes`, `_sass` and `assets` at the root of your site) can be edited via the interface.
  * Template files (and files within any directory) within a theme-gem can be *viewed* and copied over to the source directory for editing.
  * Ability to select layouts for a document based on available layouts in the Site.
  * Special metadata field for tags.


## Contributing

Unless your contribution improves the changes outlined above or updates this repo's documentation, we'd appreciate it if you propose those changes at the upstream repo. Upstream changes *may* eventually find their way here after being altered as
required.

Interested in contributing to Jekyll Manager anyways?. See [the contributing instructions](.github/CONTRIBUTING.md), and [the development docs](http://ashmaroli.github.io/jekyll-manager/development/) for more information.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

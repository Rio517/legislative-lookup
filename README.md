# Project Tigress

## Description

Rails application and database to lookup congressional and state legislative districts by latitude and longitude.

## Dependencies

Install Postgres (9.1+) and postGIS (2+), set up a database, apply the appropriate functions and populate it.  The following works, but most up to date instructions can be found at the source: http://postgis.net/install/


### Postsgres for Ubuntu 11.04

Install Postgress

    sudo apt-get install postgresql-contrib postgresql postgresql-9.3-postgis libpq-dev gdal-bin

Postgres won't let you connect without a password out of the box. Create a new postgres user with a password or configure postgres to trust all connections from localhost and make sure the "postgres" user in postgres doesn't have a password. These instruction assume the later. You can do that by editing `/etc/postgresql/8.4/main/pg_hba.conf` and adding a line ABOVE THE DEFAULT RULES like below.  Make sure there are no overrides further down in your file:

    host    all         postgres    127.0.0.1/32          trust

### Postsgres for OSX

Download postgres.app from http://postgresapp.com/.
Extract it.
Copy it to Applications.

* `$ sudo cp /Applications/Postgres.app/Contents/MacOS/lib/libjpeg* /usr/local/lib` to make postgis work with postgres.app
* Run `postgres.app.`

## Creating the DB, enabling postgres and seeding the DB

After making any necessary updates to `database.yml`, the following would create the DB, enable postgis and seed it with test data for Rhode Island from db/test_data.sql.tar.gz.  If you're going to use the importers or don't need test data, leave off `rake db:seed`

    rake db:create db:add_postgis db:migrate db:seed


### Starting the App

    bundle install
    rails server #note page may not load due to needed data.


## Loading Real Data

The `DatasetImporter` classes and subclasses have importers for census data and several state level data.  As of April 2014, censuses GIS files did not have correct state level legislative districts, hence the need for state level data. The DatasetImporter(s) essentially execute the following basic process:

1. Download zipfiles from relevant sources
2. Extract shapefiles
3. Assess coordinate systems
4. Import data to postgres, with correct coordinate mappings
5. Normalize naming conventions among the datasets
6. Combine data into a `pending_districts` table
7. Run `Scheduler.schedule!` to assign the correct valid dates to imported datasets.  Valid districts are pulled unless a date param is submitted.
8. Move `pending_districts` to the app's expected `districts` table for use in the app.

You can execute this import process by running the following from `rails console`:

    DatasetImporter::Base.import_and_process!
    DatasetImporter::Base.temp_to_live! #when ready

## Updating Datasets

When new datasets are required or available, a few steps are required to update importing classes for new data.

###Census

If new census tiger files are available, you should:

1. Add `DatasetImporter.new(:year => YYYY)` to the import commands in `DatasetImporter::Base`.
2. Add a new session key to SESSION_KEYS `in DatasetImporter::Census`
3. Update Scheduler with the relevant dates for your new dataset.


### State Level Data

While note difficult creating state level imports can be more challenging.  You'll have to get more into the code.

1. Find the urls for the zip files you'll need to download.
2. Create a new `DatasetImporter::StateAbbreviation < DatasetImporter::StateBase` for your state.
3. Update and modify the four methods from, for example, `DatasetImporter::Ky` as appropriate for your data.
4. Update Scheduler with the relevant dates for your new dataset.
5. Add an import command to `DatasetImporter::Base`.

The above steps have been completed for [http://congress.mcommons.org](http://congress.mcommons.org).

## Testing

To run specs, you need to seed the database with sample polygons.  This repo contains sql imports for Rhode Island. To execute run:

    rake db:test:prepare # redefined in lib/tasks/database.rb
    rake spec


## Authors

 - [Nathan Woodhull](mailto:nathan@mcommons.com)
 - [Benjamin Stein](mailto:ben@mcommons.com)
 - [Mal McKay](mailto:mal@mcommons.com)
 - [Mario Olivio Flores](mailto:mflores3@gmail.com)
 - [Dan Benamy](mailto:dbenamy@mcommons.com)
 - Special thanks to the research of [Katherine Snedden](mailto:katherine@mobilecommons.com)

Project sponsored by [Mobile Commons](http://www.mobilecommons.com/)


## License

Copyright (c) 2008-2014 Mobile Commons
See MIT-LICENSE in this directory.

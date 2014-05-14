# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20140403202836) do

  create_table "datasets", :force => true do |t|
    t.string "source_organization"
    t.string "source_url"
    t.string "source_type"
    t.string "source_identifer"
    t.string "epsg_code"
  end

  add_index "datasets", ["source_identifer"], :name => "index_datasets_on_source_identifer"

  create_table "districts", :force => true do |t|
    t.string        "state"
    t.string        "cd"
    t.string        "name"
    t.string        "level"
    t.multi_polygon "the_geom",   :limit => nil, :srid => 0
    t.integer       "dataset_id"
    t.datetime      "expires_at"
    t.datetime      "valid_at"
  end

  add_index "districts", ["dataset_id"], :name => "index_districts_on_dataset_id"
  add_index "districts", ["expires_at"], :name => "index_districts_on_expires_at"
  add_index "districts", ["level"], :name => "index_districts_on_level"
  add_index "districts", ["state"], :name => "index_districts_on_state"
  add_index "districts", ["the_geom"], :name => "index_districts_on_the_geom", :spatial => true
  add_index "districts", ["valid_at"], :name => "index_districts_on_valid_at"

end

class CreateDatasets < ActiveRecord::Migration
  def self.up
    create_table :datasets do |t|
      t.string   :source_organization, :source_url, :source_type, :source_identifer, :epsg_code
      t.references
    end
    add_index :datasets, :source_identifer

    add_column :districts, :dataset_id, :integer
    add_column :districts, :expires_at, :datetime
    add_column :districts, :valid_at, :datetime

    add_index  :districts, :dataset_id
    add_index :districts, :state
    add_index :districts, :level
    add_index :districts, :valid_at
    add_index :districts, :expires_at
  end

  def self.down
    drop_table :dataset_sources
    remove_column :districts, :expires_at
    remove_column :districts, :valid_at
    remove_column :districts, :dataset_id
  end
end

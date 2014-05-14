  class DatasetImporter::StateBase < DatasetImporter::Base

  def import_and_process!(options={})
    self.download! if options[:download] == true
    self.unzip! if options[:unzip] == true
    self.store_dataset_origin!
    self.import_shapefiles!
    self.combine_and_normalize!
    self.merge_into_pending_data!
  end

  def state_name
    self.class.name.demodulize.downcase
  end

  def fips_code
    District::STATES[state_name.upcase]
  end

  private

  def rename_or_insert_into_combined(current_table_name)
    if !self.connection.table_exists?(temp_table_name)
      self.connection.execute "ALTER TABLE #{current_table_name} RENAME TO #{temp_table_name}"
    else
      self.connection.execute("INSERT INTO #{temp_table_name} SELECT * FROM #{current_table_name}")
      self.connection.drop_table(current_table_name)
    end
  end

  def normalize_level_table(current_table_name,level_name)
    level_name = 'state'+level_name
    self.connection.execute "ALTER TABLE ONLY #{current_table_name} DROP CONSTRAINT #{[current_table_name, 'pk'].join('_')}"
    self.connection.execute "DROP INDEX #{[current_table_name, 'geom_idx'].join('_')}"
    self.connection.add_column current_table_name, :level, :string
    self.connection.execute "UPDATE #{current_table_name} SET level = '#{level_name}'"
  end

  def normalize_combined_data(district_field='ogc_fid')
    self.connection.add_column temp_table_name, :state, :string, :limit => 2
    self.connection.add_column temp_table_name, :dataset_id, :integer
    self.connection.add_column temp_table_name, :cd, :string, :limit => 3
    self.connection.add_column temp_table_name, :name, :string

    self.connection.execute "UPDATE #{temp_table_name} SET state = '#{self.fips_code}'"
    self.connection.execute "UPDATE #{temp_table_name} SET cd = #{district_field}"
    self.connection.execute "UPDATE #{temp_table_name} SET name = #{district_field}"
    self.connection.remove_column temp_table_name, :ogc_fid
  end

  def temp_table_name
    "temp_#{self.state_name}_districts"
  end

  def zip_files_directory
    "db/zips/#{self.state_name}"
  end

  def shape_files_directory
    "db/shapes/#{self.state_name}"
  end

end
class DatasetImporter::Census < DatasetImporter::Base

  SESSION_KEYS = {
    '2013' => '113',
    '2011' => '112',
    '2010' => '111'
  }

  def initialize(new_attributes={})
    super(new_attributes)
    raise 'You need to supply a year, eg: `:year => 2013' if self.year.blank?
    self.year = self.year.to_s
  end

  def import_and_process!(options={})
    self.download! if options[:download] == true
    self.unzip! if options[:unzip] == true
    self.store_dataset_origin!
    self.import_shapefiles!
    self.combine_and_normalize!
    self.merge_into_pending_data!
  end

  def download!
    self.create_path_and_clean!(self.zip_files_directory, false)
    self.ftp_root_url  = "ftp://ftp2.census.gov/geo/tiger/TIGER#{year}/"
    p "Downloading federal level data w/ #{download_command}"
    download_file(federal_level_path,federal_level_filename)
    District::FIPS_CODES.sort_by{|k,v| k }.each do |fips_code, state_name|
      %w[sldu sldl].each{|level| download_file(state_level_path(level),state_level_filename(level,fips_code)) }
    end
  end

  def clear_temp_tables!
    %w[federal lower upper].each do |table_suffix|
      table_name = temp_tables_prefix + table_suffix
      self.connection.drop_table(table_name) if self.connection.table_exists?(table_name)
      self.connection.execute("DROP index if exists #{table_name}_geom_idx")
    end
  end

  def import_shapefiles!
    clear_temp_tables!
    import_shapefile_processor do |shape_file|
      temp_tables_prefix + case shape_file
        when /cd#{congressional_session}/ then 'federal'
        when /sldl/ then 'lower'
        when /sldu/ then 'upper'
        else puts "WARNING! Unrecongnized shapefile: #{shape_file}" && next
      end
    end
  end

  def combine_and_normalize!
    self.federal_to_combined_districs!
    self.state_to_combined_districs!

    store_dataset_origin!
    update_dataset_ref
  end

  def federal_to_combined_districs!
    p 'Moving federal level data into temp_districts table.'
    ActiveRecord::Base.transaction do
      federal_table_name = temp_tables_prefix + 'federal'

      self.remove_unneeded_year_references!(federal_table_name) if year_in_path
      self.remove_unneeded_columns!(federal_table_name)


      {:state => 'statefp',:cd => "cd#{congressional_session}fp"}.each do |system_name,imported_name|
        self.connection.rename_column federal_table_name, imported_name, system_name
      end
      self.connection.change_column federal_table_name, :cd, :string, :limit => 3
      self.connection.add_column federal_table_name, :level, :string
      self.connection.add_column federal_table_name, :name, :string
      self.connection.execute "UPDATE #{federal_table_name} SET level = 'federal'"

      self.connection.drop_table(self.temp_table_name) if self.connection.table_exists?(self.temp_table_name)
      self.connection.execute "ALTER TABLE #{federal_table_name} RENAME TO #{self.temp_table_name}"
    end

    if self.connection.table_exists?(:temp_districts) #can't be done in transaction
      self.connection.execute "DROP INDEX #{federal_table_name}_geom_pk"
      self.connection.execute "DROP INDEX #{federal_table_name}_geom_idx"
    end
  end

  def state_to_combined_districs!
    p "Moving state level data into #{temp_tables_prefix}districts table."

    %w[lower upper].each do |level_name|
      current_table_name = temp_tables_prefix + level_name

      self.remove_unneeded_year_references!(current_table_name) if year_in_path

      ActiveRecord::Base.transaction do
        p "inserting #{current_table_name} into #{self.temp_table_name}"
        self.connection.execute(
          "INSERT INTO #{self.temp_table_name} (state,   cd,                        name,     the_geom, level)
           SELECT                               statefp, sld#{level_name[0,1]}st,   namelsad, the_geom, 'state_#{level_name}'
           FROM #{current_table_name}")
        self.connection.drop_table(current_table_name)
      end
    end
  end

  def dataset_attributes(options={})
    {
      :table_name          => options[:table_name] || self.temp_table_name,
      :source_type         => 'national',
      :source_organization => 'U.S. Census',
      :source_url          => 'http://www.census.gov/geo/maps-data/data/tiger-line.html#tab_' + (options[:tab_id] || self.year),
      :source_identifer    => options[:source_identifer] || source_identifer,
    }
  end

  def source_identifer
    'census' + self.year
  end

  def zip_files_directory
    "db/zips/#{self.year}"
  end

  def shape_files_directory
    "db/shapes/#{self.year}"
  end

  def temp_table_name
    temp_tables_prefix + 'districts'
  end

  def remove_unneeded_year_references!(table_name)
    class_name = "Rename#{table_name.camelcase}District"
    Object.const_set(class_name, Class.new(ActiveRecord::Base) {self.table_name = table_name})
    ActiveRecord::Base.transaction do
      class_name.constantize.column_names.select{|name| name =~ /#{year_abbreviation}/ }.each do |column_name|
        self.connection.rename_column table_name, column_name, column_name.gsub('10','')  #table references are loaded at app/console start time.  Running multiple times may cause errors.
      end
    end
  end

  private

  def year_abbreviation
    self.year[2..-1]
  end

  def temp_tables_prefix
    'temp_' + self.year + '_'
  end

  def congressional_session
    SESSION_KEYS[self.year.to_s]
  end

  def year_in_path
    self.year == '2010'
  end

  def federal_level_filename
    'tl_' + self.year + '_us_cd' + congressional_session + '.zip'
  end

  def federal_level_path
    file_url = self.ftp_root_url + 'CD/'
    file_url.gsub!('CD/','CD/'+congressional_session) if year_in_path
    file_url
  end

  def state_level_filename(level,fips_code)
    filename = 'tl_' + self.year + '_' + fips_code + '_'+level+'.zip'
    filename.gsub!('.zip',year_abbreviation+'.zip') if year_in_path
    puts "filename: #{filename}"
    filename
  end

  def state_level_path(level)
    file_url = self.ftp_root_url + level.upcase + '/'
    file_url.gsub!(level.upcase + '/',level.upcase + self.year + '/') if year_in_path
    file_url
  end

end